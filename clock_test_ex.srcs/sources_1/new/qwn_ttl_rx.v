`timescale 1ns / 1ps
`ifndef DLY
`define DLY #1
`endif
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: 
// 
// Create Date: 03/17/2023 02:28:15 PM
// Design Name: 
// Module Name: qwn_ttl_rx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module qwn_ttl_rx#(
parameter guard_time_pre = 22'h7d0,
parameter guard_time_post = 22'h1f4,
parameter tdc_clock_4M = 22'd20,
parameter DIVISOR_trigger = 22'd225750

)
(
input wire clock_in, // input clock from TX
input wire start_count,
input wire [15:0] payload_dur,
output wire payload,
output wire tdc_clock,
output wire divided_4mhz_clock,
output wire trgr_dca    
    
    );
    
reg reg_payload=1'b0;
reg hold=1'b0;
reg [21:0] counter = 22'h0;
reg [21:0] counter_divisor_4m = 22'h0; 
reg clock_out_4MHz=1'b0;


always @(posedge clock_in)
begin
    if((hold == 1'b0) && (start_count == 1'b1))begin
        hold <= 1'b1;
        counter <= 22'h0;
        reg_payload <= 1'b0;
    end
    else if (hold) begin
    counter <= counter + 22'h1;
    if (counter == guard_time_pre)begin
        reg_payload <= 1'b1;
        end
    else if (counter == (payload_dur - guard_time_post)) begin
        reg_payload <= 1'b0;
        end
    else if (counter == payload_dur)begin
        hold <= 1'b0;
        end
    end 
    end
 
 assign  payload = reg_payload;
 
 always @(posedge clock_in)
 begin
  counter_divisor_4m <= counter_divisor_4m + 22'd1;
  if(counter_divisor_4m>=(tdc_clock_4M-1))begin
    counter_divisor_4m <= 22'd0;
    clock_out_4MHz <= `DLY ~clock_out_4MHz;
  end
 end
 
reg[21:0] trigger_c=22'd0;
reg trigger = 1'b0;

 always @(posedge clock_in)
 begin
  trigger_c <= trigger_c + 22'h1;
  if(trigger_c >=(DIVISOR_trigger-1))begin
   trigger_c <= 22'd0;
   trigger <= `DLY ~trigger;
  end
 end

   assign trgr_dca = trigger;  
  assign divided_4mhz_clock = clock_out_4MHz;
  assign tdc_clock = reg_payload & clock_out_4MHz;
endmodule
