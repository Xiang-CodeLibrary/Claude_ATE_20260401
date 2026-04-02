## Generate DDR3 IP for ATE Pattern Card
## UltraScale DDR3 SDRAM IP (xilinx.com:ip:ddr3)

set ip_dir [file join [get_property DIRECTORY [current_project]] "ip"]
file mkdir $ip_dir

if {[llength [get_ips mig_ddr3 -quiet]] > 0} {
    puts "mig_ddr3 already exists, skipping"
    return
}

create_ip -name ddr3 -vendor xilinx.com -library ip \
    -module_name mig_ddr3 -dir $ip_dir

## Step 1: Set timing first (must be compatible with part speed grade)
## MT41K256M16HA-107: min tCK=1.07ns → TimePeriod >= 1071 ps
set_property CONFIG.C0.DDR3_TimePeriod {1071} [get_ips mig_ddr3]
set_property CONFIG.C0.DDR3_InputClockPeriod {4999} [get_ips mig_ddr3]

## Step 2: Set memory part (now compatible with timing)
set_property CONFIG.C0.DDR3_MemoryPart {MT41K256M16HA-107} [get_ips mig_ddr3]

## Step 3: Set remaining params
set_property -dict [list \
    CONFIG.C0.DDR3_MemoryType            {Components} \
    CONFIG.C0.DDR3_DataWidth             {64} \
    CONFIG.C0.DDR3_DataMask              {true} \
    CONFIG.C0.DDR3_Ordering              {Normal} \
    CONFIG.C0.DDR3_Slot                  {Single} \
    CONFIG.C0.DDR3_AxiSelection          {true} \
    CONFIG.C0.DDR3_AxiDataWidth          {128} \
    CONFIG.C0.DDR3_AxiIDWidth            {4} \
    CONFIG.C0.DDR3_isCustom              {true} \
    CONFIG.C0.DDR3_BurstLength           {8} \
    CONFIG.C0.DDR3_BurstType             {Sequential} \
    CONFIG.C0.DDR3_Mem_Add_Map           {BANK_ROW_COLUMN} \
    CONFIG.System_Clock                  {No_Buffer} \
    CONFIG.Reference_Clock               {No_Buffer} \
] [get_ips mig_ddr3]

generate_target all [get_ips mig_ddr3]
puts "mig_ddr3 IP generated"
