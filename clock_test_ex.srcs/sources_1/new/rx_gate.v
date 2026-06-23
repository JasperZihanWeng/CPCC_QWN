`timescale 1ns/1ps
//==============================================================================
// rx_gate v2 -- deterministic payload-start marker, FREE-RUNNING from the
// fiducial (spans the laser-off dark protection gap).
//
// Model (confirmed): the "header" is the entire laser-on classical-comms burst
// (WARMUP..FID..header fields..PRBS). After it the laser turns OFF, then a
// DARK PROTECTION gap, then the (external optical) quantum payload. The marker
// must fire at quantum-payload start -- i.e. it must count THROUGH a dark gap
// with no recovered bytes.
//
// So v2 counts FREE-RUNNING rxusrclk2 cycles from fid_pulse (NOT byte_valid):
// rxusrclk2 keeps running off the Si570/QPLL through the laser-off gap
// (RXCDRHOLD only freezes CDR phase), and the bit rate is ppm-free intra-burst
// -- so a pure cycle count from the fiducial deterministically spans both the
// laser-on header AND the dark protection. gate_delay_i is now in rxusrclk2
// CYCLES (TX-computed: header-content cycles + protection cycles). eph latched
// at the fiducial -> ODELAY sub-UI fine. [B8 update to that sentence: there
// are now TWO eph inputs with SPLIT roles -- instantaneous for the borrow,
// filtered-and-anchored for the trim; see the port comments.] CAL_OFFSET
// absorbs the fixed fid_pulse / pipeline skew (sim-tuned, then HW Phase-1B).
//
// `bv` is retained on the port for interface compatibility but is unused in
// v2 (the count is no longer byte-gated).
//==============================================================================
// BUILD CHRONOLOGY of this module (see docs/CAMPAIGN_BRIEF_2026-06.md for
// the full campaign record; sigma ledger ~2000 ps -> 88.4 ps over B3..B8):
//   - v2 base     : free-running count + hdr_valid fire-gating
//                   (sim tb_pdark_resid: dark garbage -> false fid -> the
//                   old byte-gated version fired a SPURIOUS marker).
//   - Build B4    : gate_ui_o commit latch added -- the raw rx_header
//                   ui_offset was stale at gate time on ~5% of bursts
//                   (rewritten by dark false fids mid-countdown); sim
//                   tb_stale_ui. Measured actual event rate 0.03% (B6).
//   - Build B8    : split-role eph (eph_inst_i borrow / eph_filt_i trim,
//                   anchored math below; sim tb_eph_jitter); main-bin 99.2%,
//                   early tail 7.3% -> 0.65% on the bench.
//   - Build B9    : veto v1, VETO_TH=24 (150 ps) -- NEGATIVE RESULT, kept in
//                   the record (see VETO_TH parameter comment).
//   - Build B11   : VETO_TH retuned 24->48 (300 ps); JTAG-validated,
//                   analog verdict pending (bench scope signals lost).
//   - armed_o     : consumed by rxcdrhold_ctrl's gate_pending deferral (B5):
//                   never let the CDR hold/track policy reopen the recovered-
//                   clock grid while a gate countdown is in flight.
//
// FPGA BASICS -- the COMMIT-LATCH discipline (invented during B4 and used
// for gate_fine/gate_inst/gate_ui alike): every per-burst decision input is
// snapshotted in ONE place at ONE instant (the arm, = the fiducial cycle).
// After that, no in-domain churn -- false fiducials, re-align snaps, eph
// drift in dark -- can touch the armed gate. The alternative ("read the live
// register when needed") silently couples the gate to everything that can
// rewrite that register during the ~2200-cycle countdown. Rule of thumb:
// if a value is consumed long after it is decided, latch it at the decision.
//==============================================================================
module rx_gate #(
    // B9->B11 VETO RETUNE: TH=24 (150ps) vetoed 14.75% of bursts for ZERO
    // sigma benefit (b9_final.csv) -- on HW the INST eph is >=2 steps off on
    // ~15% of bursts and the anchored FILTER was silently correcting exactly
    // those (the B8 tail fix). Large disagreement = the correction WORKING.
    // Veto only the genuinely ambiguous regime: near the +-4-step circular-
    // distance boundary the wrap direction is unknowable -> TH=48 (300ps,
    // 3 steps). Expected veto rate ~1%; residual -300ps events are SMALL-
    // disagreement bursts (different mechanism, not veto-addressable).
    parameter signed [9:0]  VETO_TH    = 10'sd48,
    parameter signed [15:0] CAL_OFFSET = -16'sd1  // fixed fid/pipeline skew
                                  // (cyc); sim-tuned: gate fired fid+gd+1 ->
                                  // -1 lands the marker exactly at gd. Common
                                  // to both lanes -> cancels in signal-idler.
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        bv,            // (unused in v2; kept for interface compat)
    // B8 SPLIT-ROLE sub-UI phase (tb_eph_jitter proved the naive swap wrong):
    //  - eph_inst_i: this burst's instantaneous CDR edge phase. CORRELATED
    //    with this burst's framer k decision -> stays the BORROW authority
    //    (a long-term average decorrelates from k -> +-800ps flips at the
    //    slot boundary under jitter).
    //  - eph_filt_i: circular-EMA estimate (eph_filter). Better magnitude ->
    //    TRIM authority, expressed in the inst-ANCHORED frame below.
    input  wire [2:0]  eph_inst_i,
    input  wire [6:0]  eph_filt_i,    // {int[2:0], frac[3:0]} 6.25ps units
    input  wire        fid_pulse,     // 1 strobe at the fiducial (rx_header)
    input  wire        hdr_valid_i,   // rx_header validated this fiducial's header
    input  wire        hdr_discard_i, // rx_header rejected this fiducial's header
    input  wire [23:0] gate_delay_i,  // fiducial->payload-start, rxusrclk2 CYCLES
    input  wire [2:0]  ui_offset_i,   // rx_header FID slot -- LIVE register,
                                      // overwritten by every fid incl. dark
                                      // FALSE fids during the countdown
    output reg         gate_o,
    output reg  [7:0]  gate_fine_o,   // ANCHORED trim, 6.25ps units 0..159:
                                      // inst*16 + circular(est - inst*16),
                                      // clamped -- continuous across the wrap
                                      // because borrow (from inst) x 800ps and
                                      // trim share the inst anchor
    output reg  [2:0]  gate_inst_o,   // committed INST eph (borrow + hist)
    output reg         veto_o,        // 1-cyc pulse: validated burst SUPPRESSED
                                      // by phase-disagreement veto (diag count)
    output reg  [2:0]  gate_ui_o,     // FID slot of the COMMITTED burst: latched
                                      // at arm (like gate_fine), immune to later
                                      // false fids -> feeds mark_oserdes. (The
                                      // raw ui_offset at gate time was stale for
                                      // ~5% of bursts: dark false fids between
                                      // fid and gate rewrote it -> marker at a
                                      // RANDOM slot = the quasi-uniform 7.0ns
                                      // straggler background, bench 2026-06-09.)
    output reg         armed_o
);
    // GATE INTEGRITY: only fire the marker if the header that FOLLOWS the
    // fiducial actually validated. A false fiducial (garbage in the laser-off
    // dark decoding as the FID byte) otherwise fired a SPURIOUS marker,
    // because the count was armed on raw fid_pulse alone (sim tb_pdark_resid:
    // dark garbage -> false fid -> spurious gate). hdr_valid arrives ~9 byte-
    // times after the fiducial, far earlier than gate_delay (~2202 cyc), so
    // we arm/count on fid_pulse as before but SUPPRESS the fire unless the
    // header validated; cancel early on hdr_discard. Timing is unchanged
    // (still fires at fid+gate_delay) -- this only gates WHETHER it fires.
    // Once validated, a running gate IGNORES later (false) fiducials so the
    // dark's garbage fiducials can't clobber the real committed countdown.
    // Enforces "missing gate, never a WRONG gate" at the gate, not just the
    // header.
    reg [23:0] cnt;
    reg        run;
    reg        validated;            // header for the current fiducial passed
    reg        veto;                 // phase measurement suspect this burst

    // inst-anchored trim: est unwrapped onto the inst frame (circular dist
    // in [-64,+63] units), clamped to [0,159] (taps 0..13, ODELAY range ok)
    //
    // THE B8 ANCHOR MATH, step by step. Units: 6.25 ps everywhere; one CDR
    // sample (one eph step, 100 ps) = 16 units; one UI (800 ps) = 128 units
    // -- so a 7-bit value covers exactly one UI and mod-128 two's-complement
    // arithmetic IS the circular phase topology (eph 7.9 and eph 0.1 are
    // 0.2 steps apart, not 7.8).
    //   anch_base = inst eph expressed in units (inst*16);
    //   anch_d    = filtered estimate minus base, mod 128 (7-bit wrap);
    //   anch_sd   = anch_d remapped to signed [-64,+63] (+-400 ps): the
    //               SHORTEST circular distance from inst to the filter;
    //   anch_s    = base + sd = the filtered MAGNITUDE re-expressed in the
    //               inst FRAME (can be <0 or >127 when the shortest path
    //               crosses the wrap -- that overshoot is intentional);
    //   anch_trim = clamp to [0,159] = what ODELAYE2 taps 0..13 (78.125 ps
    //               each) can realize via tap = (units*2+12)/25 downstream.
    //
    // WHY ANCHOR INSTEAD OF JUST USING THE FILTER (tb_eph_jitter, the sim
    // that killed the naive design): the integer-UI borrow in mark_oserdes
    // (slot_eff = ui-1 when eph>=6, Build B3) keys off the SAME per-burst
    // instantaneous eph as the framer's k decision -- they wrap together, so
    // borrow*800ps + trim stays continuous across the slot boundary. A
    // filtered value crosses the wrap at a DIFFERENT instant than k does;
    // letting it drive the borrow (or an unanchored trim) decorrelates the
    // two and produces +-800 ps flips exactly at slot boundaries. Hence the
    // split roles: inst decides the borrow, the filter only contributes its
    // (better-averaged) magnitude INSIDE the inst frame. Averaging is
    // single-shot-legitimate here because under B7's frozen CDR grid the
    // sub-UI phase is quasi-static over the warmup window: the EMA averages
    // N redundant measurements of one packet's own constant.
    wire [6:0] anch_base = {eph_inst_i, 4'd0};
    wire [6:0] anch_d    = eph_filt_i - anch_base;          // mod-128
    wire signed [7:0] anch_sd = (anch_d >= 7'd64)
                              ? ({1'b0, anch_d} - 8'd128)
                              : {1'b0, anch_d};
    wire signed [9:0] anch_s  = $signed({3'b000, anch_base}) + anch_sd;
    wire [7:0] anch_trim = (anch_s < 0)         ? 8'd0
                         : (anch_s > 10'sd159)  ? 8'd159
                         : anch_s[7:0];
    // effective target = recovered cycle count + fixed cal (clamp >=1)
    wire signed [25:0] tgt_s = $signed({2'b00, gate_delay_i})
                             + $signed(CAL_OFFSET);
    wire [23:0] tgt = (tgt_s < 26'sd1) ? 24'd1 : tgt_s[23:0];

    always @(posedge clk) begin
        if (rst) begin
            cnt<=24'd0; run<=1'b0; validated<=1'b0; veto<=1'b0;
            gate_o<=1'b0; gate_fine_o<=8'd0; gate_inst_o<=3'd0;
            gate_ui_o<=3'd0; armed_o<=1'b0; veto_o<=1'b0;
        end else begin
            gate_o<=1'b0; veto_o<=1'b0;
            // ARM = the single commit point (see header). Re-arm policy:
            //  - run && validated  -> IGNORE new fiducials: the countdown is
            //    committed; dark false fids must not clobber it.
            //  - run && !validated -> a NEW fid re-arms. The earlier fid was
            //    false (its header never validated -- a real one validates
            //    ~9 byte-times after fid, long before the next burst), so the
            //    new, possibly real, fiducial must win.
            // All four per-burst latches (fine/inst/ui + veto decision)
            // commit HERE, in the same cycle as fid_pulse, so they are
            // mutually consistent and immune to later in-domain churn.
            if (fid_pulse && !(run && validated)) begin
                run<=1'b1; armed_o<=1'b1;       // (re)arm; a committed validated
                cnt<=24'd0; validated<=1'b0;    // gate ignores new fiducials
                gate_fine_o<=anch_trim;         // anchored sub-UI at fiducial
                gate_inst_o<=eph_inst_i;        // inst eph (borrow authority)
                gate_ui_o<=ui_offset_i;         // latch FID slot at same commit
                veto<=(anch_sd > VETO_TH) || (anch_sd < -VETO_TH);
            end else if (run) begin
                if (hdr_valid_i) validated<=1'b1;
                if (hdr_discard_i && !validated) begin
                    run<=1'b0; armed_o<=1'b0;    // false fiducial -> cancel, no gate
                end else if (cnt == tgt - 24'd1) begin
                    // fire ONLY for a validated header AND a trusted phase
                    // measurement; a vetoed burst is MISSING, never wrong
                    // (veto_o pulses instead of gate_o so the suppression is
                    // countable -- B6-style occurrence counter, hist idx11).
                    if (validated &&  !veto) gate_o<=1'b1;
                    if (validated &&   veto) veto_o<=1'b1;
                    run<=1'b0; armed_o<=1'b0;
                end else begin
                    // Free-running increment: ticks on EVERY rxusrclk2 cycle,
                    // bytes or no bytes -- this is what carries the countdown
                    // through the laser-off dark gap. It is exact because
                    // rxusrclk2 is the RECOVERED clock (RXOUTCLKPMA): zero
                    // ppm offset against the TX that computed gate_delay, and
                    // RXCDRHOLD freezes only the CDR's phase interpolator /
                    // frequency integrator, never the clock itself.
                    cnt<=cnt+24'd1;
                end
            end
        end
    end
endmodule
