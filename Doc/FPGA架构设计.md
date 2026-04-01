# FPGA架构设计 — XCKU035 Pattern Card

## 一、FPGA资源与引脚分配概览

### 1.1 FPGA型号
**XCKU035-2FFVA1156I** (Xilinx UltraScale Kintex)
- Logic Cells: ~443K
- BRAM: 21.1 Mb (540 × 36Kb)
- DSP Slices: 1700
- GTH Transceivers: 16 (12.5 Gb/s)
- HP I/O: 312, HR I/O: 104
- PCIe Gen3x8 硬核

### 1.2 Bank分配

| FPGA Bank | 类型 | VCCO | 用途 | 连接目标 |
|-----------|------|------|------|---------|
| Bank 0 | Config | 3.3V | QSPI Flash, JTAG, I2C温度传感器 | N25Q128A, TMP451 |
| Bank 44 | HP | 1.5V | DDR3 Memory (Addr/Ctrl) | DDR3 SDRAM |
| Bank 45 | HP | 1.5V | DDR3 Memory (Data) | DDR3 SDRAM |
| Bank 46 | HP | 1.5V | DDR3 Memory (Data) | DDR3 SDRAM |
| Bank 47 | HP | 1.8V | BTB连接器 → ADATE305 LVDS信号 | DLC_Board |
| Bank 48 | HP | 1.8V | BTB连接器 → ADATE305 LVDS信号 | DLC_Board |
| Bank 64 | HR | 1.8V | BTB连接器 → SPI/OVD/杂项信号 | DLC_Board |
| Bank 66 | HP | 1.8V | PXIe Trigger Bus, DSTAR | PXIe背板 |
| Bank 67 | HP | 1.8V | BTB连接器 → ADATE305 LVDS信号 | DLC_Board |
| Bank 68 | HP | 1.8V | BTB连接器 → ADATE305 LVDS信号 | DLC_Board |
| Bank 224/225 | MGT | - | PCIe Gen2x4 | PXIe背板 |
| Bank 226/227 | MGT | - | PCIe Gen2x4 (备用) | PXIe背板 |

### 1.3 时钟资源

| 时钟源 | 频率 | 类型 | 用途 |
|--------|------|------|------|
| G1 (SIT9121AI) | 200 MHz | LVDS差分 | DDR3 MIG参考时钟 |
| G2 (SIT9121AI) | 125 MHz | LVDS差分 | PCIe参考时钟 |
| G3 (SIT9121AI) | 200 MHz | LVDS差分 | 系统主时钟 / Pattern Engine |
| U11 (SIT1602BI) | 66 MHz | 单端LVCMOS | EMCCLK / 慢速外设时钟 |
| PXIe_CLK100 | 100 MHz | LVDS差分 | PXIe同步基准时钟 |

