create_project tmp_q ./tmp_q -part xcku035-ffva1156-2-i -force
file mkdir ./tmp_q/ip
create_ip -name ddr3 -vendor xilinx.com -library ip -module_name mig_tmp -dir ./tmp_q/ip
set props [list_property [get_ips mig_tmp]]
foreach p $props {
    if {[string match "CONFIG.*" $p]} {
        set val [get_property $p [get_ips mig_tmp]]
        puts "  $p = $val"
    }
}
close_project
file delete -force ./tmp_q
