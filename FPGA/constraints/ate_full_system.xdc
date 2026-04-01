## =============================================================================
## ATE Pattern Card - Complete Pin Assignments (auto-generated)
## Site N -> Channel index (N-1): S1=ch0, S2=ch1, ..., S16=ch15
## =============================================================================

## ===================== System Clocks =====================
set_property PACKAGE_PIN AH18 [get_ports sys_clk_p]
set_property PACKAGE_PIN AH17 [get_ports sys_clk_n]
set_property IOSTANDARD LVDS [get_ports sys_clk_p]
set_property IOSTANDARD LVDS [get_ports sys_clk_n]
set_property DIFF_TERM TRUE [get_ports sys_clk_p]
create_clock -period 5.000 -name sys_clk_200 [get_ports sys_clk_p]

set_property PACKAGE_PIN E18 [get_ports pxie_clk100_p]
set_property PACKAGE_PIN E17 [get_ports pxie_clk100_n]
set_property IOSTANDARD LVDS [get_ports pxie_clk100_p]
set_property IOSTANDARD LVDS [get_ports pxie_clk100_n]
set_property DIFF_TERM TRUE [get_ports pxie_clk100_p]
create_clock -period 10.000 -name pxie_clk100 [get_ports pxie_clk100_p]

## ===================== DATA0 (output) =====================
set_property PACKAGE_PIN C11    [get_ports {data0_p[0]}]
set_property PACKAGE_PIN B11    [get_ports {data0_n[0]}]
set_property PACKAGE_PIN G15    [get_ports {data0_p[1]}]
set_property PACKAGE_PIN G14    [get_ports {data0_n[1]}]
set_property PACKAGE_PIN V21    [get_ports {data0_p[2]}]
set_property PACKAGE_PIN W21    [get_ports {data0_n[2]}]
set_property PACKAGE_PIN AC22   [get_ports {data0_p[3]}]
set_property PACKAGE_PIN AC23   [get_ports {data0_n[3]}]
set_property PACKAGE_PIN B17    [get_ports {data0_p[4]}]
set_property PACKAGE_PIN B16    [get_ports {data0_n[4]}]
set_property PACKAGE_PIN G20    [get_ports {data0_p[5]}]
set_property PACKAGE_PIN F20    [get_ports {data0_n[5]}]
set_property PACKAGE_PIN L8     [get_ports {data0_p[6]}]
set_property PACKAGE_PIN K8     [get_ports {data0_n[6]}]
set_property PACKAGE_PIN AB25   [get_ports {data0_p[7]}]
set_property PACKAGE_PIN AB26   [get_ports {data0_n[7]}]
set_property PACKAGE_PIN B29    [get_ports {data0_p[8]}]
set_property PACKAGE_PIN A29    [get_ports {data0_n[8]}]
set_property PACKAGE_PIN K16    [get_ports {data0_p[9]}]
set_property PACKAGE_PIN J16    [get_ports {data0_n[9]}]
set_property PACKAGE_PIN V29    [get_ports {data0_p[10]}]
set_property PACKAGE_PIN W29    [get_ports {data0_n[10]}]
set_property PACKAGE_PIN AN8    [get_ports {data0_p[11]}]  ;# Bank64 HR
set_property PACKAGE_PIN AP8    [get_ports {data0_n[11]}]  ;# Bank64 HR
set_property PACKAGE_PIN B25    [get_ports {data0_p[12]}]
set_property PACKAGE_PIN A25    [get_ports {data0_n[12]}]
set_property PACKAGE_PIN H19    [get_ports {data0_p[13]}]
set_property PACKAGE_PIN H18    [get_ports {data0_n[13]}]
set_property PACKAGE_PIN Y31    [get_ports {data0_p[14]}]
set_property PACKAGE_PIN Y32    [get_ports {data0_n[14]}]
set_property PACKAGE_PIN AK12   [get_ports {data0_p[15]}]  ;# Bank64 HR
set_property PACKAGE_PIN AL12   [get_ports {data0_n[15]}]  ;# Bank64 HR
set_property IOSTANDARD LVDS [get_ports {data0_p[*]}]
set_property IOSTANDARD LVDS [get_ports {data0_n[*]}]

