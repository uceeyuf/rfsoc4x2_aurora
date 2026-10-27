// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Yijie Yu
//
// PRBS31 checker for prbs31_tx's words (256 bits, bit i the sequence bit at time t0 + i), with valid gaps.
// Unlocked, each word is predicted from the previous received word (self-synchronizing); after LOCK_WORDS error-free
// words it locks and predicts from its own sequence, so a bit error counts once (not three times through the feedback
// taps). Locked, UNLOCK_WORDS consecutive words with more than 64 bit errors unlock it (lock_lost counts it).
// The error bits are counted through a pipelined population count.

`resetall
`timescale 1ns / 1ps
`default_nettype none

module prbs31_rx #(
    parameter integer LOCK_WORDS   = 64,
    parameter integer UNLOCK_WORDS = 8
)(
    input  wire          clk,
    input  wire          rst,
    input  wire          clear,          // the counters to zero
    input  wire          valid,
    input  wire [255:0]  data,
    output reg           locked = 1'b0,
    output reg  [47:0]   words = 48'd0,      // words checked while locked
    output reg  [47:0]   err_bits = 48'd0,   // bit errors in them
    output reg  [47:0]   err_words = 48'd0,  // words with at least one bit error
    output reg  [31:0]   lock_lost = 32'd0
);

`include "prbs31_next.vh"

// stage 1: the received word, registered
reg          v1 = 1'b0;
reg  [255:0] d1 = 256'd0;
always @(posedge clk) begin
    v1 <= valid && !rst;
    d1 <= data;
end

// stage 2: the prediction (from the previous received word, or locked from the own sequence) and the difference
reg  [30:0]  prev = 31'd0;                  // the previous received word's last 31 bits
reg  [30:0]  own = 31'd0;                   // (locked) the own sequence's last 31 bits
reg          have_prev = 1'b0;
wire [255:0] prd = prbs31_next(locked ? own : prev);
reg          v2 = 1'b0;
reg  [255:0] e2 = 256'd0;                   // the error bits
always @(posedge clk) begin
    v2 <= 1'b0;
    if (v1) begin
        prev <= d1[255:225];
        own  <= prd[255:225];               // (unlocked: the prediction, the received word when it is right)
        have_prev <= 1'b1;
        v2 <= have_prev;
        e2 <= d1 ^ prd;
    end
    if (rst) begin have_prev <= 1'b0; v2 <= 1'b0; end
end

// stages 3 .. 6: the population count of e2 (64 x 4 -> 3 bit, 16 x 4 -> 5 bit, 4 x 4 -> 7 bit, 4 -> 9 bit)
reg          v3 = 1'b0, v4 = 1'b0, v5 = 1'b0, v6 = 1'b0;
reg  [2:0]   c3 [0:63];
reg  [4:0]   c4 [0:15];
reg  [6:0]   c5 [0:3];
reg  [8:0]   c6 = 9'd0;
integer i;
initial begin
    for (i = 0; i < 64; i = i + 1) c3[i] = 3'd0;
    for (i = 0; i < 16; i = i + 1) c4[i] = 5'd0;
    for (i = 0; i < 4; i = i + 1)  c5[i] = 7'd0;
end
always @(posedge clk) begin
    v3 <= v2 && !rst; v4 <= v3 && !rst; v5 <= v4 && !rst; v6 <= v5 && !rst;
    for (i = 0; i < 64; i = i + 1)
        c3[i] <= {2'd0, e2[4 * i]} + {2'd0, e2[4 * i + 1]} + {2'd0, e2[4 * i + 2]} + {2'd0, e2[4 * i + 3]};
    for (i = 0; i < 16; i = i + 1)
        c4[i] <= ({2'd0, c3[4 * i]} + {2'd0, c3[4 * i + 1]}) + ({2'd0, c3[4 * i + 2]} + {2'd0, c3[4 * i + 3]});
    for (i = 0; i < 4; i = i + 1)
        c5[i] <= ({2'd0, c4[4 * i]} + {2'd0, c4[4 * i + 1]}) + ({2'd0, c4[4 * i + 2]} + {2'd0, c4[4 * i + 3]});
    c6 <= ({2'd0, c5[0]} + {2'd0, c5[1]}) + ({2'd0, c5[2]} + {2'd0, c5[3]});
end

// the lock (decided at stage 6, a few words late; the own sequence is the prediction, right while the words are)
reg  [7:0]   good = 8'd0;
reg  [3:0]   bad = 4'd0;
always @(posedge clk) begin
    if (v6) begin
        if (!locked) begin
            if (c6 != 9'd0) good <= 8'd0;
            else if (good == LOCK_WORDS - 1) begin locked <= 1'b1; good <= 8'd0; end
            else good <= good + 1'b1;
        end else begin
            words <= words + 1'b1;
            err_bits <= err_bits + c6;
            if (c6 != 9'd0) err_words <= err_words + 1'b1;
            if (c6 > 9'd64) begin
                if (bad == UNLOCK_WORDS - 1) begin locked <= 1'b0; bad <= 4'd0; lock_lost <= lock_lost + 1'b1; end
                else bad <= bad + 1'b1;
            end else bad <= 4'd0;
        end
    end
    if (clear) begin words <= 48'd0; err_bits <= 48'd0; err_words <= 48'd0; lock_lost <= 32'd0; end
    if (rst) begin locked <= 1'b0; good <= 8'd0; bad <= 4'd0; end
end

endmodule

`resetall
