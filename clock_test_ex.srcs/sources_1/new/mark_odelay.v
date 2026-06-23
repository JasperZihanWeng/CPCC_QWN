`timescale 1ns/1ps
//==============================================================================
// mark_odelay -- apply the recovered sub-UI fine phase (gate_fine) to a
// payload-start marker output via an ODELAYE2 variable output delay.
//
// WHY: rx_gate's coarse gate_o fires on a rxusrclk2 edge and DISCARDS the 8x
// oversample sub-bit phase (eph / gate_fine). At 10 Gbps RX (1.25 Gbps data,
// 8x oversample): data bit = 800 ps, eph step = 100 ps. So the coarse marker
// carries up to ~700 ps of burst-to-burst quantization (the very CDR phase
// that IS the intra-channel jitter). This module delays the marker edge by
// gate_fine, landing it at the true sub-bit payload-start position.
//
// MAPPING (legacy, pre-B8 -- kept for history; the current frac-resolution
// map is in the B8 block inside the module): ODELAYE2 tap @ 200 MHz
// IDELAYCTRL ref = 78.125 ps. eph step 100 ps
// -> tap = round(eph * 100/78.125) = round(eph * 1.28). 8 levels -> 0..9 taps
// (well within the 31-tap / ~2.4 ns range). A constant BASE_TAP cancels in
// the signal-vs-reference difference (offset-invariant).
//
// FPGA-basics aside, ODELAYE2/IDELAYCTRL: every HP-bank I/O tile has a
// 31-tap delay line whose raw tap size drifts with process/voltage/temp.
// IDELAYCTRL closes the loop: it continuously calibrates all IDELAY/ODELAY
// taps in its bank against a known REFCLK, so one tap = 1/(32*2*Fref) =
// 78.125 ps at 200 MHz, PVT-stable. The IODELAY_GROUP attribute (here
// "qwn_mark_grp") tells the tools WHICH IDELAYCTRL serves this delay; the
// controller itself lives once in qwn_exdes, where the 200 MHz REFCLK is
// synthesized from the 156.25 MHz stable clock by a dedicated MMCM
// (x8 / 6.25 -> exactly 200) because drpclk is NOT 200 MHz. ODELAY_TYPE
// VAR_LOAD = the tap count reloads atomically from CNTVALUEIN on an LD
// pulse (no inc/dec walking, no intermediate tap values on the line).
//
// SIGN (INVERT): whether the marker must be delayed MORE or LESS for higher
// eph depends on the CDR edge-phase convention -- HW-calibratable by a single
// parameter flip (the wrong sign DOUBLES the eph variation instead of
// cancelling it). Default = direct (tap grows with eph).
//
// IDELAYCTRL (200 MHz ref) is instantiated ONCE at the top with a matching
// IODELAY_GROUP; see qwn_exdes.
//
// CHANGELOG / EVIDENCE: pre-campaign module (the eph trim existed at campaign
// start, but a <=2.4 ns delay line cannot span the 8 x 800 ps integer-UI
// stripe problem -- that is mark_oserdes' job; this module handles ONLY the
// sub-UI residue). Build B (p_b/p_b2): lane-0 input rewired from rx_gate's
// coarse pulse to mark_oserdes.OQ (slot-placed cascade). Build B8 (p_b8):
// gate_fine widened to the 8-bit ANCHORED trim (6.25 ps units) + the frac-
// resolution tap map below; tap quantization is ~23 ps of the residual B8
// jitter budget. Bench: part of the B8 result, sigma 88.4 ps scope-measured
// (b8_final.csv).
//==============================================================================
module mark_odelay #(
    parameter [4:0] BASE_TAP = 5'd0,    // constant headroom (cancels in diff)
    parameter       INVERT   = 1'b0     // flip eph->tap sign (HW-calibratable)
)(
    input  wire       clk,        // rxusrclk2 (gate_fine / load domain)
    input  wire       rst,
    input  wire       gate_in,    // marker pulse. Lane 0: mark_oserdes.oq
                                  // (slot-placed, dedicated same-tile
                                  // OQ->ODATAIN route); lane 1: rx_gate
                                  // gate_o (coarse path = on-bench A/B ref)
    input  wire [7:0] gate_fine,  // ANCHORED trim, 6.25 ps units 0..159
                                  // (rx_gate: inst-frame + filtered residual)
    input  wire       fid,        // fiducial strobe (gate_fine valid next cyc)
    output wire       gate_dly    // -> OBUF -> marker pad (sub-UI placed)
);
    // B8: frac-resolution map. gate_fine is in 6.25 ps units (0..127 = one
    // 800 ps cell); ODELAY tap = 78.125 ps = 12.5 units:
    //   tap = round(units / 12.5) = (units*2 + 12) / 25
    //   (0..10 over a single 0..127 cell; the anchored trim is clamped to
    //   0..159 in rx_gate, so the map reaches tap 13 -- still < 31 max)
    // Replaces the legacy 8-level 100 ps map (its 0..57 ps roundoff band and
    // the 100 ps input quantization both shrink to tap resolution ~22 ps rms).
    wire [8:0] gf2     = {gate_fine, 1'b0};            // units*2
    wire [4:0] tap_map = (gf2 + 9'd12) / 9'd25;        // 0..13, const-div
    // optional sign flip (mirror about max tap 13): keeps range, flips slope
    wire [4:0] tap_eff = INVERT ? (5'd13 - tap_map) : tap_map;
    wire [4:0] cntval  = BASE_TAP + tap_eff;

    // load the tap one cycle after the fiducial (gate_fine settled by then),
    // long before the marker fires (~gate_delay cycles later) -> no glitch on
    // the marker pulse, tap stable when the pulse passes through.
    reg ld;
    always @(posedge clk) ld <= (rst ? 1'b0 : fid);

    // DELAY_SRC=ODATAIN selects the dedicated OLOGIC->ODELAY input: on lane 0
    // the OSERDES OQ reaches this delay line without ever leaving the pad's
    // IOB tile (DDR3-write style routing) -- no fabric net, no routing jitter.
    (* IODELAY_GROUP = "qwn_mark_grp" *)
    ODELAYE2 #(
        .CINVCTRL_SEL("FALSE"),
        .DELAY_SRC("ODATAIN"),
        .HIGH_PERFORMANCE_MODE("TRUE"),
        .ODELAY_TYPE("VAR_LOAD"),
        .ODELAY_VALUE(0),
        .PIPE_SEL("FALSE"),
        .REFCLK_FREQUENCY(200.0),
        .SIGNAL_PATTERN("DATA")
    ) u_odelay (
        .DATAOUT     (gate_dly),
        .CNTVALUEOUT (),
        .C           (clk),
        .CE          (1'b0),
        .CINVCTRL    (1'b0),
        .CLKIN       (1'b0),
        .CNTVALUEIN  (cntval),
        .INC         (1'b0),
        .LD          (ld),
        .LDPIPEEN    (1'b0),
        .ODATAIN     (gate_in),
        .REGRST      (rst)
    );
endmodule