## ===================== DATA1 (output) =====================
set_property PACKAGE_PIN F13    [get_ports {data1_p[0]}]
set_property PACKAGE_PIN E13    [get_ports {data1_n[0]}]
set_property PACKAGE_PIN AA20   [get_ports {data1_p[1]}]
set_property PACKAGE_PIN AB20   [get_ports {data1_n[1]}]
set_property PACKAGE_PIN AB24   [get_ports {data1_p[2]}]
set_property PACKAGE_PIN AC24   [get_ports {data1_n[2]}]
set_property PACKAGE_PIN AG12   [get_ports {data1_p[3]}]  ;# Bank64 HR
set_property PACKAGE_PIN AH12   [get_ports {data1_n[3]}]  ;# Bank64 HR
set_property PACKAGE_PIN D20    [get_ports {data1_p[4]}]
set_property PACKAGE_PIN D21    [get_ports {data1_n[4]}]
set_property PACKAGE_PIN K10    [get_ports {data1_p[5]}]
set_property PACKAGE_PIN J10    [get_ports {data1_n[5]}]
set_property PACKAGE_PIN Y26    [get_ports {data1_p[6]}]
set_property PACKAGE_PIN Y27    [get_ports {data1_n[6]}]
set_property PACKAGE_PIN AM11   [get_ports {data1_p[7]}]  ;# Bank64 HR
set_property PACKAGE_PIN AN11   [get_ports {data1_n[7]}]  ;# Bank64 HR
set_property PACKAGE_PIN D24    [get_ports {data1_p[8]}]
set_property PACKAGE_PIN C24    [get_ports {data1_n[8]}]
set_property PACKAGE_PIN L13    [get_ports {data1_p[9]}]
set_property PACKAGE_PIN K13    [get_ports {data1_n[9]}]
set_property PACKAGE_PIN W30    [get_ports {data1_p[10]}]
set_property PACKAGE_PIN Y30    [get_ports {data1_n[10]}]
set_property PACKAGE_PIN AK8    [get_ports {data1_p[11]}]  ;# Bank64 HR
set_property PACKAGE_PIN AL8    [get_ports {data1_n[11]}]  ;# Bank64 HR
set_property PACKAGE_PIN C26    [get_ports {data1_p[12]}]
set_property PACKAGE_PIN B26    [get_ports {data1_n[12]}]
set_property PACKAGE_PIN J19    [get_ports {data1_p[13]}]
set_property PACKAGE_PIN J18    [get_ports {data1_n[13]}]
set_property PACKAGE_PIN AA34   [get_ports {data1_p[14]}]
set_property PACKAGE_PIN AB34   [get_ports {data1_n[14]}]
set_property PACKAGE_PIN AH13   [get_ports {data1_p[15]}]  ;# Bank64 HR
set_property PACKAGE_PIN AJ13   [get_ports {data1_n[15]}]  ;# Bank64 HR
set_property IOSTANDARD LVDS [get_ports {data1_p[*]}]
set_property IOSTANDARD LVDS [get_ports {data1_n[*]}]

## ===================== RCV0 (input) =====================
set_property PACKAGE_PIN A13    [get_ports {rcv0_p[0]}]
set_property PACKAGE_PIN A12    [get_ports {rcv0_n[0]}]
set_property PACKAGE_PIN H17    [get_ports {rcv0_p[1]}]
set_property PACKAGE_PIN H16    [get_ports {rcv0_n[1]}]
set_property PACKAGE_PIN V22    [get_ports {rcv0_p[2]}]
set_property PACKAGE_PIN V23    [get_ports {rcv0_n[2]}]
set_property PACKAGE_PIN AB21   [get_ports {rcv0_p[3]}]
set_property PACKAGE_PIN AC21   [get_ports {rcv0_n[3]}]
set_property PACKAGE_PIN C18    [get_ports {rcv0_p[4]}]
set_property PACKAGE_PIN C17    [get_ports {rcv0_n[4]}]
set_property PACKAGE_PIN F18    [get_ports {rcv0_p[5]}]
set_property PACKAGE_PIN F17    [get_ports {rcv0_n[5]}]
set_property PACKAGE_PIN W23    [get_ports {rcv0_p[6]}]
set_property PACKAGE_PIN W24    [get_ports {rcv0_n[6]}]
set_property PACKAGE_PIN AC28   [get_ports {rcv0_p[7]}]
set_property PACKAGE_PIN AD28   [get_ports {rcv0_n[7]}]
set_property PACKAGE_PIN C27    [get_ports {rcv0_p[8]}]
set_property PACKAGE_PIN B27    [get_ports {rcv0_n[8]}]
set_property PACKAGE_PIN L15    [get_ports {rcv0_p[9]}]
set_property PACKAGE_PIN K15    [get_ports {rcv0_n[9]}]
set_property PACKAGE_PIN V31    [get_ports {rcv0_p[10]}]
set_property PACKAGE_PIN W31    [get_ports {rcv0_n[10]}]
set_property PACKAGE_PIN AK10   [get_ports {rcv0_p[11]}]  ;# Bank64 HR
set_property PACKAGE_PIN AL9    [get_ports {rcv0_n[11]}]  ;# Bank64 HR
set_property PACKAGE_PIN B24    [get_ports {rcv0_p[12]}]
set_property PACKAGE_PIN A24    [get_ports {rcv0_n[12]}]
set_property PACKAGE_PIN H21    [get_ports {rcv0_p[13]}]
set_property PACKAGE_PIN G21    [get_ports {rcv0_n[13]}]
set_property PACKAGE_PIN W33    [get_ports {rcv0_p[14]}]
set_property PACKAGE_PIN Y33    [get_ports {rcv0_n[14]}]
set_property PACKAGE_PIN AK13   [get_ports {rcv0_p[15]}]  ;# Bank64 HR
set_property PACKAGE_PIN AL13   [get_ports {rcv0_n[15]}]  ;# Bank64 HR
set_property IOSTANDARD LVDS [get_ports {rcv0_p[*]}]
set_property IOSTANDARD LVDS [get_ports {rcv0_n[*]}]
set_property DIFF_TERM TRUE [get_ports {rcv0_p[*]}]

