`timescale 1ns/1ps
//==============================================================================
// dark_period_ctrl -- RXCDRHOLD management for the blind-oversample RX.
//
// Per AMD/XAPP572: with the GT at Nx the optical rate and encoding=None, the
// CDR must NOT track the slow data. After reset (and after any requested
// re-acquire) the CDR is allowed to FREQUENCY-settle to the local reference
// for INIT_CYC stable-clock cycles (rxcdrhold=0); thereafter rxcdrhold=1 is
// held steadily so the sampling grid stays on the local ref through bursts
// AND dark gaps (it does not chase noise/idle). A persistent decode-error
// burst, or an external reacq pulse, re-runs the settle.
//==============================================================================
module dark_period_ctrl #(
    parameter INIT_CYC  = 16'd2048,        // CDR->ref settle window
    parameter ERR_LIMIT = 8'd64,           // consecutive code-errs -> re-acq
    // STALL_CYC: in S_HOLD, if NO byte activity (neither good_sym nor
    // code_err) for this many stable-clock cycles, force a re-settle.
    // MUST exceed the longest LEGITIMATE laser-off dark gap (user spec
    // <=600us; @156.25MHz that is ~93,750 cyc) so a real dark gap still
    // HOLDs (the blind-oversample thesis), but a genuine lock-loss/deadlock
    // (where errc can never reach ERR_LIMIT because no bytes flow at all)
    // self-heals. Default ~6.7 ms (>> 600 us).
    parameter [23:0] STALL_CYC = 24'd1048575
)(
    input  wire        clk,           // stable clock (Si570 156.25 MHz)
    input  wire        rst,
    input  wire        reacq,         // external re-acquire request (pulse)
    input  wire        code_err_stb,  // 1 when a decode error occurs
    input  wire        good_sym_stb,  // 1 when a clean symbol decodes
    output reg         rxcdrhold,     // -> GT gt*_rxcdrhold_in
    output reg         settling       // status: in CDR->ref settle window
);
    localparam S_SETTLE=1'b0, S_HOLD=1'b1;
    reg        st;
    reg [15:0] cnt;
    reg [7:0]  errc;
    reg [23:0] stall;                 // no-activity watchdog (S_HOLD)

    always @(posedge clk) begin
        if (rst) begin
            st<=S_SETTLE; cnt<=0; errc<=0; stall<=0;
            rxcdrhold<=1'b0; settling<=1'b1;
        end else begin
            case (st)
            S_SETTLE: begin
                rxcdrhold<=1'b0; settling<=1'b1; errc<=0; stall<=0;
                if (cnt==INIT_CYC-1) begin cnt<=0; st<=S_HOLD; end
                else cnt<=cnt+1;
            end
            S_HOLD: begin
                rxcdrhold<=1'b1; settling<=1'b0;
                // no-activity watchdog: any byte (good or err) resets it;
                // expiry => link is dead/deadlocked => re-settle (self-heal)
                if (good_sym_stb || code_err_stb) stall<=0;
                else if (stall==STALL_CYC) begin
                    st<=S_SETTLE; cnt<=0; errc<=0; stall<=0;
                end else stall<=stall+24'd1;
                if (good_sym_stb) errc<=0;
                else if (code_err_stb) begin
                    if (errc==ERR_LIMIT-1) begin st<=S_SETTLE; cnt<=0; errc<=0; end
                    else errc<=errc+1;
                end
                if (reacq) begin st<=S_SETTLE; cnt<=0; errc<=0; stall<=0; end
            end
            endcase
        end
    end
endmodule
