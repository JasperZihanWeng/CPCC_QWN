`timescale 1ns/1ps
//==============================================================================
// rx_frame_par -- ROLE IN THE SYSTEM (see docs/CAMPAIGN_BRIEF_2026-06.md):
// the framer/decoder of the RX chain. Takes the variable-rate recovered-bit
// stream from rx_oversample_cdr_64, finds symbol boundaries via the K28.5
// comma, and emits decoded bytes (<=1/cycle) to rx_header / rx_gate.
//
//   rx_oversample_cdr_64 -> [THIS] -> rx_header -> rx_gate -> marker
//
// FPGA BASICS -- 8B/10B in one paragraph: each byte is sent as a 10-bit
// symbol chosen (per running disparity) to keep the line DC-balanced and
// transition-rich. The control symbol K28.5 ("comma", decodes to 0xBC with
// k=1) contains a 7-bit run -- 0011111 or its complement 1100000 -- that
// CANNOT occur at any other bit offset in a legal aligned stream, not even
// straddling two symbols. Seeing that pattern therefore pins the symbol
// boundary exactly: that is what "comma alignment" means, and it is the
// hard-block function we lost by running the GT in raw oversampled mode --
// reimplemented here in fabric.
//
// byte_bit_pos / "k" (Build A, p_a_2026-05-27 -- detection half of fix #3):
// the loop index k (0..7) at which a symbol's LAST bit arrived = which UI
// slot of the 64-bit rxusrclk2 word the symbol ended on (800 ps grid).
// WHY k STEPS BY 2: consecutive symbols are 10 bits apart, and nominally 8
// bits arrive per cycle, so the end-slot advances 10 mod 8 = 2 per symbol
// (one full cycle plus two slots). Within a burst the sequence is rigid
// (k, k+2, k+4, ... mod 8); ACROSS bursts the GT divider/CDR re-lock places
// the stream on a random slot -- byte_bit_pos at the FID byte is exactly the
// integer-UI offset (the "8-stripe" ~2 ns jitter root cause) that
// mark_oserdes later cancels. HW evidence: ui_offset spans 0..7 near-uniform
// on the live link, distinctly skewed on a dark input (Build A diagnosis).
//
// BUILD/EVIDENCE SUMMARY for this file:
//   - base framer: faithful 8x-unrolled replica of the proven sample-serial
//     rx_frame (tb_frame_par_equiv: identical {k,byte,code_err} sequence);
//   - continuous comma RE-ALIGN added after sim tb_realign showed a wrong
//     re-lock could decode clean-but-wrong forever (see in-line comment);
//     this re-align is also what makes B7's HOLD_FOREVER CDR policy viable
//     (it absorbs alignment drift so the CDR grid never has to re-acquire);
//   - byte_bit_pos export: Build A (fix #3 detection);
//   - sym_cap feed-forward pipeline stage: timing closure (see in-line).
//==============================================================================
// rx_frame_par -- word-parallel K28.5 comma-align + 8B/10B decode. Consumes
// the variable 0..8 recovered bits/cycle from rx_oversample_cdr_64 and applies
// the EXACT proven rx_frame bit-step, unrolled up to 8x/cycle. Because a
// symbol is 10 bits and <=8 bits arrive per cycle, at most ONE symbol
// completes per cycle -> byte_o/byte_valid is <=1/cycle, so the existing
// byte-rate rx_header / rx_gate need NO change.
//
// Faithful replica of rx_frame by construction; verified by equivalence
// (tb_frame_par_equiv): identical {k,byte,code_err} sequence vs sample-serial
// rx_frame for the same recovered-bit stream.
//==============================================================================
module rx_frame_par #(
    parameter CODE_ERR_LIM = 8
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  rbits_i,      // up to 8 recovered bits, [0]=earliest
    input  wire [3:0]  rcnt_i,       // # valid bits this cycle (0..8)
    output reg  [7:0]  byte_o,
    output reg         k_o,
    output reg         byte_valid,
    output reg         code_err,
    output reg         comma_locked,
    // bit-position within the rxusrclk2 cycle where this BYTE's symbol's last
    // bit landed (0..7, 800 ps grid). Aligned with byte_valid. Per-burst the
    // recovered clock locks at 1-of-8 phase modes -> this value differs per
    // burst (the "8-stripe" integer-UI ambiguity); within a burst it's
    // deterministic. P1 of fix #3: data-driven ui-offset detection.
    output reg  [2:0]  byte_bit_pos
);
    // Framer recurrence state (single-cycle, like the CDR's carry):
    //   sr   : 10-bit shift register of recovered bits, [9]=oldest. A full
    //          symbol therefore sits in sr with its FIRST-transmitted bit at
    //          sr[9] -- this is the bit order dec_8b10b's table is built for.
    //   cnt  : bits remaining until the current symbol completes (10..1).
    //   errc : consecutive decode-error count; CODE_ERR_LIM errors drop
    //          comma_locked and force a fresh comma hunt.
    reg  [9:0] sr;
    reg  [3:0] cnt;
    reg  [3:0] errc;

    // working locals for the unrolled pass
    reg  [9:0] v_sr, v_srn;
    reg  [3:0] v_cnt, v_errc;
    reg        v_lock, comma_m, sym_hit;
    reg  [9:0] sym_cap;
    reg  [2:0] v_sym_pos;    // k of the loop iteration that triggered sym_hit
    integer k;

    // single decoder shared by the (<=1/cycle) latched symbol
    // (a 10-bit-in lookup is a large ROM cone; sharing ONE instance is why
    // the <=1-symbol-per-cycle guarantee matters -- no per-slot decoders)
    reg  [9:0] dec_in; reg dec_vld;
    wire [7:0] d_byte; wire d_k, d_cerr;
    dec_8b10b u_dec(.datain(dec_in),.dout(d_byte),.kout(d_k),.code_err(d_cerr));

    // Feed-forward pipeline stage (timing-closure structural fix). The path
    // rbits -> [8x unrolled loop] -> sym_cap -> dec_in (8b10b ROM addr) was
    // the recurring route-marginal clkout0 cone (15 levels, 86% route to the
    // far-placed decoder BRAM). sym_cap is PURE FEED-FORWARD (not in the
    // sr/cnt/comma_locked recurrence), so registering it here is hazard-free
    // (mirrors the CDR's "single-cycle carry, pipelined feed-forward") and
    // costs only +1 cycle byte latency -- absorbed by the eph/fid-RELATIVE
    // gate timing (rx_gate) and the alignment-agnostic e2e oracle.
    reg  [9:0] sym_cap_q; reg sym_hit_q;
    reg  [2:0] sym_pos_q, sym_pos_q1;     // pipeline bit_pos alongside sym_cap

    always @(posedge clk) begin
        if (rst) begin
            sr<=10'd0; cnt<=4'd0; errc<=4'd0;
            byte_o<=8'd0; k_o<=1'b0; byte_valid<=1'b0;
            code_err<=1'b0; comma_locked<=1'b0;
            dec_vld<=1'b0; sym_hit_q<=1'b0;
            sym_pos_q<=3'd0; sym_pos_q1<=3'd0; byte_bit_pos<=3'd0;
        end else begin
            v_sr=sr; v_cnt=cnt; v_lock=comma_locked; v_errc=errc;
            sym_hit=1'b0; sym_cap=10'd0; v_sym_pos=3'd0;

            // 8x-unrolled serial framer: each iteration consumes ONE recovered
            // bit, exactly as the proven sample-serial rx_frame did per clock.
            // Unrolling preserves the bit-at-a-time semantics (the v_* blocking
            // locals thread the state through the loop); synthesis just sees an
            // 8-deep combinational chain.
            for (k=0;k<8;k=k+1) begin
                if (k < rcnt_i) begin
                    v_srn   = {v_sr[8:0], rbits_i[k]};
                    // Comma detect on the 7 NEWEST bits: the K28.5 singular
                    // run (0011111 / 1100000) occupies bits 1..7 of the
                    // symbol, so when it matches, 3 bits of the symbol remain
                    // -- hence v_cnt=3 below (both at first lock and at every
                    // re-snap), after which cnt counts 3->2->1 and the symbol
                    // completes on the 10th bit.
                    comma_m = (v_srn[6:0]==7'b0011111)||(v_srn[6:0]==7'b1100000);
                    if (!v_lock) begin
                        if (comma_m) begin v_lock=1'b1; v_cnt=4'd3; v_errc=4'd0; end
                    end else begin
                        // Continuous comma RE-ALIGN (standard 8B/10B receiver
                        // behavior; the GT's hardened comma-align does this).
                        // A comma can only legitimately occur at a byte
                        // boundary, so re-snap v_cnt to every comma seen --
                        // this corrects a STALE WRONG alignment (e.g. a wrong
                        // re-lock after a laser-off dark) that the warmup
                        // K28.5 would otherwise never fix. The original
                        // lock-once-and-hold left rx_frame_par permanently
                        // stuck for mis-alignments that decode clean-but-wrong
                        // (sim tb_realign: S=6 slip never recovered). Inert
                        // when already aligned: in aligned K28.5 the comma
                        // fires exactly when v_cnt would be 3, so v_cnt<=3 is a
                        // no-op (preserves tb_frame_par_equiv / tb_e2e_hw).
                        if (comma_m) begin
                            v_cnt = 4'd3;
                        end else if (v_cnt==4'd1) begin
                            // Symbol complete: this bit is the 10th. Capture
                            // the whole symbol AND the loop index k -- k is
                            // byte_bit_pos, the UI slot (0..7) where the
                            // symbol ended. Reload cnt=10 for the next symbol;
                            // with 8 bits/cycle this is why the end slot
                            // advances by 10 mod 8 = 2 each symbol.
                            v_cnt   = 4'd10;
                            sym_cap = v_srn;       // <=1 hit/cycle (10>8)
                            sym_hit = 1'b1;
                            v_sym_pos = k[2:0];    // bit-position of symbol end
                        end else v_cnt = v_cnt - 4'd1;
                    end
                    v_sr = v_srn;
                end
            end

            sr<=v_sr; cnt<=v_cnt; comma_locked<=v_lock;

            // Stage A->B feed-forward register: break the long route to the
            // decoder ROM. Recurrence (sr/cnt/comma_locked) above is unchanged
            // and single-cycle -> no pipeline-feedback hazard.
            sym_hit_q <= sym_hit;
            if (sym_hit) sym_cap_q <= sym_cap;
            if (sym_hit) sym_pos_q <= v_sym_pos;
            // pipeline bit_pos alongside sym_cap -> dec_in -> byte_o
            if (sym_hit_q) sym_pos_q1 <= sym_pos_q;

            // Stage B: decode the (optional) latched symbol; 1-cycle pipeline
            dec_vld <= sym_hit_q;
            if (sym_hit_q) dec_in <= sym_cap_q;

            // Total latency symbol-end -> byte_valid = 3 cycles (sym_cap_q ->
            // dec_in -> byte_o). Downstream never depends on absolute byte
            // latency (rx_gate counts RELATIVE to fid_pulse, and CAL_OFFSET
            // absorbs the fixed skew), only on byte_bit_pos staying aligned
            // with its byte -- hence the sym_pos_q/q1 shadow pipeline above.
            byte_valid<=1'b0; code_err<=1'b0;
            if (dec_vld) begin
                byte_o<=d_byte; k_o<=d_k;
                byte_bit_pos<=sym_pos_q1;       // aligned with byte_valid
                code_err<=d_cerr; byte_valid<=1'b1;
                // CODE_ERR_LIM CONSECUTIVE invalid symbols -> declare comma
                // lock lost and re-hunt. A threshold (not single-error) so the
                // laser-off dark's garbage cannot drop lock on every blip; a
                // single code_err during a header is handled separately (and
                // more strictly) by rx_header's whole-burst discard.
                if (d_cerr) begin
                    if (errc==CODE_ERR_LIM-1) comma_locked<=1'b0;
                    else errc<=errc+1;
                end else errc<=4'd0;
            end else errc<=v_errc;
        end
    end
endmodule
