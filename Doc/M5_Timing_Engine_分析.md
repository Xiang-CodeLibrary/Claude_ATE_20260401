# M5 Timing Engine 可行性分析

## 一、PXIe-6571 Timing规格 vs 当前实现

| 参数 | PXIe-6571规格 | 当前实现 | 差距 |
|------|-------------|---------|------|
| **Vector Rate** | 100 MHz (10ns) | 整数时钟分频 | 只能整数周期,无法产生非整数周期 |
| **Vector Period Range** | 10 ns ~ 40 µs | 整数时钟周期×5ns | ✅基本满足 |
| **Vector Period Resolution** | **38 fs** | 5 ns (一个时钟周期) | ❌ 差13万倍 |
| **Edge Placement Resolution** | **39.0625 ps** | 5 ns (一个时钟周期) | ❌ 差128倍 |
| **Edge Placement Range** | 0 ~ 5 vector periods (或40µs) | 1个周期内 | ❌ 不支持跨周期边沿 |
| **TDR Deskew Resolution** | 39.0625 ps per channel | 未实现 | ❌ 缺失 |
| **Edge Accuracy (Drive)** | ±500 ps warranted | 未评估 | 取决于物理实现 |
| **Overall Timing Accuracy** | ±1.5 ns warranted | 未评估 | 取决于物理实现 |
| **Min Edge Separation** | 3.75 ns (data change) | 未约束 | ❌ 缺失 |
| **Edge per channel** | 独立per-channel | 全通道共享 | ❌ 不支持per-channel边沿 |

**结论: 当前timing_engine.sv是占位级别,远不满足PXIe-6571规格。需要完全重写。**

## 二、39.0625 ps 边沿分辨率的实现方案

### 2.1 关键计算

```
39.0625 ps = 10 ns / 256 = 1 / (256 × 100 MHz)

等价于: ODELAYE3 tap delay @ IDELAYCTRL refclk = 800 MHz
  tap_delay = 1 / (32 × f_REF) = 1 / (32 × 800 MHz) = 39.0625 ps ✓
  512 taps × 39.0625 ps = 20 ns 最大延迟
```

### 2.2 XCKU035 ODELAYE3 能力

| 参数 | XCKU035-2 (Speed Grade -2) |
|------|---------------------------|
| IDELAYCTRL REFCLK范围 | 200 ~ 800 MHz |
| ODELAYE3 taps | 512 |
| @800MHz: tap分辨率 | 39.0625 ps ✓ |
| @800MHz: 最大延迟 | 512 × 39.0625 ps = 20 ns |
| DELAY_FORMAT | COUNT 或 TIME |
| 动态调整 | 支持 (CE + INC/DEC) |

**结论: XCKU035 @800MHz REFCLK 可以精确实现 39.0625 ps 分辨率 ✓**

### 2.3 800MHz REFCLK生成

```
MMCM配置:
  Input:  200 MHz (G3 oscillator)
  VCO:    200 MHz × 4 = 800 MHz
  CLKOUT: 800 MHz (divide=1) → BUFG → IDELAYCTRL REFCLK

XCKU035-2 MMCM VCO范围: 600~1440 MHz → 800 MHz ✓
MMCM CLKOUT max (BUFG path): 800 MHz → ✓
```

## 三、38 fs Vector Period分辨率的实现方案

### 3.1 DDS相位累加器方案

```
基准时钟: 100 MHz (PXIe_CLK100) → T_ref = 10 ns
目标分辨率: 38 fs

需要细分: 10 ns / 38 fs = 263,158 步
log2(263158) ≈ 18 bit → 用18-bit小数部分

实际: 10 ns / 2^18 = 38.147 fs ≈ 38 fs ✓

相位累加器设计:
  total_bits = 12 (整数,覆盖4000个时钟@40µs) + 18 (小数) = 30 bit
  phase_accumulator[29:0]:
    [29:18] = 整数时钟周期计数 (0~4095)
    [17:0]  = 亚时钟周期小数 (38.147 fs分辨率)

  period_register[29:0]:
    写入值 = desired_period_ps / 38.147 fs
    例: 10 ns → 10000 ps / 0.038147 ps = 262144 = 0x40000
    例: 15 ns → 15000 ps / 0.038147 ps = 393216 = 0x60000
    例: 40 µs → 40000000 ps / 0.038147 ps = 1048576000 (超出30bit!)

需要更多位数: 40 µs / 38 fs = 1.053 × 10^9 → log2 ≈ 30 bit
用32-bit phase accumulator:
  [31:18] = 整数 (14 bit → 0~16383 时钟, 最大163.83 µs @100MHz) ✓
  [17:0]  = 小数 (18 bit → 38.147 fs分辨率) ✓
```

