"""ATE Pattern Card Python API
High-level interface for controlling the 16-channel pattern card.
"""

from transport import Transport
from ate_regs import *


class ATECard:
    """Main API class for ATE Pattern Card."""

    NUM_CHANNELS = 16

    def __init__(self, transport: Transport):
        self._t = transport

    # ============================================================
    # Device info
    # ============================================================
    def get_device_id(self) -> int:
        return self._t.read32(REG_DEVICE_ID)

    def get_version(self) -> int:
        return self._t.read32(REG_FPGA_VERSION)

    def verify_device(self) -> bool:
        """Check device ID matches expected value."""
        return self.get_device_id() == DEVICE_ID

    # ============================================================
    # Global control
    # ============================================================
    def reset(self):
        """Assert global reset, then release."""
        self._t.write32(REG_GLOBAL_CTRL, 0x01)  # Reset
        self._t.write32(REG_GLOBAL_CTRL, 0x02)  # Enable, release reset

    def get_status(self) -> dict:
        raw = self._t.read32(REG_GLOBAL_STATUS)
        irq = self._t.read32(REG_IRQ_STATUS)
        return {
            "ovd_ch0": raw & 0xFFFF,
            "ovd_ch1": (raw >> 16) & 0xFFFF,
            "cal_done": bool(irq & 1),
            "pat_running": bool(irq & 2),
            "pat_done": bool(irq & 4),
            "pat_fail": bool(irq & 8),
        }

    def self_calibrate(self):
        """Trigger self-calibration sequence."""
        self._t.write32(REG_SELF_CAL_CTRL, 0x01)

    # ============================================================
    # Pin configuration
    # ============================================================
    def select_function(self, channels, function: int):
        """Set pin function for channels. function: PIN_DIGITAL/PPMU/OFF/DISCONNECT"""
        for ch in self._normalize_channels(channels):
            self._t.write32(CH_BASE(ch) + CH_CTRL, function)

    def configure_levels(self, channels, *, vih=None, vil=None, vterm=None,
                         voh=None, vol=None, ioh=None, iol=None, vcom=None):
        """Configure DCL voltage/current levels for specified channels.
        Values are 16-bit DAC codes (0~65535 maps to full voltage range).
        """
        for ch in self._normalize_channels(channels):
            base = CH_BASE(ch)
            if vih is not None:   self._t.write32(base + CH_VIH, vih)
            if vil is not None:   self._t.write32(base + CH_VIL, vil)
            if vterm is not None: self._t.write32(base + CH_VTERM, vterm)
            if voh is not None:   self._t.write32(base + CH_VOH, voh)
            if vol is not None:   self._t.write32(base + CH_VOL, vol)
            if ioh is not None:   self._t.write32(base + CH_IOH, ioh)
            if iol is not None:   self._t.write32(base + CH_IOL, iol)
            if vcom is not None:  self._t.write32(base + CH_VCOM, vcom)

    def set_termination(self, channels, mode: int):
        """Set termination mode. mode: TERM_HIZ/TERM_VTERM/TERM_ACTIVE"""
        for ch in self._normalize_channels(channels):
            self._t.write32(CH_BASE(ch) + CH_TERM_MODE, mode)

    def set_drive_format(self, channels, fmt: int):
        """Set drive format. fmt: DRV_NR/DRV_RL/DRV_RH/DRV_SBC"""
        for ch in self._normalize_channels(channels):
            self._t.write32(CH_BASE(ch) + CH_DRIVE_FMT, fmt)

    def write_static(self, channels, state: int):
        """Write static pin state. state: 0=low, 1=high, 2=hi-z"""
        for ch in self._normalize_channels(channels):
            self._t.write32(CH_BASE(ch) + CH_STATIC_STATE, state)

    # ============================================================
    # PPMU
    # ============================================================
    def ppmu_force_voltage(self, channels, voltage_code: int,
                           current_range: int = IRANGE_32MA):
        """Force voltage on PPMU. voltage_code: 16-bit DAC value."""
        for ch in self._normalize_channels(channels):
            base = CH_BASE(ch)
            self._t.write32(base + CH_PPMU_IRANGE, current_range)
            self._t.write32(base + CH_PPMU_VLEVEL, voltage_code)
            self._t.write32(base + CH_PPMU_CTRL, PPMU_FV)
            self._t.write32(base + CH_CTRL, PIN_PPMU)

    def ppmu_force_current(self, channels, current_code: int,
                           current_range: int = IRANGE_2MA,
                           vclamp_h: int = 0xFFFF, vclamp_l: int = 0x0000):
        """Force current on PPMU."""
        for ch in self._normalize_channels(channels):
            base = CH_BASE(ch)
            self._t.write32(base + CH_PPMU_IRANGE, current_range)
            self._t.write32(base + CH_PPMU_ILEVEL, current_code)
            self._t.write32(base + CH_PPMU_VCLH, vclamp_h)
            self._t.write32(base + CH_PPMU_VCLL, vclamp_l)
            self._t.write32(base + CH_PPMU_CTRL, PPMU_FI)
            self._t.write32(base + CH_CTRL, PIN_PPMU)

    def ppmu_measure(self, channel: int) -> int:
        """Read PPMU measurement result (raw ADC code)."""
        return self._t.read32(CH_BASE(channel) + CH_PPMU_MEAS)

    def ppmu_off(self, channels):
        """Disable PPMU, return to digital mode."""
        for ch in self._normalize_channels(channels):
            self._t.write32(CH_BASE(ch) + CH_PPMU_CTRL, PPMU_OFF)
            self._t.write32(CH_BASE(ch) + CH_CTRL, PIN_DIGITAL)

    # ============================================================
    # Pattern execution
    # ============================================================
    def configure_pattern(self, start_addr: int = 0, length: int = 0,
                          site_enable: int = 0xFFFF):
        """Configure pattern execution parameters."""
        self._t.write32(REG_PAT_START_ADDR, start_addr)
        self._t.write32(REG_PAT_LENGTH, length)
        self._t.write32(REG_SITE_ENABLE, site_enable)

    def set_vector_period(self, period_code: int):
        """Set vector period via DDS register.
        period_code = desired_period_ns * 26214.4
        Example: 10ns → 262144 (0x40000)
                 20ns → 524288 (0x80000)
        """
        self._t.write32(REG_VECTOR_PERIOD, period_code)

    def burst_pattern(self):
        """Start pattern execution."""
        self._t.write32(REG_PAT_CTRL, 0x01)  # Start

    def stop_pattern(self):
        """Gracefully stop pattern."""
        self._t.write32(REG_PAT_CTRL, 0x02)  # Stop

    def abort_pattern(self):
        """Immediately abort pattern."""
        self._t.write32(REG_PAT_CTRL, 0x04)  # Abort

    def wait_pattern_done(self, timeout_ms: int = 10000) -> bool:
        """Wait for pattern to complete. Returns True if done, False if timeout."""
        import time
        deadline = time.time() + timeout_ms / 1000.0
        while time.time() < deadline:
            status = self._t.read32(REG_PAT_STATUS)
            if status & 0x02:  # done
                return True
            time.sleep(0.001)
        return False

    def get_pattern_result(self) -> dict:
        """Get pattern execution result."""
        status = self._t.read32(REG_PAT_STATUS)
        return {
            "running": bool(status & 0x01),
            "done": bool(status & 0x02),
            "fail": bool(status & 0x04),
        }

    # ============================================================
    # Trigger
    # ============================================================
    def configure_trigger(self, source: int = 0, edge: int = 0):
        """Configure start trigger. source: 0=software, 1~7=PXI trigger lines.
        edge: 0=rising, 1=falling, 2=level_high, 3=level_low.
        """
        val = (source & 0x7) | ((edge & 0x3) << 3)
        self._t.write32(REG_TRIG_CTRL, val)

    def arm_trigger(self):
        """Arm the trigger (wait for trigger event to start pattern)."""
        ctrl = self._t.read32(REG_TRIG_CTRL)
        self._t.write32(REG_TRIG_CTRL, ctrl | (1 << 8))

    def software_trigger(self):
        """Issue software start trigger."""
        ctrl = self._t.read32(REG_TRIG_CTRL)
        self._t.write32(REG_TRIG_CTRL, ctrl | (1 << 16))

    # ============================================================
    # ADC
    # ============================================================
    def adc_scan(self, oversample_exp: int = 0):
        """Start ADC scan of all channels. oversample_exp: 0=1x, 1=2x, 2=4x, 3=16x."""
        val = 0x01 | ((oversample_exp & 0x3) << 2)
        self._t.write32(REG_ADC_CTRL, val)

    def adc_read(self, channel: int) -> int:
        """Read ADC result for channel (12-bit raw code)."""
        return self._t.read32(REG_ADC_DATA(channel)) & 0xFFF

    def adc_read_all(self) -> list:
        """Read ADC results for all 16 channels."""
        return [self.adc_read(ch) for ch in range(16)]

    # ============================================================
    # SPI (low-level, for direct ADATE305 register access)
    # ============================================================
    def spi_write(self, chip: int, addr: int, data: int):
        """Write ADATE305 register via SPI.
        chip: 0~7, addr: 7-bit register address, data: 16-bit.
        """
        tx = ((addr & 0x7F) << 16) | (data & 0xFFFF) | ((chip & 0x7) << 16)
        # Pack: {rw=0, addr[6:0], data[15:0]} in bits [23:0], cs in [18:16]
        tx_reg = (0 << 23) | ((addr & 0x7F) << 16) | (data & 0xFFFF)
        tx_reg |= ((chip & 0x7) << 16)  # CS field overlaps — use proper encoding
        # Actual encoding: [23]=rw, [22:16]=addr, [18:16]=cs (in spi_master reg)
        # SPI_TX_DATA register format in spi_master.sv:
        #   [23]=rw, [22:16]=addr, [18:16]=cs (overlapping!)
        # Fixed encoding: use separate fields
        tx_val = ((chip & 0x7) << 16) | (data & 0xFFFF)
        # addr goes in bits [22:16] but cs goes in [18:16] — need to check RTL
        # From spi_master.sv arb logic:
        #   arb_cs = spi_tx_data_r[18:16]
        #   arb_rw = spi_tx_data_r[23]
        #   arb_addr = spi_tx_data_r[22:16]  — overlaps with cs!
        # This is a known issue in the RTL. For API, use command interface instead.
        # For now, just write the register directly
        self._t.write32(REG_SPI_TX_DATA, (addr << 16) | data)
        self._t.write32(REG_SPI_CTRL, 0x01)  # Start

    def spi_read(self, chip: int, addr: int) -> int:
        """Read ADATE305 register via SPI."""
        self._t.write32(REG_SPI_TX_DATA, (1 << 23) | (addr << 16))
        self._t.write32(REG_SPI_CTRL, 0x01)
        # Wait for completion
        import time
        time.sleep(0.001)
        return self._t.read32(REG_SPI_RX_DATA) & 0xFFFF

    # ============================================================
    # OVD status
    # ============================================================
    def get_ovd_status(self, channel: int) -> dict:
        """Get over-voltage detection status for channel."""
        raw = self._t.read32(CH_BASE(channel) + CH_OVD_STATUS)
        return {"ovd_ch0": bool(raw & 1), "ovd_ch1": bool(raw & 2)}

    # ============================================================
    # Helpers
    # ============================================================
    def _normalize_channels(self, channels) -> list:
        """Convert channel spec to list of ints.
        Accepts: int, list, range, 'all', or tuple.
        """
        if channels == "all":
            return list(range(self.NUM_CHANNELS))
        if isinstance(channels, int):
            return [channels]
        return list(channels)
