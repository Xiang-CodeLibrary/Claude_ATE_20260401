## Generate XDMA PCIe IP for ATE Pattern Card
## Must be sourced inside an open Vivado project
## Target: PCIe Gen2 x4, AXI4-Lite master for register access

set ip_dir [file join [get_property DIRECTORY [current_project]] "ip"]
file mkdir $ip_dir

## Check if IP already exists
if {[llength [get_ips xdma_0 -quiet]] > 0} {
    puts "xdma_0 already exists, skipping creation"
} else {
    create_ip -name xdma -vendor xilinx.com -library ip \
        -module_name xdma_0 -dir $ip_dir

    set_property -dict [list \
        CONFIG.mode_selection              {Basic} \
        CONFIG.pcie_blk_locn              {X0Y0} \
        CONFIG.pl_link_cap_max_link_width {X4} \
        CONFIG.pl_link_cap_max_link_speed {5.0_GT/s} \
        CONFIG.ref_clk_freq               {100_MHz} \
        CONFIG.axi_data_width             {64_bit} \
        CONFIG.dma_reset_source_sel       {Phy_Ready} \
        CONFIG.axilite_master_en          {true} \
        CONFIG.axilite_master_size        {64} \
        CONFIG.axilite_master_scale       {KILOBYTES} \
        CONFIG.axist_bypass_en            {false} \
        CONFIG.xdma_num_usr_irq           {4} \
        CONFIG.pf0_device_id              {6571} \
        CONFIG.pf0_subsystem_vendor_id    {A7E0} \
        CONFIG.pf0_subsystem_id           {0001} \
        CONFIG.pf0_class_code_base        {11} \
        CONFIG.pf0_class_code_sub         {80} \
        CONFIG.pf0_class_code_interface   {00} \
        CONFIG.pf0_bar0_enabled           {true} \
        CONFIG.pf0_bar0_type_mqdma        {AXI_Lite_Master} \
        CONFIG.pf0_bar0_size              {128} \
        CONFIG.pf0_bar0_scale             {Kilobytes} \
        CONFIG.PF0_DEVICE_ID_mqdma        {6571} \
        CONFIG.cfg_mgmt_if                {false} \
        CONFIG.pciebar2axibar_axil_master {0x00000000} \
        CONFIG.en_gt_selection            {true} \
        CONFIG.select_quad                {GTH_Quad_224} \
        CONFIG.INS_LOSS_NYQ               {5} \
        CONFIG.type1_membase_memlimit_enable {Disabled} \
        CONFIG.type1_prefetchable_membase_memlimit {Disabled} \
    ] [get_ips xdma_0]

    generate_target all [get_ips xdma_0]
    puts "xdma_0 IP generated successfully"
}
