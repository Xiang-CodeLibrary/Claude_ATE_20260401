open_checkpoint D:/ATE_20260401/FPGA/project/ate_full_ip_project/ate_full_ip.runs/impl_1/ate_top_routed.dcp
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]
set_property SEVERITY {Warning} [get_drc_checks IOSTDTYPE-1]
write_bitstream -force D:/ATE_20260401/FPGA/project/ate_top_full.bit
puts "=== DONE ==="
