#!/usr/bin/env python
"""Generate complete XDC from netlist cross-reference."""
import csv, re

# Load DLC board netlist
dlc_btb = {}
with open('D:/ATE_20260401/Doc/DLC_Board/Sch/A_PXIE-DCL_16SIT-BOARD.csv', encoding='utf-8') as f:
    for row in csv.DictReader(f):
        name = row['Name'].strip('"')
        parts = row.get('PartPin','').strip('"')
        m = re.search(r'J2([A-J])\.([A-J]\d+)', parts)
        if m:
            dlc_btb[f'J2{m.group(1)}.{m.group(2)}'] = name

# Load Ku035 netlist
ku035_fpga, ku035_btb = {}, {}
with open('D:/ATE_20260401/Doc/Ku035_Board/SCH/PATENTS_M_BOARD_V_C.csv', encoding='utf-8') as f:
    for row in csv.DictReader(f):
        name = row['Name'].strip('"')
        parts = row.get('PartPin','').strip('"')
        fm = re.search(r'U1[A-Z]\.([A-Z]+\d+)', parts)
        bm = re.search(r'J1-(\d+)\.([A-Z]\d+)', parts)
        if fm:
            ku035_fpga[name] = fm.group(1)
        if bm:
            ku035_btb[name] = f'J1-{bm.group(1)}.{bm.group(2)}'

def j1_to_j2(j1):
    m = re.match(r'J1-\\d+\\.([A-J])(\\d+)', j1)
    if not m:
        m = re.match(r'J1-\d+\.([A-J])(\d+)', j1)
    if m:
        return f'J2{m.group(1)}.{m.group(1)}{m.group(2)}'
    return None

# Cross-reference
pin_map = {}
for io_name, fpga_pin in ku035_fpga.items():
    j1 = ku035_btb.get(io_name)
    if not j1:
        continue
    j2 = j1_to_j2(j1)
    if not j2:
        continue
    dlc_sig = dlc_btb.get(j2)
    if dlc_sig:
        pin_map[dlc_sig] = fpga_pin

# OVD signals from Ku035 directly
for io_name, fpga_pin in ku035_fpga.items():
    m = re.match(r'IO_18_OVD_S(\d+)_(\d+)', io_name)
    if m:
        site = int(m.group(1))
        ch = int(m.group(2))
        pin_map[f'S{site}_OVD_{ch-1}'] = fpga_pin

# Build sites dict
sites = {}
for sig, pin in sorted(pin_map.items()):
    m = re.match(r'S(\d+)_(.+)', sig)
    if m:
        site = int(m.group(1))
        sigtype = m.group(2)
        if site not in sites:
            sites[site] = {}
        sites[site][sigtype] = pin

# Generate XDC
L = []
L.append('## =============================================================================')
L.append('## ATE Pattern Card - Complete Pin Assignments (auto-generated)')
L.append('## Site N -> Channel index (N-1): S1=ch0, S2=ch1, ..., S16=ch15')
L.append('## =============================================================================')
L.append('')

# Clocks
L.append('## ===================== System Clocks =====================')
L.append('set_property PACKAGE_PIN AH18 [get_ports sys_clk_p]')
L.append('set_property PACKAGE_PIN AH17 [get_ports sys_clk_n]')
L.append('set_property IOSTANDARD LVDS [get_ports sys_clk_p]')
L.append('set_property IOSTANDARD LVDS [get_ports sys_clk_n]')
L.append('set_property DIFF_TERM TRUE [get_ports sys_clk_p]')
L.append('create_clock -period 5.000 -name sys_clk_200 [get_ports sys_clk_p]')
L.append('')
L.append('set_property PACKAGE_PIN E18 [get_ports pxie_clk100_p]')
L.append('set_property PACKAGE_PIN E17 [get_ports pxie_clk100_n]')
L.append('set_property IOSTANDARD LVDS [get_ports pxie_clk100_p]')
L.append('set_property IOSTANDARD LVDS [get_ports pxie_clk100_n]')
L.append('set_property DIFF_TERM TRUE [get_ports pxie_clk100_p]')
L.append('create_clock -period 10.000 -name pxie_clk100 [get_ports pxie_clk100_p]')
L.append('')

# LVDS groups
sig_groups = [
    ('data0', 'DATA_0', 'output'),
    ('data1', 'DATA_1', 'output'),
    ('rcv0',  'RCV_0',  'input'),
    ('rcv1',  'RCV_1',  'input'),
    ('comp_qh0', 'COMP_QH_0', 'input'),
    ('comp_qh1', 'COMP_QH_1', 'input'),
    ('comp_ql0', 'COMP_QL_0', 'input'),
    ('comp_ql1', 'COMP_QL_1', 'input'),
]

