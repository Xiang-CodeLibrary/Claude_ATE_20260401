"""ATE Pattern Card — Usage Example

Demonstrates typical workflow:
1. Connect to device
2. Configure levels
3. Load pattern
4. Execute and check results
"""

from transport import SimTransport, PCIeTransport
from ate_card import ATECard
from ate_regs import *


def main():
    # For hardware: use PCIeTransport()
    # For development: use SimTransport()
    transport = SimTransport()

    with transport:
        card = ATECard(transport)

        # Verify device
        if not card.verify_device():
            print(f"ERROR: Wrong device ID 0x{card.get_device_id():08X}")
            return
        print(f"Device: 0x{card.get_device_id():08X}  Version: 0x{card.get_version():08X}")

        # Reset
        card.reset()

        # Configure all 16 channels for digital mode
        card.select_function("all", PIN_DIGITAL)
        card.set_termination("all", TERM_VTERM)
        card.set_drive_format("all", DRV_NR)

        # Set typical LVCMOS33 levels
        # VIH=2.4V, VIL=0.4V, VOH=2.0V, VOL=0.8V, VTERM=1.5V
        # DAC code = voltage / full_scale * 65535
        # ADATE305 range: -2V to +6V (8V span), 14-bit DAC
        # code = (voltage + 2.0) / 8.0 * 16383
        def v_to_code(v):
            return int((v + 2.0) / 8.0 * 16383) & 0xFFFF

        card.configure_levels("all",
            vih=v_to_code(2.4),
            vil=v_to_code(0.4),
            voh=v_to_code(2.0),
            vol=v_to_code(0.8),
            vterm=v_to_code(1.5),
        )
        print("Levels configured: LVCMOS33 (VIH=2.4V VIL=0.4V VOH=2.0V VOL=0.8V)")

        # Set vector period to 10ns (100MHz)
        card.set_vector_period(0x40000)
        print("Vector rate: 100 MHz")

        # Configure pattern
        card.configure_pattern(start_addr=0, length=1000, site_enable=0xFFFF)

        # Execute pattern
        card.burst_pattern()
        print("Pattern burst started...")

        done = card.wait_pattern_done(timeout_ms=5000)
        result = card.get_pattern_result()
        print(f"Result: done={result['done']}, fail={result['fail']}")

        # PPMU example: measure leakage on channel 0
        print("\nPPMU leakage test on CH0:")
        card.ppmu_force_voltage(0, voltage_code=v_to_code(3.3), current_range=IRANGE_2UA)
        meas = card.ppmu_measure(0)
        print(f"  Force 3.3V, measure current: raw ADC = {meas}")

        card.ppmu_off(0)

        # Read all ADC channels
        card.adc_scan(oversample_exp=2)  # 4x oversample
        adc_values = card.adc_read_all()
        print(f"\nADC scan (4x oversample): {adc_values[:4]}... (showing first 4)")

        # Status check
        status = card.get_status()
        print(f"\nDevice status: {status}")

        print("\nDone.")


if __name__ == "__main__":
    main()
