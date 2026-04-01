// Timing Clock Generation
// Generates all clocks required by the timing engine from 200MHz system clock
//
// Output clocks:
//   clk_800  — 800 MHz IDELAYCTRL reference (39.0625 ps tap resolution)
//   clk_400  — 400 MHz OSERDES/ISERDES high-speed clock (DDR → 800 Mbps)
//   clk_100  — 100 MHz parallel clock (CLKDIV) and pattern engine clock
//
// MMCM configuration:
//   Input:   200 MHz
//   VCO:     200 × 4.0 = 800 MHz
//   CLKOUT0: 800 / 1 = 800 MHz → IDELAYCTRL
//   CLKOUT1: 800 / 2 = 400 MHz → OSERDES CLK
//   CLKOUT2: 800 / 8 = 100 MHz → CLKDIV / Pattern clock

module timing_clocks (
    input  logic        sys_clk_200,    // 200 MHz system clock (buffered)
    input  logic        rst,            // Active high async reset

    output logic        clk_800,        // 800 MHz for IDELAYCTRL
    output logic        clk_400,        // 400 MHz for OSERDES (DDR)
    output logic        clk_100,        // 100 MHz for parallel / pattern
    output logic        locked,         // PLL locked indicator

    output logic        idelayctrl_rdy  // IDELAYCTRL ready
);

    logic clk_800_unbuf, clk_400_unbuf, clk_100_unbuf;
    logic mmcm_fb;
    logic mmcm_locked;

    MMCME3_BASE #(
        .BANDWIDTH        ("OPTIMIZED"),
        .CLKIN1_PERIOD    (5.0),         // 200 MHz = 5 ns
        .CLKFBOUT_MULT_F  (4.0),         // VCO = 200 × 4.0 = 800 MHz
        .CLKFBOUT_PHASE   (0.0),
        .CLKOUT0_DIVIDE_F (1.0),         // 800 / 1 = 800 MHz
        .CLKOUT0_PHASE    (0.0),
        .CLKOUT1_DIVIDE   (2),           // 800 / 2 = 400 MHz
        .CLKOUT1_PHASE    (0.0),
        .CLKOUT2_DIVIDE   (8),           // 800 / 8 = 100 MHz
        .CLKOUT2_PHASE    (0.0),
        .DIVCLK_DIVIDE    (1),
        .STARTUP_WAIT     ("FALSE")
    ) u_mmcm_timing (
        .CLKIN1     (sys_clk_200),
        .CLKFBIN    (mmcm_fb),
        .CLKFBOUT   (mmcm_fb),
        .CLKOUT0    (clk_800_unbuf),
        .CLKOUT1    (clk_400_unbuf),
        .CLKOUT2    (clk_100_unbuf),
        .LOCKED     (mmcm_locked),
        .PWRDWN     (1'b0),
        .RST        (rst),
        // Unused outputs
        .CLKOUT0B   (), .CLKOUT1B  (), .CLKOUT2B  (),
        .CLKOUT3    (), .CLKOUT3B  (),
        .CLKOUT4    (), .CLKOUT5   (), .CLKOUT6   (),
        .CLKFBOUTB  ()
    );

    // Clock buffers
    // 800 MHz: use BUFG (supported up to 800 MHz in UltraScale)
    BUFG u_buf_800 (.I(clk_800_unbuf), .O(clk_800));
    BUFG u_buf_400 (.I(clk_400_unbuf), .O(clk_400));
    BUFG u_buf_100 (.I(clk_100_unbuf), .O(clk_100));

    assign locked = mmcm_locked;

    // ================================================================
    // IDELAYCTRL — required for IDELAYE3/ODELAYE3 calibration
    // ================================================================
    // One IDELAYCTRL per I/O bank that uses IDELAYE3/ODELAYE3.
    // In the top-level, instantiate one per bank (47, 48, 67, 68).
    // Here we instantiate one as reference; replicate in top-level per bank.

    logic idelayctrl_rdy_int;

    IDELAYCTRL u_idelayctrl (
        .RDY    (idelayctrl_rdy_int),
        .REFCLK (clk_800),
        .RST    (~mmcm_locked)    // Hold reset until MMCM locked
    );

    assign idelayctrl_rdy = idelayctrl_rdy_int & mmcm_locked;

endmodule