## ===================== RCV1 (input) =====================
set_property PACKAGE_PIN E15    [get_ports {rcv1_p[0]}]
set_property PACKAGE_PIN D15    [get_ports {rcv1_n[0]}]
set_property PACKAGE_PIN J8     [get_ports {rcv1_p[1]}]
set_property PACKAGE_PIN H8     [get_ports {rcv1_n[1]}]
set_property PACKAGE_PIN AD25   [get_ports {rcv1_p[2]}]
set_property PACKAGE_PIN AD26   [get_ports {rcv1_n[2]}]
set_property PACKAGE_PIN AF9    [get_ports {rcv1_p[3]}]  ;# Bank64 HR
set_property PACKAGE_PIN AG9    [get_ports {rcv1_n[3]}]  ;# Bank64 HR
set_property PACKAGE_PIN E20    [get_ports {rcv1_p[4]}]
set_property PACKAGE_PIN E21    [get_ports {rcv1_n[4]}]
set_property PACKAGE_PIN J9     [get_ports {rcv1_p[5]}]
set_property PACKAGE_PIN H9     [get_ports {rcv1_n[5]}]
set_property PACKAGE_PIN AA27   [get_ports {rcv1_p[6]}]
set_property PACKAGE_PIN AB27   [get_ports {rcv1_n[6]}]
set_property PACKAGE_PIN AL10   [get_ports {rcv1_p[7]}]  ;# Bank64 HR
set_property PACKAGE_PIN AM10   [get_ports {rcv1_n[7]}]  ;# Bank64 HR
set_property PACKAGE_PIN E26    [get_ports {rcv1_p[8]}]
set_property PACKAGE_PIN D26    [get_ports {rcv1_n[8]}]
set_property PACKAGE_PIN L12    [get_ports {rcv1_p[9]}]
set_property PACKAGE_PIN K12    [get_ports {rcv1_n[9]}]
set_property PACKAGE_PIN AA29   [get_ports {rcv1_p[10]}]
set_property PACKAGE_PIN AB29   [get_ports {rcv1_n[10]}]
set_property PACKAGE_PIN AJ9    [get_ports {rcv1_p[11]}]  ;# Bank64 HR
set_property PACKAGE_PIN AJ8    [get_ports {rcv1_n[11]}]  ;# Bank64 HR
set_property PACKAGE_PIN A27    [get_ports {rcv1_p[12]}]
set_property PACKAGE_PIN A28    [get_ports {rcv1_n[12]}]
set_property PACKAGE_PIN K18    [get_ports {rcv1_p[13]}]
set_property PACKAGE_PIN K17    [get_ports {rcv1_n[13]}]
set_property PACKAGE_PIN AB30   [get_ports {rcv1_p[14]}]
set_property PACKAGE_PIN AB31   [get_ports {rcv1_n[14]}]
set_property PACKAGE_PIN AG11   [get_ports {rcv1_p[15]}]  ;# Bank64 HR
set_property PACKAGE_PIN AH11   [get_ports {rcv1_n[15]}]  ;# Bank64 HR
set_property IOSTANDARD LVDS [get_ports {rcv1_p[*]}]
set_property IOSTANDARD LVDS [get_ports {rcv1_n[*]}]
set_property DIFF_TERM TRUE [get_ports {rcv1_p[*]}]

