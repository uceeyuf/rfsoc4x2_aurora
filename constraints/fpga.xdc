# RFSoC 4x2 (XCZU48DR-FFVG1517-2-E) pins and clocks for the Aurora design.
# The transceiver channels (X0Y4..X0Y7, the QSFP28 cage) are placed by the GT wizard IP.

set_property CFGBVS GND [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]

# 100 MHz PL system clock
set_property PACKAGE_PIN AM15 [get_ports clk_p]
set_property PACKAGE_PIN AN15 [get_ports clk_n]
set_property IOSTANDARD LVDS [get_ports {clk_p clk_n}]
create_clock -period 10.000 -name clk_100 [get_ports clk_p]

# reset push button (active low)
set_property -dict {PACKAGE_PIN AN12 IOSTANDARD LVCMOS18} [get_ports reset_n]
set_false_path -from [get_ports reset_n]

# QSFP28 sideband
set_property -dict {PACKAGE_PIN AK22 IOSTANDARD LVCMOS18} [get_ports qsfp0_modsell]
set_property -dict {PACKAGE_PIN AL21 IOSTANDARD LVCMOS18} [get_ports qsfp0_resetl]
set_property -dict {PACKAGE_PIN AL22 IOSTANDARD LVCMOS18} [get_ports qsfp0_modprsl]
set_property -dict {PACKAGE_PIN AM22 IOSTANDARD LVCMOS18} [get_ports qsfp0_intl]
set_property -dict {PACKAGE_PIN AN22 IOSTANDARD LVCMOS18} [get_ports qsfp0_lpmode]
set_false_path -to [get_ports {qsfp0_modsell qsfp0_resetl qsfp0_lpmode}]
set_false_path -from [get_ports {qsfp0_modprsl qsfp0_intl}]

# QSFP28 GT reference clock, 156.25 MHz (MGTREFCLK0 of quad 128, routed north to the channels' quad)
set_property PACKAGE_PIN AA33 [get_ports qsfp0_mgt_refclk_0_p]
create_clock -period 6.400 -name qsfp_refclk [get_ports qsfp0_mgt_refclk_0_p]

# the counters' snapshot: taken in the user clock, held while the VIO (100 MHz) reads it
set_false_path -from [get_cells -hierarchical -filter {NAME =~ s_*_reg*}] -to [get_clocks clk_100]

# the 100 MHz domain (init clock, VIO) and the transceiver domains (the user clocks from the GTs, derived from the reference)
# are asynchronous: the crossings are synchronized (the Aurora support logic's cdc_to registers, xpm_cdc, the snapshot
# handshake), as the core's example design constrains them
set_clock_groups -asynchronous -group [get_clocks clk_100 -include_generated_clocks] -group [get_clocks qsfp_refclk -include_generated_clocks]
set_false_path -to [get_pins -hier *aurora_qsfp_cdc_to*/D]
set_false_path -through [get_pins -quiet -hier *bufg_gt_clr_delayed_reg*/Q]
set_false_path -through [get_pins -filter {REF_PIN_NAME=~*gtwiz_userclk_rx_reset_in} -of_objects [get_cells -hierarchical -filter {NAME =~ *ultrascale_rx_userclk}]]
