// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Yijie Yu
//
// PRBS31 (x^31 + x^28 + 1) source, 256 bits a cycle: a new word each cycle with ready. Bit i of a word is the
// sequence bit at time t0 + i. inject (one cycle) flips bit 0 of the next word sent (the checker's self test).

`resetall
`timescale 1ns / 1ps
`default_nettype none

module prbs31_tx (
    input  wire          clk,
    input  wire          rst,
    input  wire          ready,
    input  wire          inject,
    output reg  [255:0]  data = 256'd0,
    output reg           valid = 1'b0
);

`include "prbs31_next.vh"

reg  [30:0] state = 31'h7FFFFFFF;
reg         inj_pend = 1'b0;
wire [255:0] nxt = prbs31_next(state);

always @(posedge clk) begin
    if (inject) inj_pend <= 1'b1;
    if (rst) begin
        state <= 31'h7FFFFFFF; valid <= 1'b0; inj_pend <= 1'b0;
    end else if (!valid || ready) begin
        data <= nxt ^ {255'd0, inj_pend};
        state <= nxt[255:225];
        valid <= 1'b1;
        inj_pend <= 1'b0;
    end
end

endmodule

`resetall