## ===================== COMP_QH0 (input) =====================
set_property PACKAGE_PIN B15    [get_ports {comp_qh0_p[0]}]
set_property PACKAGE_PIN A15    [get_ports {comp_qh0_n[0]}]
set_property PACKAGE_PIN H11    [get_ports {comp_qh0_p[1]}]
set_property PACKAGE_PIN G11    [get_ports {comp_qh0_n[1]}]
set_property PACKAGE_PIN AF30   [get_ports {comp_qh0_p[2]}]
set_property PACKAGE_PIN AG30   [get_ports {comp_qh0_n[2]}]
set_property PACKAGE_PIN AD11   [get_ports {comp_qh0_p[3]}]  ;# Bank64 HR
set_property PACKAGE_PIN AE11   [get_ports {comp_qh0_n[3]}]  ;# Bank64 HR
set_property PACKAGE_PIN C19    [get_ports {comp_qh0_p[4]}]
set_property PACKAGE_PIN B19    [get_ports {comp_qh0_n[4]}]
set_property PACKAGE_PIN J15    [get_ports {comp_qh0_p[5]}]
set_property PACKAGE_PIN J14    [get_ports {comp_qh0_n[5]}]
set_property PACKAGE_PIN W25    [get_ports {comp_qh0_p[6]}]
set_property PACKAGE_PIN Y25    [get_ports {comp_qh0_n[6]}]
set_property PACKAGE_PIN AN13   [get_ports {comp_qh0_p[7]}]  ;# Bank64 HR
set_property PACKAGE_PIN AP13   [get_ports {comp_qh0_n[7]}]  ;# Bank64 HR
set_property PACKAGE_PIN B21    [get_ports {comp_qh0_p[8]}]
set_property PACKAGE_PIN B22    [get_ports {comp_qh0_n[8]}]
set_property PACKAGE_PIN G19    [get_ports {comp_qh0_p[9]}]
set_property PACKAGE_PIN F19    [get_ports {comp_qh0_n[9]}]
set_property PACKAGE_PIN V27    [get_ports {comp_qh0_p[10]}]
set_property PACKAGE_PIN V28    [get_ports {comp_qh0_n[10]}]
set_property PACKAGE_PIN AN9    [get_ports {comp_qh0_p[11]}]  ;# Bank64 HR
set_property PACKAGE_PIN AP9    [get_ports {comp_qh0_n[11]}]  ;# Bank64 HR
set_property PACKAGE_PIN E22    [get_ports {comp_qh0_p[12]}]
set_property PACKAGE_PIN E23    [get_ports {comp_qh0_n[12]}]
set_property PACKAGE_PIN F27    [get_ports {comp_qh0_p[13]}]
set_property PACKAGE_PIN E27    [get_ports {comp_qh0_n[13]}]
set_property PACKAGE_PIN U34    [get_ports {comp_qh0_p[14]}]
set_property PACKAGE_PIN V34    [get_ports {comp_qh0_n[14]}]
set_property PACKAGE_PIN AE33   [get_ports {comp_qh0_p[15]}]
set_property PACKAGE_PIN AF34   [get_ports {comp_qh0_n[15]}]
set_property IOSTANDARD LVDS [get_ports {comp_qh0_p[*]}]
set_property IOSTANDARD LVDS [get_ports {comp_qh0_n[*]}]
set_property DIFF_TERM TRUE [get_ports {comp_qh0_p[*]}]

## ===================== COMP_QH1 (input) =====================
set_property PACKAGE_PIN C12    [get_ports {comp_qh1_p[0]}]
set_property PACKAGE_PIN B12    [get_ports {comp_qh1_n[0]}]
set_property PACKAGE_PIN G10    [get_ports {comp_qh1_p[1]}]
set_property PACKAGE_PIN F10    [get_ports {comp_qh1_n[1]}]
set_property PACKAGE_PIN AG31   [get_ports {comp_qh1_p[2]}]
set_property PACKAGE_PIN AG32   [get_ports {comp_qh1_n[2]}]
set_property PACKAGE_PIN AE12   [get_ports {comp_qh1_p[3]}]  ;# Bank64 HR
set_property PACKAGE_PIN AF12   [get_ports {comp_qh1_n[3]}]  ;# Bank64 HR
set_property PACKAGE_PIN D19    [get_ports {comp_qh1_p[4]}]
set_property PACKAGE_PIN D18    [get_ports {comp_qh1_n[4]}]
set_property PACKAGE_PIN K11    [get_ports {comp_qh1_p[5]}]
set_property PACKAGE_PIN J11    [get_ports {comp_qh1_n[5]}]
set_property PACKAGE_PIN W28    [get_ports {comp_qh1_p[6]}]
set_property PACKAGE_PIN Y28    [get_ports {comp_qh1_n[6]}]
set_property PACKAGE_PIN AP11   [get_ports {comp_qh1_p[7]}]  ;# Bank64 HR
set_property PACKAGE_PIN AP10   [get_ports {comp_qh1_n[7]}]  ;# Bank64 HR
set_property PACKAGE_PIN F23    [get_ports {comp_qh1_p[8]}]
set_property PACKAGE_PIN F24    [get_ports {comp_qh1_n[8]}]
set_property PACKAGE_PIN T22    [get_ports {comp_qh1_p[9]}]
set_property PACKAGE_PIN T23    [get_ports {comp_qh1_n[9]}]
set_property PACKAGE_PIN AC31   [get_ports {comp_qh1_p[10]}]
set_property PACKAGE_PIN AC32   [get_ports {comp_qh1_n[10]}]
set_property PACKAGE_PIN AF10   [get_ports {comp_qh1_p[11]}]  ;# Bank64 HR
set_property PACKAGE_PIN AG10   [get_ports {comp_qh1_n[11]}]  ;# Bank64 HR
set_property PACKAGE_PIN E28    [get_ports {comp_qh1_p[12]}]
set_property PACKAGE_PIN D29    [get_ports {comp_qh1_n[12]}]
set_property PACKAGE_PIN U26    [get_ports {comp_qh1_p[13]}]
set_property PACKAGE_PIN U27    [get_ports {comp_qh1_n[13]}]
set_property PACKAGE_PIN AD30   [get_ports {comp_qh1_p[14]}]
set_property PACKAGE_PIN AD31   [get_ports {comp_qh1_n[14]}]
set_property PACKAGE_PIN AE8    [get_ports {comp_qh1_p[15]}]  ;# Bank64 HR
set_property PACKAGE_PIN AF8    [get_ports {comp_qh1_n[15]}]  ;# Bank64 HR
set_property IOSTANDARD LVDS [get_ports {comp_qh1_p[*]}]
set_property IOSTANDARD LVDS [get_ports {comp_qh1_n[*]}]
set_property DIFF_TERM TRUE [get_ports {comp_qh1_p[*]}]

