## Run all testbenches via Vivado xsim
## Usage: vivado -mode batch -source run_all_sim.tcl

set sim_dir [file normalize [file dirname [info script]]]
set src_dir [file normalize "$sim_dir/../src"]
set pass_count 0
set fail_count 0
set results {}

proc run_tb {tb_name src_files} {
    upvar sim_dir sim_dir
    upvar pass_count pass_count
    upvar fail_count fail_count
    upvar results results

    puts "============================================================"
    puts "Running: $tb_name"
    puts "============================================================"

    set work_dir [file join $sim_dir "work_${tb_name}"]
    file mkdir $work_dir
    cd $work_dir

    # Compile
    set cmd "xvlog -sv -work work"
    foreach f $src_files {
        append cmd " $f"
    }
    set rc [catch {exec {*}[split $cmd] 2>@1} output]
    if {$rc && [string match "*ERROR*" $output]} {
        puts "COMPILE ERROR:\n$output"
        incr fail_count
        lappend results "$tb_name: COMPILE FAIL"
        return
    }

    # Elaborate
    set rc [catch {exec xelab -debug typical -top $tb_name -snapshot ${tb_name}_snap 2>@1} output]
    if {$rc && [string match "*ERROR*" $output]} {
        puts "ELABORATE ERROR:\n$output"
        incr fail_count
        lappend results "$tb_name: ELABORATE FAIL"
        return
    }

    # Simulate
    set rc [catch {exec xsim ${tb_name}_snap -runall -onerror quit 2>@1} output]
    puts $output

    if {[string match "*ALL TESTS PASSED*" $output]} {
        incr pass_count
        lappend results "$tb_name: PASS"
    } else {
        incr fail_count
        lappend results "$tb_name: FAIL"
    }
}

## TB1: SPI Master
run_tb "tb_spi_master" [list \
    "$src_dir/top/ate_pkg.sv" \
    "$src_dir/spi_master/spi_master.sv" \
    "$sim_dir/tb_spi_master.sv" \
]

## TB2: Sequencer
run_tb "tb_sequencer" [list \
    "$src_dir/top/ate_pkg.sv" \
    "$src_dir/pattern_engine/sequencer.sv" \
    "$sim_dir/tb_sequencer.sv" \
]

## TB3: AXI-Lite Register Map
run_tb "tb_reg_map" [list \
    "$src_dir/top/ate_pkg.sv" \
    "$src_dir/pcie/axi_lite_slave.sv" \
    "$sim_dir/tb_reg_map.sv" \
]

## TB4: Drive Format
run_tb "tb_drive_format" [list \
    "$src_dir/top/ate_pkg.sv" \
    "$src_dir/channel_ctrl/drive_format.sv" \
    "$sim_dir/tb_drive_format.sv" \
]

## TB5: ADC Controller
run_tb "tb_adc_ctrl" [list \
    "$src_dir/top/ate_pkg.sv" \
    "$src_dir/adc_ctrl/adc_ctrl.sv" \
    "$sim_dir/tb_adc_ctrl.sv" \
]

## TB6: Source/Capture
run_tb "tb_source_capture" [list \
    "$src_dir/top/ate_pkg.sv" \
    "$src_dir/pattern_engine/source_capture.sv" \
    "$sim_dir/tb_source_capture.sv" \
]

## TB7: SPI Level Update
run_tb "tb_spi_level_update" [list \
    "$src_dir/top/ate_pkg.sv" \
    "$src_dir/spi_master/spi_level_update.sv" \
    "$sim_dir/tb_spi_level_update.sv" \
]

## TB8: Vector Prefetch
run_tb "tb_vector_prefetch" [list \
    "$src_dir/top/ate_pkg.sv" \
    "$src_dir/pattern_engine/vector_prefetch.sv" \
    "$sim_dir/tb_vector_prefetch.sv" \
]

## TB9: Trigger Interface
run_tb "tb_trigger_intf" [list \
    "$src_dir/top/ate_pkg.sv" \
    "$src_dir/trigger/trigger_intf.sv" \
    "$sim_dir/tb_trigger_intf.sv" \
]

## TB10: Calibration Controller
run_tb "tb_cal_controller" [list \
    "$src_dir/top/ate_pkg.sv" \
    "$src_dir/calibration/cal_controller.sv" \
    "$sim_dir/tb_cal_controller.sv" \
]

## Summary
puts ""
puts "============================================================"
puts "SIMULATION SUMMARY"
puts "============================================================"
foreach r $results {
    puts "  $r"
}
puts "------------------------------------------------------------"
puts "  PASS: $pass_count  FAIL: $fail_count"
puts "============================================================"

if {$fail_count > 0} {
    exit 1
}
