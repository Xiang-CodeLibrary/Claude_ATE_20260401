## Build ATE Pattern Card — Full system with XDMA + MIG
## Usage: vivado -mode batch -source build_full_with_ip.tcl
## Defines: USE_XDMA_IP, USE_MIG_IP

set project_name "ate_full_ip"
set project_dir  [file join [pwd] "${project_name}_project"]
set part         "xcku035-ffva1156-2-i"
set top_module   "ate_top"
set src_dir      [file normalize "../src"]
set constr_dir   [file normalize "../constraints"]

create_project $project_name $project_dir -part $part -force

## Add sources
set sv_files [glob -type f \
    $src_dir/top/ate_pkg.sv $src_dir/top/ate_top.sv \
    $src_dir/pcie/*.sv $src_dir/pattern_engine/*.sv \
    $src_dir/timing_engine/*.sv $src_dir/spi_master/*.sv \
    $src_dir/channel_ctrl/*.sv $src_dir/adc_ctrl/*.sv \
    $src_dir/ddr3_ctrl/*.sv $src_dir/calibration/*.sv \
    $src_dir/trigger/*.sv \
]
set sv_files [lsearch -all -inline -not $sv_files "*timing_test_top*"]
foreach f $sv_files { add_files -fileset sources_1 $f }

## Constraints
add_files -fileset constrs_1 $constr_dir/ate_full_system.xdc
add_files -fileset constrs_1 $constr_dir/ddr3_pins.xdc

set_property top $top_module [current_fileset]

## Enable both IPs
set_property verilog_define {USE_XDMA_IP USE_MIG_IP} [current_fileset]

## Generate XDMA IP
source [file normalize "generate_pcie_ip.tcl"]

## Generate MIG IP
source [file normalize "generate_ddr3_ip.tcl"]

update_compile_order -fileset sources_1

## Synthesis
puts ">>> Synthesis..."
launch_runs synth_1 -jobs 8
wait_on_run synth_1
set status [get_property STATUS [get_runs synth_1]]
puts "Synthesis: $status"

if {[string match "*FAILED*" $status]} {
    puts "ERROR: Synthesis failed"
    exit 1
}

open_run synth_1
report_utilization -file $project_dir/synth_util.rpt
report_timing_summary -file $project_dir/synth_timing.rpt

## Implementation
puts ">>> Implementation..."
launch_runs impl_1 -jobs 8
wait_on_run impl_1
set status [get_property STATUS [get_runs impl_1]]
puts "Implementation: $status"

if {[string match "*FAILED*" $status]} {
    open_run impl_1
    report_timing_summary -file $project_dir/impl_timing.rpt
    report_utilization -file $project_dir/impl_util.rpt
    puts "Implementation failed but reports generated"
    exit 1
}

open_run impl_1
report_timing_summary -file $project_dir/impl_timing.rpt
report_utilization -file $project_dir/impl_util.rpt

## Bitstream
set fh [open [file join [pwd] "pre_bitstream.tcl"] w]
puts $fh {set_property SEVERITY {Warning} [get_drc_checks NSTD-1]}
puts $fh {set_property SEVERITY {Warning} [get_drc_checks UCIO-1]}
puts $fh {set_property SEVERITY {Warning} [get_drc_checks IOSTDTYPE-1]}
close $fh
set_property STEPS.WRITE_BITSTREAM.TCL.PRE [file normalize "pre_bitstream.tcl"] [get_runs impl_1]

puts ">>> Bitstream..."
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

set bit_file [glob -nocomplain $project_dir/${project_name}.runs/impl_1/${top_module}.bit]
if {$bit_file ne ""} {
    file copy -force $bit_file [file join [pwd] "ate_top_full.bit"]
    puts "==========================================="
    puts "SUCCESS: ate_top_full.bit"
    puts "==========================================="
} else {
    puts "ERROR: Bitstream failed"
    exit 1
}
