"""API unit test — uses SimTransport (no hardware needed)"""

import sys
sys.path.insert(0, '.')
from transport import SimTransport
from ate_card import ATECard
from ate_regs import *


def test_device_id():
    t = SimTransport()
    card = ATECard(t)
    assert card.verify_device(), f"Device ID mismatch: 0x{card.get_device_id():08X}"
    print("  device_id OK")


def test_global_reset():
    t = SimTransport()
    card = ATECard(t)
    card.reset()
    assert t.read32(REG_GLOBAL_CTRL) == 0x02  # Enable, reset released
    print("  reset OK")


def test_channel_levels():
    t = SimTransport()
    card = ATECard(t)
    card.configure_levels(0, vih=0x3000, vil=0x1000, voh=0x2800, vol=0x0800)
    assert t.read32(CH_BASE(0) + CH_VIH) == 0x3000
    assert t.read32(CH_BASE(0) + CH_VIL) == 0x1000
    assert t.read32(CH_BASE(0) + CH_VOH) == 0x2800
    assert t.read32(CH_BASE(0) + CH_VOL) == 0x0800
    print("  channel_levels OK")


def test_multi_channel():
    t = SimTransport()
    card = ATECard(t)
    card.configure_levels([0, 5, 15], vih=0xAAAA)
    assert t.read32(CH_BASE(0) + CH_VIH) == 0xAAAA
    assert t.read32(CH_BASE(5) + CH_VIH) == 0xAAAA
    assert t.read32(CH_BASE(15) + CH_VIH) == 0xAAAA
    print("  multi_channel OK")


def test_all_channels():
    t = SimTransport()
    card = ATECard(t)
    card.set_drive_format("all", DRV_SBC)
    for ch in range(16):
        assert t.read32(CH_BASE(ch) + CH_DRIVE_FMT) == DRV_SBC
    print("  all_channels OK")


def test_pin_function():
    t = SimTransport()
    card = ATECard(t)
    card.select_function(3, PIN_PPMU)
    assert t.read32(CH_BASE(3) + CH_CTRL) == PIN_PPMU
    card.select_function(3, PIN_DIGITAL)
    assert t.read32(CH_BASE(3) + CH_CTRL) == PIN_DIGITAL
    print("  pin_function OK")


def test_ppmu():
    t = SimTransport()
    card = ATECard(t)
    card.ppmu_force_voltage(7, voltage_code=0x8000, current_range=IRANGE_2MA)
    assert t.read32(CH_BASE(7) + CH_PPMU_VLEVEL) == 0x8000
    assert t.read32(CH_BASE(7) + CH_PPMU_IRANGE) == IRANGE_2MA
    assert t.read32(CH_BASE(7) + CH_PPMU_CTRL) == PPMU_FV
    assert t.read32(CH_BASE(7) + CH_CTRL) == PIN_PPMU
    print("  ppmu OK")


def test_pattern_config():
    t = SimTransport()
    card = ATECard(t)
    card.configure_pattern(start_addr=0x100, length=1000, site_enable=0x00FF)
    assert t.read32(REG_PAT_START_ADDR) == 0x100
    assert t.read32(REG_PAT_LENGTH) == 1000
    assert t.read32(REG_SITE_ENABLE) == 0x00FF
    print("  pattern_config OK")


def test_vector_period():
    t = SimTransport()
    card = ATECard(t)
    # 10ns = 0x40000
    card.set_vector_period(0x40000)
    assert t.read32(REG_VECTOR_PERIOD) == 0x40000
    # 20ns = 0x80000
    card.set_vector_period(0x80000)
    assert t.read32(REG_VECTOR_PERIOD) == 0x80000
    print("  vector_period OK")


def test_trigger():
    t = SimTransport()
    card = ATECard(t)
    card.configure_trigger(source=2, edge=1)  # PXI TRIG1, falling
    val = t.read32(REG_TRIG_CTRL)
    assert (val & 0x7) == 2      # source
    assert ((val >> 3) & 0x3) == 1  # edge
    print("  trigger OK")


def test_static_write():
    t = SimTransport()
    card = ATECard(t)
    card.write_static(0, 1)   # Drive high
    assert t.read32(CH_BASE(0) + CH_STATIC_STATE) == 1
    card.write_static(0, 0)   # Drive low
    assert t.read32(CH_BASE(0) + CH_STATIC_STATE) == 0
    print("  static_write OK")


if __name__ == "__main__":
    print("=== ATE Card API Test ===")
    test_device_id()
    test_global_reset()
    test_channel_levels()
    test_multi_channel()
    test_all_channels()
    test_pin_function()
    test_ppmu()
    test_pattern_config()
    test_vector_period()
    test_trigger()
    test_static_write()
    print("=== ALL TESTS PASSED ===")