### 3.2 边沿位置表示

```
每个边沿位置 = {coarse_clk_count[13:0], fine_tap[8:0]}

coarse_clk_count: 相对于vector起始的整数时钟偏移 (0~16383)
  → 最大 16383 × 10 ns = 163.83 µs (远超40µs上限) ✓

fine_tap: ODELAYE3 tap值 (0~511)
  → 分辨率 39.0625 ps
  → 最大 511 × 39.0625 ps ≈ 20 ns

一个时钟周期(10ns)内的亚时钟位置:
  fine_tap 0~255 覆盖 0~9.96 ns ✓

边沿位置总分辨率 = 39.0625 ps ✓
边沿位置范围 = 0 ~ 5 vector periods (受软件限制) ✓
```

## 四、Per-Channel独立边沿的架构

PXIe-6571每个通道有独立的边沿定位。这意味着:

```
16通道 × 8边沿 × {14-bit coarse + 9-bit fine} = 16 × 8 × 23 bit = 2944 bit
每个TimeSet存储: 2944 bit → 使用BRAM
31个TimeSet: 31 × 2944 = 91,264 bit ≈ 11.4 KB → 1个36Kb BRAM即可

但PXIe-6571实际上TimeSet边沿是per-pin的:
  31 TimeSets × 8 edges × 32 channels × 23 bits = 每个6571约需182KB
  我们16通道: 31 × 8 × 16 × 23 = 91,264 bit → 3个36Kb BRAM
```

### 4.1 Per-Channel输出通路

```
每个通道独立的输出路径:

                   ┌──────────────┐
  Pattern Data ───>│ Drive Format │    ┌──────────┐    ┌──────────┐
  TimeSet Edges ──>│ State Machine│───>│ OSERDES3 │───>│ ODELAYE3 │──> OBUFDS ──> LVDS
  Edge Events  ───>│              │    │  8:1     │    │ 512 taps │
                   └──────────────┘    │ @800Mbps │    │ @39ps    │
                                       └──────────┘    └──────────┘
                                                           ↑
                                              TDR deskew (per-channel)
                                              + fine edge adjustment

类似的,每个通道的compare输入路径:

  LVDS ──> IBUFDS ──> IDELAYE3 ──> ISERDES3 ──> Compare Logic
                      512 taps     8:1
                      @39ps        @800Mbps
```

### 4.2 OSERDES3 使用方案

```
OSERDES3 配置:
  DATA_WIDTH = 8 (8:1 serialization)
  CLK = 400 MHz (DDR → 800 Mbps)
  CLKDIV = 100 MHz (parallel clock)
  每个bit时间 = 1.25 ns

边沿定位机制:
  1. Coarse: 选择哪个CLKDIV周期输出变化 (10ns步进)
  2. Medium: OSERDES3 bit位置选择 (1.25ns步进, 8个位置)
  3. Fine: ODELAYE3 tap (39.0625ps步进, 0~20ns)

总分辨率 = 39.0625 ps ✓
但需要注意: ODELAYE3只能延迟,不能提前。
所以实际方案是: 提前1个bit输出,用ODELAYE3补偿到精确位置。
```

