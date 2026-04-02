"""ATE Pattern Card Register Definitions
Maps to FPGA register addresses defined in ate_pkg.sv / reg_map.sv
"""

# Device identification
DEVICE_ID = 0xA7E06571
FPGA_VERSION_ADDR = 0x0018

# ============================================================
# Global Registers (0x0000 - 0x00FF)
# ============================================================
REG_DEVICE_ID       = 0x0000
REG_GLOBAL_CTRL     = 0x0004  # [0]=reset, [1]=enable
REG_GLOBAL_STATUS   = 0x0008  # OVD flags
REG_IRQ_ENABLE      = 0x000C
REG_IRQ_STATUS      = 0x0010  # [0]=cal_done, [1]=running, [2]=done, [3]=fail
REG_SELF_CAL_CTRL   = 0x0014  # [0]=start
REG_FPGA_VERSION    = 0x0018

# ============================================================
# Timing Registers (0x0100 - 0x01FF)
# ============================================================
REG_VECTOR_PERIOD      = 0x0104  # DDS period register
REG_VECTOR_PERIOD_FINE = 0x0108

# ============================================================
# Pattern Registers (0x0200 - 0x02FF)
# ============================================================
REG_PAT_CTRL        = 0x0200  # [0]=start, [1]=stop, [2]=abort
REG_PAT_STATUS      = 0x0204  # [0]=running, [1]=done, [2]=fail
REG_PAT_START_ADDR  = 0x0208
REG_PAT_LENGTH      = 0x020C
REG_SITE_ENABLE     = 0x0210

# ============================================================
# Trigger Registers (0x0300 - 0x03FF)
# ============================================================
REG_TRIG_CTRL       = 0x0300
REG_TRIG_STATUS     = 0x0304
REG_TRIG_OUTPUT_MAP = 0x0308
REG_TRIG_LINE_DIR   = 0x030C
REG_TRIG_LINE_FORCE = 0x0310

# ============================================================
# Per-Channel Registers (0x1000 - 0x1FFF)
# Channel N base = 0x1000 + N * 0x100
# ============================================================
def CH_BASE(ch):
    return 0x1000 + ch * 0x100

CH_CTRL         = 0x00  # [1:0] pin_function: 0=Digital, 1=PPMU, 2=Off, 3=Disconnect
CH_STATUS       = 0x04
CH_VIH          = 0x08
CH_VIL          = 0x0C
CH_VTERM        = 0x10
CH_VOH          = 0x14
CH_VOL          = 0x18
CH_IOH          = 0x1C
CH_IOL          = 0x20
CH_VCOM         = 0x24
CH_TERM_MODE    = 0x28  # 0=Hi-Z, 1=VTERM, 2=Active Load
CH_DRIVE_FMT    = 0x2C  # 0=NR, 1=RL, 2=RH, 3=SBC
CH_PPMU_CTRL    = 0x30  # [2:0] ppmu_mode
CH_PPMU_VLEVEL  = 0x34
CH_PPMU_ILEVEL  = 0x38
CH_PPMU_IRANGE  = 0x3C
CH_PPMU_VCLH    = 0x40
CH_PPMU_VCLL    = 0x44
CH_PPMU_APERT   = 0x48
CH_PPMU_MEAS    = 0x4C  # Read-only: measurement result
CH_OVD_STATUS   = 0x50  # Read-only: [1:0] OVD flags
CH_STATIC_STATE = 0x54  # [1:0] 00=low, 01=high, 10=hi-z
CH_EDGE_MULT    = 0x58  # [0] 0=1x, 1=2x
CH_CAL_OFF_VIH  = 0x60
CH_CAL_OFF_VIL  = 0x64
CH_CAL_OFF_VT   = 0x68
CH_CAL_GAIN_I   = 0x6C
CH_CAL_OFF_I    = 0x70

# ============================================================
# SPI Registers (0x2000 - 0x2FFF)
# ============================================================
REG_SPI_CTRL    = 0x2000
REG_SPI_STATUS  = 0x2004
REG_SPI_TX_DATA = 0x2008
REG_SPI_RX_DATA = 0x200C
REG_SPI_CLK_DIV = 0x2014

# ============================================================
# ADC Registers (0x3000 - 0x3FFF)
# ============================================================
REG_ADC_CTRL    = 0x3000
REG_ADC_STATUS  = 0x3004

def REG_ADC_DATA(ch):
    return 0x3008 + ch * 4  # ch 0~15

# ============================================================
# Enumerations
# ============================================================
PIN_DIGITAL    = 0
PIN_PPMU       = 1
PIN_OFF        = 2
PIN_DISCONNECT = 3

TERM_HIZ    = 0
TERM_VTERM  = 1
TERM_ACTIVE = 2

DRV_NR  = 0
DRV_RL  = 1
DRV_RH  = 2
DRV_SBC = 3

PPMU_OFF  = 0
PPMU_FV   = 1
PPMU_FI   = 2
PPMU_MV   = 3
PPMU_FVMI = 4
PPMU_FVMV = 5
PPMU_FIMV = 6
PPMU_FIMI = 7

IRANGE_2UA   = 0
IRANGE_32UA  = 1
IRANGE_128UA = 2
IRANGE_2MA   = 3
IRANGE_32MA  = 4