## 二、顶层架构框图

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          XCKU035 FPGA Top Level                             │
│                                                                              │
│  ┌──────────────┐    AXI4     ┌─────────────────────────────────────┐        │
│  │  PCIe Gen2x4 │◄══════════►│         AXI Interconnect            │        │
│  │  Endpoint    │            │         (AXI4/AXI4-Lite)            │        │
│  │  (Xilinx IP) │            └──┬──────┬──────┬──────┬──────┬──┬──┘        │
│  └──────┬───────┘               │      │      │      │      │  │           │
│         │ PCIe                  │      │      │      │      │  │           │
│         │ Lanes                 ▼      ▼      ▼      ▼      ▼  ▼           │
│      ┌──┴──┐              ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐      │
│      │ MGT │              │DDR3│ │PAT │ │TIM │ │SPI │ │CAL │ │REG │      │
│      │Bank │              │Ctrl│ │ENG │ │ENG │ │MST │ │MOD │ │MAP │      │
│      │224/ │              │    │ │    │ │    │ │    │ │    │ │    │      │
│      │225  │              └──┬─┘ └─┬──┘ └─┬──┘ └─┬──┘ └──┬─┘ └────┘      │
│      └─────┘                 │     │      │      │       │                 │
│                              │     │      │      │       │                 │
│  ┌──────────────┐            │     ▼      ▼      │       │                 │
│  │  DDR3 MIG    │◄═══════════╝  ┌──────────┐     │       │                 │
│  │  Controller  │               │ Pattern  │     │       │                 │
│  │  (Xilinx IP) │               │ Data     │     │       │                 │
│  └──────┬───────┘               │ Path     │     │       │                 │
│         │ DDR3                  └────┬─────┘     │       │                 │
│         │ Interface                  │           │       │                 │
│      ┌──┴──┐                        ▼           ▼       │                 │
│      │Bank │              ┌──────────────────────────┐   │                 │
│      │44/  │              │   Channel Controller     │   │                 │
│      │45/46│              │   × 16 instances         │   │                 │
│      └─────┘              │                          │   │                 │
│                           │  ┌──────┐  ┌──────────┐ │   │                 │
│                           │  │Drive │  │Compare   │ │   │                 │
│                           │  │Format│  │& Capture │ │   │                 │
│                           │  │Logic │  │Logic     │ │   │                 │
│                           │  └──┬───┘  └────┬─────┘ │   │                 │
│                           └─────┼───────────┼───────┘   │                 │
│                                 │           │           │                 │
│  ┌──────────────┐              ▼           ▼           │                 │
│  │ Clock Mgmt   │    ┌──────────────────────────────┐  │                 │
│  │              │    │    LVDS I/O Interface         │  │                 │
│  │ PXIe_CLK100 ├───►│    (ISERDES / OSERDES)       │  │                 │
│  │ 200MHz SYS  │    └──────────┬────────────────────┘  │                 │
│  │ PLL / MMCM  │               │ LVDS                  │                 │
│  └──────────────┘            ┌──┴──┐                    │                 │
│                              │Bank │                    │                 │
│  ┌──────────────┐            │47/48│                    │                 │
│  │ Trigger Bus  │            │67/68│                    │                 │
│  │ Interface    │            └─────┘                    │                 │
│  └──────┬───────┘                                       │                 │
│      ┌──┴──┐              ┌──────────────────────────┐  │                 │
│      │Bank │              │  SPI / OVD / ADC I/O     │◄─┘                 │
│      │ 66  │              │  (Bank 64, HR)           │                    │
│      └─────┘              └──────────┬───────────────┘                    │
│                                   ┌──┴──┐                                 │
│                                   │Bank │                                 │
│                                   │ 64  │                                 │
│                                   └─────┘                                 │
└──────────────────────────────────────────────────────────────────────────────┘
                                     │
                              BTB Connector × 4
                                     │
                                     ▼
                              DLC_Board (前端板)
                         8 × ADATE305 + 2 × ADS7959
```

## 三、模块详细设计

### 3.1 PCIe接口模块 (pcie_wrapper)

```
模块: pcie_wrapper
├── Xilinx UltraScale PCIe Gen2x4 Endpoint IP
├── AXI-MM Bridge (PCIe ↔ AXI4)
├── DMA Engine (Scatter-Gather DMA)
│   ├── H2C Channel (Host → Card): Pattern数据下载
│   ├── C2H Channel (Card → Host): Capture数据上传, PPMU测量结果
│   └── Descriptor管理
├── Interrupt Controller (MSI-X)
│   ├── Pattern完成中断
│   ├── 比较失败中断
│   ├── OVD报警中断
│   └── 校准完成中断
└── BAR空间映射
    ├── BAR0: 寄存器空间 (AXI4-Lite, 64KB)
    └── BAR1: Vector Memory直接访问 (AXI4-MM, 可选)
```

**关键参数**:
- PCIe Gen2 x4: 理论带宽 2 GB/s (每方向)
- DMA引擎: 支持 Scatter-Gather 描述符链
- 中断: MSI-X, 最多16个中断向量

### 3.2 寄存器映射模块 (reg_map)

```
地址空间 (BAR0, AXI4-Lite):

0x0000 - 0x00FF: 全局控制寄存器
  0x0000: DEVICE_ID / VERSION
  0x0004: GLOBAL_CTRL (复位, 使能)
  0x0008: GLOBAL_STATUS (忙, 错误, OVD)
  0x000C: INTERRUPT_ENABLE
  0x0010: INTERRUPT_STATUS
  0x0014: SELF_CAL_CTRL
  0x0018: SELF_CAL_STATUS
  0x001C: CAL_INFO (上次校准日期/温度)

