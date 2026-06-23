`timescale 1ns/1ps
//==============================================================================
// qwn_rx_lane -- one full QWN bufferless RX recovery lane, encapsulated.
//
// Wraps the per-lane RX fabric that was previously duplicated inline per lane
// in qwn_exdes (lane 0 = qwn_*, lane 1 = qwn1_*):
//
//   GT rxdata[63:0] -> rx_oversample_cdr_64 (8x blind-oversample CDR)
//                   -> rx_frame_par (8B/10B decode + continuous comma RE-ALIGN)
//                   -> rx_header     (FID/header parse, integrity discard)
//                   -> rx_gate       (payload-start marker, fires only on a
//                                     VALIDATED header -- "never a wrong gate")
//   plus rxcdrhold_ctrl (per-burst self-healing RXCDRHOLD across the dark gap).
//
// EVERY internal node is brought out as a port so the surrounding per-lane
// wiring in qwn_exdes -- which DIFFERS per lane (VIO rxcdrhold override on
// lane 0 only, per-lane SFP/pin assigns, dbg counters, ILA capture) -- stays
// at the top and is unchanged: this module just drives the same wire names
// the inline instances used to. Pure refactor, equivalence-preserving.
//
// Clocked entirely by the lane's RXUSRCLK2 (single clock domain in/out).
// Prereq for the LEVER-B 4-RX/32-bit swapping-node rewrite (one block to
// re-pipeline + replicate, not two hand-copied lanes).
//
// FPGA-basics aside, why this domain exists at all: the GT runs raw 64-bit
// RX (RXBUF_EN=FALSE) with RXOUTCLKSEL=RXOUTCLKPMA, so rxusrclk2 is derived
// from the CDR's RECOVERED clock, not a local oscillator. Everything in this
// module therefore rides the recovered grid -- which is both the feature
// (deterministic relation to the data) and the trap (a whole-grid
// displacement is invisible from inside; see rxcdrhold_ctrl's B7 addendum).
//
// PROVENANCE: introduced by the P4 encapsulation refactor (see the "P4" note
// at the lane-0 instance in qwn_exdes); EPH_BYPASS + eph_filter added in B8;
// gate_ui/gate_inst/gate_veto ports track the B4/B8/B9 rx_gate evolution.
// The marker OUTPUT chain (mark_oserdes -> mark_odelay -> pad) is
// deliberately NOT in here: it is lane-0/N41-only and needs the top-level
// IOB + clocking primitives. This module ends at the committed per-burst
// placement facts (gate, gate_ui, gate_inst, gate_fine) that chain consumes.
//==============================================================================
module qwn_rx_lane #(
    parameter EPH_BYPASS = 1'b0   // 1 = legacy instantaneous eph (sim A/B)
)(
    input  wire        rxusrclk2,    // gtN_rxusrclk2_i
    input  wire        rx_reset,     // gtN_rx_system_reset_c
    input  wire [63:0] rxdata,       // gtN_rxdata_i (raw 64-bit GT word)

    // recovered bit/byte stream taps (ILA debug)
    output wire [7:0]  rbits,
    output wire [3:0]  rcnt,
    output wire [3:0]  reph,         // recovered edge-phase (gate fine timing;
                                     // [2:0] = eph 0..7, 100 ps steps -- the
                                     // CDR zero-extends to 4 bits, port width
                                     // predates the 3-bit eph)
    output wire [7:0]  byte_o,
    output wire        k_o,
    output wire        byte_valid,
    output wire        code_err,
    output wire        comma_locked,

    // header recovery
    output wire        fid_pulse,
    output wire        hdr_valid,
    output wire        hdr_discard,
    output wire [7:0]  destination,
    output wire [15:0] payload_dur,
    output wire [23:0] gate_delay,

    // payload-start marker
    output wire        gate,
    output wire [7:0]  gate_fine,    // committed ANCHORED trim (6.25ps units,
                                     // 0..159; inst-frame, see rx_gate)
    output wire [2:0]  gate_inst,    // committed INST eph (borrow + hist)
    output wire        gate_veto,    // validated burst suppressed (diag)
    output wire [2:0]  gate_ui,      // COMMITTED FID slot (latched at gate arm,
                                     // immune to dark false-fid overwrite of
                                     // the live ui_offset; feeds mark_oserdes)

    // per-burst self-healing CDR hold (raw; VIO override stays at top if any)
    output wire        rxcdrhold,
    output wire        hold_blocked, // diag: reopen deferred by pending gate

    // P1 of fix #3: bit-position-within-cycle of the FID, latched at fid_pulse.
    // = the integer-UI mode (0..7, 800 ps grid) the recovery locked to this
    // burst. The 8-stripe ambiguity Phase B (OSERDES) will consume to correct.
    output wire [2:0]  ui_offset
);

    // ---- 8x blind-oversample CDR: raw GT word -> recovered bits + phase ----
    rx_oversample_cdr_64 #(.OS(8)) u_cdr
      (.clk(rxusrclk2),.rst(rx_reset),.word_i(rxdata),
       .rbits_o(rbits),.rcnt_o(rcnt),.reph_o(reph));

    // ---- 8B/10B decode + continuous comma RE-ALIGN (periodic-dark fix) ----
    wire [2:0] frame_byte_bit_pos;
    rx_frame_par u_frame
      (.clk(rxusrclk2),.rst(rx_reset),
       .rbits_i(rbits),.rcnt_i(rcnt),.byte_o(byte_o),.k_o(k_o),
       .byte_valid(byte_valid),.code_err(code_err),.comma_locked(comma_locked),
       .byte_bit_pos(frame_byte_bit_pos));

    // ---- QWN header parse (integrity discard on any error) ----
    rx_header u_hdr
      (.clk(rxusrclk2),.rst(rx_reset),.byte_valid(byte_valid),
       .code_err(code_err),.k_i(k_o),.byte_i(byte_o),
       .byte_bit_pos(frame_byte_bit_pos),
       .fid_pulse(fid_pulse),
       .hdr_valid(hdr_valid),.hdr_discard(hdr_discard),.destination(destination),
       .payload_dur(payload_dur),.gate_delay(gate_delay),
       .ui_offset(ui_offset));

    // ---- payload-start marker: fires ONLY for a validated header ----
    // ---- B8: filtered sub-UI phase (circular EMA over many edges; kills the
    // single-edge estimator's dead-zone bias = the early-marker tail, and its
    // shot noise = most of the unexplained core sigma) ----
    // SPLIT-ROLE (B8, tb_eph_jitter): eph_est is the TRIM authority only --
    // rx_gate anchors it to the instantaneous frame for gate_fine; the
    // BORROW decision and the histogram stay on the instantaneous eph
    // (gate_inst), which is what stays correlated with the framer's k.
    wire [6:0] eph_est;
    eph_filter #(.BYPASS(EPH_BYPASS)) u_ephf
      (.clk(rxusrclk2),.rst(rx_reset),
       .reph(reph[2:0]),.en(comma_locked),.est(eph_est));

    wire gate_armed;
    rx_gate u_gate
      (.clk(rxusrclk2),.rst(rx_reset),.bv(byte_valid),
       .eph_inst_i(reph[2:0]),.eph_filt_i(eph_est),.fid_pulse(fid_pulse),
       .hdr_valid_i(hdr_valid),.hdr_discard_i(hdr_discard),.gate_delay_i(gate_delay),
       .ui_offset_i(ui_offset),
       .gate_o(gate),.gate_fine_o(gate_fine),.gate_inst_o(gate_inst),
       .veto_o(gate_veto),.gate_ui_o(gate_ui),.armed_o(gate_armed));

    // ---- per-burst self-healing RXCDRHOLD across the laser-off dark gap ----
    // gate_pending: never release the CDR grid under a counting marker (the
    // dark comma-flicker early-reopen slewed the grid mid-countdown -> the
    // +-3.2ns straggler family; see rxcdrhold_ctrl header).
    // Since B7 the controller defaults to HOLD_FOREVER (hold permanently
    // after the first fiducial; release only on sustained comma loss) -- the
    // campaign's decisive fix, sigma 480 -> 122 ps. hold_blocked is counted
    // at the top as hist idx13 (~98% of bursts on HW, harmless).
    rxcdrhold_ctrl u_dark
      (.clk(rxusrclk2),.rst(rx_reset),
       .fid_pulse(fid_pulse),.comma_locked(comma_locked),
       .gate_pending(gate_armed),
       .gate_delay_i(gate_delay),.payload_dur_i(payload_dur),
       .rxcdrhold(rxcdrhold),.settling(),
       .reopen_blocked(hold_blocked));

endmodule