mapped = 0
unmapped = 0

for port_base, sig_base, direction in sig_groups:
    L.append(f'## ===================== {port_base.upper()} ({direction}) =====================')
    for site_num in range(1, 17):
        ch = site_num - 1
        sigs = sites.get(site_num, {})
        pin_p = sigs.get(f'{sig_base}_P')
        pin_n = sigs.get(f'{sig_base}_N')
        if pin_p and pin_n:
            L.append(f'set_property PACKAGE_PIN {pin_p:<6} [get_ports {{{port_base}_p[{ch}]}}]')
            L.append(f'set_property PACKAGE_PIN {pin_n:<6} [get_ports {{{port_base}_n[{ch}]}}]')
            mapped += 2
        else:
            L.append(f'## S{site_num} ({port_base}[{ch}]): not found in netlist')
            unmapped += 2
    L.append(f'set_property IOSTANDARD LVDS [get_ports {{{port_base}_p[*]}}]')
    L.append(f'set_property IOSTANDARD LVDS [get_ports {{{port_base}_n[*]}}]')
    if direction == 'input':
        L.append(f'set_property DIFF_TERM TRUE [get_ports {{{port_base}_p[*]}}]')
    L.append('')

# OVD
L.append('## ===================== OVD =====================')
for site_num in range(1, 17):
    ch = site_num - 1
    sigs = sites.get(site_num, {})
    for ovd_ch in [0, 1]:
        pin = sigs.get(f'OVD_{ovd_ch}')
        if pin:
            L.append(f'set_property PACKAGE_PIN {pin:<6} [get_ports {{ovd_ch{ovd_ch}[{ch}]}}]')
            mapped += 1
        else:
            L.append(f'## S{site_num} OVD_{ovd_ch} (ch{ch}): not found')
            unmapped += 1
L.append('set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch0[*]}]')
L.append('set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch1[*]}]')
L.append('')

# PXI Trigger
L.append('## ===================== PXI Trigger =====================')
for i, pin in enumerate(['B9','A10','B10','C9','D9','D11','E11']):
    L.append(f'set_property PACKAGE_PIN {pin:<6} [get_ports {{pxi_trig[{i}]}}]')
    mapped += 1
L.append('set_property IOSTANDARD LVCMOS18 [get_ports {pxi_trig[*]}]')
L.append('')

# DSTAR
L.append('## ===================== DSTAR =====================')
L.append('set_property PACKAGE_PIN E10 [get_ports dstarb_p]')
L.append('set_property PACKAGE_PIN D10 [get_ports dstarb_n]')
L.append('set_property IOSTANDARD LVDS [get_ports dstarb_p]')
L.append('set_property DIFF_TERM TRUE [get_ports dstarb_p]')
L.append('set_property PACKAGE_PIN F8  [get_ports dstarc_p]')
L.append('set_property PACKAGE_PIN E8  [get_ports dstarc_n]')
L.append('set_property IOSTANDARD LVDS [get_ports dstarc_p]')
mapped += 4
L.append('')

# Timing
L.append('## ===================== Timing =====================')
L.append('set_false_path -to [get_pins {rst_pipe_reg[0]/D}]')
L.append('set_output_delay -clock [get_clocks sys_clk_200] -max 0.5 [get_ports {data0_p[*]}]')
L.append('set_output_delay -clock [get_clocks sys_clk_200] -min -0.5 [get_ports {data0_p[*]}]')
L.append('')

# DRC
L.append('## ===================== DRC (allow unmapped pins) =====================')
L.append('set_property SEVERITY {Warning} [get_drc_checks NSTD-1]')
L.append('set_property SEVERITY {Warning} [get_drc_checks UCIO-1]')
L.append('')

# Bitstream
L.append('## ===================== Bitstream =====================')
L.append('set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]')
L.append('set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]')
L.append('set_property CONFIG_MODE SPIx4 [current_design]')
L.append('set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]')
L.append('')
L.append(f'## Stats: {mapped} pins mapped, {unmapped} not found')

with open('D:/ATE_20260401/FPGA/constraints/ate_full_system.xdc', 'w') as f:
    f.write('\n'.join(L) + '\n')

print(f'Done: {mapped} mapped, {unmapped} not found')