0x0100 - 0x01FF: 时钟与时序控制
  0x0100: CLOCK_CTRL (时钟源选择, 分频)
  0x0104: VECTOR_RATE (10ns ~ 40μs)
  0x0108: VECTOR_PERIOD_FINE (38fs分辨率)
  0x0110: TIMESET_0 ~ TIMESET_30 (31组时序集)
    每组: DRIVE_ON, DRIVE_DATA, DRIVE_RETURN, DRIVE_OFF,
          COMPARE_STROBE, DRIVE_DATA2, DRIVE_RETURN2, STROBE2

0x0200 - 0x02FF: Pattern控制
  0x0200: PATTERN_CTRL (Start, Stop, Abort)
  0x0204: PATTERN_STATUS (Running, Done, Fail)
  0x0208: PATTERN_START_ADDR
  0x020C: PATTERN_LENGTH
  0x0210: SITE_ENABLE (bit[15:0] = 16 sites)
  0x0214: FAIL_MASK
  0x0218: HRAM_CTRL (History RAM配置)

0x0300 - 0x03FF: Trigger控制
  0x0300: TRIGGER_CTRL
  0x0304: TRIGGER_STATUS
  0x0308: PXI_TRIG_MAP (PXI触发线映射)

0x1000 - 0x1FFF: Per-Channel寄存器 (16通道 × 0x100每通道)
  基址 = 0x1000 + channel_id × 0x100
  +0x00: CH_CTRL (模式选择: Digital/PPMU/Off/Disconnect)
  +0x04: CH_STATUS
  +0x08: VIH (Driver高电平, 14-bit DAC值)
  +0x0C: VIL (Driver低电平)
  +0x10: VTERM (终端电压)
  +0x14: VOH (Comparator高阈值)
  +0x18: VOL (Comparator低阈值)
  +0x1C: IOH (Active Load高电流)
  +0x20: IOL (Active Load低电流)
  +0x24: VCOM (Active Load换向电压)
  +0x28: TERMINATION_MODE (Hi-Z / VTERM / Active Load)
  +0x2C: DRIVE_FORMAT (NR / RL / RH / SBC)
  +0x30: PPMU_CTRL (FV/FI/MV/MI模式)
  +0x34: PPMU_VOLTAGE_LEVEL
  +0x38: PPMU_CURRENT_LEVEL
  +0x3C: PPMU_CURRENT_RANGE
  +0x40: PPMU_VOLTAGE_CLAMP_H
  +0x44: PPMU_VOLTAGE_CLAMP_L
  +0x48: PPMU_APERTURE_TIME
  +0x4C: PPMU_MEASURE_RESULT
  +0x50: OVD_STATUS
  +0x54: STATIC_STATE (静态驱动状态)
  +0x58: EDGE_MULTIPLIER (1x / 2x)
  +0x60: CAL_OFFSET_VIH (校准偏移)
  +0x64: CAL_OFFSET_VIL
  +0x68: CAL_OFFSET_VTERM
  +0x6C: CAL_GAIN_PPMU_I (校准增益)
  +0x70: CAL_OFFSET_PPMU_I

0x2000 - 0x2FFF: SPI控制寄存器
  0x2000: SPI_CTRL
  0x2004: SPI_STATUS
  0x2008: SPI_TX_DATA
  0x200C: SPI_RX_DATA
  0x2010: SPI_CS_SELECT (芯片选择, 16位 → 8片×2通道)

0x3000 - 0x3FFF: ADC控制寄存器
  0x3000: ADC_CTRL
  0x3004: ADC_STATUS
  0x3008: ADC_DATA[0..15] (16通道MEASOUT读数)
  0x3048: ADC_DAC16_MON[0..15]

0x4000 - 0x4FFF: 校准常数存储 (Flash读写接口)
  0x4000: CAL_FLASH_CTRL
  0x4004: CAL_FLASH_ADDR
  0x4008: CAL_FLASH_WDATA
  0x400C: CAL_FLASH_RDATA