## 五、重新设计的Timing Engine架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    Timing Engine (Redesigned)                     │
│                                                                   │
│  ┌─────────────────────┐                                         │
│  │  Vector Period       │  DDS Phase Accumulator                  │
│  │  Generator           │  32-bit: [31:18]=coarse, [17:0]=fine    │
│  │  (38 fs resolution)  │  → generates vector boundary ticks      │
│  └──────────┬──────────┘                                         │
│             │ vec_tick (vector period boundary)                    │
│             ▼                                                     │
│  ┌─────────────────────┐                                         │
│  │  TimeSet Memory      │  BRAM: 31 × 8 edges × 16ch             │
│  │  (per-channel edges) │  Each edge: {coarse[13:0], fine[8:0]}  │
│  └──────────┬──────────┘                                         │
│             │ edge positions for current timeset                   │
│             ▼                                                     │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Per-Channel Edge Generator × 16                             │ │
│  │  ┌────────────────────────────────────────────────────────┐ │ │
│  │  │  Channel N Edge Gen                                     │ │ │
│  │  │                                                         │ │ │
│  │  │  coarse_counter[13:0] ──compare──> 8 edge_match signals│ │ │
│  │  │          │                              │               │ │ │
│  │  │          ▼                              ▼               │ │ │
│  │  │  ┌──────────────┐              ┌──────────────┐        │ │ │
│  │  │  │Drive Format  │              │OSERDES3 Data │        │ │ │
│  │  │  │State Machine │──8-bit D──>  │Pattern Gen   │        │ │ │
│  │  │  │(NR/RL/RH/SBC)│              │(per bit-slot)│        │ │ │
│  │  │  └──────────────┘              └──────┬───────┘        │ │ │
│  │  │                                       │ 8-bit          │ │ │
│  │  │                                ┌──────┴───────┐        │ │ │
│  │  │                                │  OSERDES3    │        │ │ │
│  │  │                                │  8:1 @400MHz │        │ │ │
│  │  │                                └──────┬───────┘        │ │ │
│  │  │                                       │ serial         │ │ │
│  │  │       fine_tap[8:0] ──────────> ┌─────┴───────┐        │ │ │
│  │  │       tdr_deskew[8:0] ────────> │  ODELAYE3   │        │ │ │
│  │  │                                 │ 512 taps    │        │ │ │
│  │  │                                 │ @39.0625ps  │        │ │ │
│  │  │                                 └──────┬──────┘        │ │ │
│  │  │                                        │               │ │ │
│  │  │                                 ┌──────┴──────┐        │ │ │
│  │  │                                 │   OBUFDS    │──> LVDS│ │ │
│  │  │                                 └─────────────┘        │ │ │
│  │  └────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌──────────────────┐                                            │
│  │ IDELAYCTRL       │  refclk = 800 MHz (from MMCM)              │
│  │ (共享,每个bank一个)│  为 ODELAYE3/IDELAYE3 提供参考             │
│  └──────────────────┘                                            │
│                                                                   │
│  ┌──────────────────┐                                            │
│  │  MMCM_timing     │  200MHz → VCO 800MHz                       │
│  │                   │  CLKOUT0: 800MHz → IDELAYCTRL refclk      │
│  │                   │  CLKOUT1: 400MHz → OSERDES3 CLK (DDR)     │
│  │                   │  CLKOUT2: 100MHz → OSERDES3 CLKDIV        │
│  └──────────────────┘                                            │
└─────────────────────────────────────────────────────────────────┘
```

## 六、关键风险与缓解

| 风险 | 影响 | 缓解方案 |
|------|------|---------|
| 800MHz IDELAYCTRL时钟稳定性 | tap精度 | MMCM jitter <50ps,可接受 |
| OSERDES3 @400MHz DDR时序收敛 | 输出信号质量 | 约束LOC和PBLOCK,使用专用时钟区域 |
| 16通道×OSERDES3+ODELAYE3资源 | FPGA资源 | 每通道1个OSERDES+1个ODELAY,共16对,资源充裕 |
| Per-channel边沿独立配置延迟 | 通道间skew | TDR deskew功能,出厂校准 |
| LVDS到ADATE305的PCB走线延迟匹配 | 通道间skew | DLC_Board PCB等长布线(已有delay数据) |

## 七、结论

| 项目 | 可行性 | 方案 |
|------|--------|------|
| 39.0625 ps edge resolution | ✅ 可行 | ODELAYE3 @800MHz REFCLK |
| 38 fs vector period resolution | ✅ 可行 | 32-bit DDS相位累加器 |
| Per-channel独立边沿 | ✅ 可行 | 每通道独立OSERDES3+ODELAYE3 |
| TDR deskew | ✅ 可行 | Per-channel ODELAYE3 偏移 |
| ±500 ps edge accuracy | ⚠️ 需验证 | 取决于MMCM jitter + ODELAY精度 |
| ±1.5 ns overall accuracy | ⚠️ 需验证 | 含PCB走线+连接器+ADATE305延迟 |
| 5 vector period edge range | ✅ 可行 | 14-bit coarse counter覆盖 |
| 3.75 ns min edge separation | ✅ 可行 | 3个OSERDES bit @1.25ns/bit |
