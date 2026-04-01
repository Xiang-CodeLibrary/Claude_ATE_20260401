## Program FPGA via JTAG
set bit_file "D:/ATE_20260401/FPGA/project/timing_test_top.bit"

open_hw_manager
connect_hw_server

set targets [get_hw_targets]
puts "Found targets: $targets"

if {[llength $targets] == 0} {
    puts "ERROR: No JTAG targets found. Check cable connection."
    close_hw_manager
    exit 1
}

open_hw_target [lindex $targets 0]

set devices [get_hw_devices]
puts "Found devices: $devices"

set dev [lindex $devices 0]
current_hw_device $dev

set_property PROGRAM.FILE $bit_file $dev
program_hw_devices $dev

puts "==========================================="
puts "Programming complete!"
puts "==========================================="

close_hw_manager
