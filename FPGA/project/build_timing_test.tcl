## Vivado Build Script — Timing Engine HW Verification (no VIO/ILA)
## Usage: C:/Xilinx/2025.2/Vivado/bin/vivado.bat -mode batch -source build_timing_test.tcl

set project_name "timing_test"
set project_dir  [file join [pwd] "timing_test_project"]
set part         "xcku035-ffva1156-2-i"
set top_module   "timing_test_top"
set src_dir      [file normalize "../src"]
set constr_dir   [file normalize "../constraints"]

## Create project
create_project $project_name $project_dir -part $part -force

## Add sources
add_files -fileset sources_1 [list \
    $src_dir/top/ate_pkg.sv \
    $src_dir/timing_engine/timing_clocks.sv \
    $src_dir/timing_engine/channel_serdes.sv \
    $src_dir/top/timing_test_top.sv \
]
add_files -fileset constrs_1 $constr_dir/timing_test.xdc

set_property top $top_module [current_fileset]
update_compile_order -fileset sources_1

## Synthesis
puts ">>> Starting synthesis..."
launch_runs synth_1 -jobs 8
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis status: $synth_status"

if {[string match "*ERROR*" $synth_status] || [string match "*FAILED*" $synth_status]} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

open_run synth_1
report_timing_summary -file $project_dir/synth_timing.rpt
report_utilization -file $project_dir/synth_util.rpt
puts ">>> Synthesis done. Reports in $project_dir/"

## Implementation
puts ">>> Starting implementation..."
launch_runs impl_1 -jobs 8
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "Implementation status: $impl_status"

if {[string match "*ERROR*" $impl_status] || [string match "*FAILED*" $impl_status]} {
    puts "ERROR: Implementation failed!"
    open_run impl_1 -name impl_1
    report_timing_summary -file $project_dir/impl_timing.rpt
    exit 1
}

open_run impl_1
report_timing_summary -file $project_dir/impl_timing.rpt
report_utilization -file $project_dir/impl_util.rpt
report_clock_utilization -file $project_dir/impl_clocks.rpt
puts ">>> Implementation done."

## Bitstream
puts ">>> Generating bitstream..."
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

set bit_file [glob -nocomplain $project_dir/${project_name}.runs/impl_1/${top_module}.bit]
if {$bit_file ne ""} {
    puts "==========================================="
    puts "SUCCESS! Bitstream: $bit_file"
    puts "==========================================="
} else {
    puts "ERROR: Bitstream not found!"
    exit 1
}
