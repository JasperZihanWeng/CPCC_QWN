`timescale 1ns/1ps
//==============================================================================
// tx_burst_seq -- QWN burst protocol sequencer (BRAM-header version).
//
// Per burst:  WARMUP (K28.5 idle = laser warm + RX lock + cdr pilot)
//          -> SETTLE (balanced data preamble)
//          -> FIDUCIAL byte (timing reference)
//          -> ROM stream: HEADER (qwn_header_rom[0 .. HDR_LEN-1] =
//             SOH,dest,payload_dur,gate_delay,check) + PAYLOAD
//             (rom[HDR_LEN .. HDR_LEN+PAY_LEN-1] = BER/PRBS block)
//          -> TRAIL idle -> TXINHIBIT then TXDISABLE -> dark -> repeat.
//
// Header/payload content lives in the qwn_header_rom BRAM (mirrors the
// reference design's BRAM frame generator). The ROM has 1-cycle registered
// read latency; rom_addr is prefetched one byte ahead (primed during S_FID)
// so the emitted symbol stream stays contiguous (no bubbles).
//==============================================================================
module tx_burst_seq #(
    parameter [7:0] K285 = 8'hBC,
    parameter [7:0] FID  = 8'h6B,
    parameter       AW   = 9
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        adv,                 // symbol-rate advance strobe
    input  wire [15:0] warmup_syms,
    input  wire [7:0]  settle_syms,
    input  wire [15:0] rom_tx_len,          // HDR_LEN + PAY_LEN bytes to stream
    input  wire [7:0]  rom_dout,            // qwn_header_rom data (registered)
    output reg  [AW-1:0] rom_addr,          // -> qwn_header_rom addr (prefetch)
    output reg  [7:0]  sym,
    output reg         sym_k,
    output reg         sym_vld,
    output reg         tx_inhibit,
    output reg         sfp_disable,
    output reg         fid_stb
);
    localparam S_WARM=0,S_SET=1,S_FID=2,S_ROM=3,S_TRL=4,S_DARK=5;
    reg [2:0]  st;
    reg [15:0] c;
    reg [15:0] bidx;                        // ROM byte index being emitted

    always @(posedge clk) begin
        if (rst) begin
            st<=S_WARM; c<=0; bidx<=0; rom_addr<={AW{1'b0}};
            sym<=K285; sym_k<=1'b1; sym_vld<=1'b0;
            tx_inhibit<=1'b1; sfp_disable<=1'b1; fid_stb<=1'b0;
        end else begin
            sym_vld<=1'b0; fid_stb<=1'b0;
            if (adv) begin
                sym_vld<=1'b1;
                case (st)
                S_WARM: begin
                    tx_inhibit<=1'b0; sfp_disable<=1'b0;       // laser on, CW idle
                    sym<=K285; sym_k<=1'b1;
                    if (c==warmup_syms-1) begin c<=0; st<=S_SET; end
                    else c<=c+1;
                end
                S_SET: begin
                    sym<=8'hAA; sym_k<=1'b0;                   // balanced filler
                    if (c==settle_syms-1) begin c<=0; st<=S_FID; end
                    else c<=c+1;
                end
                S_FID: begin
                    sym<=FID; sym_k<=1'b0; fid_stb<=1'b1;
                    bidx<=16'd0;
                    rom_addr<={AW{1'b0}};                      // prime ROM[0]
                    st<=S_ROM;
                end
                S_ROM: begin
                    // rom_dout holds ROM[addr presented on the previous adv]
                    sym<=rom_dout; sym_k<=1'b0;
                    if (bidx == rom_tx_len-16'd1) begin
                        c<=0; st<=S_TRL;
                    end else begin
                        bidx<=bidx+16'd1;
                        rom_addr<=(bidx+16'd1);                // prefetch next
                    end
                end
                S_TRL: begin
                    sym<=K285; sym_k<=1'b1;
                    if (c==15) begin
                        tx_inhibit<=1'b1; sfp_disable<=1'b1;   // hard cutoff
                        c<=0; st<=S_DARK;
                    end else c<=c+1;
                end
                S_DARK: begin
                    sym_vld<=1'b0;                              // laser off
                    if (c==255) begin c<=0; st<=S_WARM; end
                    else c<=c+1;
                end
                endcase
            end
        end
    end
endmodule
