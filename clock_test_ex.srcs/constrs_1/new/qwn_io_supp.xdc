#==============================================================================
# qwn_io_supp.xdc -- supplemental board I/O for top qwn_exdes.v
#
# ROLE: every FABRIC pin of the design lives here (the regenerated wizard
# XDC constrains GT serial/refclk/internal clocks only; qwn_bufferless.xdc
# holds clock relationships + the marker CLOCK_DELAY_GROUP). Pin sources, in
# order of trust: bench-proven buffered-reference XDC > IBERT example XDC >
# UG887 Table 1-14 (datasheet only, unproven) -- each entry says which.
#
# The three pins the experiment actually measures (HP 54825A via Prologix
# GPIB; SNSPD timing downstream -- every ps counts):
#   N41 RX_PAYLOAD_MARK_SIGNAL  FMC LA02_N  lane-0 payload-start marker
#   H31 TX_PAYLOAD_REF          FMC LA27_N  gt2 TX-side reference strobe
#                               (single-shot jitter figure = N41 - H31)
#   J40 TRACK_DATA_OUT          FMC LA01_P  coarse-gate copy (pre-OSERDES)
#   H41 RX_PAYLOAD_MARK_IDLER   lane-1 marker (dark on the current bench)
# All LVCMOS18; the jitter-critical edges are FAST/16 mA since Build B8
# (rationale at the SLEW lines below).
# (Documentation pass 2026-06-10: comments only, no constraint changed.)
#==============================================================================
# Supplemental board I/O constraints missing from the regenerated wizard XDC
# (which constrains GT/clocks but not these fabric ports). Pins per the
# original bufferless clock_test_ex example + buffered reference.
set_property IOSTANDARD DIFF_SSTL15 [get_ports DRP_CLK_IN_P]
set_property IOSTANDARD DIFF_SSTL15 [get_ports DRP_CLK_IN_N]
# J40 = FMC LA01_P: coarse-gate copy (qwn_gate straight off the fabric FF,
# BEFORE the OSERDES/ODELAY path that makes N41) -- the diagnostic for
# separating fabric-gate problems from marker-path problems. Open item
# (task #40): compare J40 vs N41 pulse WIDTH (N41 shows ~52 ns vs 6.4 ns RTL).
set_property PACKAGE_PIN J40        [get_ports TRACK_DATA_OUT]
set_property IOSTANDARD  LVCMOS18   [get_ports TRACK_DATA_OUT]

# --- Si570 GT-refclk forwarding (restored from buffered reference) ---
# Si570 156.25 MHz differential input
set_property PACKAGE_PIN AK34 [get_ports SYSCLK_IN_P]
set_property PACKAGE_PIN AL34 [get_ports SYSCLK_IN_N]
set_property IOSTANDARD  LVDS [get_ports SYSCLK_IN_P]
set_property IOSTANDARD  LVDS [get_ports SYSCLK_IN_N]
# forwarded clock out -> external SMA loopback -> Q3_CLK1_GTREFCLK_PAD
set_property PACKAGE_PIN AJ32 [get_ports ref_clk_true_p]
set_property PACKAGE_PIN AK32 [get_ports ref_clk_true_n]
set_property IOSTANDARD  LVDS [get_ports ref_clk_true_p]
set_property IOSTANDARD  LVDS [get_ports ref_clk_true_n]
# 156.25 MHz forwarded clock; pure feedthrough, async to all fabric clocks
create_clock -period 6.400 -name si570_fwd [get_ports SYSCLK_IN_P]
set_clock_groups -asynchronous -group [get_clocks si570_fwd]

# --- Tier-1 SFP control (lane 0). Pins from the bench-proven buffered XDC ---
set_property PACKAGE_PIN AB41     [get_ports SFP0_TX_DISABLE]
set_property IOSTANDARD  LVCMOS18 [get_ports SFP0_TX_DISABLE]
set_property PACKAGE_PIN W40      [get_ports SFP0_RS0]
set_property IOSTANDARD  LVCMOS18 [get_ports SFP0_RS0]
set_property PACKAGE_PIN M36      [get_ports ALWAYS_ON]
set_property IOSTANDARD  LVCMOS18 [get_ports ALWAYS_ON]
# SFP+ Module 1 (P3) status/RS1 -- UG887 Table 1-14 (via level shifter)
set_property PACKAGE_PIN Y40      [get_ports SFP0_RS1]
set_property IOSTANDARD  LVCMOS18 [get_ports SFP0_RS1]
set_property PACKAGE_PIN Y38      [get_ports SFP0_TX_FAULT]
set_property IOSTANDARD  LVCMOS18 [get_ports SFP0_TX_FAULT]
set_property PACKAGE_PIN Y39      [get_ports SFP0_RX_LOS]
set_property IOSTANDARD  LVCMOS18 [get_ports SFP0_RX_LOS]
set_property PACKAGE_PIN AB42     [get_ports SFP0_MOD_ABS]
set_property IOSTANDARD  LVCMOS18 [get_ports SFP0_MOD_ABS]
# Other 3 cages -- presence map (UG887 Table 1-14 MOD_DETECT)
set_property PACKAGE_PIN AA42     [get_ports SFP2_MOD_ABS]
set_property IOSTANDARD  LVCMOS18 [get_ports SFP2_MOD_ABS]
set_property PACKAGE_PIN AC39     [get_ports SFP3_MOD_ABS]
set_property IOSTANDARD  LVCMOS18 [get_ports SFP3_MOD_ABS]
set_property PACKAGE_PIN AC41     [get_ports SFP4_MOD_ABS]
set_property IOSTANDARD  LVCMOS18 [get_ports SFP4_MOD_ABS]

