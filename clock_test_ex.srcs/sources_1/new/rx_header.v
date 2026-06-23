`timescale 1ns/1ps
//==============================================================================
// rx_header -- parse the QWN header from the decoded byte stream (post
// rx_frame). Sequence: FID, SOH, destination, payload_dur[15:8],
// payload_dur[7:0], gate_delay[23:16..7:0], check(=XOR of SOH..gd0).
//
// INTEGRITY: any code_err during the header, a wrong SOH, or a check mismatch
// -> the whole burst is DISCARDED (hdr_discard pulse, NO hdr_valid, NO gate).
// "Missing gate, never a wrong gate" -- correct failure mode for the quantum
// measurement. fid_pulse marks the fiducial symbol for the gate timer.
//==============================================================================
// ROLE IN THE SYSTEM (see docs/CAMPAIGN_BRIEF_2026-06.md): third stage of
// the RX chain (rx_oversample_cdr_64 -> rx_frame_par -> [THIS] -> rx_gate).
// Each ~26 us TX burst is: K28.5 warmup, settle, FID byte (0x6B), this
// 8-byte header, payload, trailer, then LASER OFF (dark gap). This module
// finds the fiducial, validates the header, and hands rx_gate everything it
// needs to fire the payload-start marker gate_delay cycles later.
//
// WHY the integrity invariant is one-sided: the downstream SNSPD experiment
// can tolerate a missing gate (lost sample) but NOT a misplaced one (wrong
// data silently gated in). So every failure path here converges on "discard
// the burst", never "guess".
//
// ui_offset (Build A, p_a_2026-05-27 -- detection half of fix #3): the FID
// byte's symbol-end slot (byte_bit_pos from rx_frame_par), latched at the
// fiducial. This is the per-burst integer-UI offset that the GT divider/CDR
// re-lock randomizes (the original 8-stripe ~2 ns jitter signature: 8 bins,
// 800 ps apart, spanning one 6.4 ns rxusrclk2 word). HW evidence: 0..7
// near-uniform on the live link, skewed on a dark input control.
// CAUTION (Build B4 lesson, bench 2026-06-09): this is a LIVE register --
// every later fid_ok, INCLUDING false fiducials decoded from comma-rich dark
// garbage, overwrites it. Anything that consumes ui_offset at gate time
// (~2200 cycles after the real FID, deep in dark) must use rx_gate's
// COMMITTED copy gate_ui_o (latched at arm), not this register; the raw
// value was stale on ~5% of bursts -> markers at a random slot (the
// quasi-uniform straggler background). Measured rate of actual corruption
// events: 0.03% (B6 occurrence counter, hist idx12).
//==============================================================================
module rx_header #(
    parameter [7:0] SOH = 8'h7C,
    parameter [7:0] FID = 8'h6B,
    // FID hardening (DISABLED by default -- net-NEGATIVE on HW, see below):
    // require the fiducial byte to be IMMEDIATELY preceded by a K28.5 comma.
    // In sim (LFSR dark) this cut false fiducials to zero, but on HW it TRIPLED
    // the discard rate (~5% -> ~18%, dark_commafix2 2026-05-21): the real
    // laser-off dark is comma-RICH (the comma re-align churns it into K28.5-
    // like patterns), so "K28.5 then 0x6B" pairs are common, not rare -- the
    // delimiter doesn't filter them and the extra re-align snap right before
    // the FID perturbs the real header decode. The sim missed this (no settle
    // region, LFSR dark not comma-rich). rx_gate's hdr_valid gating already
    // makes false fiducials HARMLESS (no spurious marker), so the residual
    // discards don't need this. Kept parameterized for a future attempt with
    // a HW-faithful (comma-rich, settle-inclusive) dark model.
    parameter       REQUIRE_COMMA_FID = 0
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        byte_valid,
    input  wire        code_err,
    input  wire        k_i,
    input  wire [7:0]  byte_i,
    input  wire [2:0]  byte_bit_pos,         // bit-position of byte's symbol-end
    output reg         fid_pulse,
    output reg         hdr_valid,
    output reg         hdr_discard,
    output reg  [7:0]  destination,
    output reg  [15:0] payload_dur,
    output reg  [23:0] gate_delay,
    output reg  [2:0]  ui_offset             // latched at FID -> mode indicator
);
    // FSM: S_IDLE hunts for the fiducial; S_SOH expects the start-of-header
    // byte immediately after it; S_F walks the 7 remaining fields (fi=0..6).
    // Header fields accumulate in shadow regs (d_r/pd_r/gd_r) and are copied
    // to the outputs ONLY if the check byte matches -- so the exported
    // destination/payload_dur/gate_delay always describe the last GOOD
    // header, never a partially-received or corrupt one (rx_gate reads
    // gate_delay ~9 byte-times after fid, by which time the check has run).
    localparam S_IDLE=0,S_SOH=1,S_F=2;
    reg [1:0] st;
    reg [2:0] fi;
    reg [7:0] acc;          // running XOR check
    reg [7:0] d_r;
    reg [15:0] pd_r;
    reg [23:0] gd_r;
    reg       prev_comma;   // last decoded byte was a K28.5 comma
    // fiducial accepted iff a clean FID data byte AND (delimiter satisfied)
    wire fid_ok = !code_err && !k_i && byte_i==FID
                  && (!REQUIRE_COMMA_FID || prev_comma);

    always @(posedge clk) begin
        if (rst) begin
            st<=S_IDLE; fi<=0; acc<=0; prev_comma<=1'b0;
            fid_pulse<=1'b0; hdr_valid<=1'b0; hdr_discard<=1'b0;
            destination<=0; payload_dur<=0; gate_delay<=0;
            ui_offset<=3'd0;
        end else begin
            fid_pulse<=1'b0; hdr_valid<=1'b0; hdr_discard<=1'b0;
            if (byte_valid) begin
                // track comma-ness of THIS byte for the next byte's fid check
                prev_comma <= (!code_err && k_i && byte_i==8'hBC);
                case (st)
                S_IDLE: if (fid_ok) begin
                            // Fiducial found. fid_pulse starts rx_gate's
                            // free-running countdown THIS cycle; ui_offset
                            // snapshots the FID's UI slot for the integer-UI
                            // marker correction. NOTE: a false fid in dark
                            // also lands here -- harmless for the gate
                            // (rx_gate requires hdr_valid before firing and a
                            // committed gate ignores re-arms) but it DOES
                            // rewrite ui_offset, which is why consumers must
                            // take rx_gate's committed copy (B4 lesson).
                            fid_pulse<=1'b1; st<=S_SOH;
                            ui_offset<=byte_bit_pos;  // FID byte's bit-position
                        end
                S_SOH:  begin
                        if (code_err || k_i || byte_i!==SOH) begin
                            hdr_discard<=1'b1; st<=S_IDLE;       // bad header
                        end else begin
                            acc<=SOH; fi<=0; st<=S_F;
                        end
                        end
                S_F:    begin
                        if (code_err || k_i) begin
                            hdr_discard<=1'b1; st<=S_IDLE;       // discard
                        end else begin
                            case (fi)
                              3'd0: d_r<=byte_i;
                              3'd1: pd_r[15:8]<=byte_i;
                              3'd2: pd_r[7:0]<=byte_i;
                              3'd3: gd_r[23:16]<=byte_i;
                              3'd4: gd_r[15:8]<=byte_i;
                              3'd5: gd_r[7:0]<=byte_i;
                              3'd6: begin                          // check byte
                                  // acc = SOH^dst^pd1^pd0^gd2^gd1^gd0 (seeded
                                  // with SOH in S_SOH, folded per field
                                  // below). XOR catches any odd number of
                                  // single-bit flips per bit lane -- adequate
                                  // here because 8B/10B code_err already
                                  // rejects most line corruption upstream;
                                  // this guards the residual valid-but-wrong
                                  // decodes.
                                  if (byte_i == acc) begin
                                      destination<=d_r; payload_dur<=pd_r;
                                      gate_delay<=gd_r; hdr_valid<=1'b1;
                                  end else hdr_discard<=1'b1;
                                  st<=S_IDLE;
                              end
                            endcase
                            if (fi!=3'd6) begin acc<=acc^byte_i; fi<=fi+1; end
                        end
                        end
                endcase
            end
        end
    end
endmodule