```

### 3.3 Pattern Engine (pattern_engine)

```
模块: pattern_engine
│
├── Sequencer (指令解码与执行)
│   ├── 指令获取 (从DDR3 Vector Memory)
│   ├── Opcode解码器
│   │   ├── repeat / jump / jump_if
│   │   ├── set_loop / end_loop / exit_loop / exit_loop_if
│   │   ├── call / return (调用栈, 深度8)
│   │   ├── halt / keep_alive
│   │   ├── match (跨通道结果匹配)
│   │   ├── set_signal / pulse_signal / clear_signal
│   │   ├── reset_trigger
│   │   ├── set_seqflag / clear_seqflag / write_reg
│   │   ├── capture_start / capture / capture_stop
│   │   ├── source_start / source / source_d_replace
│   │   └── scan
│   ├── 循环计数器 (嵌套循环, 深度8)
│   ├── 调用栈 (深度8)
│   └── Sequencer Flags / Registers
│
├── Vector Memory Interface
│   ├── DDR3 AXI4 读接口 (预取缓冲)
│   ├── Vector解压缩 (针对scan向量的压缩)
│   ├── 预取FIFO (隐藏DDR3延迟)
│   └── 每通道Pin State提取
│       16通道 × {drive_data, compare_data, timeset_id}
│
├── Source Engine (最多8个site)
│   ├── Source Memory (BRAM, 32MB total)
│   ├── Source数据分发到通道
│   └── 串行/并行模式
│
├── Capture Engine (最多8个site)
│   ├── Capture Memory (BRAM, 1M samples)
│   ├── 从比较结果采集数据
│   └── 串行/并行模式
│
├── History RAM (HRAM)
│   ├── 8192/N_sites 深度
│   ├── 记录失败cycle信息
│   └── 可配置触发条件
│
└── Match/Fail Logic
    ├── 每通道比较结果汇总
    ├── 80-cycle pipeline延迟
    └── 跨板卡结果合并 (通过Trigger Bus)
```

**Vector格式** (每条vector在DDR3中的存储):
```
Bit Field:
[127:112] - Opcode (16 bits)
[111:96]  - Opcode Operand (16 bits)
[95:80]   - TimeSet ID (5 bits) + Reserved
[79:64]   - Channel 15~8 Pin States (2 bits × 8)
[63:48]   - Channel 7~0 Pin States (2 bits × 8)
[47:32]   - Reserved / Source-Capture flags
[31:0]    - Loop count / Jump address / Operand data

Pin State编码 (2 bits):
  00 = Drive 0
  01 = Drive 1
  10 = Compare (L/H/V/M按timeset配置)
  11 = Hi-Z / Mask (X)
```

### 3.4 Timing Engine (timing_engine)

```
模块: timing_engine
│
├── Master Clock Generator
│   ├── MMCM/PLL (from 200MHz → 可编程输出)
│   ├── Vector Period Counter (10ns ~ 40μs)
│   └── Fine Phase Shifter (38fs分辨率, 使用ODELAY)
│
├── TimeSet Manager (31组时序集)
│   每组TimeSet包含8个边沿:
│   ├── drive_on_edge    (驱动器开启)
│   ├── drive_data_edge  (数据边沿)
│   ├── drive_return_edge(返回边沿)
│   ├── drive_off_edge   (驱动器关闭)
│   ├── compare_strobe   (比较采样沿)
│   ├── drive_data2_edge (2x模式第二数据沿)
│   ├── drive_return2_edge(2x模式第二返回沿)
│   └── compare_strobe2  (2x模式第二采样沿)
│   边沿范围: 0ns ~ 5个vector周期 (或40μs)
│   分辨率: 39.0625 ps (使用ODELAYE3/IDELAYE3)
│
├── Per-Channel Edge Generator × 16
│   ├── Drive Format State Machine
│   │   ├── NR (Non-Return): data → hold
│   │   ├── RL (Return Low): data → low
│   │   ├── RH (Return High): data → high
│   │   └── SBC (Surround by Complement): comp → data → comp
│   ├── ODELAYE3 (输出延迟精调)
│   ├── IDELAYE3 (输入延迟精调, 用于compare strobe)
│   └── TDR Deskew Adjustment (39.0625ps分辨率)
│
└── Edge Multiplier (1x / 2x)
    ├── 1x: 标准模式, 最高100MHz
    └── 2x: 双边沿模式, 最高200Mbps等效
