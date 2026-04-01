## Generate MIG DDR3 IP for ATE Pattern Card
## Target: 64-bit DDR3 on Bank 44/45/46
## Must be sourced inside an open Vivado project

set ip_dir [file join [get_property DIRECTORY [current_project]] "ip"]
file mkdir $ip_dir

if {[llength [get_ips mig_ddr3 -quiet]] > 0} {
    puts "mig_ddr3 already exists, skipping"
    return
}

create_ip -name mig -vendor xilinx.com -library ip \
    -module_name mig_ddr3 -dir $ip_dir

## MIG requires an XML/PRJ configuration file.
## Generate it programmatically then apply.
## For UltraScale MIG, use set_property on the IP directly.

set_property -dict [list \
    CONFIG.MIG_DONT_TOUCH_PARAM          {Custom} \
    CONFIG.BOARD_MIG_PARAM               {Custom} \
    CONFIG.C0.DDR3_TimePeriod            {1250} \
    CONFIG.C0.DDR3_InputClockPeriod      {5000} \
    CONFIG.C0.DDR3_MemoryType            {Components} \
    CONFIG.C0.DDR3_MemoryPart            {MT41K256M16XX-107} \
    CONFIG.C0.DDR3_DataWidth             {64} \
    CONFIG.C0.DDR3_DataMask              {DM_NO_DBI} \
    CONFIG.C0.DDR3_Ordering              {Normal} \
    CONFIG.C0.DDR3_CasLatency            {11} \
    CONFIG.C0.DDR3_CasWriteLatency       {8} \
    CONFIG.C0.DDR3_Slot                  {Single} \
    CONFIG.C0.DDR3_nCK_PER_CLK           {4} \
    CONFIG.C0.DDR3_AxiDataWidth          {128} \
    CONFIG.C0.DDR3_AxiIDWidth            {4} \
    CONFIG.C0.DDR3_AxiAddressWidth       {30} \
    CONFIG.C0.DDR3_AxiSelection          {true} \
    CONFIG.C0.DDR3_isCustom              {true} \
    CONFIG.C0.DDR3_BurstLength           {8} \
    CONFIG.C0.DDR3_BurstType             {Sequential} \
    CONFIG.System_Clock                  {No_Buffer} \
    CONFIG.Reference_Clock               {No_Buffer} \
    CONFIG.C0.DDR3_Mem_Add_Map           {BANK_ROW_COLUMN} \
] [get_ips mig_ddr3]

generate_target all [get_ips mig_ddr3]
puts "mig_ddr3 IP generated"
