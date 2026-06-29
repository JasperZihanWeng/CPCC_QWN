// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2023.2 (win64) Build 4029153 Fri Oct 13 20:14:34 MDT 2023
// Date        : Sun May 17 21:46:20 2026
// Host        : ECE-OP7010PC2 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub -rename_top decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix -prefix
//               decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_ clock_test_stub.v
// Design      : clock_test
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7vx690tffg1761-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "clock_test,gtwizard_v3_6_15,{protocol_file=Start_from_scratch}" *)
module decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix(sysclk_in, soft_reset_tx_in, 
  soft_reset_rx_in, dont_reset_on_data_error_in, gt0_tx_fsm_reset_done_out, 
  gt0_rx_fsm_reset_done_out, gt0_data_valid_in, gt0_tx_mmcm_lock_in, 
  gt0_tx_mmcm_reset_out, gt0_rx_mmcm_lock_in, gt0_rx_mmcm_reset_out, 
  gt1_tx_fsm_reset_done_out, gt1_rx_fsm_reset_done_out, gt1_data_valid_in, 
  gt1_tx_mmcm_lock_in, gt1_tx_mmcm_reset_out, gt1_rx_mmcm_lock_in, gt1_rx_mmcm_reset_out, 
  gt2_tx_fsm_reset_done_out, gt2_rx_fsm_reset_done_out, gt2_data_valid_in, 
  gt2_tx_mmcm_lock_in, gt2_tx_mmcm_reset_out, gt2_rx_mmcm_lock_in, gt2_rx_mmcm_reset_out, 
  gt3_tx_fsm_reset_done_out, gt3_rx_fsm_reset_done_out, gt3_data_valid_in, 
  gt3_tx_mmcm_lock_in, gt3_tx_mmcm_reset_out, gt3_rx_mmcm_lock_in, gt3_rx_mmcm_reset_out, 
  gt0_gtnorthrefclk0_in, gt0_gtnorthrefclk1_in, gt0_gtsouthrefclk0_in, 
  gt0_gtsouthrefclk1_in, gt0_drpaddr_in, gt0_drpclk_in, gt0_drpdi_in, gt0_drpdo_out, 
  gt0_drpen_in, gt0_drprdy_out, gt0_drpwe_in, gt0_rxsysclksel_in, gt0_txsysclksel_in, 
  gt0_loopback_in, gt0_eyescanreset_in, gt0_rxuserrdy_in, gt0_eyescandataerror_out, 
  gt0_eyescantrigger_in, gt0_rxcdrhold_in, gt0_rxslide_in, gt0_dmonitorout_out, 
  gt0_rxusrclk_in, gt0_rxusrclk2_in, gt0_rxdata_out, gt0_gthrxn_in, gt0_rxphmonitor_out, 
  gt0_rxphslipmonitor_out, gt0_rxbyteisaligned_out, gt0_rxbyterealign_out, 
  gt0_rxcommadet_out, gt0_rxmonitorout_out, gt0_rxmonitorsel_in, gt0_rxoutclk_out, 
  gt0_rxoutclkfabric_out, gt0_gtrxreset_in, gt0_gthrxp_in, gt0_rxresetdone_out, 
  gt0_gttxreset_in, gt0_txuserrdy_in, gt0_txusrclk_in, gt0_txusrclk2_in, gt0_txinhibit_in, 
  gt0_txdata_in, gt0_gthtxn_out, gt0_gthtxp_out, gt0_txoutclk_out, gt0_txoutclkfabric_out, 
  gt0_txoutclkpcs_out, gt0_txresetdone_out, gt1_gtnorthrefclk0_in, gt1_gtnorthrefclk1_in, 
  gt1_gtsouthrefclk0_in, gt1_gtsouthrefclk1_in, gt1_drpaddr_in, gt1_drpclk_in, 
  gt1_drpdi_in, gt1_drpdo_out, gt1_drpen_in, gt1_drprdy_out, gt1_drpwe_in, 
  gt1_rxsysclksel_in, gt1_txsysclksel_in, gt1_loopback_in, gt1_eyescanreset_in, 
  gt1_rxuserrdy_in, gt1_eyescandataerror_out, gt1_eyescantrigger_in, gt1_rxcdrhold_in, 
  gt1_rxslide_in, gt1_dmonitorout_out, gt1_rxusrclk_in, gt1_rxusrclk2_in, gt1_rxdata_out, 
  gt1_gthrxn_in, gt1_rxphmonitor_out, gt1_rxphslipmonitor_out, gt1_rxbyteisaligned_out, 
  gt1_rxbyterealign_out, gt1_rxcommadet_out, gt1_rxmonitorout_out, gt1_rxmonitorsel_in, 
  gt1_rxoutclk_out, gt1_rxoutclkfabric_out, gt1_gtrxreset_in, gt1_gthrxp_in, 
  gt1_rxresetdone_out, gt1_gttxreset_in, gt1_txuserrdy_in, gt1_txusrclk_in, 
  gt1_txusrclk2_in, gt1_txinhibit_in, gt1_txdata_in, gt1_gthtxn_out, gt1_gthtxp_out, 
  gt1_txoutclk_out, gt1_txoutclkfabric_out, gt1_txoutclkpcs_out, gt1_txresetdone_out, 
  gt2_gtnorthrefclk0_in, gt2_gtnorthrefclk1_in, gt2_gtsouthrefclk0_in, 
  gt2_gtsouthrefclk1_in, gt2_drpaddr_in, gt2_drpclk_in, gt2_drpdi_in, gt2_drpdo_out, 
  gt2_drpen_in, gt2_drprdy_out, gt2_drpwe_in, gt2_rxsysclksel_in, gt2_txsysclksel_in, 
  gt2_loopback_in, gt2_eyescanreset_in, gt2_rxuserrdy_in, gt2_eyescandataerror_out, 
  gt2_eyescantrigger_in, gt2_rxcdrhold_in, gt2_rxslide_in, gt2_dmonitorout_out, 
  gt2_rxusrclk_in, gt2_rxusrclk2_in, gt2_rxdata_out, gt2_gthrxn_in, gt2_rxphmonitor_out, 
  gt2_rxphslipmonitor_out, gt2_rxbyteisaligned_out, gt2_rxbyterealign_out, 
  gt2_rxcommadet_out, gt2_rxmonitorout_out, gt2_rxmonitorsel_in, gt2_rxoutclk_out, 
  gt2_rxoutclkfabric_out, gt2_gtrxreset_in, gt2_gthrxp_in, gt2_rxresetdone_out, 
  gt2_gttxreset_in, gt2_txuserrdy_in, gt2_txusrclk_in, gt2_txusrclk2_in, gt2_txinhibit_in, 
  gt2_txdata_in, gt2_gthtxn_out, gt2_gthtxp_out, gt2_txoutclk_out, gt2_txoutclkfabric_out, 
  gt2_txoutclkpcs_out, gt2_txresetdone_out, gt3_gtnorthrefclk0_in, gt3_gtnorthrefclk1_in, 
  gt3_gtsouthrefclk0_in, gt3_gtsouthrefclk1_in, gt3_drpaddr_in, gt3_drpclk_in, 
  gt3_drpdi_in, gt3_drpdo_out, gt3_drpen_in, gt3_drprdy_out, gt3_drpwe_in, 
  gt3_rxsysclksel_in, gt3_txsysclksel_in, gt3_loopback_in, gt3_eyescanreset_in, 
  gt3_rxuserrdy_in, gt3_eyescandataerror_out, gt3_eyescantrigger_in, gt3_rxcdrhold_in, 
  gt3_rxslide_in, gt3_dmonitorout_out, gt3_rxusrclk_in, gt3_rxusrclk2_in, gt3_rxdata_out, 
  gt3_gthrxn_in, gt3_rxphmonitor_out, gt3_rxphslipmonitor_out, gt3_rxbyteisaligned_out, 
  gt3_rxbyterealign_out, gt3_rxcommadet_out, gt3_rxmonitorout_out, gt3_rxmonitorsel_in, 
  gt3_rxoutclk_out, gt3_rxoutclkfabric_out, gt3_gtrxreset_in, gt3_gthrxp_in, 
  gt3_rxresetdone_out, gt3_gttxreset_in, gt3_txuserrdy_in, gt3_txusrclk_in, 
  gt3_txusrclk2_in, gt3_txinhibit_in, gt3_txdata_in, gt3_gthtxn_out, gt3_gthtxp_out, 
  gt3_txoutclk_out, gt3_txoutclkfabric_out, gt3_txoutclkpcs_out, gt3_txresetdone_out, 
  gt0_qplllock_in, gt0_qpllrefclklost_in, gt0_qpllreset_out, gt0_qplloutclk_in, 
  gt0_qplloutrefclk_in)