```

**关键时序约束**:
- 驱动数据变化之间最小间隔: 3.75 ns
- Drive On 到 Drive Off 最小间隔: 5 ns
- Compare Strobe 之间最小间隔: 5 ns
- 边沿放置精度: ±500 ps (warranted)
- 总体时序精度: ±1.5 ns (warranted)

### 3.5 Channel Controller (channel_ctrl × 16)

```
模块: channel_ctrl (每通道一个实例)
│
├── Pin State Machine
│   ├── Digital模式
│   │   ├── Drive: 根据Pattern data + Drive Format生成输出
│   │   ├── Compare: 采样RCV信号与VOH/VOL比较
│   │   ├── Active Load: 控制IOH/IOL/VCOM
│   │   └── Termination: Hi-Z / VTERM / Active Load
│   ├── PPMU模式
│   │   ├── Force Voltage / Force Current
│   │   ├── Measure Voltage / Measure Current
│   │   └── Clamp Control
│   ├── Off模式 (电气连接, PPMU和Driver关闭)
│   └── Disconnect模式 (电气断开)
│
├── ADATE305 SPI Register Cache
│   ├── 影子寄存器 (减少SPI通信)
│   ├── 14-bit DAC值 → VIH/VIL/VT/VOH/VOL/IOH/IOL/VCOM
│   ├── 16-bit DAC值 → PPMU电压/电流
│   └── 模式/使能控制
│
├── Calibration Compensator
│   ├── DAC值 = 理想值 + 校准偏移 + 增益校正
│   ├── 查表补偿 (INL校正)
│   └── 温度漂移补偿 (可选)
│
├── LVDS Serializer (OSERDES3)
│   ├── DATA_P/N: 发送到ADATE305的驱动数据
│   └── DATA1_P/N: 双通道时的第二数据
│
├── LVDS Deserializer (ISERDES3)
│   ├── RCV_P/N: 接收ADATE305的比较结果
│   ├── COMP_QH_P/N: 高阈值比较结果
│   └── COMP_QL_P/N: 低阈值比较结果
│
└── Compare & Fail Logic
    ├── 期望值 vs 实际比较结果
    ├── Pass/Fail标志
    └── 结果输出到History RAM
```

### 3.6 SPI Master Controller (spi_master)

```
模块: spi_master
│
├── SPI物理层
│   ├── SCLK: 最高25MHz (ADATE305限制)
│   ├── SDIN: FPGA → ADATE305
│   ├── SDOUT: ADATE305 → FPGA
│   ├── CS: 8片独立片选 (每片2通道共享SPI)
│   └── RST: 全局复位 (ALL0_SPI_RST)
│
├── SPI事务调度器
│   ├── 优先级仲裁 (紧急更新 > 批量配置)
│   ├── Broadcast模式 (同时写多片相同数据)
│   └── Sequential模式 (逐片独立配置)
│
├── ADATE305寄存器控制
│   ├── DAC配置 (14-bit: VIH/VIL/VT等, 16-bit: PMU levels)
│   ├── 模式切换 (Driver/Comparator/PMU/Hi-Z)
│   ├── OVD配置
│   ├── Temperature Sensor读取
│   └── HVOUT控制
│
└── 批量更新引擎
    ├── Level Change: 在vector间隙更新DAC值
    ├── 预计算SPI帧队列
    └── 双缓冲 (不影响正在执行的pattern)
```

**SPI通信时间预算**:
- ADATE305 SPI: 24-bit帧, SCLK最高25MHz
- 单次写: 24/25MHz = 0.96 μs
- 配置一个通道的全部DAC (约10个寄存器): ~10 μs
- 配置全部16通道: ~160 μs (sequential) 或 ~20 μs (8片broadcast)

### 3.7 ADC Control (adc_ctrl)

```
模块: adc_ctrl
│
├── ADS7959 SPI Interface × 2
│   ├── SCLK: 最高18MHz
│   ├── SDO: ADC数据输出
│   ├── SDI: ADC配置输入
│   └── CS: 片选
│
├── Channel MUX Control
│   ├── ADATE305 MEASOUT → ADC输入 (通过ADATE305内部MUX)
│   ├── ADATE305 DAC16_MON → ADC输入
│   └── MEASOUT选择: PMU电流/电压, 温度
│
├── 采样序列控制器
│   ├── 自动扫描模式 (按通道轮询)
│   ├── 单通道模式 (指定通道采样)
│   └── 过采样平均 (提高有效分辨率)
│
└── 数据处理
    ├── 12-bit原始数据 → 校准后电压/电流值
    ├── 校准系数应用
    └── 结果存入寄存器供主机读取
