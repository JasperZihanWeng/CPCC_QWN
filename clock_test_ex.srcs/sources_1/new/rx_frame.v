`timescale 1ns/1ps
//==============================================================================
// rx_frame -- K28.5 comma alignment + 8B/10B decode on the recovered bit
// stream (post rx_oversample_cdr). Produces aligned decoded bytes.
//   bv/bit_i  : recovered-bit strobe + bit (a..j, a first)
//   byte_o,k_o,byte_valid,code_err : decoded symbol
//   comma_locked : word boundary established
// Re-acquires (drops lock) after CODE_ERR_LIM consecutive code errors.
//==============================================================================
module rx_frame #(
    parameter CODE_ERR_LIM = 8
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       bv,
    input  wire       bit_i,
    output reg  [7:0]  byte_o,
    output reg         k_o,
    output reg         byte_valid,
    output reg         code_err,
    output reg         comma_locked
);
    reg  [9:0] sr;
    reg  [3:0] cnt;          // received-bit index within current symbol 0..9
    reg  [3:0] errc;

    wire [9:0] sr_n   = {sr[8:0], bit_i};         // post-shift value
    wire comma_m = (sr_n[6:0]==7'b0011111) || (sr_n[6:0]==7'b1100000);

    wire [7:0] d_byte; wire d_k, d_cerr;
    dec_8b10b u_dec(.datain(sr_n),.dout(d_byte),.kout(d_k),.code_err(d_cerr));

    always @(posedge clk) begin
        if (rst) begin
            sr<=10'd0; cnt<=4'd0; errc<=4'd0;
            byte_o<=8'd0; k_o<=1'b0; byte_valid<=1'b0;
            code_err<=1'b0; comma_locked<=1'b0;
        end else begin
            byte_valid<=1'b0; code_err<=1'b0;
            if (bv) begin
                sr <= sr_n;
                if (!comma_locked) begin
                    // this bv received the 7th K28.5 bit -> 3 more (g,h,j)
                    // until the symbol completes; latch on that 3rd one.
                    if (comma_m) begin comma_locked<=1'b1; cnt<=4'd3; errc<=0; end
                end else begin
                    if (cnt==4'd1) begin                  // 10th bit this bv
                        cnt<=4'd10;
                        byte_o<=d_byte; k_o<=d_k;          // decode of sr_n
                        code_err<=d_cerr; byte_valid<=1'b1;
                        if (d_cerr) begin
                            if (errc==CODE_ERR_LIM-1) comma_locked<=1'b0;
                            else errc<=errc+1;
                        end else errc<=0;
                    end else cnt<=cnt-4'd1;
                end
            end
        end
    end
endmodule
