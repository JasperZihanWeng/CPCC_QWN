#==============================================================================
# qwn_bufferless.xdc -- constraints for the bufferless oversampling QWN design
# (VC709, xc7vx690tffg1761-2). Derived from gth_sfp_exdes.xdc (app I/O) +
# MIGRATION_PLAN.md Phase 5 (bufferless additions). Pins reuse the verified
# buffered-reference pinout; revisit gate_out pin for the time-tagger cable.
#
# ROLE: one of TWO user constraint files for top qwn_exdes.v ("clock_test_
# exdes"); the other is qwn_io_supp.xdc (board I/O the regenerated wizard
# XDC misses). The GT channel LOCs / serial pins / RXOUTCLK clocks come from
# the clock_test IP's own XDCs -- never duplicate those here.
# This file's load-bearing content today: the gt_refclk create_clock, the
# async clock-group separation, and the B4/B10 CLOCK_DELAY_GROUP for the
# marker OSERDES clock pair (see bottom).
#
# XDC basics for the incoming reader: constraints match against the
# post-synthesis netlist BY NAME. A constraint whose get_ports/get_nets
# matches nothing is dropped with a warning, not an error -- which is why
# stale entries (flagged below) can sit here harmlessly, and also why a
# TYPO fails silently. Always check the methodology/timing report after
# changing names in RTL.
#
# Evidence: every campaign build (p_b2 .. p_b11_2026-06-10) closed timing
# with this file; B10 builds carry the two-net CLOCK_DELAY_GROUP form.
# (Documentation pass 2026-06-10: comments only, no constraint changed.)
#==============================================================================

# ---- GT serial reference clock: Si570 156.25 MHz via the User-SMA loopback ---
set_property PACKAGE_PIN AK8 [get_ports Q3_CLK1_GTREFCLK_PAD_P_IN]
set_property PACKAGE_PIN AK7 [get_ports Q3_CLK1_GTREFCLK_PAD_N_IN]
create_clock -period 6.400 -name gt_refclk [get_ports Q3_CLK1_GTREFCLK_PAD_P_IN]
# (STABLE_CLOCK_PERIOD=6 in the GT core / exdes generic -- matches 156.25 MHz)

# ---- IDELAYCTRL reference: on-board 200 MHz oscillator (H19/G18) -------------
# VESTIGIAL (kept for history, inert): the current top has NO IDELAY_REFCLK_*
# ports -- the plan to feed IDELAYCTRL from the board's 200 MHz oscillator
# was replaced by a dedicated 156.25->200 MHz MMCM off drpclk inside
# qwn_exdes.v (u_idelay_mmcm). These four lines match nothing and are
# dropped with warnings at synthesis (see "XDC basics" in the header).
set_property PACKAGE_PIN H19 [get_ports IDELAY_REFCLK_P]
set_property PACKAGE_PIN G18 [get_ports IDELAY_REFCLK_N]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {IDELAY_REFCLK_P IDELAY_REFCLK_N}]
create_clock -period 5.000 -name idelay_refclk [get_ports IDELAY_REFCLK_P]

# ---- Application I/O (from gth_sfp_exdes.xdc) --------------------------------
# VESTIGIAL (inert): sfp0_dis / gate_out / hdr_valid_led were ports of the
# early qwn_bufferless_top skeleton. The current top names them differently:
# AB41 = SFP0_TX_DISABLE and J40 = TRACK_DATA_OUT (the coarse-gate copy for
# the scope), BOTH constrained in qwn_io_supp.xdc; M37 is unused. These
# lines match no port and are dropped with warnings.
set_property PACKAGE_PIN AB41 [get_ports sfp0_dis]
set_property IOSTANDARD LVCMOS18 [get_ports sfp0_dis]
# gate/trigger to the time tagger -- reuse FMC1_HPC_LA01_P (was sfp0_dis_scope)
set_property PACKAGE_PIN J40 [get_ports gate_out]
set_property IOSTANDARD LVCMOS18 [get_ports gate_out]
set_property PACKAGE_PIN M37 [get_ports hdr_valid_led]
set_property IOSTANDARD LVCMOS18 [get_ports hdr_valid_led]
# GT SERIAL (RXN/RXP/TXN/TXP) + GT-channel placement + the GT-refclk routing
# are constrained by the REGENERATED clock_test IP's own XDC
# (clock_test.xdc / clock_test_ooc.xdc, quad 113 -- same as the buffered
# reference). Do NOT add top-level PACKAGE_PINs for the GT serial pins here
# (would conflict with the IP GT LOC).
#
# NOTE: re-add the remaining buffered-reference app pins (UART, FMC switch
# controls, receiver switches, SFP RS, interrupts) here when the cleaned
# qwn_ttl/switch_controller/etc. are reconnected -- see MIGRATION_PLAN Phase 5.