```

**ADC精度说明**:
- ADS7959: 12-bit, 1MSPS, 8通道MUX
- 2片ADC × 8通道 = 16通道 MEASOUT
- 有效分辨率: 12-bit → ~1.22mV/LSB (5V range)
- 4倍过采样: 有效提升至~13-bit
- 16倍过采样: 有效提升至~14-bit (但速度降低)

### 3.8 DDR3 Memory Controller (ddr3_ctrl)

```
模块: ddr3_ctrl
│
├── Xilinx MIG IP (DDR3 SDRAM Controller)
│   ├── DDR3-1600 (800MHz DDR)
│   ├── 数据宽度: 32-bit (或64-bit, 视PCB)
│   └── 容量: 取决于DDR3颗粒 (256MB ~ 2GB)
│
├── AXI4接口
│   ├── 读端口: Pattern Engine读取Vector数据
│   ├── 写端口: DMA写入Vector数据
│   └── 仲裁: 读优先 (Pattern执行时)
│
└── Vector Memory映射
    ├── Vector存储区 (大部分容量)
    ├── Source Waveform存储区
    └── 校准常数暂存区
```

**Vector Memory容量计算**:
- 每条Vector: 128 bits = 16 bytes
- 256MB DDR3: 256M / 16 = 16M vectors
- 512MB DDR3: 32M vectors
- 1GB DDR3: 64M vectors
- 目标: 128M vectors → 需要2GB DDR3 (或使用压缩)

### 3.9 Trigger Bus Interface (trigger_intf)

```
模块: trigger_intf
│
├── PXI Trigger Lines (Bank 66)
│   ├── TRIG_18_1 ~ TRIG_18_7 (7条PXI触发线)
│   └── 双向，可配置输入/输出
│
├── DSTAR Lines (差分星型触发)
│   ├── DSTARB+/- (差分)
│   └── DSTARC+/- (差分)
│
├── Trigger控制器
│   ├── Start Trigger: 启动Pattern执行
│   ├── 条件触发: 基于Sequencer Flag
│   ├── 输出触发: Pattern完成/失败通知
│   └── 跨板卡同步: 多板协同执行
│
└── NI-TClk同步支持
    ├── PXIe_CLK100同步
    └── 多板卡时钟对齐
```

### 3.10 Clock Management (clock_mgmt)

```
模块: clock_mgmt
│
├── MMCM_0: Pattern Engine时钟
│   ├── 输入: 200MHz (G3)
│   ├── 输出0: pattern_clk (100MHz, 主Pattern时钟)
│   ├── 输出1: pattern_clk_2x (200MHz, 2x edge multiplier)
│   ├── 输出2: pattern_clk_div (可编程分频, 慢速pattern)
│   └── 动态重配置: 支持运行时改变Vector Rate
│
├── MMCM_1: SPI / ADC外设时钟
│   ├── 输入: 200MHz (G3) 或 66MHz (U11)
│   ├── 输出0: spi_clk (25MHz, ADATE305 SPI)
│   └── 输出1: adc_clk (18MHz, ADS7959 SPI)
│
├── PXIe_CLK100 Buffer
│   ├── IBUFDS → BUFG
│   └── 用于Trigger同步和频率计数器参考
│
├── DDR3参考时钟
│   ├── 200MHz (G1) → MIG IP
│   └── 固定配置
│
└── PCIe参考时钟
    ├── 125MHz (G2) → PCIe IP refclk
    └── 固定配置 (或由PXIe背板提供)
