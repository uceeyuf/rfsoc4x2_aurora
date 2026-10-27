# Aurora 100G link test on the RFSoC 4x2 (QSFP28, PRBS31 over the channel), read through the VIO.
#
#   vivado -mode batch -source tests/aurora_test.tcl [-tclargs <seconds> [loopback] [noprog]]
#
#   seconds   measurement time (default 10), one line a second
#   loopback  0 (default): through the QSFP28 (a loopback module, or the other end); 2: the GTs' near-end PMA
#             loopback (no module needed: checks the design and the board)
#   noprog    the FPGA already programmed (skips programming)
# Programs prebuilt/rfsoc4x2_aurora.bit (or build/fpga.bit), restarts the link, waits for channel up, clears the counters,
# then prints per second: the payload rate, the bit errors and the BER of the PRBS31 checker; at the end one error is
# injected at the transmitter to show that the checker counts it. Output also in out/aurora_test.txt.

set repo_dir [file normalize [file join [file dirname [info script]] ..]]
set secs     [expr {$argc > 0 ? [lindex $argv 0] : 10}]
set lb       [expr {$argc > 1 ? [lindex $argv 1] : 0}]
set noprog   [expr {$argc > 2 && [lindex $argv 2] eq "noprog"}]
set f_user   402.8320312e6                ;# the Aurora user clock (25.78125 Gb/s / 64), 256 bits a cycle

file mkdir [file join $repo_dir out]
set log [open [file join $repo_dir out aurora_test.txt] w]
proc say {msg} { global log; puts $msg; puts $log $msg; flush $log }

if {$noprog} {
    open_hw_manager; connect_hw_server -allow_non_jtag; open_hw_target
    set dev [lindex [get_hw_devices xczu48dr*] 0]; current_hw_device $dev
    set b [file join $repo_dir build fpga.ltx]
    if {![file exists $b]} { set b [file join $repo_dir prebuilt rfsoc4x2_aurora.ltx] }
    set_property PROBES.FILE $b $dev; set_property FULL_PROBES.FILE $b $dev; refresh_hw_device $dev
} else {
    source [file join $repo_dir scripts program.tcl]
}
set vio [lindex [get_hw_vios -of_objects [current_hw_device]] 0]
foreach p [get_hw_probes -of_objects $vio] {
    if {[get_property TYPE $p] eq "vio_input"} { set_property INPUT_VALUE_RADIX UNSIGNED $p }
}
proc probe {name} { global vio; return [get_hw_probes $name -of_objects $vio] }
proc out {name value} {
    global vio
    set p [probe $name]
    set_property OUTPUT_VALUE_RADIX UNSIGNED $p
    set_property OUTPUT_VALUE $value $p
    commit_hw_vio $p
}
proc in {name} { global vio; refresh_hw_vio $vio; return [get_property INPUT_VALUE [probe $name]] }
proc status {} {
    set s [in st_s]; set t [in st100]
    return [dict create locked [expr {($s >> 7) & 1}] hard [expr {($s >> 6) & 1}] soft [expr {($s >> 5) & 1}] \
        up [expr {($s >> 4) & 1}] lanes [format %d%d%d%d [expr {($s >> 3) & 1}] [expr {($s >> 2) & 1}] [expr {($s >> 1) & 1}] [expr {$s & 1}]] \
        intl [expr {($t >> 7) & 1}] modprsl [expr {($t >> 6) & 1}] pll_lock [expr {($t >> 4) & 1}] ack [expr {$t & 1}]]
}
set toggles [dict create vio_snap 0 vio_clear 0 vio_inject 0]
proc toggle {name} {
    global toggles
    dict set toggles $name [expr {1 - [dict get $toggles $name]}]
    out $name [dict get $toggles $name]
}
proc snapshot {} {
    global toggles
    toggle vio_snap
    for {set i 0} {$i < 100} {incr i} {
        if {[dict get [status] ack] == [dict get $toggles vio_snap]} break
        after 10
    }
    set r [dict create]
    foreach n {s_uptime s_tx s_rx_all s_rx s_err_bits s_err_words s_lock_lost s_soft s_hard s_drops} { dict set r $n [in $n] }
    return $r
}

# the link: the loopback, then the start-up sequence again (pma_init, then reset_pb)
foreach n {vio_snap vio_clear vio_inject} { out $n 0 }
out vio_loopback $lb
out vio_reset_pb 1; out vio_pma_init 1; after 1000
out vio_pma_init 0; after 1000
out vio_reset_pb 0
set st [status]
for {set i 0} {$i < 100 && ![dict get $st up]} {incr i} { after 100; set st [status] }
say "loopback $lb ([expr {$lb == 2 ? {near-end PMA} : {through the QSFP28}}]); QSFP28 module [expr {[dict get $st modprsl] ? {absent} : {present}}], IntL [dict get $st intl]; QPLL lock [dict get $st pll_lock]"
say "channel up [dict get $st up], lanes up (0..3) [dict get $st lanes]"
if {![dict get $st up]} {
    say "RESULT: the channel did not come up"
    close $log; exit 1
}
for {set i 0} {$i < 50 && ![dict get $st locked]} {incr i} { after 100; set st [status] }
say "PRBS31 checker locked [dict get $st locked]"

toggle vio_clear; after 100
set p [snapshot]
set t0 [clock milliseconds]
for {set s 1} {$s <= $secs} {incr s} {
    after [expr {$t0 + 1000 * $s - [clock milliseconds]}]
    set c [snapshot]
    set dc [expr {[dict get $c s_uptime] - [dict get $p s_uptime]}]
    set dw [expr {[dict get $c s_rx] - [dict get $p s_rx]}]
    set de [expr {[dict get $c s_err_bits] - [dict get $p s_err_bits]}]
    set gbps [expr {$dc > 0 ? $dw * 256.0 * $f_user / $dc / 1e9 : 0}]
    say [format "%3d s: %7.3f Gb/s checked, bit errors %d (total %d of %.3e bits, BER %.2e), lock losses %d, soft-error cycles %d, hard errors %d, channel drops %d" \
        $s $gbps $de [dict get $c s_err_bits] [expr {[dict get $c s_rx] * 256.0}] \
        [expr {[dict get $c s_rx] > 0 ? [dict get $c s_err_bits] / ([dict get $c s_rx] * 256.0) : 1.0}] \
        [dict get $c s_lock_lost] [dict get $c s_soft] [dict get $c s_hard] [dict get $c s_drops]]
    set p $c
}
set total [snapshot]
set bits [expr {[dict get $total s_rx] * 256.0}]
set errs [dict get $total s_err_bits]
set rate [expr {[dict get $total s_uptime] > 0 ? $bits * $f_user / [dict get $total s_uptime] / 1e9 : 0}]
# the checker's self test: one bit flipped at the transmitter
toggle vio_inject; after 200
set after_inj [snapshot]
set inj [expr {[dict get $after_inj s_err_bits] - $errs}]
say [format "RESULT: %.3f Gb/s of PRBS31 payload checked, %.3e bits, %d bit errors (BER %s), injected error counted %d (expected 1)" \
    $rate $bits $errs [expr {$errs == 0 ? [format "< %.1e" [expr {1.0 / $bits}]] : [format %.2e [expr {$errs / $bits}]]}] $inj]
close $log