/* synthesis syn_black_box black_box_pad_pin="soft_reset_tx_in,soft_reset_rx_in,dont_reset_on_data_error_in,gt0_tx_fsm_reset_done_out,gt0_rx_fsm_reset_done_out,gt0_data_valid_in,gt0_tx_mmcm_lock_in,gt0_tx_mmcm_reset_out,gt0_rx_mmcm_lock_in,gt0_rx_mmcm_reset_out,gt1_tx_fsm_reset_done_out,gt1_rx_fsm_reset_done_out,gt1_data_valid_in,gt1_tx_mmcm_lock_in,gt1_tx_mmcm_reset_out,gt1_rx_mmcm_lock_in,gt1_rx_mmcm_reset_out,gt2_tx_fsm_reset_done_out,gt2_rx_fsm_reset_done_out,gt2_data_valid_in,gt2_tx_mmcm_lock_in,gt2_tx_mmcm_reset_out,gt2_rx_mmcm_lock_in,gt2_rx_mmcm_reset_out,gt3_tx_fsm_reset_done_out,gt3_rx_fsm_reset_done_out,gt3_data_valid_in,gt3_tx_mmcm_lock_in,gt3_tx_mmcm_reset_out,gt3_rx_mmcm_lock_in,gt3_rx_mmcm_reset_out,gt0_drpaddr_in[8:0],gt0_drpdi_in[15:0],gt0_drpdo_out[15:0],gt0_drpen_in,gt0_drprdy_out,gt0_drpwe_in,gt0_rxsysclksel_in[1:0],gt0_txsysclksel_in[1:0],gt0_loopback_in[2:0],gt0_eyescanreset_in,gt0_rxuserrdy_in,gt0_eyescandataerror_out,gt0_eyescantrigger_in,gt0_rxcdrhold_in,gt0_rxslide_in,gt0_dmonitorout_out[14:0],gt0_rxdata_out[63:0],gt0_gthrxn_in,gt0_rxphmonitor_out[4:0],gt0_rxphslipmonitor_out[4:0],gt0_rxbyteisaligned_out,gt0_rxbyterealign_out,gt0_rxcommadet_out,gt0_rxmonitorout_out[6:0],gt0_rxmonitorsel_in[1:0],gt0_rxoutclk_out,gt0_rxoutclkfabric_out,gt0_gtrxreset_in,gt0_gthrxp_in,gt0_rxresetdone_out,gt0_gttxreset_in,gt0_txuserrdy_in,gt0_txinhibit_in,gt0_txdata_in[63:0],gt0_gthtxn_out,gt0_gthtxp_out,gt0_txoutclk_out,gt0_txoutclkfabric_out,gt0_txoutclkpcs_out,gt0_txresetdone_out,gt1_drpaddr_in[8:0],gt1_drpdi_in[15:0],gt1_drpdo_out[15:0],gt1_drpen_in,gt1_drprdy_out,gt1_drpwe_in,gt1_rxsysclksel_in[1:0],gt1_txsysclksel_in[1:0],gt1_loopback_in[2:0],gt1_eyescanreset_in,gt1_rxuserrdy_in,gt1_eyescandataerror_out,gt1_eyescantrigger_in,gt1_rxcdrhold_in,gt1_rxslide_in,gt1_dmonitorout_out[14:0],gt1_rxdata_out[63:0],gt1_gthrxn_in,gt1_rxphmonitor_out[4:0],gt1_rxphslipmonitor_out[4:0],gt1_rxbyteisaligned_out,gt1_rxbyterealign_out,gt1_rxcommadet_out,gt1_rxmonitorout_out[6:0],gt1_rxmonitorsel_in[1:0],gt1_rxoutclk_out,gt1_rxoutclkfabric_out,gt1_gtrxreset_in,gt1_gthrxp_in,gt1_rxresetdone_out,gt1_gttxreset_in,gt1_txuserrdy_in,gt1_txinhibit_in,gt1_txdata_in[63:0],gt1_gthtxn_out,gt1_gthtxp_out,gt1_txoutclk_out,gt1_txoutclkfabric_out,gt1_txoutclkpcs_out,gt1_txresetdone_out,gt2_drpaddr_in[8:0],gt2_drpdi_in[15:0],gt2_drpdo_out[15:0],gt2_drpen_in,gt2_drprdy_out,gt2_drpwe_in,gt2_rxsysclksel_in[1:0],gt2_txsysclksel_in[1:0],gt2_loopback_in[2:0],gt2_eyescanreset_in,gt2_rxuserrdy_in,gt2_eyescandataerror_out,gt2_eyescantrigger_in,gt2_rxcdrhold_in,gt2_rxslide_in,gt2_dmonitorout_out[14:0],gt2_rxdata_out[63:0],gt2_gthrxn_in,gt2_rxphmonitor_out[4:0],gt2_rxphslipmonitor_out[4:0],gt2_rxbyteisaligned_out,gt2_rxbyterealign_out,gt2_rxcommadet_out,gt2_rxmonitorout_out[6:0],gt2_rxmonitorsel_in[1:0],gt2_rxoutclk_out,gt2_rxoutclkfabric_out,gt2_gtrxreset_in,gt2_gthrxp_in,gt2_rxresetdone_out,gt2_gttxreset_in,gt2_txuserrdy_in,gt2_txinhibit_in,gt2_txdata_in[63:0],gt2_gthtxn_out,gt2_gthtxp_out,gt2_txoutclk_out,gt2_txoutclkfabric_out,gt2_txoutclkpcs_out,gt2_txresetdone_out,gt3_drpaddr_in[8:0],gt3_drpdi_in[15:0],gt3_drpdo_out[15:0],gt3_drpen_in,gt3_drprdy_out,gt3_drpwe_in,gt3_rxsysclksel_in[1:0],gt3_txsysclksel_in[1:0],gt3_loopback_in[2:0],gt3_eyescanreset_in,gt3_rxuserrdy_in,gt3_eyescandataerror_out,gt3_eyescantrigger_in,gt3_rxcdrhold_in,gt3_rxslide_in,gt3_dmonitorout_out[14:0],gt3_rxdata_out[63:0],gt3_gthrxn_in,gt3_rxphmonitor_out[4:0],gt3_rxphslipmonitor_out[4:0],gt3_rxbyteisaligned_out,gt3_rxbyterealign_out,gt3_rxcommadet_out,gt3_rxmonitorout_out[6:0],gt3_rxmonitorsel_in[1:0],gt3_rxoutclk_out,gt3_rxoutclkfabric_out,gt3_gtrxreset_in,gt3_gthrxp_in,gt3_rxresetdone_out,gt3_gttxreset_in,gt3_txuserrdy_in,gt3_txinhibit_in,gt3_txdata_in[63:0],gt3_gthtxn_out,gt3_gthtxp_out,gt3_txoutclk_out,gt3_txoutclkfabric_out,gt3_txoutclkpcs_out,gt3_txresetdone_out,gt0_qplllock_in,gt0_qpllrefclklost_in,gt0_qpllreset_out,gt0_qplloutrefclk_in" */
/* synthesis syn_force_seq_prim="sysclk_in" */
/* synthesis syn_force_seq_prim="gt0_gtnorthrefclk0_in" */
/* synthesis syn_force_seq_prim="gt0_gtnorthrefclk1_in" */
/* synthesis syn_force_seq_prim="gt0_gtsouthrefclk0_in" */
/* synthesis syn_force_seq_prim="gt0_gtsouthrefclk1_in" */
/* synthesis syn_force_seq_prim="gt0_drpclk_in" */
/* synthesis syn_force_seq_prim="gt0_rxusrclk_in" */
/* synthesis syn_force_seq_prim="gt0_rxusrclk2_in" */
/* synthesis syn_force_seq_prim="gt0_txusrclk_in" */
/* synthesis syn_force_seq_prim="gt0_txusrclk2_in" */
/* synthesis syn_force_seq_prim="gt1_gtnorthrefclk0_in" */
/* synthesis syn_force_seq_prim="gt1_gtnorthrefclk1_in" */
/* synthesis syn_force_seq_prim="gt1_gtsouthrefclk0_in" */
/* synthesis syn_force_seq_prim="gt1_gtsouthrefclk1_in" */
/* synthesis syn_force_seq_prim="gt1_drpclk_in" */
/* synthesis syn_force_seq_prim="gt1_rxusrclk_in" */
/* synthesis syn_force_seq_prim="gt1_rxusrclk2_in" */
/* synthesis syn_force_seq_prim="gt1_txusrclk_in" */
/* synthesis syn_force_seq_prim="gt1_txusrclk2_in" */
/* synthesis syn_force_seq_prim="gt2_gtnorthrefclk0_in" */
/* synthesis syn_force_seq_prim="gt2_gtnorthrefclk1_in" */
/* synthesis syn_force_seq_prim="gt2_gtsouthrefclk0_in" */
/* synthesis syn_force_seq_prim="gt2_gtsouthrefclk1_in" */
/* synthesis syn_force_seq_prim="gt2_drpclk_in" */
/* synthesis syn_force_seq_prim="gt2_rxusrclk_in" */
/* synthesis syn_force_seq_prim="gt2_rxusrclk2_in" */
/* synthesis syn_force_seq_prim="gt2_txusrclk_in" */
/* synthesis syn_force_seq_prim="gt2_txusrclk2_in" */
/* synthesis syn_force_seq_prim="gt3_gtnorthrefclk0_in" */
/* synthesis syn_force_seq_prim="gt3_gtnorthrefclk1_in" */
/* synthesis syn_force_seq_prim="gt3_gtsouthrefclk0_in" */
/* synthesis syn_force_seq_prim="gt3_gtsouthrefclk1_in" */
/* synthesis syn_force_seq_prim="gt3_drpclk_in" */
/* synthesis syn_force_seq_prim="gt3_rxusrclk_in" */
/* synthesis syn_force_seq_prim="gt3_rxusrclk2_in" */
/* synthesis syn_force_seq_prim="gt3_txusrclk_in" */
/* synthesis syn_force_seq_prim="gt3_txusrclk2_in" */
/* synthesis syn_force_seq_prim="gt0_qplloutclk_in" */;
  input sysclk_in /* synthesis syn_isclock = 1 */;
  input soft_reset_tx_in;
  input soft_reset_rx_in;
  input dont_reset_on_data_error_in;
  output gt0_tx_fsm_reset_done_out;
  output gt0_rx_fsm_reset_done_out;
  input gt0_data_valid_in;
  input gt0_tx_mmcm_lock_in;
  output gt0_tx_mmcm_reset_out;
  input gt0_rx_mmcm_lock_in;
  output gt0_rx_mmcm_reset_out;
  output gt1_tx_fsm_reset_done_out;
  output gt1_rx_fsm_reset_done_out;
  input gt1_data_valid_in;
  input gt1_tx_mmcm_lock_in;
  output gt1_tx_mmcm_reset_out;
  input gt1_rx_mmcm_lock_in;
  output gt1_rx_mmcm_reset_out;
  output gt2_tx_fsm_reset_done_out;
  output gt2_rx_fsm_reset_done_out;
  input gt2_data_valid_in;
  input gt2_tx_mmcm_lock_in;
  output gt2_tx_mmcm_reset_out;
  input gt2_rx_mmcm_lock_in;
  output gt2_rx_mmcm_reset_out;
  output gt3_tx_fsm_reset_done_out;
  output gt3_rx_fsm_reset_done_out;
  input gt3_data_valid_in;
  input gt3_tx_mmcm_lock_in;
  output gt3_tx_mmcm_reset_out;
  input gt3_rx_mmcm_lock_in;
  output gt3_rx_mmcm_reset_out;
  input gt0_gtnorthrefclk0_in /* synthesis syn_isclock = 1 */;
  input gt0_gtnorthrefclk1_in /* synthesis syn_isclock = 1 */;
  input gt0_gtsouthrefclk0_in /* synthesis syn_isclock = 1 */;
  input gt0_gtsouthrefclk1_in /* synthesis syn_isclock = 1 */;
  input [8:0]gt0_drpaddr_in;
  input gt0_drpclk_in /* synthesis syn_isclock = 1 */;
  input [15:0]gt0_drpdi_in;
  output [15:0]gt0_drpdo_out;
  input gt0_drpen_in;
  output gt0_drprdy_out;
  input gt0_drpwe_in;
  input [1:0]gt0_rxsysclksel_in;
  input [1:0]gt0_txsysclksel_in;
  input [2:0]gt0_loopback_in;
  input gt0_eyescanreset_in;
  input gt0_rxuserrdy_in;
  output gt0_eyescandataerror_out;
  input gt0_eyescantrigger_in;
  input gt0_rxcdrhold_in;
  input gt0_rxslide_in;
  output [14:0]gt0_dmonitorout_out;
  input gt0_rxusrclk_in /* synthesis syn_isclock = 1 */;
  input gt0_rxusrclk2_in /* synthesis syn_isclock = 1 */;
  output [63:0]gt0_rxdata_out;
  input gt0_gthrxn_in;
  output [4:0]gt0_rxphmonitor_out;
  output [4:0]gt0_rxphslipmonitor_out;
  output gt0_rxbyteisaligned_out;
  output gt0_rxbyterealign_out;
  output gt0_rxcommadet_out;
  output [6:0]gt0_rxmonitorout_out;
  input [1:0]gt0_rxmonitorsel_in;
  output gt0_rxoutclk_out;
  output gt0_rxoutclkfabric_out;
  input gt0_gtrxreset_in;
  input gt0_gthrxp_in;
  output gt0_rxresetdone_out;
  input gt0_gttxreset_in;
  input gt0_txuserrdy_in;
  input gt0_txusrclk_in /* synthesis syn_isclock = 1 */;
  input gt0_txusrclk2_in /* synthesis syn_isclock = 1 */;
  input gt0_txinhibit_in;
  input [63:0]gt0_txdata_in;
  output gt0_gthtxn_out;
  output gt0_gthtxp_out;
  output gt0_txoutclk_out;
  output gt0_txoutclkfabric_out;
  output gt0_txoutclkpcs_out;
  output gt0_txresetdone_out;
  input gt1_gtnorthrefclk0_in /* synthesis syn_isclock = 1 */;
  input gt1_gtnorthrefclk1_in /* synthesis syn_isclock = 1 */;
  input gt1_gtsouthrefclk0_in /* synthesis syn_isclock = 1 */;
  input gt1_gtsouthrefclk1_in /* synthesis syn_isclock = 1 */;
  input [8:0]gt1_drpaddr_in;
  input gt1_drpclk_in /* synthesis syn_isclock = 1 */;
  input [15:0]gt1_drpdi_in;
  output [15:0]gt1_drpdo_out;
  input gt1_drpen_in;
  output gt1_drprdy_out;
  input gt1_drpwe_in;
  input [1:0]gt1_rxsysclksel_in;
  input [1:0]gt1_txsysclksel_in;
  input [2:0]gt1_loopback_in;
  input gt1_eyescanreset_in;
  input gt1_rxuserrdy_in;
  output gt1_eyescandataerror_out;
  input gt1_eyescantrigger_in;
  input gt1_rxcdrhold_in;
  input gt1_rxslide_in;
  output [14:0]gt1_dmonitorout_out;
  input gt1_rxusrclk_in /* synthesis syn_isclock = 1 */;
  input gt1_rxusrclk2_in /* synthesis syn_isclock = 1 */;
  output [63:0]gt1_rxdata_out;
  input gt1_gthrxn_in;
  output [4:0]gt1_rxphmonitor_out;
  output [4:0]gt1_rxphslipmonitor_out;
  output gt1_rxbyteisaligned_out;
  output gt1_rxbyterealign_out;
  output gt1_rxcommadet_out;
  output [6:0]gt1_rxmonitorout_out;
  input [1:0]gt1_rxmonitorsel_in;
  output gt1_rxoutclk_out;
  output gt1_rxoutclkfabric_out;
  input gt1_gtrxreset_in;
  input gt1_gthrxp_in;
  output gt1_rxresetdone_out;
  input gt1_gttxreset_in;
  input gt1_txuserrdy_in;
  input gt1_txusrclk_in /* synthesis syn_isclock = 1 */;
  input gt1_txusrclk2_in /* synthesis syn_isclock = 1 */;
  input gt1_txinhibit_in;
  input [63:0]gt1_txdata_in;
  output gt1_gthtxn_out;
  output gt1_gthtxp_out;
  output gt1_txoutclk_out;
  output gt1_txoutclkfabric_out;
  output gt1_txoutclkpcs_out;
  output gt1_txresetdone_out;
  input gt2_gtnorthrefclk0_in /* synthesis syn_isclock = 1 */;
  input gt2_gtnorthrefclk1_in /* synthesis syn_isclock = 1 */;
  input gt2_gtsouthrefclk0_in /* synthesis syn_isclock = 1 */;
  input gt2_gtsouthrefclk1_in /* synthesis syn_isclock = 1 */;
  input [8:0]gt2_drpaddr_in;
  input gt2_drpclk_in /* synthesis syn_isclock = 1 */;
  input [15:0]gt2_drpdi_in;
  output [15:0]gt2_drpdo_out;
  input gt2_drpen_in;
  output gt2_drprdy_out;
  input gt2_drpwe_in;
  input [1:0]gt2_rxsysclksel_in;
  input [1:0]gt2_txsysclksel_in;
  input [2:0]gt2_loopback_in;
  input gt2_eyescanreset_in;
  input gt2_rxuserrdy_in;
  output gt2_eyescandataerror_out;
  input gt2_eyescantrigger_in;
  input gt2_rxcdrhold_in;
  input gt2_rxslide_in;
  output [14:0]gt2_dmonitorout_out;
  input gt2_rxusrclk_in /* synthesis syn_isclock = 1 */;
  input gt2_rxusrclk2_in /* synthesis syn_isclock = 1 */;
  output [63:0]gt2_rxdata_out;
  input gt2_gthrxn_in;
  output [4:0]gt2_rxphmonitor_out;
  output [4:0]gt2_rxphslipmonitor_out;
  output gt2_rxbyteisaligned_out;
  output gt2_rxbyterealign_out;
  output gt2_rxcommadet_out;
  output [6:0]gt2_rxmonitorout_out;
  input [1:0]gt2_rxmonitorsel_in;
  output gt2_rxoutclk_out;
  output gt2_rxoutclkfabric_out;
  input gt2_gtrxreset_in;
  input gt2_gthrxp_in;
  output gt2_rxresetdone_out;
  input gt2_gttxreset_in;
  input gt2_txuserrdy_in;
  input gt2_txusrclk_in /* synthesis syn_isclock = 1 */;
  input gt2_txusrclk2_in /* synthesis syn_isclock = 1 */;
  input gt2_txinhibit_in;
  input [63:0]gt2_txdata_in;
  output gt2_gthtxn_out;
  output gt2_gthtxp_out;
  output gt2_txoutclk_out;
  output gt2_txoutclkfabric_out;
  output gt2_txoutclkpcs_out;
  output gt2_txresetdone_out;
  input gt3_gtnorthrefclk0_in /* synthesis syn_isclock = 1 */;
  input gt3_gtnorthrefclk1_in /* synthesis syn_isclock = 1 */;
  input gt3_gtsouthrefclk0_in /* synthesis syn_isclock = 1 */;
  input gt3_gtsouthrefclk1_in /* synthesis syn_isclock = 1 */;
  input [8:0]gt3_drpaddr_in;
  input gt3_drpclk_in /* synthesis syn_isclock = 1 */;
  input [15:0]gt3_drpdi_in;
  output [15:0]gt3_drpdo_out;
  input gt3_drpen_in;
  output gt3_drprdy_out;
  input gt3_drpwe_in;
  input [1:0]gt3_rxsysclksel_in;
  input [1:0]gt3_txsysclksel_in;
  input [2:0]gt3_loopback_in;
  input gt3_eyescanreset_in;
  input gt3_rxuserrdy_in;
  output gt3_eyescandataerror_out;
  input gt3_eyescantrigger_in;
  input gt3_rxcdrhold_in;
  input gt3_rxslide_in;
  output [14:0]gt3_dmonitorout_out;
  input gt3_rxusrclk_in /* synthesis syn_isclock = 1 */;
  input gt3_rxusrclk2_in /* synthesis syn_isclock = 1 */;
  output [63:0]gt3_rxdata_out;
  input gt3_gthrxn_in;
  output [4:0]gt3_rxphmonitor_out;
  output [4:0]gt3_rxphslipmonitor_out;
  output gt3_rxbyteisaligned_out;
  output gt3_rxbyterealign_out;
  output gt3_rxcommadet_out;
  output [6:0]gt3_rxmonitorout_out;
  input [1:0]gt3_rxmonitorsel_in;
  output gt3_rxoutclk_out;
  output gt3_rxoutclkfabric_out;
  input gt3_gtrxreset_in;
  input gt3_gthrxp_in;
  output gt3_rxresetdone_out;
  input gt3_gttxreset_in;
  input gt3_txuserrdy_in;
  input gt3_txusrclk_in /* synthesis syn_isclock = 1 */;
  input gt3_txusrclk2_in /* synthesis syn_isclock = 1 */;
  input gt3_txinhibit_in;
  input [63:0]gt3_txdata_in;
  output gt3_gthtxn_out;
  output gt3_gthtxp_out;
  output gt3_txoutclk_out;
  output gt3_txoutclkfabric_out;
  output gt3_txoutclkpcs_out;
  output gt3_txresetdone_out;
  input gt0_qplllock_in;
  input gt0_qpllrefclklost_in;
  output gt0_qpllreset_out;
  input gt0_qplloutclk_in /* synthesis syn_isclock = 1 */;
  input gt0_qplloutrefclk_in;
endmodule
