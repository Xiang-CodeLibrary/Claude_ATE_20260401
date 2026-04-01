# Timing Engine 硬件验证步骤

## 前置条件

- Ku035_Board 已焊接并通电正常
- Vivado 2023.2+ 已安装
- JTAG下载器已连接
- 示波器: 带宽 ≥ 1 GHz, 采样率 ≥ 5 GSa/s (推荐), 差分探头
- 测试探头接到 BTB 连接器 J1-1 对应的 LVDS 对:
  - CH0 (被测): B47_IO_2_P/N → J1-1 Pin B15/B16
  - CH1 (参考): B47_IO_3_P/N → J1-1 Pin A14/A15

## 构建与下载

```bash
cd D:/ATE_20260401/FPGA/project
vivado -mode batch -source build_timing_test.tcl
```

**首次构建前需确认/修改:**
1. 打开 `constraints/timing_test.xdc`
2. 确认 `sys_clk_p/n` 引脚号 (从原理图P07_CLK页查G3→FPGA引脚)
3. 确认 LED 引脚 (或注释掉LED端口, 改顶层为 `(* dont_touch *)`)
4. 下载 bitstream: Vivado Hardware Manager → Program Device

## 测试1: MMCM锁定验证

**目的**: 确认 800/400/100 MHz 时钟正常产生

**步骤**:
1. 下载bitstream
2. 打开 Vivado Hardware Manager → 连接VIO
3. 观察 `vio_status`:
   - bit[5] = `mmcm_locked` → 应为 **1**
   - bit[6] = `idelayctrl_rdy` → 应为 **1**
   - bit[7] = `rst_n` → 应为 **1**
4. 如果 `mmcm_locked=0`: 检查200MHz晶振, 检查引脚约束

**判定**: 三个bit全为1 → PASS

## 测试2: OSERDES3 输出功能验证

**目的**: 确认 OSERDES3 在 800 Mbps 正常工作

