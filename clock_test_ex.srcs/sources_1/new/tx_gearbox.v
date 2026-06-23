`timescale 1ns/1ps
//==============================================================================
// tx_gearbox -- pack the enc_8b10b 10-bit symbol stream into GT raw-64 TXDATA
// words (gt0_txdata_in[63:0] @ txusrclk2). 64 is not a multiple of 10, so a
// bit accumulator emits a word whenever >=64 valid bits are buffered. MSB-
// first: 'a' (sym_i[9]) is sent first -> highest bit slot -> word_o[63].
// can_accept = back-pressure for the encoder (never overflow the accumulator).
//==============================================================================
module tx_gearbox #(
    parameter ACCW = 160
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        sym_vld,
    input  wire [9:0]  sym_i,        // {a..j}, a = bit9
    output reg  [63:0] word_o,
    output reg         word_vld,
    output wire        can_accept
);
    reg  [ACCW-1:0] acc;             // MSB end = oldest = next to send
    reg  [8:0]      fill;            // # valid bits in acc

    assign can_accept = (fill <= (ACCW-10));

    // combinational next-state: append (if sym_vld) then consume 64 if ready
    reg  [ACCW-1:0] acc_app;
    reg  [8:0]      fill_app;
    always @* begin
        acc_app  = acc;
        fill_app = fill;
        if (sym_vld) begin
            acc_app[ACCW-1-fill -: 10] = sym_i;   // place a..j MSB-first
            fill_app = fill + 9'd10;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            acc<=0; fill<=0; word_o<=0; word_vld<=1'b0;
        end else begin
            word_vld <= 1'b0;
            if (fill_app >= 9'd64) begin
                word_o   <= acc_app[ACCW-1 -: 64];   // oldest 64, a-first
                word_vld <= 1'b1;
                acc      <= acc_app << 64;            // drop sent bits
                fill     <= fill_app - 9'd64;
            end else begin
                acc  <= acc_app;
                fill <= fill_app;
            end
        end
    end
endmodule
