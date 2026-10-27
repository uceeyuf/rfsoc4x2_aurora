# Aurora 64B/66B, four lanes at 25.78125 Gb/s (100G), streaming, full duplex, the transceivers outside the core
# (C_GTWIZ_OUT: ip/aurora_qsfp_gt.tcl, at the board's 156.25 MHz reference). C_REFCLK_FREQUENCY is the core's nominal value
# only (it allows integer multiples); the GT wizard sets the real one.
create_ip -vlnv xilinx.com:ip:aurora_64b66b:12.0 -module_name aurora_qsfp
set_property -dict [list CONFIG.C_AURORA_LANES {4} CONFIG.C_LINE_RATE {25.78125}] [get_ips aurora_qsfp]
set_property -dict [list \
    CONFIG.C_REFCLK_FREQUENCY {161.1328125} \
    CONFIG.C_INIT_CLK {100} \
    CONFIG.DRP_FREQ {100} \
    CONFIG.interface_mode {Streaming} \
    CONFIG.dataflow_config {Duplex} \
    CONFIG.flow_mode {None} \
    CONFIG.C_GTWIZ_OUT {true} \
    CONFIG.drp_mode {Native} \
] [get_ips aurora_qsfp]
