// Testbench: prbs31_tx -> prbs31_rx with random ready / valid gaps; lock, then one injected bit error counted once.
//   xvlog -i rtl rtl/prbs31_tx.v rtl/prbs31_rx.v sim/tb_prbs31.v && xelab tb_prbs31 -R
`timescale 1ns / 1ps
module tb_prbs31;
reg clk = 0, rst = 1, inject = 0, clear = 0;
always #1.25 clk = ~clk;
reg ready = 0;
wire [255:0] d; wire v;
prbs31_tx tx (.clk(clk), .rst(rst), .ready(ready), .inject(inject), .data(d), .valid(v));
reg rv = 0; reg [255:0] rd = 0;
always @(posedge clk) begin rv <= v && ready; rd <= d; end
wire locked; wire [47:0] words, eb, ew; wire [31:0] ll;
prbs31_rx rx (.clk(clk), .rst(rst), .clear(clear), .valid(rv), .data(rd), .locked(locked), .words(words), .err_bits(eb), .err_words(ew), .lock_lost(ll));
integer n;
initial begin
    repeat (10) @(posedge clk); rst <= 0;
    for (n = 0; n < 3000; n = n + 1) begin ready <= ($random % 4) != 0; @(posedge clk); end
    $display("after 3000 cycles: locked %0d words %0d err_bits %0d err_words %0d lock_lost %0d", locked, words, eb, ew, ll);
    inject <= 1; @(posedge clk); inject <= 0;
    for (n = 0; n < 2000; n = n + 1) begin ready <= ($random % 4) != 0; @(posedge clk); end
    $display("after the injection: locked %0d words %0d err_bits %0d err_words %0d lock_lost %0d", locked, words, eb, ew, ll);
    // ... and with ready held high (as on the board: the request and the next word in the same cycle)
    ready <= 1; repeat (20) @(posedge clk);
    inject <= 1; @(posedge clk); inject <= 0;
    repeat (200) @(posedge clk);
    $display("after an injection with ready high: err_bits %0d err_words %0d", eb, ew);
    $display("%s", locked && eb == 2 && ew == 2 && ll == 0 ? "PASS" : "FAIL");
    $finish;
end
endmodule