```

### 3.11 Calibration Module (cal_module)

```
模块: cal_module
│
├── Self-Calibration Controller
│   ├── 序列:
│   │   1. 通过SPI读取ADATE305温度传感器
│   │   2. 通过ADC测量板载VREF (ADR431 5V)
│   │   3. 通过ADC测量0V参考
│   │   4. 计算电压参考偏移/增益校准系数
│   │   5. 通过SPI配置ADATE305输出已知电阻参考
│   │   6. 通过ADC测量→计算电阻校准系数
│   │   7. 更新所有通道校准常数
│   │   8. 存储校准日期/温度到Flash
│   └── 触发: 软件命令 或 上电自动执行
│
├── Calibration Constant Storage
│   ├── Flash接口 (存储持久校准数据)
│   ├── BRAM Cache (运行时快速访问)
│   └── 每通道校准数据:
│       ├── voltage_offset[14-bit DAC]
│       ├── voltage_gain[14-bit DAC]
│       ├── pmu_voltage_offset[16-bit DAC]
│       ├── pmu_voltage_gain[16-bit DAC]
│       ├── pmu_current_offset[5 ranges]
│       ├── pmu_current_gain[5 ranges]
│       ├── comparator_offset
│       ├── resistor_reference
│       └── cal_temperature, cal_date
│
├── External Calibration Interface
│   ├── 密码保护 (默认: "NATI")
│   ├── 校准路径选择 (Voltage Ref / Resistor Ref / Current)
│   ├── 校准参考配置 (连接CAL引脚到内部参考)
│   ├── 调整写入接口
│   └── 校准会话管理 (Open/Close/Commit)
│
└── DAC Compensation Engine
    ├── 输入: 理想DAC代码
    ├── 处理: code_out = (code_in × gain) + offset
    ├── 查表: INL校正表 (可选, 用BRAM)
    └── 输出: 补偿后DAC代码 → SPI写入ADATE305
```

## 四、数据流架构

### 4.1 Pattern执行数据流

```
Host PC                     FPGA                              DLC_Board
  │                          │                                    │
  │ 1. 下载Vector数据        │                                    │
  │ ══════PCIe DMA═══════>  │                                    │
  │                     ┌────┴────┐                               │
  │                     │  DDR3   │                               │
  │                     │ Vector  │                               │
  │                     │ Memory  │                               │
  │                     └────┬────┘                               │
  │ 2. 配置Levels/Timing    │                                    │
  │ ════PCIe Register══> ┌──┴──┐                                 │
  │                      │ SPI │──SPI──> ADATE305 DAC配置         │
  │                      │ Mst │                                  │
  │                      └─────┘                                  │
  │ 3. Burst Pattern         │                                    │
  │ ════PCIe Register══> ┌──┴──────┐                              │
  │                      │ Pattern │                              │
  │                      │ Engine  │                              │
  │                      └──┬──────┘                              │
  │                         │ Vector Data (per cycle)             │
  │                    ┌────┴─────┐                               │
  │                    │ Timing   │                               │
  │                    │ Engine   │                               │
  │                    └────┬─────┘                               │
  │                         │ Timed Drive/Compare signals         │
  │                    ┌────┴─────┐     LVDS      ┌────────────┐ │
  │                    │ Channel  │══════════════> │ ADATE305   │ │
  │                    │ Ctrl×16  │ DATA_P/N       │ Driver     │──>DUT
  │                    │          │<══════════════ │ Comparator │<──DUT
  │                    └────┬─────┘ RCV/COMP       └────────────┘ │
  │                         │                                     │
  │                    ┌────┴─────┐                               │
  │                    │ Compare  │                               │
  │                    │ & HRAM   │                               │
  │                    └────┬─────┘                               │
  │ 4. 读取结果              │                                    │
  │ <════PCIe Register═══ Pass/Fail, HRAM data                    │
  │ <════PCIe DMA═══════ Capture data                             │
```

### 4.2 PPMU测量数据流

```
Host PC                     FPGA                              DLC_Board
  │                          │                                    │
  │ 1. 设PPMU模式+电平       │                                    │
  │ ════PCIe Register══> ┌──┴──┐                                 │
  │                      │ SPI │──SPI──> ADATE305                 │
  │                      │ Mst │   设定PMU模式, 16-bit DAC电平      │
  │                      └─────┘                                  │
  │                                          │                    │
  │ 2. PPMU Source                   ADATE305│PMU Force ──> DUT   │
  │                                          │                    │
  │ 3. PPMU Measure                          │                    │
  │ ════PCIe Register══> ┌──┴──┐    MEASOUT  │                    │
  │                      │ ADC │<═══════════ │ ADATE305           │
  │                      │Ctrl │  ADS7959    │ MEASOUT pin        │
  │                      └──┬──┘             │                    │
  │                         │ 12-bit ADC data│                    │
  │                    ┌────┴─────┐          │                    │
  │                    │   Cal    │          │                    │
  │                    │ Compen.  │          │                    │
  │                    └────┬─────┘          │                    │
  │ 4. 读取测量结果          │                │                    │
  │ <════PCIe Register═══ 校准后V/I值         │                    │
