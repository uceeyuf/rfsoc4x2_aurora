# Recreate the Vivado project from the sources in this repository.
#
#   vivado -mode batch -source scripts/create_project.tcl
#
# The project is created in build/rfsoc4x2_aurora (ignored by git). Tested with Vivado 2023.2.

set repo_dir  [file normalize [file join [file dirname [info script]] ..]]
set proj_name rfsoc4x2_aurora
set proj_dir  [file join $repo_dir build $proj_name]
set part      xczu48dr-ffvg1517-2-e

create_project $proj_name $proj_dir -part $part -force

# Board files are optional; only the part is needed to build.
set board [lindex [get_board_parts -quiet -latest_file_version {realdigital.org:rfsoc4x2:*}] 0]
if {$board ne ""} {
    set_property board_part $board [current_project]
}
set_property target_language Verilog [current_project]
set_property default_lib xil_defaultlib [current_project]

# ---------------------------------------------------------------- sources
add_files -norecurse -fileset sources_1 [glob [file join $repo_dir rtl *.v]]
add_files -norecurse -fileset sources_1 [file join $repo_dir rtl prbs31_next.vh]
set_property file_type {Verilog Header} [get_files prbs31_next.vh]
set_property include_dirs [file join $repo_dir rtl] [get_filesets sources_1]

# ---------------------------------------------------------------- IP
# aurora_qsfp (the core, its transceivers outside: C_GTWIZ_OUT), aurora_qsfp_gt (those transceivers at the board's
# 156.25 MHz reference, fractional-N), vio_aurora
foreach ip_tcl [lsort [glob [file join $repo_dir ip *.tcl]]] {
    source $ip_tcl
}
generate_target all [get_ips]
# the core's support wrapper (its reset sequence, clocking, the four-lane GT wrapper) from its own generated example design,
# copied into the project as ordinary sources (the generated files belong to the IP)
set exd [file join [get_property IP_OUTPUT_DIR [get_ips aurora_qsfp]] aurora_qsfp example_design]
set sup [file join $proj_dir aurora_support]
file mkdir $sup
foreach f [concat [glob [file join $exd support *.v]] [glob [file join $exd gt *.v]]] { file copy -force $f $sup }
add_files -norecurse -fileset sources_1 [glob [file join $sup *.v]]

set_property top fpga [get_filesets sources_1]

# ---------------------------------------------------------------- constraints
add_files -norecurse -fileset constrs_1 [file join $repo_dir constraints fpga.xdc]
set_property target_constrs_file [file join $repo_dir constraints fpga.xdc] [get_filesets constrs_1]

# ---------------------------------------------------------------- runs
# the traffic and checker run at the 402.83 MHz user clock: the timing-driven implementation strategy
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]

update_compile_order -fileset sources_1
puts "Project created: [file join $proj_dir $proj_name.xpr]"
