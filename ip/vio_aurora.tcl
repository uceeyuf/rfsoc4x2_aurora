# Aurora link control and counters (100 MHz; the counters are a snapshot taken on request in the user clock).
#   in0 {locked, hard_err, soft_err, channel_up, lane_up 0..3}, in1 {modprsl / intl of the QSFP28, mmcm_not_locked,
#   gt_pll_lock, rx_rev, pma_init, reset_pb, snapshot acknowledge}; snapshot: in2 user clock cycles, in3 words sent,
#   in4 words received, in5 words checked (checker locked), in6 bit errors, in7 words with errors, in8 checker lock
#   losses, in9 soft-error cycles, in10 hard errors, in11 channel-up drops
#   out0 reset_pb, out1 pma_init, out2 loopback (GT: 0 normal, 2 near-end PMA), out3 snapshot toggle, out4 clear
#   toggle, out5 error-injection toggle, out6 the received lanes in reverse order (a loopback plug: TX lane l on RX lane 3 - l)
create_ip -name vio -vendor xilinx.com -library ip -module_name vio_aurora
set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN {12} \
    CONFIG.C_PROBE_IN0_WIDTH {8} \
    CONFIG.C_PROBE_IN1_WIDTH {8} \
    CONFIG.C_PROBE_IN2_WIDTH {48} \
    CONFIG.C_PROBE_IN3_WIDTH {48} \
    CONFIG.C_PROBE_IN4_WIDTH {48} \
    CONFIG.C_PROBE_IN5_WIDTH {48} \
    CONFIG.C_PROBE_IN6_WIDTH {48} \
    CONFIG.C_PROBE_IN7_WIDTH {48} \
    CONFIG.C_PROBE_IN8_WIDTH {32} \
    CONFIG.C_PROBE_IN9_WIDTH {32} \
    CONFIG.C_PROBE_IN10_WIDTH {32} \
    CONFIG.C_PROBE_IN11_WIDTH {32} \
    CONFIG.C_NUM_PROBE_OUT {7} \
    CONFIG.C_PROBE_OUT0_WIDTH {1} \
    CONFIG.C_PROBE_OUT1_WIDTH {1} \
    CONFIG.C_PROBE_OUT2_WIDTH {3} \
    CONFIG.C_PROBE_OUT3_WIDTH {1} \
    CONFIG.C_PROBE_OUT4_WIDTH {1} \
    CONFIG.C_PROBE_OUT5_WIDTH {1} \
    CONFIG.C_PROBE_OUT6_WIDTH {1} \
    CONFIG.C_EN_PROBE_IN_ACTIVITY {0} \
] [get_ips vio_aurora]
