# Program the RFSoC 4x2 over JTAG (+ the VIO's probes file).
#
#   vivado -mode batch -source scripts/program.tcl [-tclargs <bit> [<ltx>]]
#
# Default: build/fpga.bit when it exists (a local build), else prebuilt/rfsoc4x2_aurora.bit.

set repo_dir [file normalize [file join [file dirname [info script]] ..]]
proc default_files {repo_dir} {
    set b [file join $repo_dir build fpga.bit]
    if {[file exists $b]} { return [list $b [file join $repo_dir build fpga.ltx]] }
    return [list [file join $repo_dir prebuilt rfsoc4x2_aurora.bit] [file join $repo_dir prebuilt rfsoc4x2_aurora.ltx]]
}
lassign [default_files $repo_dir] bit ltx
# (sourced by tests/*.tcl, which set prog_sourced: their arguments are not file names)
if {![info exists prog_sourced]} {
    if {$argc > 0} { set bit [lindex $argv 0] }
    if {$argc > 1} { set ltx [lindex $argv 1] }
}

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set dev [lindex [get_hw_devices xczu48dr*] 0]
current_hw_device $dev
set_property PROGRAM.FILE $bit $dev
if {[file exists $ltx]} {
    set_property PROBES.FILE      $ltx $dev
    set_property FULL_PROBES.FILE $ltx $dev
}
program_hw_devices $dev
refresh_hw_device $dev
puts "Programmed $dev with $bit"
