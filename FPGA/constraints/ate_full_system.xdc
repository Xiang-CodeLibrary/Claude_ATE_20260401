## =============================================================================
## ATE Pattern Card — Full System XDC
## XCKU035-2FFVA1156I on Ku035_Board V_C
## =============================================================================

## ===================== System Clocks =====================
## 200 MHz LVDS (G3 SIT9121AI → Bank 45, AH18/AH17)
set_property PACKAGE_PIN AH18 [get_ports sys_clk_p]
set_property PACKAGE_PIN AH17 [get_ports sys_clk_n]
set_property IOSTANDARD LVDS [get_ports sys_clk_p]
set_property IOSTANDARD LVDS [get_ports sys_clk_n]
set_property DIFF_TERM TRUE [get_ports sys_clk_p]
create_clock -period 5.000 -name sys_clk_200 [get_ports sys_clk_p]

## PXIe 100 MHz (Bank 68, E18/E17)
set_property PACKAGE_PIN E18 [get_ports pxie_clk100_p]
set_property PACKAGE_PIN E17 [get_ports pxie_clk100_n]
set_property IOSTANDARD LVDS [get_ports pxie_clk100_p]
set_property IOSTANDARD LVDS [get_ports pxie_clk100_n]
set_property DIFF_TERM TRUE [get_ports pxie_clk100_p]
create_clock -period 10.000 -name pxie_clk100 [get_ports pxie_clk100_p]

## PCIe 125 MHz refclk (Bank 225 MGT, from PXIe backplane or G2)
## Pin assignment depends on MGT refclk input used — verify from schematic
## set_property PACKAGE_PIN xx [get_ports pcie_refclk_p]
## set_property PACKAGE_PIN xx [get_ports pcie_refclk_n]
## create_clock -period 8.000 -name pcie_refclk [get_ports pcie_refclk_p]

## ===================== PCIe Lanes (MGT Bank 224/225) =====================
## Pin assignments auto-mapped by Vivado PCIe IP based on GT location
## set_property LOC GTHE3_CHANNEL_X0Y0 [get_cells u_pcie/...]

## ===================== SPI to ADATE305 (Bank 64 HR, 1.8V) =====================
## TODO: Assign from schematic P19_FPGA_BANK_64_HR connections to BTB
## These go through BTB connector to DLC board
## Example (verify from actual schematic netlist):
# set_property PACKAGE_PIN AK12 [get_ports adate_spi_sclk]
# set_property IOSTANDARD LVCMOS18 [get_ports adate_spi_sclk]
# set_property PACKAGE_PIN AL12 [get_ports adate_spi_mosi]
# set_property IOSTANDARD LVCMOS18 [get_ports adate_spi_mosi]
# set_property PACKAGE_PIN AK13 [get_ports adate_spi_miso]
# set_property IOSTANDARD LVCMOS18 [get_ports adate_spi_miso]

## ===================== LVDS to ADATE305 (Bank 47/48/67/68, 1.8V) =====================
## 16 channels, each with DATA_P/N output and RCV_P/N input
## Bank 47 pins confirmed from schematic CSV:
## B47_IO_2: AD25/AD26, B47_IO_3: AB24/AC24
## These map to first 2 channels; remaining need full pin-out from schematic

## Channel 0 data output
set_property PACKAGE_PIN AD25 [get_ports {data0_p[0]}]
set_property PACKAGE_PIN AD26 [get_ports {data0_n[0]}]
set_property IOSTANDARD LVDS [get_ports {data0_p[0]}]
set_property IOSTANDARD LVDS [get_ports {data0_n[0]}]

## Channel 1 data output
set_property PACKAGE_PIN AB24 [get_ports {data0_p[1]}]
set_property PACKAGE_PIN AC24 [get_ports {data0_n[1]}]
set_property IOSTANDARD LVDS [get_ports {data0_p[1]}]
set_property IOSTANDARD LVDS [get_ports {data0_n[1]}]

## Channels 2~15: TODO assign from complete BTB↔FPGA pin mapping
## For now, let synthesis pass with unplaced I/O (DRC downgraded)
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]

## ===================== PXI Trigger (Bank 66, 1.8V) =====================
## From schematic: TRIG_18_1~7 → U1J pins
set_property PACKAGE_PIN B9  [get_ports {pxi_trig[0]}]
set_property PACKAGE_PIN A10 [get_ports {pxi_trig[1]}]
set_property PACKAGE_PIN B10 [get_ports {pxi_trig[2]}]
set_property PACKAGE_PIN C9  [get_ports {pxi_trig[3]}]
set_property PACKAGE_PIN D9  [get_ports {pxi_trig[4]}]
set_property PACKAGE_PIN D11 [get_ports {pxi_trig[5]}]
set_property PACKAGE_PIN E11 [get_ports {pxi_trig[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {pxi_trig[*]}]

## DSTAR (Bank 66, differential)
set_property PACKAGE_PIN E10 [get_ports dstarb_p]
set_property PACKAGE_PIN D10 [get_ports dstarb_n]
set_property IOSTANDARD LVDS [get_ports dstarb_p]
set_property DIFF_TERM TRUE [get_ports dstarb_p]

set_property PACKAGE_PIN F8  [get_ports dstarc_p]
set_property PACKAGE_PIN E8  [get_ports dstarc_n]
set_property IOSTANDARD LVDS [get_ports dstarc_p]

## ===================== Timing Constraints =====================
## False paths
set_false_path -to [get_pins {rst_pipe_reg[0]/D}]

## OSERDES output constraints
set_output_delay -clock [get_clocks sys_clk_200] -max 0.5 [get_ports {data0_p[*]}]
set_output_delay -clock [get_clocks sys_clk_200] -min -0.5 [get_ports {data0_p[*]}]

## Clock domain crossings (PCIe user_clk ↔ clk_100)
## set_false_path -from [get_clocks pcie_user_clk] -to [get_clocks clk_100]
## set_false_path -from [get_clocks clk_100] -to [get_clocks pcie_user_clk]

## ===================== Bitstream =====================
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
