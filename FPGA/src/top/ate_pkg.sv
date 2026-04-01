// ATE Pattern Card - Global Parameter Package
// Target: XCKU035-2FFVA1156I

package ate_pkg;

    // System parameters
    parameter NUM_CHANNELS    = 16;
    parameter NUM_ADATE305    = 8;   // Each ADATE305 has 2 channels
    parameter NUM_SITES       = 8;   // Max multi-site
    parameter NUM_TIMESETS    = 31;
    parameter NUM_ADC         = 2;   // ADS7959 x2

    // Clock frequencies (Hz)
    parameter SYS_CLK_FREQ    = 200_000_000;
    parameter PCIE_REF_FREQ   = 125_000_000;
    parameter PXIE_CLK100     = 100_000_000;
    parameter SPI_CLK_FREQ    = 25_000_000;
    parameter ADC_CLK_FREQ    = 18_000_000;

    // Vector parameters
    parameter VECTOR_WIDTH    = 128;  // bits per vector
    parameter VECTOR_ADDR_W   = 27;   // 128M vectors address width

    // DAC resolution
    parameter DAC14_WIDTH     = 14;   // ADATE305 DCL DAC
    parameter DAC16_WIDTH     = 16;   // ADATE305 PMU DAC
    parameter ADC_WIDTH       = 12;   // ADS7959

    // SPI frame format
    parameter SPI_FRAME_WIDTH = 24;   // ADATE305: 1-bit R/W + 7-bit addr + 16-bit data

    // AXI4-Lite address width
    parameter AXI_ADDR_W      = 16;
    parameter AXI_DATA_W      = 32;

    // Register map base addresses
    parameter ADDR_GLOBAL     = 16'h0000;  // 0x0000 - 0x00FF
    parameter ADDR_TIMING     = 16'h0100;  // 0x0100 - 0x01FF
    parameter ADDR_PATTERN    = 16'h0200;  // 0x0200 - 0x02FF
    parameter ADDR_TRIGGER    = 16'h0300;  // 0x0300 - 0x03FF
    parameter ADDR_CHANNEL    = 16'h1000;  // 0x1000 - 0x1FFF (16ch x 0x100)
    parameter ADDR_SPI        = 16'h2000;  // 0x2000 - 0x2FFF
    parameter ADDR_ADC        = 16'h3000;  // 0x3000 - 0x3FFF
    parameter ADDR_CAL        = 16'h4000;  // 0x4000 - 0x4FFF

    // Channel register offsets (within each channel's 0x100 block)
    parameter CH_CTRL         = 8'h00;
    parameter CH_STATUS       = 8'h04;
    parameter CH_VIH          = 8'h08;
    parameter CH_VIL          = 8'h0C;
    parameter CH_VTERM        = 8'h10;
    parameter CH_VOH          = 8'h14;
    parameter CH_VOL          = 8'h18;
    parameter CH_IOH          = 8'h1C;
    parameter CH_IOL          = 8'h20;
    parameter CH_VCOM         = 8'h24;
    parameter CH_TERM_MODE    = 8'h28;
    parameter CH_DRIVE_FMT    = 8'h2C;
    parameter CH_PPMU_CTRL    = 8'h30;
    parameter CH_PPMU_VLEVEL  = 8'h34;
    parameter CH_PPMU_ILEVEL  = 8'h38;
    parameter CH_PPMU_IRANGE  = 8'h3C;
    parameter CH_PPMU_VCLH    = 8'h40;
    parameter CH_PPMU_VCLL    = 8'h44;
    parameter CH_PPMU_APERT   = 8'h48;
    parameter CH_PPMU_MEAS    = 8'h4C;
    parameter CH_OVD_STATUS   = 8'h50;
    parameter CH_STATIC_STATE = 8'h54;
    parameter CH_EDGE_MULT    = 8'h58;
    parameter CH_CAL_OFF_VIH  = 8'h60;
    parameter CH_CAL_OFF_VIL  = 8'h64;
    parameter CH_CAL_OFF_VT   = 8'h68;
    parameter CH_CAL_GAIN_I   = 8'h6C;
    parameter CH_CAL_OFF_I    = 8'h70;

    // Pin function modes
    typedef enum logic [1:0] {
        PIN_DIGITAL    = 2'b00,
        PIN_PPMU       = 2'b01,
        PIN_OFF        = 2'b10,
        PIN_DISCONNECT = 2'b11
    } pin_func_t;

    // Termination modes
    typedef enum logic [1:0] {
        TERM_HIZ       = 2'b00,
        TERM_VTERM     = 2'b01,
        TERM_ACTIVE    = 2'b10
    } term_mode_t;

    // Drive formats
    typedef enum logic [1:0] {
        DRV_NR  = 2'b00,   // Non-Return
        DRV_RL  = 2'b01,   // Return to Low
        DRV_RH  = 2'b10,   // Return to High
        DRV_SBC = 2'b11    // Surround by Complement
    } drive_fmt_t;

    // Pin data states (in vector memory)
    typedef enum logic [1:0] {
        PS_DRIVE0  = 2'b00,
        PS_DRIVE1  = 2'b01,
        PS_COMPARE = 2'b10,
        PS_HIZ     = 2'b11
    } pin_state_t;

    // PPMU modes
    typedef enum logic [2:0] {
        PPMU_OFF  = 3'b000,
        PPMU_FV   = 3'b001,  // Force Voltage
        PPMU_FI   = 3'b010,  // Force Current
        PPMU_MV   = 3'b011,  // Measure Voltage (no force)
        PPMU_FVMI = 3'b100,  // Force Voltage, Measure Current
        PPMU_FVMV = 3'b101,  // Force Voltage, Measure Voltage
        PPMU_FIMV = 3'b110,  // Force Current, Measure Voltage
        PPMU_FIMI = 3'b111   // Force Current, Measure Current
    } ppmu_mode_t;

    // PPMU current ranges
    typedef enum logic [2:0] {
        IRANGE_2UA   = 3'b000,
        IRANGE_32UA  = 3'b001,
        IRANGE_128UA = 3'b010,
        IRANGE_2MA   = 3'b011,
        IRANGE_32MA  = 3'b100
    } ppmu_irange_t;

    // ADATE305 SPI register addresses (key registers)
    parameter ADATE_REG_MODE     = 7'h00;
    parameter ADATE_REG_VH       = 7'h01;
    parameter ADATE_REG_VL       = 7'h02;
    parameter ADATE_REG_VT       = 7'h03;
    parameter ADATE_REG_VOH      = 7'h04;
    parameter ADATE_REG_VOL      = 7'h05;
    parameter ADATE_REG_IOH      = 7'h06;
    parameter ADATE_REG_IOL      = 7'h07;
    parameter ADATE_REG_VCOM     = 7'h08;
    parameter ADATE_REG_PMU_V    = 7'h10;
    parameter ADATE_REG_PMU_I    = 7'h11;
    parameter ADATE_REG_PMU_CTRL = 7'h12;
    parameter ADATE_REG_OVD_CTRL = 7'h20;
    parameter ADATE_REG_HVOUT    = 7'h30;
    parameter ADATE_REG_TEMP     = 7'h3F;

    // Device ID
    parameter DEVICE_ID        = 32'hA7E0_6571;
    parameter FPGA_VERSION     = 32'h0001_0000;  // v1.0.0

endpackage
