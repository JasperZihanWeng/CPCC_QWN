`timescale 1ns/1ps
//==============================================================================
// gt_reset_on_los -- autonomous two-board bring-up.
//
// Problem: a board powered/flashed before its inter-board partner is
// transmitting has its GT RX *startup FSM* time out (gt_rxfsmresetdone stuck 0
// even though QPLL is locked, usrclks alive, and optical signal is now
// present). It then needs a manual soft_reset to re-attempt. (This is the GT
// *hardware* startup FSM -- distinct from rxcdrhold_ctrl, which handles the
// ongoing *fabric* CDR self-heal.)
//
// Fix: while there IS light (SFP RX_LOS deasserted) but the RX FSM has NOT
// completed, periodically re-pulse the GT soft_reset until it locks. Gated on
// the lane-0/SFP0 (inter-board RX) lane only -- NOT lane-1: on the RX board
// the lane-1 cage is empty, so gating on it would retry forever.
//
//  - Self-limiting : once rxfsm_done=1 it stops (no further resets).
//  - Non-disruptive: never fires while the link is up; only when light is
//    present AND the RX FSM is down -> cannot disturb a healthy link.
//  - RETRY_CYC must exceed the GT init time (~ms) so attempts don't stomp
//    each other. Runs on the free-running drpclk; inputs must be drpclk-synced.
//==============================================================================
module gt_reset_on_los #(
    parameter [27:0] RETRY_CYC = 28'd8388608,  // ~53 ms @156.25 MHz between tries
    parameter [15:0] PULSE_CYC = 16'd1024       // soft_reset assert width (~6.5 us)
)(
    input  wire clk,           // drpclk (free-running)
    input  wire rst,
    input  wire los_present,   // 1 = optical light present (RX_LOS deasserted)
    input  wire rxfsm_done,    // 1 = GT RX startup FSM complete (drpclk-synced)
    output reg  soft_reset     // 1 = assert GT init/reset
);
    reg [27:0] cnt;
    reg [15:0] pw;
    always @(posedge clk) begin
        if (rst) begin
            cnt<=28'd0; pw<=16'd0; soft_reset<=1'b0;
        end else if (rxfsm_done || !los_present) begin
            // link up, or no light: idle -- no resets, counters cleared
            cnt<=28'd0; pw<=16'd0; soft_reset<=1'b0;
        end else if (soft_reset) begin
            // asserting the reset pulse
            if (pw==PULSE_CYC-16'd1) begin soft_reset<=1'b0; pw<=16'd0; cnt<=28'd0; end
            else pw<=pw+16'd1;
        end else begin
            // light present, RX FSM not up: count down the retry interval
            if (cnt==RETRY_CYC-28'd1) begin soft_reset<=1'b1; pw<=16'd0; end
            else cnt<=cnt+28'd1;
        end
    end
endmodule
