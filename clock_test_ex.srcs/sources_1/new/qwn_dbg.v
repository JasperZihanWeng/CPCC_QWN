`timescale 1ns/1ps
//==============================================================================
// qwn_dbg -- bring-up debug aggregator.
//
// Crosses RX-fabric (rxusrclk2) event strobes into the free-running drpclk
// domain and maintains sticky counters + latched header fields for the VIO
// probe_in ports. drpclk keeps running even when the GT/RX MMCM is down, so
// these stay readable over JTAG during reset/no-light conditions.
//
// Also provides GT bring-up diagnostics:
//   - qpll_l : QPLL lock, registered into drpclk (refclk/PLL health).
//   - tx_hb / rx_hb : clock-liveness counters. A toggle is generated every
//     2^14 ticks of gt0_txusrclk2 / gt0_rxusrclk2, synchronized to drpclk and
//     counted. If a GT user clock is dead (no refclk/PLL), its heartbeat
//     FREEZES; if alive, it increments. This definitively distinguishes
//     "GT reference clock absent" from "FSM/reset logic stuck".
//
// CDC: per-event toggle -> 3-FF synchronizer in drpclk -> edge detect ->
// counter. Latched values (dst/pd) double-registered (display only).
//==============================================================================
module qwn_dbg (
    // RX fabric domain
    input  wire        rx_clk,
    input  wire        rx_rst,
    input  wire        ev_good,   // qwn_byv & ~qwn_ce
    input  wire        ev_err,    // qwn_byv &  qwn_ce
    input  wire        ev_fid,    // qwn_fidp
    input  wire        ev_hv,     // qwn_hv  (header valid)
    input  wire        ev_hd,     // qwn_hd  (header discard)
    input  wire [7:0]  dst_i,
    input  wire [15:0] pd_i,
    // GT bring-up diagnostics
    input  wire        tx_clk,    // gt0_txusrclk2  (alive iff TX PLL/refclk ok)
    input  wire        rxhb_clk,  // gt0_rxusrclk2  (alive iff RX PLL/refclk ok)
    input  wire        qpll_i,    // gt0_qplllock   (async)
    // free-running domain
    input  wire        drpclk,
    output reg  [31:0] good_cnt,
    output reg  [31:0] err_cnt,
    output reg  [15:0] fid_cnt,
    output reg  [15:0] hv_cnt,
    output reg  [15:0] hd_cnt,
    output reg  [7:0]  dst_l,
    output reg  [15:0] pd_l,
    output reg         qpll_l,
    output reg  [15:0] tx_hb,
    output reg  [15:0] rx_hb
);
    // ---- RX domain: event -> toggle, slow-changing latch ----
    reg t_good, t_err, t_fid, t_hv, t_hd;
    reg [7:0]  dst_q;
    reg [15:0] pd_q;
    always @(posedge rx_clk) begin
        if (rx_rst) begin
            t_good<=1'b0; t_err<=1'b0; t_fid<=1'b0; t_hv<=1'b0; t_hd<=1'b0;
        end else begin
            if (ev_good) t_good <= ~t_good;
            if (ev_err ) t_err  <= ~t_err;
            if (ev_fid ) t_fid  <= ~t_fid;
            if (ev_hv  ) t_hv   <= ~t_hv;
            if (ev_hd  ) t_hd   <= ~t_hd;
        end
        if (ev_hv) begin dst_q <= dst_i; pd_q <= pd_i; end
    end

    // ---- clock-liveness: divide each GT user clock, emit a toggle ----
    reg [14:0] tx_div; reg tx_tg;
    always @(posedge tx_clk) begin tx_div<=tx_div+15'd1; if (tx_div==15'd0) tx_tg<=~tx_tg; end
    reg [14:0] rx_div; reg rx_tg;
    always @(posedge rxhb_clk) begin rx_div<=rx_div+15'd1; if (rx_div==15'd0) rx_tg<=~rx_tg; end

    // ---- drpclk domain: 3-FF sync + edge detect + count ----
    reg [2:0] s_good, s_err, s_fid, s_hv, s_hd, s_txhb, s_rxhb;
    reg [1:0] s_qpll;
    reg [7:0]  d0_dst, d1_dst;
    reg [15:0] d0_pd,  d1_pd;
    initial begin
        good_cnt=0; err_cnt=0; fid_cnt=0; hv_cnt=0; hd_cnt=0;
        dst_l=0; pd_l=0; qpll_l=0; tx_hb=0; rx_hb=0;
        s_good=0; s_err=0; s_fid=0; s_hv=0; s_hd=0; s_txhb=0; s_rxhb=0; s_qpll=0;
    end
    always @(posedge drpclk) begin
        s_good <= {s_good[1:0], t_good};
        s_err  <= {s_err [1:0], t_err };
        s_fid  <= {s_fid [1:0], t_fid };
        s_hv   <= {s_hv  [1:0], t_hv  };
        s_hd   <= {s_hd  [1:0], t_hd  };
        s_txhb <= {s_txhb[1:0], tx_tg };
        s_rxhb <= {s_rxhb[1:0], rx_tg };
        s_qpll <= {s_qpll[0],   qpll_i};
        if (s_good[2]^s_good[1]) good_cnt <= good_cnt + 32'd1;
        if (s_err [2]^s_err [1]) err_cnt  <= err_cnt  + 32'd1;
        if (s_fid [2]^s_fid [1]) fid_cnt  <= fid_cnt  + 16'd1;
        if (s_hv  [2]^s_hv  [1]) hv_cnt   <= hv_cnt   + 16'd1;
        if (s_hd  [2]^s_hd  [1]) hd_cnt   <= hd_cnt   + 16'd1;
        if (s_txhb[2]^s_txhb[1]) tx_hb    <= tx_hb    + 16'd1;
        if (s_rxhb[2]^s_rxhb[1]) rx_hb    <= rx_hb    + 16'd1;
        qpll_l <= s_qpll[1];
        d0_dst<=dst_q; d1_dst<=d0_dst; dst_l<=d1_dst;
        d0_pd <=pd_q;  d1_pd <=d0_pd;  pd_l <=d1_pd;
    end
endmodule
