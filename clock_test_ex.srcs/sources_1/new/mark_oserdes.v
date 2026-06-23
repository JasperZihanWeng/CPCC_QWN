`timescale 1ns/1ps
//==============================================================================
// mark_oserdes -- place the payload-start marker RISING EDGE at the burst's
// integer-UI slot (fix #3 Build B: kill the 8-mode / 800 ps stripe hop).
//
// WHY: rxusrclk2 is the GT-divided recovered clock (RXOUTCLKSEL=PMA). The
// divider has no phase memory across the laser-off gap, so each burst the
// recovered byte stream lands on one of 8 UI slots (800 ps grid) inside the
// 6.4 ns word -- the coarse gate (a rxusrclk2 FF) inherits that +-5.6 ns
// integer-UI ambiguity (the 8 scope stripes; HW-confirmed near-uniform over
// all 8 modes, p_a_2026-05-27). ODELAYE2 spans only ~2.4 ns -> can't reach.
// OSERDESE2 (DDR 8:1, CLK=625 MHz, CLKDIV=156.25 MHz) places an edge at any
// of the 8x800 ps sub-cycle slots: emit the marker edge AT slot ui_offset
// (the FID byte's bit-position captured by rx_frame_par/rx_header -- the
// burst's mode, observable in fabric) and the readout cancels the hop.
//
// WORD BUILD (D1 = earliest slot = bit 0): rise word = 8'hFF << slot (first
// '1' at slot), next word = ~(8'hFF << slot) (fall at the same slot) -> a
// marker pulse exactly 8 slots = 6.4 ns wide, both edges slot-placed, same
// width as the previous coarse marker. Idle = all-0.
//   FPGA-basics aside, OSERDESE2 DDR 8:1: the OLOGIC serializer accepts an
//   8-bit word per CLKDIV (156.25 MHz) cycle and shifts it out on BOTH edges
//   of CLK (625 MHz = 4x CLKDIV; 8 bits x 800 ps = one 6.4 ns word). D1 is
//   transmitted FIRST -- so D1 = the earliest 800 ps slot, D8 the latest.
// (Bench note, open item #40: N41 measures ~52 ns pulse width vs this 6.4 ns
// RTL width -- a post-OSERDES mystery downstream of the IOB. The RISING
// edge, which is the figure of merit, is unaffected; J40-vs-N41 width check
// pending.)
//
// CLOCKS as introduced (B2..B9): clk156/clk625 from one dedicated MMCM fed
// by rxusrclk2 with BUFG-deskewed feedback -> clk156 is phase-aligned &
// RELATED to rxusrclk2 (same master clock, gt_refclk group): the
// gate_in/ui_offset capture below is an ordinary timed FF-FF path, NOT an
// async CDC. ui_offset is quasi-static at capture time (latched at fid, gate
// fires ~gate_delay~2200 cycles later).
//   FPGA-basics aside, MMCM deskew: routing CLKFBOUT->BUFG->CLKFBIN puts a
//   BUFG insertion delay INSIDE the feedback loop, so the MMCM advances its
//   VCO until CLKOUTn as seen at the fabric (through its own BUFG) aligns
//   with CLKIN at the MMCM pin. That is what makes an MMCM "copy" of
//   rxusrclk2 phase-aligned to the original instead of lagging it by the
//   whole clock-network delay -- and what makes the capture a timed path.
//
// CLOCKS current (B10/B11 DE-CASCADE, p_b10/p_b11_2026-06-10): the dedicated
// marker MMCM (+3 BUFGs) is DELETED. clk156 is now rxusrclk2 ITSELF, and
// clk625 is the divide-1 625 MHz output (CLK2_OUT) of the SAME GT RX MMCM
// that already generates rxusrclk2 (rxoutclk_mmcm1 in the GENERATED
// clock_test_gt_usrclk_source.v: 312.5 MHz RXOUTCLKPMA in, MULT 2.0, VCO
// exactly 625 MHz; it always had this output, internally BUFG'd, unused).
// This removes the cascaded MMCM's VCO phase noise + tracking lag from the
// marker path AND eliminates the rxusrclk2->clk156 capture crossing entirely
// (the word builder below runs native rxusrclk2). CLOCK_DELAY_GROUP on
// {gt0_rxusrclk2_i, gt0_rxusrclk625_i} matches the two BUFG insertion delays
// so CLK/CLKDIV arrive at the OSERDES aligned. `locked` = the GT RX MMCM
// lock. (B11 JTAG-validated; analog verdict pending bench, see brief.)
//   FPGA-basics aside, the OSERDES CLK/CLKDIV pairing rule: the internal
//   CLKDIV->CLK word handoff inside OLOGIC has NO STA-covered path -- the
//   tools simply assume CLK and CLKDIV are the same-source, edge-aligned
//   pair the primitive requires (here 625/156.25 from one VCO). A misaligned
//   pair corrupts serialized words SILENTLY: no timing violation is ever
//   reported. This is why both clocks must come from one MMCM and why the
//   matched-insertion CLOCK_DELAY_GROUP matters.
//
// SIGN (INVERT_SLOT): later arrival -> FID symbol ends at a HIGHER slot ->
// marker must move LATER -> slot = ui_offset directly. Sim-verified
// (tb_uioff_e2e: marker tracks a 0..15 UI stream shift exactly, 800 ps/UI);
// parameter kept for HW calibration symmetry with mark_odelay.INVERT.
//
// OUTPUT: oq -> ODELAYE2.ODATAIN (mark_odelay, eph sub-UI trim) -> OBUF.
// OQ->ODATAIN is the dedicated OLOGIC->ODELAY path (DDR3-write style); it
// also forces OSERDES/ODELAY/OBUF into the marker pad's own IOB tile.
// Total placement = ui_offset x 800 ps (this) + anchored trim x 6.25 ps
// rounded to taps (ODELAY; B8+ -- see eph_filter.v / rx_gate.v).
//
// CHANGELOG / EVIDENCE:
//   p_b  (introduced, 2026-06-09): DEAD ON THE PIN -- the TQ/tristate
//        pitfall documented above the primitive below. Every sim passed.
//   p_b2: TCE=1/INIT_TQ=0 fix + fire_cnt diag; first slot-placed markers on
//        the bench; the 8-stripe / ~2 ns family collapsed.
//   B3  (p_b3): BORROW_TH coarse/fine handoff (parameter block below); the
//        +800 ps satellite (~25% of bursts) verified GONE in all later runs.
//   B4  (p_b4): top now feeds the COMMITTED gate_ui (latched at gate arm)
//        instead of rx_header's live ui_offset register; lock-gated firing.
//   B10/B11: same-MMCM clock pair (see CLOCKS above).
//   Sim: tb_mark_oserdes (exact 800 ps slot grid), tb_uioff_e2e (tracks
//   0..15-UI stream shifts exactly, sign direct), tb_subui_sweep (borrow).
//   HW: markers per validated header = 1.0000 over 3.1M bursts (B6, via
//   fire_cnt on hist idx14).
//==============================================================================
module mark_oserdes #(
    parameter INVERT_SLOT = 1'b0,   // flip ui->slot sign (HW-calibratable)
    // COARSE/FINE HANDOFF BORROW: the framer's ui_offset increments TWO eph
    // steps BEFORE the eph wrap (tb_subui_sweep, 100 ps-granularity sweep:
    // eph 6,7 -> k already new but trim still high -> composite one UI LATE
    // = the +800 ps satellite bin seen on the bench 2026-06-09, ~25% of
    // bursts). slot_eff = ui_offset-1 when eph >= BORROW_TH re-aligns the
    // two estimators. Wrap (slot 0 -> previous word's slot 7) is absorbed by
    // ONE constant word of added latency (calibrates out).
    parameter [2:0] BORROW_TH = 3'd6
)(
    input  wire       clk156,      // OSERDES CLKDIV (B10+: rxusrclk2 itself;
                                   // pre-B10: dedicated marker-MMCM 156.25)
    input  wire       clk625,      // OSERDES CLK, 4x clk156 from the SAME
                                   // MMCM/VCO (B10+: GT RX MMCM CLK2_OUT)
    input  wire       rst,         // async: rx reset | ~MMCM locked
    input  wire       gate_in,     // 1-cycle coarse marker pulse (rxusrclk2 FF)
    input  wire [2:0] ui_offset,   // burst integer-UI mode. B4+: this is the
                                   // COMMITTED rx_gate.gate_ui (latched at
                                   // arm, immune to dark false-fid rewrites),
                                   // NOT rx_header's live register
    input  wire [2:0] eph_in,      // committed INSTANTANEOUS eph (rx_gate
                                   // gate_inst). B8 split-role: the borrow
                                   // must stay on inst eph, correlated with
                                   // the framer's k -- never the filtered/
                                   // anchored gate_fine (see eph_filter.v)
    input  wire       locked,      // clock-source MMCM LOCKED (B10+: GT RX
                                   // MMCM): suppress fire while
                                   // low (transient grid = wrong placement;
                                   // missing gate, never a wrong gate)
    output wire       oq,          // -> mark_odelay.gate_in (ODATAIN) -> pad
    output reg [21:0] fire_cnt     // captured-gate count (HW diag, hist idx14)
);
    // 2-FF synchronizer for the (async) LOCKED status. FPGA-basics aside:
    // ASYNC_REG marks these as CDC flops -- Vivado packs them into one slice
    // (minimal metastability exposure) and won't fold them into an SRL.
    (* ASYNC_REG = "TRUE" *) reg [1:0] lk_s = 2'b00;
    // reset bridge: async assert, release synchronous to CLKDIV (UG471
    // OSERDES requirement -- de-asserting RST asynchronously can bring the
    // internal CLK/CLKDIV divider up in a skewed phase, yet another OSERDES
    // failure mode STA cannot see)
    (* ASYNC_REG = "TRUE" *) reg [1:0] rst_s = 2'b11;
    always @(posedge clk156 or posedge rst)
        if (rst) rst_s <= 2'b11; else rst_s <= {rst_s[0], 1'b0};
    wire srst = rst_s[1];

    always @(posedge clk156) lk_s <= {lk_s[0], locked};

    wire [2:0] slot_in = INVERT_SLOT ? (3'd7 - ui_offset) : ui_offset;

    // capture (timed related-clock path) + borrow + 2-word pulse builder.
    // Position in slot units with a constant +8 (one word) of headroom:
    //   P = slot + 8 - borrow  in {7..15}
    // P==7  (slot 0 borrowing) -> fire rise word NOW at slot 7;
    // P>=8                     -> fire rise word NEXT cycle at slot P-8.
    // All markers carry the same +1-word latency except the P==7 wrap case,
    // which is exactly the -1 UI it needs relative to them.
    reg       g_q;
    reg [2:0] ui_q, eph_q, ui_fire;
    reg       rise_pend, fall_pend;
    reg [7:0] dword;
    wire        borrow = (eph_q >= BORROW_TH);
    wire [3:0]  pos    = {1'b0, ui_q} + 4'd8 - {3'd0, borrow};
    always @(posedge clk156) begin
        if (srst) begin
            g_q <= 1'b0; ui_q <= 3'd0; eph_q <= 3'd0; ui_fire <= 3'd0;
            rise_pend <= 1'b0; fall_pend <= 1'b0;
            dword <= 8'h00; fire_cnt <= 22'd0;
        end else begin
            g_q   <= gate_in & lk_s[1];         // fire only with stable grid
            ui_q  <= slot_in;                   // quasi-static by gate time
            eph_q <= eph_in;
            rise_pend <= 1'b0;
            if (fall_pend) begin
                dword <= ~(8'hFF << ui_fire);   // fall at the same slot
                fall_pend <= 1'b0;
            end else if (rise_pend) begin
                dword <= 8'hFF << ui_fire;      // delayed rise (P>=8 path)
                fall_pend <= 1'b1;
            end else if (g_q) begin
                fire_cnt <= fire_cnt + 22'd1;   // HW diag: capture FF saw gate
                if (pos == 4'd7) begin
                    dword <= 8'hFF << 3'd7;     // wrap: rise NOW at slot 7
                    ui_fire <= 3'd7;
                    fall_pend <= 1'b1;
                end else begin
                    ui_fire <= pos[2:0];        // rise next cycle at P-8
                    rise_pend <= 1'b1;
                    dword <= 8'h00;
                end
            end else begin
                dword <= 8'h00;
            end
        end
    end

    // TRISTATE path: TCE=1 + T1=0 actively clocks the tristate register to 0
    // every CLKDIV, and INIT_TQ/SRVAL_TQ=0 so it NEVER presents Hi-Z. (First
    // p_b spin had TCE=0/INIT_TQ=1: the unisim's OQ ignores TQ so every sim
    // passed, but in the physical IOB the OLOGIC tristate path can hold the
    // output buffer disabled -> N41 dead on the bench, 2026-06-09.)
    OSERDESE2 #(
        .DATA_RATE_OQ   ("DDR"),
        .DATA_RATE_TQ   ("SDR"),
        .DATA_WIDTH     (8),
        .INIT_OQ        (1'b0),
        .INIT_TQ        (1'b0),
        .SERDES_MODE    ("MASTER"),
        .SRVAL_OQ       (1'b0),
        .SRVAL_TQ       (1'b0),
        .TBYTE_CTL      ("FALSE"),
        .TBYTE_SRC      ("FALSE"),
        .TRISTATE_WIDTH (1)
    ) u_oserdes (
        .OQ        (oq),
        .OFB       (),
        .TQ        (),
        .TFB       (),
        .SHIFTOUT1 (),
        .SHIFTOUT2 (),
        .TBYTEOUT  (),
        .CLK       (clk625),
        .CLKDIV    (clk156),
        .D1        (dword[0]),     // earliest slot
        .D2        (dword[1]),
        .D3        (dword[2]),
        .D4        (dword[3]),
        .D5        (dword[4]),
        .D6        (dword[5]),
        .D7        (dword[6]),
        .D8        (dword[7]),     // latest slot
        .OCE       (1'b1),
        .RST       (srst),
        .SHIFTIN1  (1'b0),
        .SHIFTIN2  (1'b0),
        .T1        (1'b0),
        .T2        (1'b0),
        .T3        (1'b0),
        .T4        (1'b0),
        .TBYTEIN   (1'b0),
        .TCE       (1'b1)
    );
endmodule