## ===================== COMP_QL0 (input) =====================
set_property PACKAGE_PIN B14    [get_ports {comp_ql0_p[0]}]
set_property PACKAGE_PIN A14    [get_ports {comp_ql0_n[0]}]
set_property PACKAGE_PIN H12    [get_ports {comp_ql0_p[1]}]
set_property PACKAGE_PIN G12    [get_ports {comp_ql0_n[1]}]
set_property PACKAGE_PIN Y23    [get_ports {comp_ql0_p[2]}]
set_property PACKAGE_PIN AA23   [get_ports {comp_ql0_n[2]}]
set_property PACKAGE_PIN AD10   [get_ports {comp_ql0_p[3]}]  ;# Bank64 HR
set_property PACKAGE_PIN AE10   [get_ports {comp_ql0_n[3]}]  ;# Bank64 HR
set_property PACKAGE_PIN A19    [get_ports {comp_ql0_p[4]}]
set_property PACKAGE_PIN A18    [get_ports {comp_ql0_n[4]}]
set_property PACKAGE_PIN G17    [get_ports {comp_ql0_p[5]}]
set_property PACKAGE_PIN G16    [get_ports {comp_ql0_n[5]}]
set_property PACKAGE_PIN AA24   [get_ports {comp_ql0_p[6]}]
set_property PACKAGE_PIN AA25   [get_ports {comp_ql0_n[6]}]
set_property PACKAGE_PIN AD29   [get_ports {comp_ql0_p[7]}]
set_property PACKAGE_PIN AE30   [get_ports {comp_ql0_n[7]}]
set_property PACKAGE_PIN B20    [get_ports {comp_ql0_p[8]}]
set_property PACKAGE_PIN A20    [get_ports {comp_ql0_n[8]}]
set_property PACKAGE_PIN G22    [get_ports {comp_ql0_p[9]}]
set_property PACKAGE_PIN F22    [get_ports {comp_ql0_n[9]}]
set_property PACKAGE_PIN U24    [get_ports {comp_ql0_p[10]}]
set_property PACKAGE_PIN U25    [get_ports {comp_ql0_n[10]}]
set_property PACKAGE_PIN AC33   [get_ports {comp_ql0_p[11]}]
set_property PACKAGE_PIN AD33   [get_ports {comp_ql0_n[11]}]
set_property PACKAGE_PIN D23    [get_ports {comp_ql0_p[12]}]
set_property PACKAGE_PIN C23    [get_ports {comp_ql0_n[12]}]
set_property PACKAGE_PIN G24    [get_ports {comp_ql0_p[13]}]
set_property PACKAGE_PIN F25    [get_ports {comp_ql0_n[13]}]
set_property PACKAGE_PIN V33    [get_ports {comp_ql0_p[14]}]
set_property PACKAGE_PIN W34    [get_ports {comp_ql0_n[14]}]
set_property PACKAGE_PIN AF33   [get_ports {comp_ql0_p[15]}]
set_property PACKAGE_PIN AG34   [get_ports {comp_ql0_n[15]}]
set_property IOSTANDARD LVDS [get_ports {comp_ql0_p[*]}]
set_property IOSTANDARD LVDS [get_ports {comp_ql0_n[*]}]
set_property DIFF_TERM TRUE [get_ports {comp_ql0_p[*]}]

