`timescale 1ns/1ps
//==============================================================================
// rxcdrhold_ctrl -- per-burst RXCDRHOLD for the blind-oversample RX, with
// self-healing recovery (no soft_reset needed) for the SEPARATE-CLOCK
// (inter-board) case.
//
// (READ ME FIRST, 2026-06: the per-burst policy described in the next three
//  paragraphs is this module's ORIGINAL design, retained as the
//  HOLD_FOREVER=0 legacy mode. Since Build B7 the shipped configuration is
//  HOLD_FOREVER=1 -- the jitter campaign's centerpiece change. See the
//  B7 ADDENDUM at the end of this header and the parameter block below.)
//
// Why this exists: the old dark_period_ctrl did SETTLE-once -> HOLD-forever.
// That is only correct for 0-ppm loopback (TX and RX share one Si570): the
// grid, once frozen on the local ref, stays aligned to the data forever.
// Across two boards there is a ppm offset; with RXCDRHOLD held forever the
// frozen grid eventually walks off the data, comma lock is lost, and -- because
// HOLD was terminal -- the CDR can never re-converge, so the link is dead
// until a manual soft_reset. Observed on HW.
//
// Fix (per first principles + the original architecture intent): RXCDRHOLD is
// held ONLY across the deterministic window of each burst, then released so
// the CDR re-converges to the local ref before the next burst. The blind
// oversampler needs a settled grid to comma-lock, so recovery still happens in
// the HELD state AFTER a brief SETTLE -- but HOLD is now bounded and ALWAYS
// returns to SETTLE (on payload-window end, on lost comma lock, or on a
// no-fiducial timeout). Every path leads back to SETTLE => the CDR is
// periodically re-converged => the link re-acquires on its own. No soft_reset.
//
//   S_SETTLE : rxcdrhold=0 for INIT_CYC cycles (CDR frequency-converges to
//              the local reference; XAPP572 settle window).
//   S_HOLD   : rxcdrhold=1. Comma/fiducial/header recover here (frozen grid).
//              On fid_pulse, latch win = gate_delay + payload_dur + GUARD and
//              count from the fiducial; when the deterministic window elapses,
//              reopen -> S_SETTLE (SFP/CDR ready + re-settled for next burst).
//              Self-heal exits to S_SETTLE: comma lock dropped while held, or
//              HOLD_MAX elapsed with no fiducial (this attempt missed) -> retry.
//
// All inputs are rxusrclk2-domain (fiducial/lock/gate_delay/payload_dur), so
// the FSM runs on rxusrclk2. RXCDRHOLD is a slow async-tolerant GT control.
// INIT_CYC/GUARD/HOLD_MAX are bench-tunable (RXCDRHOLD behaviour is HW-empirical
// per the project's Phase-1B / XAPP572 notes).
//
// ---------------------------------------------------------------------------
// B7 ADDENDUM (the campaign centerpiece, 2026-06-09/10): the per-burst
// release/re-acquire policy above turned out to be the DOMINANT jitter
// source. Mechanism and evidence, in full:
//
// FPGA-basics aside, what RXCDRHOLD actually does: the GT RX CDR steers a
// phase interpolator (and a frequency integrator) to keep the sampling clock
// tracking the incoming data. RXCDRHOLD=1 freezes both, so the recovered
// clock free-runs at its last frequency/phase. With RXBUF_EN=FALSE and
// RXOUTCLKSEL=RXOUTCLKPMA, rxusrclk/rxusrclk2 are DERIVED from that
// recovered clock: the entire RX fabric domain rides the CDR's grid.
//
// THE MECHANISM (why re-acquisition is fatal to an armed gate): every CDR
// re-acquisition after a hold is a convergence transient that can DISPLACE
// the recovered-clock grid. The marker countdown, the framer, and every
// observable counter live IN that domain, so they all move together: no
// in-domain observable can detect the displacement, BY CONSTRUCTION (a
// reference frame cannot measure its own motion); only the external scope
// reference (H31) can. That is why the B4/B6 occurrence counters showed
// everything healthy while the bench still showed +-3.2 ns / -6.4 ns
// stragglers.
//
// VIO DOSE-RESPONSE EXPERIMENT (no rebuild; vio_cdrhold_mode = probe_out2 on
// C6A; b6_holdforce / b6_trackforce / b6_hold_10k CSVs):
//   force-track (re-acquire every burst): 26% stragglers at -6.4 ns (one
//     full rxusrclk2 cycle), sigma 2910 ps;
//   fabric per-burst hold (the legacy policy above): ~2% stragglers at
//     +-3.2 ns (one RXOUTCLKPMA period), sigma 480 ps;
//   force-hold (never re-acquire): ZERO stragglers, sigma 101.9 ps
//     (103.5 ps stable over an 87-minute 10k-sample run).
// A monotone dose-response in re-acquisition frequency nailed the mechanism.
//
// WHY HOLD_FOREVER IS VIABLE NOW (it was fatal in the old architecture --
// see "Why this exists" above): the continuous comma RE-ALIGN in
// rx_frame_par plus the per-burst ui_offset/eph corrections absorb the ppm
// walk of the frozen grid, so the link no longer needs the CDR to track.
// Release happens ONLY on SUSTAINED comma loss (LOSS_CYC = 131072 cyc ~
// 840 us ~ 32 burst periods: a true link event, e.g. pulled fiber); the
// per-burst dark flicker resets the loss counter long before that.
//
// B7 RESULT (p_b7): sigma 122 ps, missing markers 1/2000 -- BETTER than the
// VIO force-hold override's 5.8% missing, because the fabric FSM lets the
// CDR settle on real data before the first (now permanent) hold. Sim
// tb_holdgate2: flicker immunity, sustained-loss release, gate_pending
// deferral, fid-less retry. B5/B6 context: the gate_pending deferral (B5,
// tb_holdgate) fires on ~98% of bursts (hist idx13) -- ubiquitous but
// harmless once HOLD_FOREVER removed the reopen itself.
// ---------------------------------------------------------------------------
//==============================================================================
module rxcdrhold_ctrl #(
    parameter [15:0] INIT_CYC = 16'd4096,   // CDR->local-ref settle window
    parameter [23:0] GUARD    = 24'd512,    // extra hold past payload end
    parameter [23:0] HOLD_MAX = 24'd20000,  // cap a fiducial-less HOLD -> retry
    // B7 POLICY INVERSION (VIO A/B-proven 2026-06-09): hold FOREVER after the
    // first fiducial; never reopen per burst. Every CDR re-acquisition rolls a
    // grid-displacement transient under the armed gate (per-burst fabric
    // reopen -> ~2% markers at +-3.2ns/half-cycle; forced re-acquire -> 26% at
    // -6.4ns/full-cycle; forced hold -> ZERO stragglers, sigma 480->102ps =
    // oversample floor; b6_holdforce/b6_trackforce.csv). The continuous comma
    // RE-ALIGN + ui_offset slot correction absorb the ppm walk that made
    // hold-forever fatal pre-realign. Release ONLY on SUSTAINED comma loss
    // (true link event, e.g. pulled fiber) -> re-settle -> re-acquire; the
    // per-burst dark flicker (lock low ~ms^-1 scale) never reaches LOSS_CYC.
    parameter        HOLD_FOREVER = 1'b1,
    parameter [23:0] LOSS_CYC     = 24'd131072  // ~840us =~ 32 burst periods
)(
    input  wire        clk,            // rxusrclk2
    input  wire        rst,            // gt*_rx_system_reset_c
    input  wire        fid_pulse,      // fiducial detected (deterministic start)
    input  wire        comma_locked,   // rx_frame_par comma lock
    input  wire        gate_pending,   // rx_gate armed_o: a committed marker is
                                       // still counting -- do NOT release the
                                       // CDR grid under it (early reopen on a
                                       // dark comma flicker let the CDR re-pull
                                       // MID-COUNTDOWN -> marker fired on a
                                       // slewing grid, +-3.2ns/PMA-period-
                                       // wrapped stragglers, 2.3% @ bench
                                       // 2026-06-09, b4_run1.csv)
    input  wire [23:0] gate_delay_i,   // recovered: cycles fiducial->payload
    input  wire [15:0] payload_dur_i,  // recovered: payload length
    output reg         rxcdrhold,      // -> GT (1 = freeze grid on local ref)
    output reg         settling,       // status: in the SETTLE (reopened) window
    output wire        reopen_blocked  // diag: a self-heal reopen is being
                                       // DEFERRED by gate_pending right now
                                       // (top counts rising edges -> how often
                                       // the B5 fix actually fires on HW)
);
    localparam S_SETTLE = 1'b0, S_HOLD = 1'b1;
    reg        st;
    reg [15:0] scnt;                   // settle counter
    reg [23:0] hcnt, win;              // hold counter / window length
    reg        armed;                  // fiducial seen this HOLD -> window armed
    reg [23:0] losscnt;                // consecutive !comma_locked cycles

    wire sustained_loss = (losscnt >= LOSS_CYC);
    // diag mirror of the two DEFERRED release terms in the FSM below: it
    // answers "would we reopen right now if gate_pending were clear?" and
    // MUST be kept in lockstep with those else-if conditions if they ever
    // change. The top counts its rising edges as hist idx13; measured ~98%
    // of bursts on HW (B6) -- i.e. some dark comma flicker occurs under
    // nearly every armed gate, which is exactly why the B5 deferral and the
    // B7 sustained-loss filter exist.
    assign reopen_blocked = (st == S_HOLD) && gate_pending &&
                            ((armed && (HOLD_FOREVER ? sustained_loss
                                                     : !comma_locked)) ||
                             (!armed && hcnt >= HOLD_MAX));

    always @(posedge clk) begin
        if (rst) begin
            st<=S_SETTLE; scnt<=16'd0; hcnt<=24'd0; win<=24'd0; armed<=1'b0;
            losscnt<=24'd0;
            rxcdrhold<=1'b0; settling<=1'b1;
        end else begin
            case (st)
            S_SETTLE: begin
                rxcdrhold<=1'b0; settling<=1'b1; hcnt<=24'd0; armed<=1'b0;
                losscnt<=24'd0;
                if (scnt==INIT_CYC-16'd1) begin scnt<=16'd0; st<=S_HOLD; end
                else scnt<=scnt+16'd1;
            end
            S_HOLD: begin
                rxcdrhold<=1'b1; settling<=1'b0;
                // sustained-loss detector (per-burst dark flicker resets it)
                losscnt <= comma_locked ? 24'd0 : (losscnt + 24'd1);
                // arm on the first fiducial; with HOLD_FOREVER the arm is
                // permanent (no per-burst reopen -> no re-acquisition rolls)
                if (fid_pulse && !armed) begin
                    armed <= 1'b1;
                    win   <= gate_delay_i + {8'd0,payload_dur_i} + GUARD;
                    hcnt  <= 24'd0;
                end else begin
                    hcnt <= hcnt + 24'd1;
                end
                // legacy per-burst reopen (window complete) -- DISABLED by
                // HOLD_FOREVER: every reopen = a re-acquisition = a chance of
                // a grid-displacement transient under the next armed gate
                if (!HOLD_FOREVER && armed && hcnt>=win) begin st<=S_SETTLE; end
                // self-heal release, deferred while a gate is counting:
                //  HOLD_FOREVER: only SUSTAINED comma loss (true link event)
                //  legacy      : any lock loss while armed
                else if (armed && (HOLD_FOREVER ? sustained_loss : !comma_locked)
                         && !gate_pending) begin st<=S_SETTLE; end
                // fiducial-less HOLD -> retry settle (initial acquisition aid)
                else if (!armed && hcnt>=HOLD_MAX && !gate_pending) begin st<=S_SETTLE; end
            end
            endcase
        end
    end
endmodule
