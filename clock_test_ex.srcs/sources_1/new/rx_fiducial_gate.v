`timescale 1ns/1ps
//==============================================================================
// rx_fiducial_gate
//------------------------------------------------------------------------------
// Detects the burst SYNC then the unique FIDUCIAL byte in the recovered bit
// stream, latches the free-running sub-UI sample phase at the fiducial instant
// (= the ODELAY fine-tap code), then counts gate_delay_i recovered-bit periods
// and emits the gate.
//
// Determinism model (digital): the coarse gate fires an exact integer number of
// recovered-bit periods after the fiducial (ppm-free intra-burst). gate_fine_o
// is the captured sub-UI phase; applying it (the ODELAY tap in HW) cancels the
// arbitrary sampling-grid offset so (gate - true_fiducial_edge) is invariant
// across bursts / skew / ppm / dark gaps. Proven in tb_fiducial_gate.
//==============================================================================
module rx_fiducial_gate #(
    parameter [15:0] SYNC = 16'hFA53,
    parameter [7:0]  FID  = 8'h6B
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        bv,            // recovered-bit valid strobe
    input  wire        bit_o,         // recovered bit
    input  wire [3:0]  eph_i,         // edge-latched sub-UI phase from CDR
    input  wire [23:0] gate_delay_i,  // recovered-bit cycles fiducial->gate
    output reg         fid_seen_o,
    output reg         gate_o,
    output reg  [3:0]  gate_fine_o    // sub-UI correction -> ODELAY tap select
);
    localparam S_LOCK=2'd0, S_ARM=2'd1, S_CNT=2'd2;
    reg [1:0]  st;
    reg [15:0] sr;
    reg [23:0] cnt;

    wire [15:0] sr_n = {sr[14:0], bit_o};

    always @(posedge clk) begin
        if (rst) begin
            st<=S_LOCK; sr<=16'd0; cnt<=24'd0;
            fid_seen_o<=1'b0; gate_o<=1'b0; gate_fine_o<=4'd0;
        end else begin
            fid_seen_o<=1'b0; gate_o<=1'b0;
            if (bv) begin
                sr <= sr_n;
                case (st)
                    S_LOCK: if (sr_n==SYNC)            st<=S_ARM;
                    S_ARM : if (sr_n[7:0]==FID) begin
                                fid_seen_o  <= 1'b1;
                                gate_fine_o <= eph_i;      // latch sub-UI phase
                                cnt         <= 24'd0;
                                st          <= S_CNT;
                            end
                    S_CNT : begin
                                if (cnt == gate_delay_i-24'd1) begin
                                    gate_o <= 1'b1;        // coarse gate
                                    st     <= S_LOCK;      // re-arm next burst
                                    sr     <= 16'd0;
                                end
                                cnt <= cnt + 24'd1;
                            end
                endcase
            end
        end
    end
endmodule