## ===================== COMP_QL1 (input) =====================
set_property PACKAGE_PIN D14    [get_ports {comp_ql1_p[0]}]
set_property PACKAGE_PIN C14    [get_ports {comp_ql1_n[0]}]
set_property PACKAGE_PIN G9     [get_ports {comp_ql1_p[1]}]
set_property PACKAGE_PIN F9     [get_ports {comp_ql1_n[1]}]
set_property PACKAGE_PIN AF29   [get_ports {comp_ql1_p[2]}]
set_property PACKAGE_PIN AG29   [get_ports {comp_ql1_n[2]}]
set_property PACKAGE_PIN AE13   [get_ports {comp_ql1_p[3]}]  ;# Bank64 HR
set_property PACKAGE_PIN AF13   [get_ports {comp_ql1_n[3]}]  ;# Bank64 HR
set_property PACKAGE_PIN C21    [get_ports {comp_ql1_p[4]}]
set_property PACKAGE_PIN C22    [get_ports {comp_ql1_n[4]}]
set_property PACKAGE_PIN J13    [get_ports {comp_ql1_p[5]}]
set_property PACKAGE_PIN H13    [get_ports {comp_ql1_n[5]}]
set_property PACKAGE_PIN V26    [get_ports {comp_ql1_p[6]}]
set_property PACKAGE_PIN W26    [get_ports {comp_ql1_n[6]}]
set_property PACKAGE_PIN AM12   [get_ports {comp_ql1_p[7]}]  ;# Bank64 HR
set_property PACKAGE_PIN AN12   [get_ports {comp_ql1_n[7]}]  ;# Bank64 HR
set_property PACKAGE_PIN E25    [get_ports {comp_ql1_p[8]}]
set_property PACKAGE_PIN D25    [get_ports {comp_ql1_n[8]}]
set_property PACKAGE_PIN U21    [get_ports {comp_ql1_p[9]}]
set_property PACKAGE_PIN U22    [get_ports {comp_ql1_n[9]}]
set_property PACKAGE_PIN AA32   [get_ports {comp_ql1_p[10]}]
set_property PACKAGE_PIN AB32   [get_ports {comp_ql1_n[10]}]
set_property PACKAGE_PIN AH9    [get_ports {comp_ql1_p[11]}]  ;# Bank64 HR
set_property PACKAGE_PIN AH8    [get_ports {comp_ql1_n[11]}]  ;# Bank64 HR
set_property PACKAGE_PIN D28    [get_ports {comp_ql1_p[12]}]
set_property PACKAGE_PIN C28    [get_ports {comp_ql1_n[12]}]
set_property PACKAGE_PIN L19    [get_ports {comp_ql1_p[13]}]
set_property PACKAGE_PIN L18    [get_ports {comp_ql1_n[13]}]
set_property PACKAGE_PIN AC34   [get_ports {comp_ql1_p[14]}]
set_property PACKAGE_PIN AD34   [get_ports {comp_ql1_n[14]}]
set_property PACKAGE_PIN AD9    [get_ports {comp_ql1_p[15]}]  ;# Bank64 HR
set_property PACKAGE_PIN AD8    [get_ports {comp_ql1_n[15]}]  ;# Bank64 HR
set_property IOSTANDARD LVDS [get_ports {comp_ql1_p[*]}]
set_property IOSTANDARD LVDS [get_ports {comp_ql1_n[*]}]
set_property DIFF_TERM TRUE [get_ports {comp_ql1_p[*]}]

