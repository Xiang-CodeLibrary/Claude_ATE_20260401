## =============================================================================
## Timing Engine Hardware Verification — XDC Constraints
## Target: XCKU035-2FFVA1156I on Ku035_Board V_C
## =============================================================================

## =============================================================================
## System Clock — 200 MHz LVDS (G3 SIT9121AI oscillator)
## TODO: 确认G3输出连接到FPGA的具体引脚 (从原理图P07_CLK页)
##       G3.CLKP → 应连接到Bank 45/46的MRCC/SRCC引脚
##       需要查看原理图确认, 以下为占位
## =============================================================================
set_property PACKAGE_PIN AJ17 [get_ports sys_clk_p]
set_property PACKAGE_PIN AK17 [get_ports sys_clk_n]
set_property IOSTANDARD LVDS [get_ports sys_clk_p]
set_property IOSTANDARD LVDS [get_ports sys_clk_n]
set_property DIFF_TERM TRUE [get_ports sys_clk_p]

create_clock -period 5.000 -name sys_clk_200 [get_ports sys_clk_p]

## =============================================================================
## Test LVDS Outputs — Bank 47 (HP, VCCO=1.8V)
## 使用 B47_IO_2 和 B47_IO_3 (通过BTB连接器到DLC板/测试点)
## 从原理图CSV确认:
##   B47_IO_2_P → U1F.AD25 → BTB J1-1.B15
##   B47_IO_2_N → U1F.AD26 → BTB J1-1.B16
##   B47_IO_3_P → U1F.AB24 → BTB J1-1.A14
##   B47_IO_3_N → U1F.AC24 → BTB J1-1.A15
## =============================================================================
set_property PACKAGE_PIN AD25 [get_ports test_ch0_p]
set_property PACKAGE_PIN AD26 [get_ports test_ch0_n]
set_property IOSTANDARD LVDS [get_ports test_ch0_p]
set_property IOSTANDARD LVDS [get_ports test_ch0_n]

set_property PACKAGE_PIN AB24 [get_ports test_ch1_p]
set_property PACKAGE_PIN AC24 [get_ports test_ch1_n]
set_property IOSTANDARD LVDS [get_ports test_ch1_p]
set_property IOSTANDARD LVDS [get_ports test_ch1_n]

## =============================================================================
## Status LEDs
## TODO: 确认LED引脚 (从原理图P29_Other_01页或状态指示部分)
##       以下为占位, 需根据实际板卡修改
## =============================================================================
# set_property PACKAGE_PIN xx [get_ports led_mmcm_locked]
# set_property IOSTANDARD LVCMOS33 [get_ports led_mmcm_locked]
# set_property PACKAGE_PIN xx [get_ports led_idelayctrl_rdy]
# set_property IOSTANDARD LVCMOS33 [get_ports led_idelayctrl_rdy]
# set_property PACKAGE_PIN xx [get_ports led_test_running]
# set_property IOSTANDARD LVCMOS33 [get_ports led_test_running]

## 如果没有确认LED引脚,先注释掉LED端口,改为内部信号
## 在timing_test_top.sv中将LED输出改为(* dont_touch = "true" *)

## =============================================================================
## Timing Constraints
## =============================================================================

## MMCM generated clocks (Vivado自动推导,这里显式声明以便约束)
## 800 MHz IDELAYCTRL reference
create_generated_clock -name clk_800 \
    -source [get_pins u_clocks/u_mmcm_timing/CLKIN1] \
    -multiply_by 4 -divide_by 1 \
    [get_pins u_clocks/u_mmcm_timing/CLKOUT0]

## 400 MHz OSERDES clock
create_generated_clock -name clk_400 \
    -source [get_pins u_clocks/u_mmcm_timing/CLKIN1] \
    -multiply_by 2 -divide_by 1 \
    [get_pins u_clocks/u_mmcm_timing/CLKOUT1]

## 100 MHz parallel clock
create_generated_clock -name clk_100 \
    -source [get_pins u_clocks/u_mmcm_timing/CLKIN1] \
    -multiply_by 1 -divide_by 2 \
    [get_pins u_clocks/u_mmcm_timing/CLKOUT2]

## OSERDES output constraints
## 800 Mbps DDR → 1.25 ns bit period
set_output_delay -clock clk_400 -max 0.5 [get_ports test_ch0_p]
set_output_delay -clock clk_400 -min -0.5 [get_ports test_ch0_p]
set_output_delay -clock clk_400 -max 0.5 [get_ports test_ch1_p]
set_output_delay -clock clk_400 -min -0.5 [get_ports test_ch1_p]

## =============================================================================
## False Paths
## =============================================================================
## VIO/ILA debug paths are asynchronous
set_false_path -from [get_pins u_vio/*]
set_false_path -to [get_pins u_vio/*]
set_false_path -to [get_pins u_ila/*]

## Reset synchronizer
set_false_path -to [get_pins {rst_pipe_reg[0]/D}]

## =============================================================================
## Physical Constraints
## =============================================================================
## IDELAYCTRL must be placed in the same clock region as ODELAYE3/IDELAYE3
## Bank 47 → clock region X0Y4 (typical for KU035, verify in Vivado)
# set_property LOC IDELAYCTRL_X0Y4 [get_cells u_clocks/u_idelayctrl]

## Bitstream settings
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