# ---- Bufferless clock relationships (the constraints neither stock XDC had) --
# TX usrclk (MMCM off TXOUTCLK), RX usrclk (RX-MMCM off held RXOUTCLK), the
# Si570 stable/DRP domain, and the 200 MHz IDELAY domain are all asynchronous.
#
# FPGA basics -- clock groups: STA assumes EVERY pair of clocks is related
# unless told otherwise, and will "time" paths between unrelated domains
# using a meaningless common period -- producing either impossible-to-meet
# paths or, worse, false confidence. set_clock_groups -asynchronous declares
# the listed groups mutually unrelated: inter-group paths are not timed at
# all, so every real crossing between them MUST be protected structurally
# (2-FF synchronizers, commit latches, qwn_dbg's CDC counters -- see the
# RTL). -include_generated_clocks pulls in everything an MMCM derives from
# the group's root, so e.g. idelay_ref200 follows idelay_refclk/drpclk.
# NOTE the recovered-clock subtlety: rxusrclk2 is a GENERATED clock rooted
# in the IP's RXOUTCLK create_clock, not here -- in STA it looks "related"
# to its own tree only; its relation to the TX domain is genuinely async
# (separate boards, separate oscillators) even at equal nominal frequency.
set_clock_groups -asynchronous \
  -group [get_clocks -include_generated_clocks gt_refclk] \
  -group [get_clocks -include_generated_clocks idelay_refclk]
# (add TXOUTCLK / RXOUTCLK generated-clock groups once the regenerated GT/IP
#  clock names are known from the post-synthesis netlist; placeholder above.)
# [Status note 2026-06: the idelay_refclk group root is the vestigial port
#  above, so this separation currently rides on the IP/exdes XDC defaults;
#  builds close timing and the bench validates behavior, but if STA ever
#  reports gt_refclk-vs-drpclk paths, this is the first place to look.]

# Restore the CDC false paths the bufferless IP XDC dropped vs the buffered one
# (apply against the regenerated clock_test hierarchy after first synth):
# set_false_path -to [get_pins -hier *reset_sync1*/D]
# set_false_path -to [get_pins -hier *reset_sync2*/D]
# set_false_path -to [get_pins -hier *rxpmaresetdone_i_reg*/D]

# ODELAY on the gate output is a calibrated fixed fine delay, not a timed path:
# set_false_path -to [get_pins -hier *u_gate_odelay*/IDATAIN]
#
# IODELAY_GROUP note: the binding between the marker ODELAYE2s and their
# IDELAYCTRL is NOT done here -- it is the Verilog attribute
# (* IODELAY_GROUP = "qwn_mark_grp" *) on the primitives (qwn_exdes.v /
# mark_odelay.v). XDC set_property IODELAY_GROUP would be equivalent; the
# attribute form travels with the RTL and cannot go stale against renames.
# The group tells placement which delays this controller calibrates (taps =
# 78.125 ps at the 200 MHz REFCLK) and replicates the controller per bank.

# ---- Build B4: marker OSERDES CLK/CLKDIV BUFG pair -- matched insertion ------
# The OSERDESE2 internal CLKDIV->CLK word handoff is inside the hard macro
# (no STA path; confirmed absent from timing report). Its margin = the BUFG
# insertion-delay match of mk625 vs mk156, unconstrained until now: the 625
# tree drives ONE pin, the 156 tree drives the marker FSM + CLKDIV -> skew
# mismatch puts the internal word-select near its edge -> intermittent
# HALF-WORD (4-slot = 3.2 ns) output slips = the +/-3.2 ns satellite bins on
# the bench (2026-06-09, ~5%). Matched delay group is the standard remedy
# for MMCM-sourced SERDES clock pairs.
# B10: the pair is now rxusrclk2 (CLK0) + 625 (CLK2) of the SAME gt0 RX MMCM
# (cascaded marker MMCM deleted). Matched insertion across their two BUFGs:
#
# FPGA basics -- why a *physical* constraint fixes a *timing* problem:
# OSERDESE2's CLKDIV-domain word register hands off to its CLK-domain shift
# register entirely inside the hard macro. The Xilinx timing model exposes
# NO path for that handoff -- STA cannot report it, cannot fail it, and a
# clean timing report says NOTHING about it (confirmed: the path is absent
# from our reports). Its only margin is the assumption that CLK and CLKDIV
# arrive with the phase relationship they had at the MMCM outputs, i.e.
# that the two BUFG trees insert EQUAL delay. CLOCK_DELAY_GROUP is the
# official remedy (UG472/UG949): nets tagged with the same group name are
# routed by the clock router with matched insertion delay. Without it the
# trees can differ by enough to put the internal word-select mux on its
# edge -> the half-word (4-slot = 3.2 ns) marker slips we measured at ~5%
# of bursts (the +-3.2 ns satellite bins, 2026-06-09) -- a build-to-build
# lottery, since nothing constrained the skew.
# The lesson generalizes: STA also does not cover pad tristate state (the
# Build B TQ pitfall), MMCM re-lock/tracking transients, or GT divider
# re-lock phase -- all of which bit this project. "Timing met" is necessary,
# never sufficient; hence the per-build identical-conditions histograms.
set_property CLOCK_DELAY_GROUP mk_mark_grp [get_nets {gt0_rxusrclk2_i gt0_rxusrclk625_i}]
#==============================================================================