## ===================== OVD =====================
set_property PACKAGE_PIN AF32   [get_ports {ovd_ch0[0]}]
set_property PACKAGE_PIN AE32   [get_ports {ovd_ch1[0]}]
set_property PACKAGE_PIN AF27   [get_ports {ovd_ch0[1]}]
set_property PACKAGE_PIN AE27   [get_ports {ovd_ch1[1]}]
set_property PACKAGE_PIN AC27   [get_ports {ovd_ch0[2]}]
set_property PACKAGE_PIN AC26   [get_ports {ovd_ch1[2]}]
set_property PACKAGE_PIN L17    [get_ports {ovd_ch0[3]}]
set_property PACKAGE_PIN R27    [get_ports {ovd_ch1[3]}]
set_property PACKAGE_PIN L17    [get_ports {ovd_ch0[4]}]
set_property PACKAGE_PIN H14    [get_ports {ovd_ch1[4]}]
set_property PACKAGE_PIN F15    [get_ports {ovd_ch0[5]}]
set_property PACKAGE_PIN F12    [get_ports {ovd_ch1[5]}]
set_property PACKAGE_PIN AF28   [get_ports {ovd_ch0[6]}]
set_property PACKAGE_PIN AE28   [get_ports {ovd_ch1[6]}]
set_property PACKAGE_PIN AC29   [get_ports {ovd_ch0[7]}]
set_property PACKAGE_PIN AA33   [get_ports {ovd_ch1[7]}]
set_property PACKAGE_PIN AB22   [get_ports {ovd_ch0[8]}]
set_property PACKAGE_PIN AA22   [get_ports {ovd_ch1[8]}]
set_property PACKAGE_PIN A22    [get_ports {ovd_ch0[9]}]
set_property PACKAGE_PIN H22    [get_ports {ovd_ch1[9]}]
set_property PACKAGE_PIN H22    [get_ports {ovd_ch0[10]}]
set_property PACKAGE_PIN F14    [get_ports {ovd_ch1[10]}]
set_property PACKAGE_PIN E12    [get_ports {ovd_ch0[11]}]
set_property PACKAGE_PIN D13    [get_ports {ovd_ch1[11]}]
set_property PACKAGE_PIN C13    [get_ports {ovd_ch0[12]}]
set_property PACKAGE_PIN C16    [get_ports {ovd_ch1[12]}]
set_property PACKAGE_PIN A17    [get_ports {ovd_ch0[13]}]
set_property PACKAGE_PIN C29    [get_ports {ovd_ch1[13]}]
set_property PACKAGE_PIN A22    [get_ports {ovd_ch0[14]}]
set_property PACKAGE_PIN A23    [get_ports {ovd_ch1[14]}]
set_property PACKAGE_PIN L9     [get_ports {ovd_ch0[15]}]
set_property PACKAGE_PIN A8     [get_ports {ovd_ch1[15]}]

