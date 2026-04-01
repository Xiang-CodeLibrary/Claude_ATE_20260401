## =============================================================================
## Vivado Build Script — Timing Engine Hardware Verification
## Usage: vivado -mode batch -source build_timing_test.tcl
## =============================================================================

set project_name "timing_test"
set project_dir  "./timing_test_project"
set part         "xcku035-ffva1156-2-i"
set top_module   "timing_test_top"

# Source file paths (relative to this script location)
set src_dir      "../src"
set constr_dir   "../constraints"

## =============================================================================
## Step 1: Create project
## =============================================================================
create_project $project_name $project_dir -part $part -force

## =============================================================================
## Step 2: Add source files
## =============================================================================
# Package
add_files -fileset sources_1 $src_dir/top/ate_pkg.sv

# Timing engine modules
add_files -fileset sources_1 $src_dir/timing_engine/timing_clocks.sv
add_files -fileset sources_1 $src_dir/timing_engine/timing_engine.sv
add_files -fileset sources_1 $src_dir/timing_engine/channel_serdes.sv

# Test top
add_files -fileset sources_1 $src_dir/top/timing_test_top.sv

# Constraints
add_files -fileset constrs_1 $constr_dir/timing_test.xdc

# Set top module
set_property top $top_module [current_fileset]

## =============================================================================
## Step 3: Generate Debug IPs (VIO + ILA)
## =============================================================================
# VIO: 1 input probe (32-bit), 8 output probes
create_ip -name vio -vendor xilinx.com -library ip -version 3.0 \
    -module_name vio_timing_test -dir $project_dir/ip

set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN  {1}  \
    CONFIG.C_NUM_PROBE_OUT {8}  \
    CONFIG.C_PROBE_IN0_WIDTH  {32} \
    CONFIG.C_PROBE_OUT0_WIDTH {4}  \
    CONFIG.C_PROBE_OUT1_WIDTH {8}  \
    CONFIG.C_PROBE_OUT2_WIDTH {9}  \
    CONFIG.C_PROBE_OUT3_WIDTH {1}  \
    CONFIG.C_PROBE_OUT4_WIDTH {32} \
    CONFIG.C_PROBE_OUT5_WIDTH {14} \
    CONFIG.C_PROBE_OUT6_WIDTH {3}  \
    CONFIG.C_PROBE_OUT7_WIDTH {1}  \
    CONFIG.C_PROBE_OUT0_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT7_INIT_VAL {0x0} \
] [get_ips vio_timing_test]

generate_target all [get_ips vio_timing_test]

# ILA: 6 probes
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 \
    -module_name ila_timing_test -dir $project_dir/ip

set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES {6}   \
    CONFIG.C_DATA_DEPTH    {4096} \
    CONFIG.C_PROBE0_WIDTH  {8}   \
    CONFIG.C_PROBE1_WIDTH  {8}   \
    CONFIG.C_PROBE2_WIDTH  {8}   \
    CONFIG.C_PROBE3_WIDTH  {10}  \
    CONFIG.C_PROBE4_WIDTH  {14}  \
    CONFIG.C_PROBE5_WIDTH  {32}  \
] [get_ips ila_timing_test]

generate_target all [get_ips ila_timing_test]

## =============================================================================
## Step 4: Synthesis
## =============================================================================
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# Check synthesis results
if {[get_property STATUS [get_runs synth_1]] != "synth_design Complete!"} {
    puts "ERROR: Synthesis failed!"
    open_run synth_1
    report_timing_summary -file $project_dir/synth_timing.rpt
    report_utilization -file $project_dir/synth_util.rpt
    exit 1
}

open_run synth_1
report_timing_summary -file $project_dir/synth_timing.rpt
report_utilization -file $project_dir/synth_util.rpt
puts "Synthesis complete. Check synth_timing.rpt and synth_util.rpt"

## =============================================================================
## Step 5: Implementation
## =============================================================================
launch_runs impl_1 -jobs 8
wait_on_run impl_1

if {[get_property STATUS [get_runs impl_1]] != "route_design Complete!"} {
    puts "ERROR: Implementation failed!"
    exit 1
}

open_run impl_1
report_timing_summary -file $project_dir/impl_timing.rpt
report_utilization -file $project_dir/impl_util.rpt
report_clock_utilization -file $project_dir/impl_clocks.rpt
puts "Implementation complete."

## =============================================================================
## Step 6: Generate bitstream
## =============================================================================
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

puts "========================================="
puts "Build complete!"
puts "Bitstream: $project_dir/timing_test_project.runs/impl_1/$top_module.bit"
puts "========================================="