**步骤**:
1. VIO设置:
   - `vio_test_mode` = 1 (固定pattern模式)
   - `vio_enable` = 1
   - `vio_oserdes_pat` = 0xF0 (8'b1111_0000)
2. 示波器观察 CH0 差分输出:
   - 预期: **100 MHz 方波** (4bit高+4bit低 @800Mbps = 5ns+5ns)
3. 改 `vio_oserdes_pat` = 0xAA (8'b10101010):
   - 预期: **400 MHz 方波** (1bit高+1bit低 @800Mbps = 1.25ns+1.25ns)
4. 改 `vio_oserdes_pat` = 0xCC (8'b11001100):
   - 预期: **200 MHz 方波**

**判定**: 各pattern频率正确 → PASS

**预期波形**:
```
0xF0: ████████________████████________  (100MHz)
0xAA: ██__██__██__██__██__██__██__██__  (400MHz)
0xCC: ████____████____████____████____  (200MHz)
0x80: ██______________________________  (单脉冲@1.25ns每8个CLKDIV)
```

## 测试3: ODELAYE3 延迟步进验证 (关键测试)

**目的**: 验证 39.0625 ps 延迟分辨率

**步骤**:
1. VIO设置:
   - `vio_test_mode` = 2 (延迟扫描模式)
   - `vio_enable` = 1
   - `vio_delay_tap` = 0
   - 点击 `vio_delay_load` = 1, 然后回0
2. 示波器设置:
   - CH1 作触发源 (参考通道, 固定delay)
   - CH0 测量 (被测通道, delay可变)
   - 时基: 200 ps/div
   - 触发: CH1 上升沿
3. 测量 CH0 相对 CH1 的延迟 (初始值 Δt₀)
4. VIO改 `vio_delay_tap` = 1, load
5. 测量新的延迟 Δt₁
6. **单步延迟 = Δt₁ - Δt₀, 预期 ≈ 39 ps**
7. 重复: tap=0,10,20,50,100,200,511, 记录每次延迟

**记录表**:

| tap值 | 预期延迟(ps) | 实测延迟(ps) | 误差(ps) |
|-------|-------------|-------------|---------|
| 0     | 0           |             |         |
| 1     | 39.06       |             |         |
| 10    | 390.6       |             |         |
| 50    | 1953        |             |         |
| 100   | 3906        |             |         |
| 256   | 10000       |             |         |
| 511   | 19961       |             |         |

**判定标准**:
- 单步39ps可分辨 (示波器分辨率允许): ✅/⚠️
- 线性度: 256 taps对应~10ns ±500ps → PASS
- 511 taps对应~20ns ±1ns → PASS
- 如果示波器带宽不够分辨39ps单步, 改为测10步(390ps)或100步(3.9ns)

## 测试4: 边沿定位精度验证

**目的**: 验证 coarse + slot + fine 组合精度

**步骤**:
1. VIO设置:
   - `vio_test_mode` = 3 (边沿定位模式)
   - `vio_enable` = 1
   - `vio_period_reg` = 0x00080000 (20ns周期 = 50MHz)
   - `vio_edge_coarse` = 0 (第0个时钟周期)
   - `vio_edge_slot` = 0 (第0个bit-slot)
   - `vio_delay_tap` = 0
2. 示波器:
   - CH1触发 (参考, 标记周期起始)
   - CH0测量上升沿位置
3. 改 `vio_edge_slot` = 1: 预期上升沿移动 **1.25 ns**
4. 改 `vio_edge_slot` = 4: 预期移动 **5.0 ns**
5. 改 `vio_edge_coarse` = 1, slot=0: 预期移动 **10 ns** (1个CLKDIV周期)
6. 在 coarse=0, slot=0 基础上, 扫 delay_tap 0→255:
   预期上升沿平滑移动 **0 → 9.96 ns**

**判定**:
- slot步进 1.25ns ±200ps → PASS
- coarse步进 10ns ±500ps → PASS
- fine tap扫描线性 → PASS

## 测试5: Vector Period精度验证

**目的**: 验证 DDS 产生的 vector 周期精度

**步骤**:
1. VIO设置:
   - `vio_test_mode` = 3
   - `vio_enable` = 1
2. 测试不同周期:

| period_reg值 | 预期周期 | 预期频率 |
|-------------|---------|---------|
| 0x0004_0000 | 10 ns   | 100 MHz |
| 0x0006_0000 | 15 ns   | 66.67 MHz |
| 0x0008_0000 | 20 ns   | 50 MHz  |
| 0x0014_0000 | 50 ns   | 20 MHz  |
| 0x0028_0000 | 100 ns  | 10 MHz  |
| 0x0190_0000 | 1 µs    | 1 MHz   |

3. 示波器测量CH1的周期
4. 用频率计数器测量 (更精确)

**判定**: 周期误差 < 100 ps (对10ns周期) → PASS

## 故障排查

| 现象 | 可能原因 | 排查方法 |
|------|---------|---------|
| mmcm_locked=0 | 200MHz晶振未起振 | 示波器直接探晶振输出 |
| idelayctrl_rdy=0 | 800MHz时钟质量差 | 降低到400MHz REFCLK重试 |
| OSERDES无输出 | 引脚约束错误 | 检查XDC, Vivado I/O报告 |
| delay无变化 | ODELAYE3未正确连接 | ILA检查delay_load信号 |
| 非线性延迟 | 温度漂移/VT补偿 | EN_VTC=1, 等温度稳定 |
| 综合失败 | 800MHz时序不收敛 | 检查MMCM配置, 放宽约束 |

## 备选方案: 如果800MHz REFCLK不稳定

降级到400MHz REFCLK:
1. 修改 `timing_clocks.sv`: CLKOUT0 改为 400MHz
2. 修改 `channel_serdes.sv`: REFCLK_FREQUENCY 改为 400.0
3. tap分辨率变为 78.125 ps (=1/(32×400MHz))
4. 仍然大幅优于原始5ns, 足够初步验证架构

## 预期结论

如果测试1~4全部PASS:
- 确认 XCKU035 可实现 **39.0625 ps** 边沿分辨率 ✅
- 确认 OSERDES3 8:1 @800Mbps 工作正常 ✅
- 确认 coarse+slot+fine 三级定位方案可行 ✅
- 确认 DDS 周期产生精度满足 38fs 理论值 ✅
- → 可以继续推进完整 timing engine 与系统集成
