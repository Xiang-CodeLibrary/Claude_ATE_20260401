## =============================================================================
## Timing Engine HW Verification — XDC Constraints
## XCKU035-2FFVA1156I on Ku035_Board V_C
## =============================================================================

## System Clock 200 MHz LVDS (G3 SIT9121AI → Bank 45)
## Confirmed from schematic: SYS_CLK_P → U1D.AH18, SYS_CLK_N → U1D.AH17
set_property PACKAGE_PIN AH18 [get_ports sys_clk_p]
set_property PACKAGE_PIN AH17 [get_ports sys_clk_n]
set_property IOSTANDARD LVDS [get_ports sys_clk_p]
set_property IOSTANDARD LVDS [get_ports sys_clk_n]
set_property DIFF_TERM TRUE [get_ports sys_clk_p]

create_clock -period 5.000 -name sys_clk_200 [get_ports sys_clk_p]

## Test LVDS Outputs — Bank 47 (HP, VCCO=1.8V)
## B47_IO_2: U1F.AD25/AD26 → BTB J1-1 B15/B16
## B47_IO_3: U1F.AB24/AC24 → BTB J1-1 A14/A15
set_property PACKAGE_PIN AD25 [get_ports test_ch0_p]
set_property PACKAGE_PIN AD26 [get_ports test_ch0_n]
set_property IOSTANDARD LVDS [get_ports test_ch0_p]
set_property IOSTANDARD LVDS [get_ports test_ch0_n]

set_property PACKAGE_PIN AB24 [get_ports test_ch1_p]
set_property PACKAGE_PIN AC24 [get_ports test_ch1_n]
set_property IOSTANDARD LVDS [get_ports test_ch1_p]
set_property IOSTANDARD LVDS [get_ports test_ch1_n]

## OSERDES output delay
set_output_delay -clock [get_clocks sys_clk_200] -max 0.5 [get_ports test_ch0_p]
set_output_delay -clock [get_clocks sys_clk_200] -min -0.5 [get_ports test_ch0_p]
set_output_delay -clock [get_clocks sys_clk_200] -max 0.5 [get_ports test_ch1_p]
set_output_delay -clock [get_clocks sys_clk_200] -min -0.5 [get_ports test_ch1_p]

## Reset synchronizer false path
set_false_path -to [get_pins {rst_pipe_reg[0]/D}]

## Bitstream
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
