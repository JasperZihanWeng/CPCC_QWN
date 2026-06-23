`timescale 1ns/1ps
//==============================================================================
// tx_word_stream -- rate-matched per-clock 64-bit GT TX word streamer.
//
// Replaces tx_burst_seq + enc_8b10b + tx_gearbox. The entire burst (WARMUP
// K28.5 + SETTLE + FID + 8B10B header+payload) is pre-encoded offline by
// work/gen_tx_words.py into qwn_tx_words.mem (64-bit words, disparity-
// continuous). This module emits EXACTLY ONE ready word per txusrclk2 -> the
// GT (which consumes gt0_txdata every cycle in raw mode) gets a continuous,
// correctly-paced stream. Rate-matched by construction, mirroring the proven
// buffered gth_sfp_GT_FRAME_GEN; also eliminates the tx_burst_seq runtime
// ROM-prefetch off-by-one (no runtime pipeline) -> no duplicate SOH.
//
// Combinational ROM read (word_o = rom[cnt]) => zero latency, provably one
// fresh word per clock. ROM is small (warmup-dominated, ~hundreds of words)
// so LUT/distributed-RAM is fine; if a registered BRAM is later required,
// add a matching +1 on FIDW and the dark-phase compare.
//==============================================================================
// Per-period sequence:  [NW burst, laser ON] -> [GUARDW guard, laser ON,
// K28.5] -> [DARKW dark, laser OFF] -> wrap.
// The GUARD is a post-header laser-on tail of K28.5: the header sits at the
// burst tail, and the RX recovery pipeline (oversampler -> rx_frame_par ->
// rx_header) has multi-cycle latency. Without the guard, laser-off dark-noise
// floods the pipeline while the header bytes are still in flight -> header
// corrupted every burst (100% discard). The guard keeps clean K28.5 on the
// wire long enough (>> pipeline latency) for the header to fully validate
// before laser-off. gen_tx_words.py folds GUARDW into gate_delay so the
// recovered marker still lands at the true (post-dark) payload start.
module tx_word_stream #(
    parameter NW     = 25,                // burst words in qwn_tx_words.mem
    parameter FIDW   = 11,                // word index containing the FID symbol
    parameter GUARDW = 0,                 // post-header laser-ON K28.5 guard words
    parameter DARKW  = 0,                 // trailing dark (laser-OFF) words
    parameter MEM    = "qwn_tx_words.mem"
)(
    input  wire        clk,
    input  wire        rst,
    output wire [63:0] word_o,            // -> gt0_txdata (every clk)
    output reg         fid_stb,           // 1-cyc pulse at the FID word
    output reg         tx_inhibit,        // 1 during dark phase
    output reg         sfp_disable        // 1 during dark phase (laser off)
);
    localparam integer DS  = NW + GUARDW;          // dark-phase start index
    localparam integer TOT = NW + GUARDW + DARKW;  // full period
    localparam integer AW  = (TOT <= 1) ? 1 : $clog2(TOT);

    (* rom_style = "distributed" *)
    reg [63:0] rom [0:NW-1];
    initial $readmemh(MEM, rom);

    reg [AW-1:0] cnt;
    always @(posedge clk) begin
        if (rst)                cnt <= {AW{1'b0}};
        else if (cnt==TOT-1)    cnt <= {AW{1'b0}};
        else                    cnt <= cnt + 1'b1;
    end

    wire in_guard = (GUARDW != 0) && (cnt >= NW) && (cnt < DS);
    wire in_dark  = (DARKW  != 0) && (cnt >= DS);
    // guard & dark both hold ROM[0] (K28.5); guard = laser ON, dark = laser OFF
    assign word_o = (in_guard || in_dark) ? rom[0] : rom[cnt];

    always @(posedge clk) begin
        if (rst) begin fid_stb<=1'b0; tx_inhibit<=1'b1; sfp_disable<=1'b1; end
        else begin
            fid_stb     <= (cnt==FIDW[AW-1:0]);
            tx_inhibit  <= in_dark;      // laser stays ON through the guard
            sfp_disable <= in_dark;
        end
    end
endmodule
