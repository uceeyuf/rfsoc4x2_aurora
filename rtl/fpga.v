// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Yijie Yu
//
// RFSoC 4x2: Aurora 64B/66B, 4 x 25.78125 Gb/s (100G) on the QSFP28 port, PRBS31 traffic and its check.
//   100 MHz board clock: Aurora init / DRP clock and the VIO's clock
//   156.25 MHz QSFP28 reference clock (AA33 / AA34): the GTs (QPLL0 fractional-N)
//   user clock 402.83 MHz (from the GTs): 256-bit PRBS31 source into the channel, checker on its output, counters
// The counters are copied on request (vio snap toggle) into a snapshot read by the VIO (tests/aurora_test.tcl).

`resetall
`timescale 1ns / 1ps
`default_nettype none

module fpga (
    input  wire         clk_p,              // 100 MHz
    input  wire         clk_n,
    input  wire         reset_n,            // push button, active low

    // QSFP28
    output wire [3:0]   qsfp0_tx_p,
    output wire [3:0]   qsfp0_tx_n,
    input  wire [3:0]   qsfp0_rx_p,
    input  wire [3:0]   qsfp0_rx_n,
    input  wire         qsfp0_mgt_refclk_0_p,
    input  wire         qsfp0_mgt_refclk_0_n,
    output wire         qsfp0_modsell,
    output wire         qsfp0_resetl,
    input  wire         qsfp0_modprsl,
    input  wire         qsfp0_intl,
    output wire         qsfp0_lpmode
);

// the module out of reset, in high-power mode (LPMode low: the lasers on), not selected (no I2C)
assign qsfp0_modsell = 1'b1;
assign qsfp0_resetl  = 1'b1;
assign qsfp0_lpmode  = 1'b0;

// ---------------------------------------------------------------- 100 MHz: init clock, VIO, start-up
wire clk_ibuf, clk100;
IBUFDS clk_ibufds (.I(clk_p), .IB(clk_n), .O(clk_ibuf));
BUFG   clk_bufg   (.I(clk_ibuf), .O(clk100));

// after configuration (and the push button): pma_init 168 ms, reset_pb until 336 ms (the Aurora start-up sequence)
reg  [25:0] por = 26'd0;
reg  [2:0]  btn_s = 3'b111;
always @(posedge clk100) begin
    btn_s <= {btn_s[1:0], reset_n};
    if (!btn_s[2]) por <= 26'd0;
    else if (!por[25]) por <= por + 1'b1;
end
wire        vio_reset_pb, vio_pma_init;
wire [2:0]  vio_loopback;
wire        vio_snap, vio_clear, vio_inject;
wire        pma_init = !por[25] && !por[24] || vio_pma_init;
wire        reset_pb = !por[25] || vio_reset_pb;

// ---------------------------------------------------------------- Aurora 64B/66B (the core's support wrapper)
wire          user_clk, sys_reset, channel_up, hard_err, soft_err, gt_pll_lock, mmcm_not_locked;
wire [0:3]    lane_up;
wire [255:0]  tx_data;
wire          tx_valid, tx_ready;
wire [0:255]  rx_data;
wire          rx_valid;

aurora_qsfp_support aurora_i (
    .s_axi_tx_tdata(tx_data), .s_axi_tx_tvalid(tx_valid && channel_up), .s_axi_tx_tready(tx_ready),
    .m_axi_rx_tdata(rx_data), .m_axi_rx_tvalid(rx_valid),
    .rxp(qsfp0_rx_p), .rxn(qsfp0_rx_n), .txp(qsfp0_tx_p), .txn(qsfp0_tx_n),
    .hard_err(hard_err), .soft_err(soft_err), .channel_up(channel_up), .lane_up(lane_up),
    .user_clk_out(user_clk), .sync_clk_out(),
    .reset_pb(reset_pb), .gt_rxcdrovrden_in(1'b0), .power_down(1'b0), .loopback(vio_loopback), .pma_init(pma_init),
    // the transceivers' DRP: unused
    .gt0_drpaddr(10'd0), .gt0_drpdi(16'd0), .gt0_drpen(1'b0), .gt0_drpwe(1'b0), .gt0_drpdo(), .gt0_drprdy(),
    .gt1_drpaddr(10'd0), .gt1_drpdi(16'd0), .gt1_drpen(1'b0), .gt1_drpwe(1'b0), .gt1_drpdo(), .gt1_drprdy(),
    .gt2_drpaddr(10'd0), .gt2_drpdi(16'd0), .gt2_drpen(1'b0), .gt2_drpwe(1'b0), .gt2_drpdo(), .gt2_drprdy(),
    .gt3_drpaddr(10'd0), .gt3_drpdi(16'd0), .gt3_drpen(1'b0), .gt3_drpwe(1'b0), .gt3_drpdo(), .gt3_drprdy(),
    .init_clk(clk100), .link_reset_out(), .gt_pll_lock(gt_pll_lock), .sys_reset_out(sys_reset),
    .gt_refclk1_p(qsfp0_mgt_refclk_0_p), .gt_refclk1_n(qsfp0_mgt_refclk_0_n),
    .bufg_gt_clr_out(), .mmcm_not_locked_out(mmcm_not_locked), .tx_out_clk()
);

// ---------------------------------------------------------------- user clock: VIO requests in
wire snap_u, clear_u, inject_u;
xpm_cdc_single #(.DEST_SYNC_FF(3), .INIT_SYNC_FF(1), .SRC_INPUT_REG(0)) snap_cdc (.src_clk(1'b0), .src_in(vio_snap), .dest_clk(user_clk), .dest_out(snap_u));
xpm_cdc_single #(.DEST_SYNC_FF(3), .INIT_SYNC_FF(1), .SRC_INPUT_REG(0)) clear_cdc (.src_clk(1'b0), .src_in(vio_clear), .dest_clk(user_clk), .dest_out(clear_u));
xpm_cdc_single #(.DEST_SYNC_FF(3), .INIT_SYNC_FF(1), .SRC_INPUT_REG(0)) inject_cdc (.src_clk(1'b0), .src_in(vio_inject), .dest_clk(user_clk), .dest_out(inject_u));
reg  snap_d = 1'b0, clear_d = 1'b0, inject_d = 1'b0;
always @(posedge user_clk) begin snap_d <= snap_u; clear_d <= clear_u; inject_d <= inject_u; end
wire clear_p  = clear_u != clear_d;          // (toggles: one pulse per change)
wire inject_p = inject_u != inject_d;
wire snap_p   = snap_u != snap_d;

// ---------------------------------------------------------------- traffic
reg  rst_u = 1'b1;
always @(posedge user_clk) rst_u <= sys_reset || !channel_up;

prbs31_tx tx_i (.clk(user_clk), .rst(rst_u), .ready(tx_ready && channel_up), .inject(inject_p), .data(tx_data), .valid(tx_valid));

wire        locked;
wire [47:0] rx_words, err_bits, err_words;
wire [31:0] lock_lost;
prbs31_rx rx_i (.clk(user_clk), .rst(rst_u), .clear(clear_p), .valid(rx_valid), .data(rx_data),
                .locked(locked), .words(rx_words), .err_bits(err_bits), .err_words(err_words), .lock_lost(lock_lost));

// ---------------------------------------------------------------- user clock: counters (since the last clear)
reg  [47:0] uptime = 48'd0, tx_words = 48'd0, rx_all = 48'd0;
reg  [31:0] soft_cyc = 32'd0, hard_ev = 32'd0, up_drops = 32'd0;
reg         hard_d = 1'b0, up_d = 1'b0;
always @(posedge user_clk) begin
    hard_d <= hard_err; up_d <= channel_up;
    uptime <= uptime + 1'b1;
    if (tx_valid && tx_ready && channel_up) tx_words <= tx_words + 1'b1;
    if (rx_valid) rx_all <= rx_all + 1'b1;
    if (soft_err) soft_cyc <= soft_cyc + 1'b1;
    if (hard_err && !hard_d) hard_ev <= hard_ev + 1'b1;
    if (up_d && !channel_up) up_drops <= up_drops + 1'b1;
    if (clear_p) begin uptime <= 48'd0; tx_words <= 48'd0; rx_all <= 48'd0; soft_cyc <= 32'd0; hard_ev <= 32'd0; up_drops <= 32'd0; end
end

// the snapshot (static while the VIO reads it: tests/aurora_test.tcl waits for the acknowledge)
reg  [47:0] s_uptime = 0, s_tx = 0, s_rx_all = 0, s_rx = 0, s_err_bits = 0, s_err_words = 0;
reg  [31:0] s_lock_lost = 0, s_soft = 0, s_hard = 0, s_drops = 0;
reg         snap_ack = 1'b0;
always @(posedge user_clk) begin
    if (snap_p) begin
        s_uptime <= uptime; s_tx <= tx_words; s_rx_all <= rx_all; s_rx <= rx_words; s_err_bits <= err_bits; s_err_words <= err_words;
        s_lock_lost <= lock_lost; s_soft <= soft_cyc; s_hard <= hard_ev; s_drops <= up_drops;
        snap_ack <= snap_u;
    end
end

// ---------------------------------------------------------------- 100 MHz: status in, VIO
wire [7:0] st_u = {locked, hard_err, soft_err, channel_up, lane_up[0], lane_up[1], lane_up[2], lane_up[3]};
wire [7:0] st_s;
xpm_cdc_array_single #(.DEST_SYNC_FF(3), .INIT_SYNC_FF(1), .SRC_INPUT_REG(0), .WIDTH(8)) st_cdc (.src_clk(1'b0), .src_in(st_u), .dest_clk(clk100), .dest_out(st_s));
wire ack_s;
xpm_cdc_single #(.DEST_SYNC_FF(3), .INIT_SYNC_FF(1), .SRC_INPUT_REG(0)) ack_cdc (.src_clk(1'b0), .src_in(snap_ack), .dest_clk(clk100), .dest_out(ack_s));
wire [7:0] st100 = {qsfp0_intl, qsfp0_modprsl, mmcm_not_locked, gt_pll_lock, 1'b0, pma_init, reset_pb, ack_s};

vio_aurora vio_i (
    .clk(clk100),
    .probe_in0(st_s),           // {locked, hard_err, soft_err, channel_up, lane_up 0..3}
    .probe_in1(st100),          // {intl, modprsl, mmcm_not_locked, gt_pll_lock, 0, pma_init, reset_pb, snap_ack}
    .probe_in2(s_uptime),
    .probe_in3(s_tx),
    .probe_in4(s_rx_all),
    .probe_in5(s_rx),
    .probe_in6(s_err_bits),
    .probe_in7(s_err_words),
    .probe_in8(s_lock_lost),
    .probe_in9(s_soft),
    .probe_in10(s_hard),
    .probe_in11(s_drops),
    .probe_out0(vio_reset_pb),
    .probe_out1(vio_pma_init),
    .probe_out2(vio_loopback),
    .probe_out3(vio_snap),
    .probe_out4(vio_clear),
    .probe_out5(vio_inject)
);

endmodule

`resetall
