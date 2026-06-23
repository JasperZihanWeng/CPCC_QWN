`timescale 1ns/1ps
//==============================================================================
// rx_oversample_cdr_64 -- ROLE IN THE SYSTEM (QWN marker-jitter campaign,
// see docs/CAMPAIGN_BRIEF_2026-06.md, the authoritative narrative).
//
// This is the fabric clock-data-recovery (CDR) stage of the RX chain:
//
//   GT raw 64-bit RX -> [THIS] -> rx_frame_par -> rx_header -> rx_gate
//                                              -> mark_oserdes -> pin N41
//
// FPGA BASICS -- why a CDR in fabric at all: the 7-series GTH runs at
// 10 Gb/s line rate with ALL hard RX blocks bypassed (RXBUF_EN=FALSE, no
// comma align, no 8B/10B): RXDATA is just 64 raw line samples per rxusrclk2
// cycle (156.25 MHz, 6.4 ns). The real payload is 1.25 Gb/s 8B/10B, so each
// data bit -- one "UI" (unit interval) = 800 ps -- appears as OS=8 consecutive
// samples (100 ps/sample). This is BLIND 8x OVERSAMPLING: the sample clock is
// never phase-aligned to the data; we sample fast and decide IN LOGIC which
// samples are bit centers. RXOUTCLKSEL=RXOUTCLKPMA makes rxusrclk2 the
// RECOVERED clock (tracks the remote TX via the GT's CDR), so in steady
// state exactly 8 data bits arrive per 64-bit word, with NO ppm slip -- the
// foundation for rx_gate's free-running cycle count through the dark gap.
//
// ALGORITHM (per 64-bit word, sample [0] earliest):
//   1. e[k]   = transition between sample k-1 and k (data edges land at bit
//               boundaries; between edges the line is flat for >=8 samples).
//   2. scan   = for every k, find the RIGHTMOST edge at index <= k
//               (parallel-prefix, see Stage A below).
//   3. cnt[k] = samples elapsed since that edge; capture the sample where
//               cnt == HALF (4 samples = 400 ps after the edge), i.e. the
//               nominal CENTER of the 800 ps bit cell -- maximum margin
//               against edge jitter on both sides.
//   4. compact the 0..8 captured samples into rbits_o[7:0] ([0] earliest)
//               with a prefix-sum scatter; rcnt_o = how many are valid.
//
// EDGE PHASE (eph, reph_o): the sub-UI phase of the data stream relative to
// the 8-sample grid -- "(index of the last edge in the word)+1 mod 8", i.e.
// which of the 8 sample slots is the FIRST sample of a bit cell. Units:
// 1 eph step = 1 sample = 100 ps. Per burst the GT CDR re-locks at an
// arbitrary phase, so eph is random per burst but quasi-static within one;
// downstream it drives the ODELAYE2 sub-UI marker trim (raw in early builds,
// filtered+anchored split-role since B8 -- see eph_filter / rx_gate).
//
// BUILD HISTORY: the 1-stage (fully combinational + output reg) version was
// functionally proven but became the recurring route-marginal timing cone of
// the design (deep scan + prefix-sum + scatter in one 6.4 ns cycle). This
// pipelined rewrite is a pure timing-closure restructure -- bit-exact
// behavior verified by the alignment-tolerant equivalence TB tb_cdr64_equiv
// (same {bits,cnt,eph} stream, output latency ignored).
//==============================================================================
// rx_oversample_cdr_64 -- parallel-prefix CDR, 2-STAGE (timing-closing).
//
// Methodical pipelining of the PROVEN 1-stage logic:
//   STAGE A: edges -> 6-level last-edge scan -> per-sample armd/cnt/cap, AND
//            the cross-word carry (depends only on the shallow scan tail ->
//            single-cycle, NO pipeline-feedback hazard). Registers
//            cap_r/word_r/eph_r (pure feed-forward to stage B).
//   STAGE B: ripple prefix-sum + scatter on cap_r/word_r -> rbits_o.
// Only the feed-forward output compaction is pipelined; the carry recurrence
// stays single-cycle. Ripple prefix-sum kept EXACTLY as proven (no parallel-
// prefix change here -- isolate one variable). +1 output latency; the
// equivalence TB (tb_cdr64_equiv) is alignment-tolerant so latency is fine.
//==============================================================================
// HISTORY NOTE (the block above is kept verbatim but describes the FIRST
// pipelined revision; the code below is the FINAL one): after the 2-stage
// rev, Stage B itself was split again because the ripple prefix-sum cone was
// still marginal. Final structure = THREE register stages:
//   A  : edges/scan/capture decisions + the carry recurrence (single-cycle)
//   B1 : LOG-DEPTH (Kogge-Stone-style) prefix-sum, registered in incl_r
//   B2 : shallow scatter -> output registers
// so "ripple ... kept EXACTLY" no longer holds (B1 is parallel-prefix now)
// and total latency is 3 clk cycles word_i -> rbits_o (+2 vs the unpipelined
// original). Still covered by the alignment-tolerant tb_cdr64_equiv.
//
// FPGA BASICS -- why pipelining is shaped this way: a RECURRENCE (state that
// next cycle's input depends on) can never simply be pipelined -- inserting a
// register into the loop changes behavior. The trick used here (and copied
// in rx_frame_par) is to split the logic into (a) the minimal recurrence,
// kept single-cycle, and (b) everything that is pure FEED-FORWARD, which can
// absorb extra register stages for free because nothing loops back. The
// carry here (c_*) depends only on sample 63's scan result -- a shallow cone
// -- so it closes timing in one cycle; the expensive compaction is all
// feed-forward and takes the extra latency.
//==============================================================================
module rx_oversample_cdr_64 #(
    parameter OS = 8
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [63:0] word_i,
    output reg  [7:0]  rbits_o,
    output reg  [3:0]  rcnt_o,
    output reg  [3:0]  reph_o
);
    // Bit-pick point: HALF = OS/2 = 4 samples (400 ps) after a detected edge
    // = the nominal center of the 800 ps bit cell.
    localparam [2:0] HALF = OS/2;

    // Word-boundary CARRY state (the single-cycle recurrence). A bit cell can
    // straddle two 64-bit words, so the per-sample logic needs, at sample 0:
    //   c_sd    = last line sample of the previous word (for edge detect e[0])
    //   c_armed = "have we EVER seen an edge" (no captures before first edge)
    //   c_cnt   = samples-since-last-edge count, continued across the seam
    //   c_eph   = last computed edge phase (held through edge-free words,
    //             e.g. long runs without transitions)
    //   c_sph   = sample-phase offset of the grid; held at its reset value 0
    //             in this design (vestigial generality), so eph is simply
    //             relative to the word boundary.
    reg        c_sd, c_armed;
    reg  [2:0] c_cnt, c_sph, c_eph;
    integer ke, ks,ss,ds, kp, kr, kw, kq,sq,dq;

    // ---- STAGE A : edges ----
    // e[k]=1 iff the line toggled between sample k-1 and k. Sample 0 compares
    // against c_sd (last sample of the previous word) so edges on the word
    // seam are not lost. With 8x oversampling a legal data stream toggles at
    // most once per 8 samples, so edges are sparse by construction.
    reg [63:0] e;
    always @* begin
        e[0] = word_i[0] ^ c_sd;
        for (ke=1;ke<64;ke=ke+1) e[ke] = word_i[ke] ^ word_i[ke-1];
    end
    // ---- STAGE A : 6-level scan (rightmost edge index <= k) ----
    // FPGA BASICS -- parallel-prefix scan: every sample k needs "where was
    // the last edge at or before me?". A naive priority chain is a 64-deep
    // serial cone (hopeless at 6.4 ns with everything else). Instead, doubling
    // strides: after level s, (sv,si)[s][k] summarize the window
    // [k-2^s+1 .. k] -- each level merges a window with the same-size window
    // 2^(s-1) further left, preferring the RIGHT (nearer) hit. 6 levels cover
    // 2^6=64 samples: log-depth (6 muxes) instead of linear (64). Same idea
    // as a Kogge-Stone carry tree, computing "last edge" instead of carries.
    //   sv[6][k] = an edge exists somewhere in [0..k]
    //   si[6][k] = index of the rightmost such edge
    reg        sv [0:6][0:63];
    reg  [5:0] si [0:6][0:63];
    always @* begin
        for (ks=0;ks<64;ks=ks+1) begin sv[0][ks]=e[ks]; si[0][ks]=ks[5:0]; end
        for (ss=1;ss<=6;ss=ss+1) begin
            ds=(1<<(ss-1));
            for (ks=0;ks<64;ks=ks+1) begin
                if (sv[ss-1][ks])                   begin sv[ss][ks]=1'b1; si[ss][ks]=si[ss-1][ks]; end
                else if (ks>=ds && sv[ss-1][ks-ds]) begin sv[ss][ks]=1'b1; si[ss][ks]=si[ss-1][ks-ds]; end
                else                                begin sv[ss][ks]=1'b0; si[ss][ks]=6'd0; end
            end
        end
    end
    // ---- STAGE A : per-sample shallow logic ----
    // For each sample k:
    //   armd[k] : at least one edge seen ever (this word or carried) -- no
    //             captures allowed before the first edge after reset.
    //   cnt[k]  : samples since the last edge, +1 because the count is "age
    //             of this sample relative to the edge sample". If no edge yet
    //             in this word, continue the carried count c_cnt. km is 7 bits
    //             so the index arithmetic can't wrap before the mod-8
    //             truncation to cnt[k] -- between edges the line is flat, so
    //             counting mod 8 just keeps capturing every 8th sample
    //             (exactly what a run of identical bits needs).
    //   cap[k]  : pick this sample as a data bit when it sits HALF=4 samples
    //             after the most recent edge (bit-cell center).
    reg  [2:0] cnt  [0:63];
    reg        armd [0:63];
    reg        cap  [0:63];
    reg  [6:0] km;
    always @* begin
        for (kp=0;kp<64;kp=kp+1) begin
            armd[kp] = c_armed | sv[6][kp];
            if (sv[6][kp]) km = (kp - si[6][kp]) + 7'd1;
            else           km = c_cnt + kp[6:0] + 7'd1;
            cnt[kp] = km[2:0];
            cap[kp] = armd[kp] & (cnt[kp]==HALF);
        end
    end
    // Edge phase from the LAST edge in the word (sample 63's scan result):
    // eph = (index_of_last_edge + 1) mod 8 = the sample slot where the new
    // bit cell STARTS. Held (c_eph) through edge-free words so eph stays
    // valid during runs without transitions. c_sph is constant 0 (see carry
    // block above), so the addition is effectively le_63 mod 8 + 1.
    // 1 eph step = 100 ps; this is the sub-UI number the whole marker-trim
    // chain (eph_filter -> rx_gate -> ODELAYE2) is built on.
    wire       le_v63  = sv[6][63];
    wire [5:0] le_63   = si[6][63];
    wire [2:0] eph_out = le_v63 ? (c_sph + le_63[2:0] + 3'd1) : c_eph;

    // ---- STAGE A registers : carry (single-cycle) + feed-forward to B ----
    // The c_* updates ARE the recurrence (next word's stage A reads them) and
    // therefore must settle in one cycle; cap_r/word_r/eph_r are the pure
    // feed-forward snapshot handed to stage B. word_i is carried alongside
    // cap_r because the scatter needs the original sample VALUES, and both
    // must stay from the SAME word.
    reg [63:0] cap_r, word_r;
    reg  [2:0] eph_r;
    always @(posedge clk) begin
        if (rst) begin
            c_sd<=1'b0; c_armed<=1'b0; c_cnt<=3'd0; c_sph<=3'd0; c_eph<=3'd0;
            cap_r<=64'd0; word_r<=64'd0; eph_r<=3'd0;
        end else begin
            for (kw=0;kw<64;kw=kw+1) cap_r[kw] <= cap[kw];
            word_r <= word_i;
            eph_r  <= eph_out;
            c_sd    <= word_i[63];
            c_armed <= armd[63];
            c_cnt   <= cnt[63];
            c_sph   <= c_sph;
            c_eph   <= eph_out;
        end
    end

    // ---- STAGE B1 : log-depth prefix-sum (route-localized) ----
    // pq[6][k] = number of captured samples at indices [0..k] (INCLUSIVE
    // prefix sum) -- this tells each captured bit which output slot it owns.
    // Same doubling-stride trick as the edge scan: 6 add levels instead of a
    // 64-deep ripple chain ("route-localized": each level only talks to a
    // neighbor 2^(s-1) away, so placement stays compact). This replaced the
    // original ripple sum when it became the timing bottleneck (see HISTORY
    // NOTE in the header).
    reg  [6:0] pq [0:6][0:63];
    always @* begin
        for (kq=0;kq<64;kq=kq+1) pq[0][kq] = {6'd0,cap_r[kq]};
        for (sq=1;sq<=6;sq=sq+1) begin
            dq=(1<<(sq-1));
            for (kq=0;kq<64;kq=kq+1)
                pq[sq][kq] = (kq>=dq) ? (pq[sq-1][kq]+pq[sq-1][kq-dq])
                                      :  pq[sq-1][kq];
        end
    end
    // B1 registers : carry the inclusive prefix-sum + cap/word/eph forward
    reg  [6:0] incl_r [0:63];
    reg [63:0] cap_r2, word_r2;
    reg  [2:0] eph_r2;
    always @(posedge clk) begin
        if (rst) begin
            cap_r2<=64'd0; word_r2<=64'd0; eph_r2<=3'd0;
            for (kw=0;kw<64;kw=kw+1) incl_r[kw]<=7'd0;
        end else begin
            for (kw=0;kw<64;kw=kw+1) incl_r[kw] <= pq[6][kw];
            cap_r2 <= cap_r;
            word_r2<= word_r;
            eph_r2 <= eph_r;
        end
    end

    // ---- STAGE B2 : scatter (shallow, route-localized) ----
    // Compaction: captured sample at index kr goes to output bit "number of
    // captures BEFORE kr" (= inclusive sum minus its own cap bit = EXCLUSIVE
    // prefix). ncap = total captures this word: exactly 8 in steady state
    // (recovered clock, no ppm), fewer/more transiently around a GT CDR
    // re-lock. The slot<8 guard silently drops a 9th capture in such a
    // transient word -- harmless, since the framer downstream re-locks on the
    // warmup commas anyway.
    reg  [6:0] slot;
    reg  [7:0] packed;
    reg  [3:0] ncap;
    always @* begin
        ncap   = incl_r[63][3:0];
        packed = 8'd0;
        for (kr=0;kr<64;kr=kr+1) begin
            slot = incl_r[kr] - {6'd0,cap_r2[kr]};    // exclusive prefix
            if (cap_r2[kr] && slot < 7'd8) packed[slot[2:0]] = word_r2[kr];
        end
    end
    // Output registers (3rd pipeline stage). Total latency word_i -> rbits_o
    // = 3 clk. reph_o is zero-extended to 4 bits (port width predates the
    // 3-bit eph) and is pipeline-aligned with the bits it describes -- the
    // downstream consumers (eph_filter, rx_gate fiducial latch) rely on that
    // alignment, not on absolute latency.
    always @(posedge clk) begin
        if (rst) begin rbits_o<=8'd0; rcnt_o<=4'd0; reph_o<=4'd0; end
        else begin
            rbits_o <= packed;
            rcnt_o  <= ncap;
            reph_o  <= {1'b0,eph_r2};
        end
    end
endmodule
