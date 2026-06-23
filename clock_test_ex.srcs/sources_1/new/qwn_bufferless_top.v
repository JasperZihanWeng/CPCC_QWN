`timescale 1ns/1ps
//==============================================================================
// qwn_bufferless_top -- integration skeleton for the bufferless oversampling
// QWN design. Wires the REGENERATED clock_test GT core (ports per the new
// clock_test.veo) + support to the VERIFIED fabric datapath.
//
// VERIFICATION STATUS of the instantiated fabric blocks (xsim, see
// IMPLEMENTATION_LOG.md):  enc/dec_8b10b PASS, rx_oversample_cdr PASS,
// rx_fiducial_gate PASS (integer-cycle determinism), rx_frame PASS (isolated),
// tx_burst_seq PASS, dark_period_ctrl PASS, rx_header PASS.
//
// NOT yet built / open (GT cannot be simulated here):
//  [TODO-1] 64-bit<->8x-sample gearbox: rx_oversample_cdr is sample-serial;
//           HW needs a 64-wide unrolled variant (gt0_rxdata_out[63:0] @
//           rxusrclk2 = 8 optical bits x 8 samples per word). Mechanical.
//  [TODO-2] TX gearbox: pack enc_8b10b 10-bit symbols into gt0_txdata_in[63:0].
//  [TODO-3] support-wrapper RX-MMCM: regenerated core now exposes
//           gt0_rx_mmcm_lock_in/gt0_rx_mmcm_reset_out (RX buf-bypass @64/32).
//           Add an RX MMCM mirroring the TX one in clock_test_support /
//           clock_test_gt_usrclk_source. Chain: RXCDRHOLD->stable RXOUTCLK->
//           RX MMCM->RXUSRCLK.
//  [TODO-4] ODELAY + IDELAYCTRL(200 MHz) on the gate output for the sub-UI
//           fine correction (gate_fine -> tap select). Analog; Phase-1B HW.
//  [TODO-5] reuse cleaned app modules (qwn_ttl/qwn_ttl_rx/switch_controller/
//           receiverSwitchStateMachine/header_regen) off the decoded fields.
//==============================================================================
module qwn_bufferless_top (
    input  wire        Q3_CLK1_GTREFCLK_PAD_P_IN, Q3_CLK1_GTREFCLK_PAD_N_IN, // Si570 via SMA
    input  wire        IDELAY_REFCLK_P, IDELAY_REFCLK_N,  // on-board 200 MHz (H19/G18)
    // GT serial: dedicated GTHE2 pins fixed by the IP's GT-channel LOC
    // (quad 113, same as the buffered reference) -- NOT top-level PACKAGE_PINs.
    input  wire [0:0]  RXN_IN, RXP_IN,
    output wire [0:0]  TXN_OUT, TXP_OUT,
    output wire        sfp0_dis,
    output wire        gate_out,                          // trigger/gate to time tagger
    output wire        hdr_valid_led
);
    // ---- stable / DRP clock = Si570 156.25 MHz (STABLE_CLOCK_PERIOD=6) ----
    wire sysclk;  // from IBUFDS/BUFG of the Si570 path (see clocking, TODO-3)

    // ---- GT support instance (regenerated; identical_config, 4-lane) --------
    // Port list per clock_test.veo (TX 1.25G / RX 10G blind oversample, raw64,
    // RXCDRHOLD exposed). Only lane0 wired here for clarity.
    wire [63:0] gt0_rxdata, gt0_txdata;
    wire        gt0_rxusrclk, gt0_rxusrclk2, gt0_txusrclk, gt0_txusrclk2;
    wire        gt0_rxcdrhold;
    wire        gt0_tx_fsm_done, gt0_rx_fsm_done, gt0_txinhibit;
    // clock_test clock_test_i ( .sysclk_in(sysclk),
    //   .gt0_rxcdrhold_in(gt0_rxcdrhold), .gt0_txinhibit_in(gt0_txinhibit),
    //   .gt0_rxdata_out(gt0_rxdata), .gt0_txdata_in(gt0_txdata),
    //   .gt0_rxusrclk_in(gt0_rxusrclk), .gt0_rxusrclk2_in(gt0_rxusrclk2),
    //   .gt0_txusrclk_in(gt0_txusrclk), .gt0_txusrclk2_in(gt0_txusrclk2),
    //   .gt0_rx_mmcm_lock_in(...), .gt0_rx_mmcm_reset_out(...),   // TODO-3
    //   ... per clock_test.veo ... );
    //   <-- instantiated once the support-wrapper RX-MMCM (TODO-3) is in place.

    // ====================  RX fabric datapath  ==========================
    // [TODO-1] gearbox gt0_rxdata[63:0] -> sample stream s for the CDR.
    wire        rx_s;                       // oversample sample (from gearbox)
    wire        rx_bit, rx_bv; wire [3:0] rx_ph, rx_sph, rx_eph;
    rx_oversample_cdr #(.OS(8)) u_cdr (
        .clk(gt0_rxusrclk2), .rst(~gt0_rx_fsm_done), .s_i(rx_s),
        .bit_o(rx_bit), .bit_valid_o(rx_bv),
        .phase_o(rx_ph), .sphase_o(rx_sph), .eph_o(rx_eph));

    wire [7:0] rx_byte; wire rx_k, rx_byv, rx_cerr, rx_locked;
    rx_frame u_frame (
        .clk(gt0_rxusrclk2), .rst(~gt0_rx_fsm_done), .bv(rx_bv), .bit_i(rx_bit),
        .byte_o(rx_byte), .k_o(rx_k), .byte_valid(rx_byv),
        .code_err(rx_cerr), .comma_locked(rx_locked));

    wire        hv, hd, fidp; wire [7:0] rx_dst;
    wire [15:0] rx_pdur; wire [23:0] rx_gd;
    rx_header u_hdr (
        .clk(gt0_rxusrclk2), .rst(~gt0_rx_fsm_done),
        .byte_valid(rx_byv), .code_err(rx_cerr), .k_i(rx_k), .byte_i(rx_byte),
        .fid_pulse(fidp), .hdr_valid(hv), .hdr_discard(hd),
        .destination(rx_dst), .payload_dur(rx_pdur), .gate_delay(rx_gd));

    wire gate_coarse; wire [3:0] gate_fine;
    rx_fiducial_gate u_fg (
        .clk(gt0_rxusrclk2), .rst(~gt0_rx_fsm_done), .bv(rx_bv), .bit_o(rx_bit),
        .eph_i(rx_eph), .gate_delay_i(rx_gd),
        .fid_seen_o(), .gate_o(gate_coarse), .gate_fine_o(gate_fine));
    // [TODO-4] gate_coarse -> ODELAY (tap=gate_fine, IDELAYCTRL @200 MHz) -> gate_out
    assign gate_out      = gate_coarse;     // placeholder (no sub-UI fine yet)
    assign hdr_valid_led = hv;

    dark_period_ctrl u_dark (
        .clk(sysclk), .rst(1'b0), .reacq(1'b0),
        .code_err_stb(rx_byv & rx_cerr), .good_sym_stb(rx_byv & ~rx_cerr),
        .rxcdrhold(gt0_rxcdrhold), .settling());

    // ====================  TX fabric datapath  ==========================
    wire [7:0] tx_sym; wire tx_k, tx_sv, tx_inh, tx_dis, tx_fid;
    tx_burst_seq u_tx (
        .clk(gt0_txusrclk2), .rst(~gt0_tx_fsm_done), .adv(1'b1),
        .warmup_syms(16'd4096), .settle_syms(8'd32),
        .destination(8'h01), .payload_dur(16'd2052), .gate_delay(24'd200),
        .payload_len(16'd0), .payload_data(8'h00), .payload_idx(),
        .sym(tx_sym), .sym_k(tx_k), .sym_vld(tx_sv),
        .tx_inhibit(tx_inh), .sfp_disable(tx_dis), .fid_stb(tx_fid));

    wire [9:0] tx_code; wire tx_disp_n; reg tx_disp;
    enc_8b10b u_enc (.datain(tx_sym), .dispin(tx_disp), .kin(tx_k),
                     .dataout(tx_code), .dispout(tx_disp_n));
    always @(posedge gt0_txusrclk2)
        if (~gt0_tx_fsm_done) tx_disp<=1'b0; else if (tx_sv) tx_disp<=tx_disp_n;
    // [TODO-2] pack tx_code (10b) -> gt0_txdata[63:0] (gearbox)
    assign gt0_txinhibit = tx_inh;
    assign sfp0_dis      = tx_dis;
endmodule
