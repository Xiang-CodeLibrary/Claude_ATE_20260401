## Build ATE Pattern Card with XDMA PCIe IP
## Usage: vivado -mode batch -source build_pcie.tcl
## Adds -verilog_define USE_XDMA_IP to enable PCIe path

set project_name "ate_pcie"
set project_dir  [file join [pwd] "${project_name}_project"]
set part         "xcku035-ffva1156-2-i"
set top_module   "ate_top"
set src_dir      [file normalize "../src"]
set constr_dir   [file normalize "../constraints"]

## Create project
create_project $project_name $project_dir -part $part -force

## Add sources (exclude timing_test_top)
set sv_files [glob -type f \
    $src_dir/top/ate_pkg.sv \
    $src_dir/top/ate_top.sv \
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
set sv_files [lsearch -all -inline -not $sv_files "*timing_test_top*"]

foreach f $sv_files {
    add_files -fileset sources_1 $f
}

add_files -fileset constrs_1 $constr_dir/ate_full_system.xdc
set_property top $top_module [current_fileset]

## Set USE_XDMA_IP define for PCIe mode
set_property verilog_define {USE_XDMA_IP} [current_fileset]

## Generate XDMA IP
source [file normalize "generate_pcie_ip.tcl"]

## Also generate supporting IPs (VIO, ILA)
set ip_dir [file join $project_dir "ip"]

if {[llength [get_ips ila_main -quiet]] == 0} {
    create_ip -name ila -vendor xilinx.com -library ip -version 6.2 \
        -module_name ila_main -dir $ip_dir
    set_property -dict [list \
        CONFIG.C_NUM_OF_PROBES {4} CONFIG.C_DATA_DEPTH {4096} \
        CONFIG.C_PROBE0_WIDTH {32} CONFIG.C_PROBE1_WIDTH {16} \
        CONFIG.C_PROBE2_WIDTH {16} CONFIG.C_PROBE3_WIDTH {8} \
    ] [get_ips ila_main]
    generate_target all [get_ips ila_main]
}

update_compile_order -fileset sources_1

## Synthesis
puts ">>> Synthesis (with USE_XDMA_IP)..."
launch_runs synth_1 -jobs 8
wait_on_run synth_1

set status [get_property STATUS [get_runs synth_1]]
puts "Synthesis: $status"

if {[string match "*ERROR*" $status] || [string match "*FAILED*" $status]} {
    puts "Synthesis failed. Check logs."
    exit 1
}

open_run synth_1
report_timing_summary -file $project_dir/synth_timing.rpt
report_utilization -file $project_dir/synth_util.rpt

## Implementation
puts ">>> Implementation..."
launch_runs impl_1 -jobs 8
wait_on_run impl_1

set status [get_property STATUS [get_runs impl_1]]
puts "Implementation: $status"

open_run impl_1
report_timing_summary -file $project_dir/impl_timing.rpt
report_utilization -file $project_dir/impl_util.rpt

## Bitstream
set_property STEPS.WRITE_BITSTREAM.TCL.PRE [file normalize "pre_bitstream.tcl"] [get_runs impl_1]
set fh [open [file join [pwd] "pre_bitstream.tcl"] w]
puts $fh {set_property SEVERITY {Warning} [get_drc_checks NSTD-1]}
puts $fh {set_property SEVERITY {Warning} [get_drc_checks UCIO-1]}
close $fh

puts ">>> Bitstream..."
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

set bit_file [glob -nocomplain $project_dir/${project_name}.runs/impl_1/${top_module}.bit]
if {$bit_file ne ""} {
    file copy -force $bit_file [file join [pwd] "ate_top_pcie.bit"]
    puts "==========================================="
    puts "SUCCESS: ate_top_pcie.bit"
    puts "==========================================="
} else {
    puts "ERROR: Bitstream failed"
    exit 1
}
