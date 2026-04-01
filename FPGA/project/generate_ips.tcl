## Generate Xilinx IPs for ATE Pattern Card
## Run inside an open Vivado project context
## Usage: source generate_ips.tcl

set ip_dir [file join [get_property DIRECTORY [current_project]] "ip"]
file mkdir $ip_dir

## ================================================================
## XDMA — PCIe Gen2 x4 with AXI4-Lite master
## ================================================================
## Note: For initial bring-up, JTAG-AXI can replace this.
## Uncomment and configure when PCIe testing is ready.

# create_ip -name xdma -vendor xilinx.com -library ip -version 4.1 \
#     -module_name xdma_0 -dir $ip_dir
# set_property -dict [list \
#     CONFIG.mode_selection           {Basic} \
#     CONFIG.pcie_blk_locn            {PCIE4C_X0Y0} \
#     CONFIG.pl_link_cap_max_link_width {X4} \
#     CONFIG.pl_link_cap_max_link_speed {5.0_GT/s} \
#     CONFIG.axi_data_width           {128_bit} \
#     CONFIG.axilite_master_en        {true} \
#     CONFIG.axilite_master_size      {64} \
#     CONFIG.pf0_device_id            {6571} \
#     CONFIG.pf0_subsystem_id         {0001} \
#     CONFIG.pf0_bar0_size            {64} \
#     CONFIG.pf0_bar0_type_mqdma      {AXI_Lite} \
#     CONFIG.cfg_mgmt_if              {false} \
#     CONFIG.pciebar2axibar_0         {0x00000000} \
#     CONFIG.vendor_id                {ATE0} \
# ] [get_ips xdma_0]
# generate_target all [get_ips xdma_0]

## ================================================================
## JTAG-AXI — For register access without PCIe (bring-up / debug)
## ================================================================
create_ip -name jtag_axi -vendor xilinx.com -library ip -version 1.2 \
    -module_name jtag_axi_0 -dir $ip_dir

set_property -dict [list \
    CONFIG.M_AXI_DATA_WIDTH {32} \
    CONFIG.M_AXI_ADDR_WIDTH {32} \
] [get_ips jtag_axi_0]

generate_target all [get_ips jtag_axi_0]

## ================================================================
## VIO — For runtime control (test modes, manual delay setting)
## ================================================================
create_ip -name vio -vendor xilinx.com -library ip -version 3.0 \
    -module_name vio_ctrl -dir $ip_dir

set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN   {4}  \
    CONFIG.C_NUM_PROBE_OUT  {4}  \
    CONFIG.C_PROBE_IN0_WIDTH  {32} \
    CONFIG.C_PROBE_IN1_WIDTH  {16} \
    CONFIG.C_PROBE_IN2_WIDTH  {16} \
    CONFIG.C_PROBE_IN3_WIDTH  {8}  \
    CONFIG.C_PROBE_OUT0_WIDTH {32} \
    CONFIG.C_PROBE_OUT1_WIDTH {16} \
    CONFIG.C_PROBE_OUT2_WIDTH {9}  \
    CONFIG.C_PROBE_OUT3_WIDTH {4}  \
] [get_ips vio_ctrl]

generate_target all [get_ips vio_ctrl]

## ================================================================
## ILA — For internal signal capture
## ================================================================
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 \
    -module_name ila_main -dir $ip_dir

set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES  {8}    \
    CONFIG.C_DATA_DEPTH     {4096} \
    CONFIG.C_PROBE0_WIDTH   {32}   \
    CONFIG.C_PROBE1_WIDTH   {16}   \
    CONFIG.C_PROBE2_WIDTH   {16}   \
    CONFIG.C_PROBE3_WIDTH   {8}    \
    CONFIG.C_PROBE4_WIDTH   {8}    \
    CONFIG.C_PROBE5_WIDTH   {32}   \
    CONFIG.C_PROBE6_WIDTH   {9}    \
    CONFIG.C_PROBE7_WIDTH   {5}    \
] [get_ips ila_main]

generate_target all [get_ips ila_main]

puts "IP generation complete."
