`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/17/2023 02:19:01 PM
// Design Name: 
// Module Name: switch_controller
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


module switch_controller(
input wire clock_in, // input clock from TX
input wire [7:0] destination,
output reg [1:0]switch_control
    );
    
 always @(posedge clock_in)
    begin
    if (destination == 8'h01)
        switch_control <= 2'b00;
    else if (destination == 8'h02)
        switch_control <= 2'b01;
    else
        switch_control <= 2'b10;
    end   
    
    
    
endmodule
