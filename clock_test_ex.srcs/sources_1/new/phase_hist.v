`timescale 1ns/1ps
//==============================================================================
// phase_hist -- on-chip histogram of the recovered sub-UI phase.
//
// Bins the committed per-burst eph (0..7, the 8x oversample sub-bit phase,
// 100 ps/bin) over many VALIDATED bursts. (Originally fed gate_fine; since
// B8 gate_fine is the 8-bit ANCHORED trim, so the top now feeds gate_inst --
// the committed INSTANTANEOUS eph -- and the 100 ps/bin meaning of the 8
// bins is unchanged.) The shape of the 8 bins = the distribution of the
// marker's fine phase = the intra-channel sub-UI jitter (at 100 ps
// resolution), with NO
// ODELAY, NO Time Tagger -- just read the counts. Increment in the recovered
// rxusrclk2 domain on each hdr_valid (real bursts only, so dark false fiducials
// don't pollute). rsel selects which bin to expose; the count is read async by
// the VIO (counts are monotonic + slowly-incrementing -> a skewed read is rare
// and self-corrects on re-read).
//
// READOUT PATH + BIN REPURPOSING (lives in qwn_exdes, documented here
// because pollers see it through this module's bins): two instances (lane 0
// idx 0-7, lane 1 idx 8-15); a free-running top-level index sweeps the 16
// bins at ~26.8 ms/step and packs {idx[31:28], ui0[27:25], ui1[24:22],
// count[21:0]} into VIO probe_in17 (count truncated 28b -> 22b there, ~4M
// runway). Lane 1 is dark on this bench, so its upper bins are REPURPOSED at
// the top mux as occurrence counters: idx11 = veto count, idx12 = stale-ui
// events, idx13 = reopen-blocked, idx14 = mark_oserdes fire_cnt, idx15 =
// marker-clock locked. GOTCHA for pollers: the index advances on its own --
// poll much faster than 26.8 ms/bin or bins alias and coverage silently
// fails (see probe_targets2.tcl notes).
//
// EVIDENCE ROLE: this readout produced the campaign's scope-free rate
// numbers -- per-build eph distributions, and via the repurposed bins (B6):
// stale-ui 0.03%, reopen-blocked ~98%, markers per validated header = 1.0000
// over 3.1M bursts.
//==============================================================================
module phase_hist #(
    parameter CW = 28      // per-bin counter width (2^28 ~ 2 h before wrap)
)(
    input  wire        clk,      // rxusrclk2 (gate_fine / stb domain)
    input  wire        rst,
    input  wire [3:0]  fine,     // sub-UI phase to bin; B8+: the top feeds
                                 // {1'b0, gate_inst} (committed INST eph
                                 // 0..7) -- NOT the 8-bit anchored gate_fine
    input  wire        stb,      // bin strobe (hdr_valid = one per real burst)
    input  wire [2:0]  rsel,     // which bin to expose on rcount
    output wire [CW-1:0] rcount
);
    // 8 x CW register file (one write port = the binned increment, one
    // asynchronous read port = the rsel mux below; synthesizes to FFs /
    // distributed RAM). CDC note: rcount is sampled by the JTAG-clocked VIO
    // with no synchronizer; a torn mid-increment read is possible but
    // harmless for a monotonic, slowly-stepping count (header rationale).
    reg [CW-1:0] bins [0:7];
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i=0;i<8;i=i+1) bins[i] <= {CW{1'b0}};
        end else if (stb) begin
            bins[fine[2:0]] <= bins[fine[2:0]] + 1'b1;
        end
    end
    assign rcount = bins[rsel];   // 8:1 mux, async-sampled by the VIO
endmodule
