# The Aurora core's transceivers (aurora_qsfp, C_GTWIZ_OUT): its own GT wizard settings (GTY-Aurora_64B66B, four lanes
# X0Y4..X0Y7 at 25.78125 Gb/s, 64B66B in the GT, 64-bit user data at 402.83 MHz) with the RFSoC 4x2's QSFP28 reference
# clock: 156.25 MHz, QPLL0 in fractional-N mode (FRACN 8388608 / 2^24 = 0.5: as the CMAC of the 100G designs). The clock is on MGTREFCLK0 of quad 128 (AA33 / AA34, the quad below):
# connected as clk0, the tools route it north (as the CMAC of rfsoc4x2_100g_udp on the same pins)
# (25.78125 = 156.25 x 165; the Aurora core itself offers only integer multiples, 161.1328125 MHz)
create_ip -vlnv xilinx.com:ip:gtwizard_ultrascale:1.7 -module_name aurora_qsfp_gt
set_property -dict [list \
    CONFIG.PRESET {GTY-Aurora_64B66B} \
    CONFIG.INTERNAL_PRESET {Aurora_64B66B} \
    CONFIG.GT_TYPE {GTY} \
    CONFIG.GT_DIRECTION {BOTH} \
    CONFIG.CHANNEL_ENABLE {X0Y4 X0Y5 X0Y6 X0Y7} \
    CONFIG.TX_MASTER_CHANNEL {X0Y5} \
    CONFIG.RX_MASTER_CHANNEL {X0Y5} \
    CONFIG.TX_LINE_RATE {25.78125} \
    CONFIG.RX_LINE_RATE {25.78125} \
    CONFIG.TX_PLL_TYPE {QPLL0} \
    CONFIG.RX_PLL_TYPE {QPLL0} \
    CONFIG.TX_QPLL_FRACN_NUMERATOR {8388608} \
    CONFIG.RX_QPLL_FRACN_NUMERATOR {8388608} \
    CONFIG.TX_REFCLK_FREQUENCY {156.25} \
    CONFIG.RX_REFCLK_FREQUENCY {156.25} \
    CONFIG.TX_REFCLK_SOURCE {X0Y4 clk0 X0Y5 clk0 X0Y6 clk0 X0Y7 clk0} \
    CONFIG.RX_REFCLK_SOURCE {X0Y4 clk0 X0Y5 clk0 X0Y6 clk0 X0Y7 clk0} \
    CONFIG.TX_DATA_ENCODING {64B66B} \
    CONFIG.RX_DATA_DECODING {64B66B} \
    CONFIG.TX_INT_DATA_WIDTH {64} \
    CONFIG.RX_INT_DATA_WIDTH {64} \
    CONFIG.TX_USER_DATA_WIDTH {64} \
    CONFIG.RX_USER_DATA_WIDTH {64} \
    CONFIG.TX_BUFFER_MODE {1} \
    CONFIG.RX_BUFFER_MODE {1} \
    CONFIG.TX_OUTCLK_SOURCE {TXOUTCLKPMA} \
    CONFIG.RX_OUTCLK_SOURCE {RXOUTCLKPMA} \
    CONFIG.TXPROGDIV_FREQ_SOURCE {QPLL0} \
    CONFIG.TXPROGDIV_FREQ_VAL {402.8320312} \
    CONFIG.RX_EQ_MODE {AUTO} \
    CONFIG.RX_COUPLING {AC} \
    CONFIG.RX_TERMINATION {PROGRAMMABLE} \
    CONFIG.RX_TERMINATION_PROG_VALUE {800} \
    CONFIG.INS_LOSS_NYQ {20} \
    CONFIG.FREERUN_FREQUENCY {100} \
    CONFIG.INCLUDE_CPLL_CAL {2} \
    CONFIG.LOCATE_COMMON {CORE} \
    CONFIG.LOCATE_RESET_CONTROLLER {CORE} \
    CONFIG.LOCATE_RX_USER_CLOCKING {EXAMPLE_DESIGN} \
    CONFIG.LOCATE_TX_USER_CLOCKING {EXAMPLE_DESIGN} \
    CONFIG.LOCATE_USER_DATA_WIDTH_SIZING {CORE} \
    CONFIG.LOCATE_RX_BUFFER_BYPASS_CONTROLLER {CORE} \
    CONFIG.LOCATE_TX_BUFFER_BYPASS_CONTROLLER {CORE} \
    CONFIG.LOCATE_IN_SYSTEM_IBERT_CORE {NONE} \
    CONFIG.ENABLE_OPTIONAL_PORTS {drpaddr_in drpclk_in drpdi_in drpen_in drpwe_in drpdo_out drprdy_out eyescanreset_in eyescantrigger_in gtrefclk0_in gtpowergood_out loopback_in rxbufreset_in rxcdrhold_in rxcdrovrden_in rxdfelpmreset_in rxlpmen_in rxpcsreset_in rxpmareset_in rxpolarity_in rxprbscntreset_in rxprbssel_in txdiffctrl_in txpcsreset_in txpmareset_in txpolarity_in txinhibit_in pcsrsvdin_in txpostcursor_in txprbsforceerr_in txprbssel_in txprecursor_in dmonitorout_out  eyescandataerror_out qpll0lock_out qpll0refclklost_out rxbufstatus_out gtwiz_userdata_rx_out rxoutclk_out rxprbserr_out rxresetdone_out txbufstatus_out txoutclkfabric_out txoutclkpcs_out txresetdone_out} \
    CONFIG.TX_DIFF_SWING_EMPH_MODE {CUSTOM} \
    CONFIG.USER_GTPOWERGOOD_DELAY_EN {1} \
    CONFIG.RX_CC_PERIODICITY {5000} \
    CONFIG.RX_COMMA_SHOW_REALIGN_ENABLE {true} \
] [get_ips aurora_qsfp_gt]