# --- Lane-1 SFP control (gt1 / SFP+ Module 2 / P2 cage). TX_DISABLE=Y42,
# RS0=AB38 from the bench-proven buffered XDC; RX_LOS=AA40 = IBERT example
# SFP2_LOS (cross-checked: lane-0 RX_LOS Y39 = IBERT SFP1_LOS). Lane-1
# MOD_ABS already wired as SFP2_MOD_ABS (AA42, Mod2/P2). ---
set_property PACKAGE_PIN Y42      [get_ports SFP1_TX_DISABLE]
set_property IOSTANDARD  LVCMOS18 [get_ports SFP1_TX_DISABLE]
set_property PACKAGE_PIN AB38     [get_ports SFP1_RS0]
set_property IOSTANDARD  LVCMOS18 [get_ports SFP1_RS0]
set_property PACKAGE_PIN AA40     [get_ports SFP1_RX_LOS]
set_property IOSTANDARD  LVCMOS18 [get_ports SFP1_RX_LOS]

# --- Dual-lane payload-start markers (buffered-ref rx_recovered_payload pins) ---
set_property PACKAGE_PIN N41      [get_ports RX_PAYLOAD_MARK_SIGNAL]
set_property IOSTANDARD  LVCMOS18 [get_ports RX_PAYLOAD_MARK_SIGNAL]
set_property PACKAGE_PIN H41      [get_ports RX_PAYLOAD_MARK_IDLER]
set_property IOSTANDARD  LVCMOS18 [get_ports RX_PAYLOAD_MARK_IDLER]
# B8: FAST slew + max drive on the timing-critical edges -- the old SLOW/12mA
# ~2ns ramps convert instrument threshold noise into timing jitter (scope AND
# time tagger). Expect some ringing into high-Z probes; terminated paths fine.
#
# FPGA basics -- why slew is a JITTER knob, not just an SI knob: any
# threshold-crossing instrument turns voltage noise into time noise at
# dt = dV / (dV/dt). A ~2 ns LVCMOS18 ramp through ~1.8 V gives roughly
# 1 V/ns; tens of mV of instrument/threshold noise is then tens of ps of
# pure measurement jitter ADDED to the device's. Measured here via the H31
# width-jitter self-test (the same edge pair on one channel): two-edge scope
# noise 32.6 ps SLOW -> 27.7 ps FAST. That 27.7 ps is what gets removed in
# quadrature to quote device jitter (B8: 88.4 ps scope = ~82 ps device).
set_property SLEW  FAST [get_ports {RX_PAYLOAD_MARK_SIGNAL RX_PAYLOAD_MARK_IDLER}]
set_property DRIVE 16   [get_ports {RX_PAYLOAD_MARK_SIGNAL RX_PAYLOAD_MARK_IDLER}]

# --- Lane-2 (gt2 / cage-2 / Mod3) TX-only inter-board source + intra-channel
# jitter reference. TX_DISABLE=AC38, RS0=AD42 (bench-proven buffered "sfp2").
# TX_PAYLOAD_REF=H31 (buffered sfp1_dis_scope -- proven LVCMOS18 scope pin). ---
set_property PACKAGE_PIN AC38     [get_ports SFP3_TX_DISABLE]
set_property IOSTANDARD  LVCMOS18 [get_ports SFP3_TX_DISABLE]
set_property PACKAGE_PIN AD42     [get_ports SFP3_RS0]
set_property IOSTANDARD  LVCMOS18 [get_ports SFP3_RS0]
set_property PACKAGE_PIN H31      [get_ports TX_PAYLOAD_REF]
set_property IOSTANDARD  LVCMOS18 [get_ports TX_PAYLOAD_REF]
# B8 FAST/16 mA: same rationale as the markers above -- H31 is the OTHER
# edge of the jitter figure (N41 - H31), so its ramp matters just as much.
set_property SLEW  FAST [get_ports TX_PAYLOAD_REF]
set_property DRIVE 16   [get_ports TX_PAYLOAD_REF]
