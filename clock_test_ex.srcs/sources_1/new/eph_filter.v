`timescale 1ns/1ps
//==============================================================================
// eph_filter -- circular EMA of the CDR edge-phase: replaces the single-edge
// instantaneous reph latch with a tracked sub-step estimate.
//
// WHY: rx_oversample_cdr_64's reph is the phase of the LAST edge in each
// 64-bit word -- one edge, one shot. Its noise/bias produced the early-marker
// tail (~7-10% of markers up to ~500 ps early, b6_hold_10k/b7_final 2026-06,
// the gate_fine hist bins-5/6 deficit) and most of the ~79 ps unexplained
// core sigma. A burst offers hundreds of clean transitions; averaging them is
// nearly free precision.
//
// CIRCULAR TOPOLOGY FOR FREE: the estimate lives in 6.25 ps units (eph step
// = 16 units), 7 bits = 128 units = exactly one 800 ps UI cell -- two's-
// complement wraparound IS the circular phase space, no special wrap logic.
//
// UPDATE: est += wrap(reph - est_int) * 2 units per enabled cycle
//   = alpha 1/8 step per step of error; full-scale (4-step) pull-in ~32
//   cycles << the 60-cycle warmup before the fiducial. en = comma_locked
//   freezes the estimate across the dark gap (dark churn edges are garbage
//   phases; lock returns during warmup -> re-converges before the fid).
//   With HOLD_FOREVER the data phase walks ~ppm across bursts; the EMA
//   tracks the walk continuously instead of re-snapping per burst.
//
// OUTPUT est[6:0] = {int[2:0] = eph 0..7, frac[3:0] = 1/16 step}, consumed by
// rx_gate ONLY. B8 SPLIT-ROLE architecture (the jitter A/B sim tb_eph_jitter
// PROVED the naive "filter everything" design wrong):
//   - the BORROW decision and the phase histogram stay on the per-burst
//     INSTANTANEOUS eph (rx_gate commits it as gate_inst): the borrow must
//     remain CORRELATED with the framer's k decision made on the same burst's
//     instantaneous phase -- a filtered borrow decorrelates from k and flips
//     +-800 ps at slot boundaries under jitter.
//   - this filtered estimate is the TRIM authority only: rx_gate re-expresses
//     it in the inst-ANCHORED frame (trim = inst*16 + circular_dist(est -
//     inst*16), clamped 0..159 units) and that anchored value feeds
//     mark_odelay's frac-resolution tap map (78.125 ps taps, rounding at tap
//     resolution instead of the old 100 ps 8-level map).
//   (An earlier draft of this header had int -> borrow/histogram directly;
//   the shipped B8 wiring does not -- see rx_gate.v "B8 SPLIT-ROLE" and the
//   qwn_exdes hist feed, which both use the committed INST eph.)
//
// AVERAGING LEGITIMACY in a single-shot experiment: with the B7 frozen CDR
// grid the sub-UI phase is quasi-static over the warmup window (~ps drift),
// so the EMA averages N redundant measurements of one packet's own constant.
// The per-packet signal path (fid cycle, k, borrow) stays single-shot.
//
// BYPASS=1 reproduces the legacy instantaneous behavior (est = reph<<4) for
// the sim A/B (tb_eph_jitter legacy-vs-filtered runs) and HW fallback.
//
// PROVENANCE: introduced Build B8 (p_b8_2026-06-10). Bench evidence
// (b8_final.csv, with FAST slew): sigma 88.4 ps scope-measured (device ~82 ps
// after removing the 27.7 ps scope two-edge noise in quadrature), main bin
// 99.2%, early tail collapsed 7.3% -> 0.65%. Residual EMA term in the
// remaining jitter budget: ~10 ps.
//==============================================================================
module eph_filter #(
    parameter BYPASS = 1'b0
)(
    input  wire       clk,        // rxusrclk2
    input  wire       rst,
    input  wire [2:0] reph,       // CDR last-edge phase (instantaneous)
    input  wire       en,         // comma_locked: update only on live data
    output wire [6:0] est         // {eph_int[2:0], frac[3:0]} (6.25 ps units)
);
    reg  [6:0] acc;
    // wrapped error: (reph - est_int) interpreted mod 8 in [-4, +3]
    // FPGA-basics aside: an n-bit subtract is natively mod-2^n, so `diff` is
    // already the circular distance on the 8-step phase wheel; prepending a
    // sign bit chosen by the half-range test (diff 4..7 -> negative -4..-1,
    // diff 0..3 -> positive) decodes "shortest way around the circle".
    // rx_gate's anchored unwrap is the same trick at 7 bits (half-range 64).
    wire [2:0] diff   = reph - acc[6:4];
    wire signed [3:0] sdelta = (diff >= 3'd4) ? {1'b1, diff} : {1'b0, diff};
    // increment = sdelta * 2 units (alpha = 1/8 step per step of error)
    // -- the error is in eph STEPS (1 step = 16 units), so +2 units = 2/16 =
    // 1/8 step: the EMA alpha costs one wired left-shift, no multiplier.
    wire signed [4:0] inc = {sdelta, 1'b0};

    always @(posedge clk) begin
        if (rst)      acc <= 7'd0;
        // sign-extend inc to 7 bits; the adder's natural mod-128 overflow IS
        // the 0/127 phase seam -- no explicit wrap logic exists anywhere
        // (see CIRCULAR TOPOLOGY in the header)
        else if (en)  acc <= acc + {{2{inc[4]}}, inc[4:0]};  // mod-128 wrap
    end

    // BYPASS is an elaboration-time constant: bypass builds prune the whole
    // accumulator (zero LUT cost), filtered builds prune the mux.
    assign est = BYPASS ? {reph, 4'd0} : acc;
endmodule
