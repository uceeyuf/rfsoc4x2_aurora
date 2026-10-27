# Synthesize, implement and write the bitstream.
#
#   vivado -mode batch -source scripts/build.tcl [-tclargs <jobs>]
#
# Creates the project first if it does not exist. Output: build/fpga.bit, build/fpga.ltx

set repo_dir  [file normalize [file join [file dirname [info script]] ..]]
set proj_name rfsoc4x2_aurora
set proj_file [file join $repo_dir build $proj_name $proj_name.xpr]
set jobs      [expr {$argc > 0 ? [lindex $argv 0] : 8}]

if {![file exists $proj_file]} {
    source [file join $repo_dir scripts create_project.tcl]
} else {
    open_project $proj_file
}

set synth [get_runs synth_1]
if {[get_property PROGRESS $synth] ne "100%" || [get_property NEEDS_REFRESH $synth]} {
    reset_run synth_1
    launch_runs synth_1 -jobs $jobs
    wait_on_run synth_1
    if {[get_property PROGRESS $synth] ne "100%"} {
        error "synth_1 failed"
    }
}


reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "impl_1 failed"
}

open_run impl_1
report_timing_summary -file [file join $repo_dir build timing_summary.rpt]
report_utilization    -file [file join $repo_dir build utilization.rpt]

set impl_dir [get_property DIRECTORY [get_runs impl_1]]
file copy -force [file join $impl_dir fpga.bit] [file join $repo_dir build fpga.bit]
if {[file exists [file join $impl_dir fpga.ltx]]} {
    file copy -force [file join $impl_dir fpga.ltx] [file join $repo_dir build fpga.ltx]
}
# the prebuilt copy for the board (scripts/program.tcl, tests/aurora_test.tcl use it when build/ has none)
file mkdir [file join $repo_dir prebuilt]
file copy -force [file join $repo_dir build fpga.bit] [file join $repo_dir prebuilt rfsoc4x2_aurora.bit]
file copy -force [file join $repo_dir build fpga.ltx] [file join $repo_dir prebuilt rfsoc4x2_aurora.ltx]
puts "Bitstream: [file join $repo_dir build fpga.bit] (and prebuilt/)"