```

## 五、FPGA资源估算

| 模块 | LUT | FF | BRAM (36Kb) | DSP | 备注 |
|------|-----|-----|-------------|-----|------|
| PCIe Gen2x4 EP | ~15K | ~20K | 20 | 0 | Xilinx IP |
| AXI Interconnect | ~5K | ~5K | 5 | 0 | Xilinx IP |
| DDR3 MIG | ~10K | ~15K | 10 | 0 | Xilinx IP |
| Pattern Engine | ~30K | ~25K | 50 | 4 | Sequencer+Opcode |
| Timing Engine | ~10K | ~15K | 10 | 0 | 31 TimeSet |
| Channel Ctrl ×16 | ~40K | ~30K | 32 | 16 | OSERDES/ISERDES |
| SPI Master | ~3K | ~3K | 2 | 0 | |
| ADC Control | ~2K | ~2K | 2 | 2 | |
| Source Engine | ~5K | ~5K | 64 | 0 | 32MB BRAM |
| Capture Engine | ~3K | ~3K | 20 | 0 | 1M samples |
| History RAM | ~2K | ~2K | 16 | 0 | 8192 entries |
| Trigger Interface | ~2K | ~2K | 0 | 0 | |
| Clock Management | ~1K | ~1K | 0 | 0 | MMCM/PLL |
| Calibration | ~5K | ~5K | 10 | 4 | 补偿计算 |
| Register Map | ~5K | ~5K | 5 | 0 | |
| **总计** | **~138K** | **~138K** | **~246** | **~26** | |
| **XCKU035容量** | **~275K** | **~550K** | **540** | **1700** | |
| **利用率** | **~50%** | **~25%** | **~46%** | **~2%** | 余量充足 |

## 六、关键接口时序

### 6.1 ADATE305 LVDS数据接口

```
Pattern时钟 (100MHz)
    │     │     │     │     │     │
    ▼     ▼     ▼     ▼     ▼     ▼
────┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
    └──┘  └──┘  └──┘  └──┘  └──┘

DATA_P/N (LVDS, 100Mbps DDR or 100Mbps SDR):
    ┌─────┐     ┌─────┐     ┌─────┐
    │ D0  │ D1  │ D2  │ D3  │ D4  │
────┘     └─────┘     └─────┘     └──

RCV_P/N (LVDS, 比较结果返回):
         ┌─────┐     ┌─────┐
    ─────┤ R0  │ R1  │ R2  │
         └─────┘─────└─────┘

ADATE305最小脉冲宽度: 1.6ns (2V terminated)
FPGA OSERDES: 支持最高1.25Gbps LVDS
```

### 6.2 SPI通信时序

```
CS ──────┐                                          ┌──────
         └──────────────────────────────────────────┘
SCLK     ────┐  ┌──┐  ┌──┐  ┌──┐      ┌──┐  ┌──┐  ┌────
              └──┘  └──┘  └──┘  └─ ... ─┘  └──┘  └──┘
SDIN     ─────X D23 X D22 X D21 X ... X D1  X D0  X──────
              │<─────── 24-bit frame ──────────────>│

SCLK频率: 最高25MHz
帧格式: [R/W(1)] [ADDR(7)] [DATA(16)]
全部16通道配置时间: ~160μs (sequential)
```

## 七、FPGA开发里程碑

| 阶段 | 内容 | 关键交付物 |
|------|------|-----------|
| M1 | PCIe + Register Map | PCIe通信、寄存器读写、DMA验证 |
| M2 | SPI Master + ADATE305配置 | 16通道DAC电平可控 |
| M3 | DDR3 MIG + Vector Memory | Vector数据上下载 |
| M4 | Pattern Engine (基础) | Sequencer、基本opcode执行 |
| M5 | Timing Engine | 100MHz vector rate、31 TimeSet |
| M6 | Channel Controller + LVDS | 16通道Drive/Compare |
| M7 | PPMU + ADC | Force/Measure电压电流 |
| M8 | Source/Capture Engine | 数字源和捕获 |
| M9 | Calibration Module | 自校准、外部校准支持 |
| M10 | Trigger + 多板同步 | PXI触发、NI-TClk |
| M11 | 系统集成与优化 | 全功能联调、性能优化 |
