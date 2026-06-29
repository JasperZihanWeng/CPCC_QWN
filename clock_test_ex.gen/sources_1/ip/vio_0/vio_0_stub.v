// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2023.2 (win64) Build 4029153 Fri Oct 13 20:14:34 MDT 2023
// Date        : Thu May 21 06:07:35 2026
// Host        : ECE-OP7010PC2 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub -rename_top vio_0 -prefix
//               vio_0_ vio_0_stub.v
// Design      : vio_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7vx690tffg1761-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "vio,Vivado 2023.2" *)
module vio_0(clk, probe_in0, probe_in1, probe_in2, probe_in3, 
  probe_in4, probe_in5, probe_in6, probe_in7, probe_in8, probe_in9, probe_in10, probe_in11, 
  probe_in12, probe_in13, probe_in14, probe_in15, probe_in16, probe_in17, probe_in18, probe_in19, 
  probe_in20, probe_in21, probe_in22, probe_in23, probe_in24, probe_out0, probe_out1, probe_out2, 
  probe_out3, probe_out4, probe_out5, probe_out6)
/* synthesis syn_black_box black_box_pad_pin="probe_in0[0:0],probe_in1[0:0],probe_in2[0:0],probe_in3[31:0],probe_in4[31:0],probe_in5[15:0],probe_in6[15:0],probe_in7[15:0],probe_in8[7:0],probe_in9[15:0],probe_in10[0:0],probe_in11[0:0],probe_in12[0:0],probe_in13[15:0],probe_in14[15:0],probe_in15[7:0],probe_in16[0:0],probe_in17[31:0],probe_in18[31:0],probe_in19[15:0],probe_in20[7:0],probe_in21[15:0],probe_in22[0:0],probe_in23[0:0],probe_in24[7:0],probe_out0[0:0],probe_out1[2:0],probe_out2[1:0],probe_out3[1:0],probe_out4[1:0],probe_out5[0:0],probe_out6[1:0]" */
/* synthesis syn_force_seq_prim="clk" */;
  input clk /* synthesis syn_isclock = 1 */;
  input [0:0]probe_in0;
  input [0:0]probe_in1;
  input [0:0]probe_in2;
  input [31:0]probe_in3;
  input [31:0]probe_in4;
  input [15:0]probe_in5;
  input [15:0]probe_in6;
  input [15:0]probe_in7;
  input [7:0]probe_in8;
  input [15:0]probe_in9;
  input [0:0]probe_in10;
  input [0:0]probe_in11;
  input [0:0]probe_in12;
  input [15:0]probe_in13;
  input [15:0]probe_in14;
  input [7:0]probe_in15;
  input [0:0]probe_in16;
  input [31:0]probe_in17;
  input [31:0]probe_in18;
  input [15:0]probe_in19;
  input [7:0]probe_in20;
  input [15:0]probe_in21;
  input [0:0]probe_in22;
  input [0:0]probe_in23;
  input [7:0]probe_in24;
  output [0:0]probe_out0;
  output [2:0]probe_out1;
  output [1:0]probe_out2;
  output [1:0]probe_out3;
  output [1:0]probe_out4;
  output [0:0]probe_out5;
  output [1:0]probe_out6;
endmodule
