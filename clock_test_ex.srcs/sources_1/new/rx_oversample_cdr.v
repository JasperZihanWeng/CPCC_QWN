`timescale 1ns/1ps
//==============================================================================
// rx_oversample_cdr
//------------------------------------------------------------------------------
// Blind-oversample digital CDR for the bufferless QWN RX path.
//
// The GTH RX runs at 8x the 1.25 Gbaud optical rate (RXCDRHOLD=1 -> sampling
// grid is the local Si570 ref, NOT locked to data; per AMD/XAPP572). This block
// recovers the 1.25 Gbaud bit stream from the 8x-oversampled sample stream by
// edge tracking + eye-centre selection ("sample furthest from a transition",
// XAPP572). It is intentionally written sample-serial (one sample/clock) so the
// algorithm is transparent and exhaustively verifiable; the HW version unrolls
// 64 samples/rxusrclk2 word (see IMPLEMENTATION_LOG / TODO: rx_oversample_cdr_hw).
//
// Outputs, per recovered optical bit:
//   bit_o        recovered data bit (eye-centre sample)
//   bit_valid_o  1-cycle strobe when bit_o is valid
//   phase_o[3:0] sample index (0..OS-1) chosen as eye centre for THIS bit,
//                relative to this block's free-running sample counter. This is
//                the sub-UI (UI/OS) position used by the fiducial extractor.
//==============================================================================
module rx_oversample_cdr #(
    parameter OS = 8            // oversampling factor (10 Gb/s / 1.25 Gbaud)
)(
    input  wire       clk,      // sample clock (one s_i sample per clk)
    input  wire       rst,      // sync, active high
    input  wire       s_i,      // oversampled serial sample
    output reg        bit_o,
    output reg        bit_valid_o,
    output reg  [3:0] phase_o,
    output reg  [3:0] sphase_o,    // FREE-RUNNING local sample phase (mod OS).
    output reg  [3:0] eph_o        // free-running phase LATCHED AT EACH DATA
                                   // EDGE = sub-UI position of the optical edge
                                   // vs the local grid (ODELAY fine code).
                                   // Not bv-aliased; varies with sampling skew.
);
    localparam HALF = OS/2;

    reg        s_d;             // previous sample (edge detect)
    reg  [3:0] cnt;             // 0..OS-1 sample counter within a bit period
    reg        armed;           // got at least one edge -> phase known
    reg  [3:0] sample_pt;       // count value at which to capture eye centre

    wire edge_seen = (s_i ^ s_d);

    always @(posedge clk) begin
        if (rst) begin
            s_d         <= 1'b0;
            cnt         <= 4'd0;
            armed       <= 1'b0;
            sample_pt   <= HALF[3:0];
            bit_o       <= 1'b0;
            bit_valid_o <= 1'b0;
            phase_o     <= 4'd0;
            sphase_o    <= 4'd0;
            eph_o       <= 4'd0;
        end else begin
            s_d         <= s_i;
            bit_valid_o <= 1'b0;
            sphase_o    <= (sphase_o == (OS-1)) ? 4'd0 : (sphase_o + 4'd1);
            if (edge_seen) eph_o <= sphase_o;   // latch grid phase at the edge

            // On a data edge, re-centre: the eye centre is HALF samples after
            // the transition. This re-aligns every transition (handles ppm by
            // continual re-centring; bounded run length keeps it tracked).
            if (edge_seen) begin
                cnt       <= 4'd1;                       // this clk is sample 0 of new bit
                sample_pt <= HALF[3:0];
                armed     <= 1'b1;
            end else if (cnt == (OS-1)) begin
                cnt <= 4'd0;
            end else begin
                cnt <= cnt + 4'd1;
            end

            // Capture the eye-centre sample once per bit period.
            if (armed && (cnt == sample_pt)) begin
                bit_o       <= s_i;
                bit_valid_o <= 1'b1;
                phase_o     <= cnt;     // sub-UI position of the captured sample
            end
        end
    end
endmodule
