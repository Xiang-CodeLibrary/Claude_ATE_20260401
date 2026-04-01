## Full System Build Script — ATE Pattern Card
## Usage: C:/Xilinx/2025.2/Vivado/bin/vivado.bat -mode batch -source build_full_system.tcl

set project_name "ate_pattern_card"
set project_dir  [file join [pwd] "${project_name}_project"]
set part         "xcku035-ffva1156-2-i"
set top_module   "ate_top"
set src_dir      [file normalize "../src"]
set constr_dir   [file normalize "../constraints"]

## Create project
create_project $project_name $project_dir -part $part -force

## Add all RTL sources
set sv_files [glob -type f \
    $src_dir/top/*.sv \
    $src_dir/pcie/*.sv \
    $src_dir/pattern_engine/*.sv \
    $src_dir/timing_engine/*.sv \
    $src_dir/spi_master/*.sv \
    $src_dir/channel_ctrl/*.sv \
    $src_dir/adc_ctrl/*.sv \
    $src_dir/ddr3_ctrl/*.sv \
    $src_dir/calibration/*.sv \
    $src_dir/trigger/*.sv \
]

# Exclude test top from full build
set sv_files [lsearch -all -inline -not $sv_files "*timing_test_top*"]

foreach f $sv_files {
    add_files -fileset sources_1 $f
    puts "Added: $f"
}

## Add constraints (create minimal one if full system XDC doesn't exist)
if {[file exists $constr_dir/ate_full_system.xdc]} {
    add_files -fileset constrs_1 $constr_dir/ate_full_system.xdc
} else {
    # Use timing test constraints as starting point
    add_files -fileset constrs_1 $constr_dir/timing_test.xdc
}

set_property top $top_module [current_fileset]
update_compile_order -fileset sources_1

## Generate IPs
source [file normalize "generate_ips.tcl"]

## Synthesis (OOC for IPs + top)
puts ">>> Starting synthesis..."
launch_runs synth_1 -jobs 8
wait_on_run synth_1

set status [get_property STATUS [get_runs synth_1]]
puts "Synthesis: $status"

open_run synth_1
report_timing_summary -file $project_dir/synth_timing.rpt
report_utilization -file $project_dir/synth_util.rpt

## Implementation
puts ">>> Starting implementation..."
launch_runs impl_1 -jobs 8
wait_on_run impl_1

set status [get_property STATUS [get_runs impl_1]]
puts "Implementation: $status"

open_run impl_1
report_timing_summary -file $project_dir/impl_timing.rpt
report_utilization    -file $project_dir/impl_util.rpt
report_clock_utilization -file $project_dir/impl_clocks.rpt
report_drc -file $project_dir/impl_drc.rpt

## Bitstream — downgrade unconstrained I/O DRC for partial pin assignment
set_property STEPS.WRITE_BITSTREAM.TCL.PRE [file normalize "pre_bitstream.tcl"] [get_runs impl_1]

# Create pre-bitstream hook
set fh [open [file join [pwd] "pre_bitstream.tcl"] w]
puts $fh {set_property SEVERITY {Warning} [get_drc_checks NSTD-1]}
puts $fh {set_property SEVERITY {Warning} [get_drc_checks UCIO-1]}
close $fh

puts ">>> Generating bitstream..."
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

set bit_file [glob -nocomplain $project_dir/${project_name}.runs/impl_1/${top_module}.bit]
if {$bit_file ne ""} {
    file copy -force $bit_file [file join [pwd] "${top_module}.bit"]
    puts "==========================================="
    puts "SUCCESS: ${top_module}.bit"
    puts "==========================================="
} else {
    puts "ERROR: Bitstream generation failed"
    exit 1
}