set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch0[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch1[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch0[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch1[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch0[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch1[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch0[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ovd_ch1[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch0[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch1[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch0[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch1[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch0[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch1[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch0[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch1[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch0[8]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch1[8]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch0[9]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch1[9]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch0[10]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch1[10]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch0[11]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch1[11]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch0[12]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch1[12]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch0[13]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch1[13]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch0[14]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch1[14]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch0[15]}]
set_property IOSTANDARD LVCMOS18 [get_ports {ovd_ch1[15]}]

## ===================== PXI Trigger =====================
set_property PACKAGE_PIN B9     [get_ports {pxi_trig[0]}]
set_property PACKAGE_PIN A10    [get_ports {pxi_trig[1]}]
set_property PACKAGE_PIN B10    [get_ports {pxi_trig[2]}]
set_property PACKAGE_PIN C9     [get_ports {pxi_trig[3]}]
set_property PACKAGE_PIN D9     [get_ports {pxi_trig[4]}]
set_property PACKAGE_PIN D11    [get_ports {pxi_trig[5]}]
set_property PACKAGE_PIN E11    [get_ports {pxi_trig[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {pxi_trig[*]}]

## ===================== DSTAR =====================
set_property PACKAGE_PIN E10 [get_ports dstarb_p]
set_property PACKAGE_PIN D10 [get_ports dstarb_n]
set_property IOSTANDARD LVDS [get_ports dstarb_p]
set_property DIFF_TERM TRUE [get_ports dstarb_p]
set_property PACKAGE_PIN F8  [get_ports dstarc_p]
set_property PACKAGE_PIN E8  [get_ports dstarc_n]
set_property IOSTANDARD LVDS [get_ports dstarc_p]

## ===================== Timing =====================
set_false_path -to [get_pins {rst_pipe_reg[0]/D}]
set_output_delay -clock [get_clocks sys_clk_200] -max 0.5 [get_ports {data0_p[*]}]
set_output_delay -clock [get_clocks sys_clk_200] -min -0.5 [get_ports {data0_p[*]}]



## ===================== DRC (allow unmapped pins) =====================
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]

## ===================== Bitstream =====================
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

## Stats: 299 pins mapped, 0 not found

## ===================== Bank 64 HR: LVDS_25 override =====================
## Bank 64 is High Range, does not support LVDS, use LVDS_25 instead
set_property IOSTANDARD LVDS_25 [get_ports {comp_qh0_p[11]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_qh0_n[11]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_qh0_p[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_qh0_n[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_qh0_p[7]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_qh0_n[7]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_qh1_p[11]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_qh1_n[11]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_qh1_p[15]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_qh1_n[15]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_qh1_p[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_qh1_n[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_qh1_p[7]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_qh1_n[7]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_ql0_p[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_ql0_n[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_ql1_p[11]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_ql1_n[11]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_ql1_p[15]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_ql1_n[15]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_ql1_p[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_ql1_n[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_ql1_p[7]}]
set_property IOSTANDARD LVDS_25 [get_ports {comp_ql1_n[7]}]
set_property IOSTANDARD LVDS_25 [get_ports {data0_p[11]}]
set_property IOSTANDARD LVDS_25 [get_ports {data0_n[11]}]
set_property IOSTANDARD LVDS_25 [get_ports {data0_p[15]}]
set_property IOSTANDARD LVDS_25 [get_ports {data0_n[15]}]
set_property IOSTANDARD LVDS_25 [get_ports {data1_p[11]}]
set_property IOSTANDARD LVDS_25 [get_ports {data1_n[11]}]
set_property IOSTANDARD LVDS_25 [get_ports {data1_p[15]}]
set_property IOSTANDARD LVDS_25 [get_ports {data1_n[15]}]
set_property IOSTANDARD LVDS_25 [get_ports {data1_p[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {data1_n[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {data1_p[7]}]
set_property IOSTANDARD LVDS_25 [get_ports {data1_n[7]}]
set_property IOSTANDARD LVDS_25 [get_ports {rcv0_p[11]}]
set_property IOSTANDARD LVDS_25 [get_ports {rcv0_n[11]}]
set_property IOSTANDARD LVDS_25 [get_ports {rcv0_p[15]}]
set_property IOSTANDARD LVDS_25 [get_ports {rcv0_n[15]}]
set_property IOSTANDARD LVDS_25 [get_ports {rcv1_p[11]}]
set_property IOSTANDARD LVDS_25 [get_ports {rcv1_n[11]}]
set_property IOSTANDARD LVDS_25 [get_ports {rcv1_p[15]}]
set_property IOSTANDARD LVDS_25 [get_ports {rcv1_n[15]}]
set_property IOSTANDARD LVDS_25 [get_ports {rcv1_p[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {rcv1_n[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {rcv1_p[7]}]
set_property IOSTANDARD LVDS_25 [get_ports {rcv1_n[7]}]

## ===================== ADATE305 SPI Bus 1 (S1~S8, Bank 65 HR) =====================
## Shared bus: SCLK/MOSI/MISO to chips 0~3 (Sites 1~8)
set_property PACKAGE_PIN R21    [get_ports adate_spi_sclk]
set_property PACKAGE_PIN N21    [get_ports adate_spi_mosi]
set_property PACKAGE_PIN R22    [get_ports adate_spi_miso]
set_property IOSTANDARD LVCMOS33 [get_ports adate_spi_sclk]
set_property IOSTANDARD LVCMOS33 [get_ports adate_spi_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports adate_spi_miso]

## SPI Chip Selects (active low, per ADATE305 chip)
## Note: 2 sites share one CS (S1+S2=chip0, S3+S4=chip1, etc.)
## DLC board has per-site CS; FPGA drives one of the pair
set_property PACKAGE_PIN J26    [get_ports {adate_spi_cs_n[0]}]
set_property PACKAGE_PIN L27    [get_ports {adate_spi_cs_n[1]}]
set_property PACKAGE_PIN L24    [get_ports {adate_spi_cs_n[2]}]
set_property PACKAGE_PIN K25    [get_ports {adate_spi_cs_n[3]}]
set_property PACKAGE_PIN R25    [get_ports {adate_spi_cs_n[4]}]
set_property PACKAGE_PIN M26    [get_ports {adate_spi_cs_n[5]}]
set_property PACKAGE_PIN T25    [get_ports {adate_spi_cs_n[6]}]
set_property PACKAGE_PIN L22    [get_ports {adate_spi_cs_n[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {adate_spi_cs_n[*]}]

## ADATE305 Global Reset
set_property PACKAGE_PIN N22    [get_ports adate_spi_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports adate_spi_rst_n]

## ===================== ADC SPI (ADS7959 x2, Bank 65 HR) =====================
## Shared SCLK/MOSI/MISO, individual CS per ADC chip

## ===================== ADC SPI (ADS7959 x2, Bank 65 HR) =====================
## DLC board: shared SCLK/SDI/SDO bus, separate CS per ADC
## FPGA top has per-ADC ports; need to merge in RTL or use single port
## For now: assign ADC[0] to shared bus, ADC[1] directly
set_property PACKAGE_PIN K21    [get_ports adc_spi_sclk]
set_property PACKAGE_PIN K22    [get_ports adc_spi_mosi]
set_property PACKAGE_PIN M21    [get_ports adc_spi_miso]
set_property PACKAGE_PIN P23    [get_ports {adc_spi_cs_n[0]}]
set_property PACKAGE_PIN R23    [get_ports {adc_spi_cs_n[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports adc_spi_sclk]
set_property IOSTANDARD LVCMOS33 [get_ports adc_spi_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports adc_spi_miso]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_spi_cs_n[*]}]
## ADC bus: shared SCLK/MOSI/MISO, separate CS. Merged to single port in RTL.
