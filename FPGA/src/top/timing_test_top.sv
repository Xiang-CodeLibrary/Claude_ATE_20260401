// Timing Engine Hardware Verification Top-Level
// Minimal version — no VIO/ILA IP dependency, uses JTAG BSCAN for debug
// All control via hardcoded test patterns, results observed on LVDS outputs

module timing_test_top (
    // 200 MHz system clock (G3 oscillator, LVDS)
    input  logic        sys_clk_p,
    input  logic        sys_clk_n,

    // Test LVDS outputs (Bank 47, to BTB connector)
    output logic        test_ch0_p,
    output logic        test_ch0_n,
    output logic        test_ch1_p,
    output logic        test_ch1_n
);

    // ================================================================
    // Clock infrastructure
    // ================================================================
    logic sys_clk_200;

    IBUFDS #(.DIFF_TERM("TRUE")) u_sys_clk_buf (
        .I(sys_clk_p), .IB(sys_clk_n), .O(sys_clk_200)
    );

    logic clk_800, clk_400, clk_100;
    logic mmcm_locked, idelayctrl_rdy;

    timing_clocks u_clocks (
        .sys_clk_200    (sys_clk_200),
        .rst            (1'b0),
        .clk_800        (clk_800),
        .clk_400        (clk_400),
        .clk_100        (clk_100),
        .locked         (mmcm_locked),
        .idelayctrl_rdy (idelayctrl_rdy)
    );

    logic rst_n;
    logic [3:0] rst_pipe;
    always_ff @(posedge clk_100 or negedge mmcm_locked) begin
        if (!mmcm_locked)
            rst_pipe <= '0;
        else
            rst_pipe <= {rst_pipe[2:0], idelayctrl_rdy};
    end
    assign rst_n = rst_pipe[3];

    // ================================================================
    // Test mode controller — slow sweep of ODELAYE3 tap
    // Automatically cycles tap 0→511→0→... every ~20ms per step
    // Outputs 100MHz square wave on both channels
    // CH0: delay swept, CH1: fixed → scope sees edge moving on CH0
    // ================================================================
    logic [19:0] sweep_timer;   // @100MHz: 2^20 = ~10ms per tick
    logic [8:0]  sweep_tap;
    logic        sweep_dir;
    logic        tap_load_pulse;

    always_ff @(posedge clk_100 or negedge rst_n) begin
        if (!rst_n) begin
            sweep_timer    <= '0;
            sweep_tap      <= '0;
            sweep_dir      <= 1'b1;  // Up
            tap_load_pulse <= 1'b0;
        end else begin
            tap_load_pulse <= 1'b0;
            sweep_timer    <= sweep_timer + 1'b1;

            if (sweep_timer == '0) begin
                tap_load_pulse <= 1'b1;

                if (sweep_dir) begin
                    if (sweep_tap == 9'd511) begin
                        sweep_dir <= 1'b0;
                        sweep_tap <= sweep_tap - 1'b1;
                    end else begin
                        sweep_tap <= sweep_tap + 1'b1;
                    end
                end else begin
                    if (sweep_tap == 9'd0) begin
                        sweep_dir <= 1'b1;
                        sweep_tap <= sweep_tap + 1'b1;
                    end else begin
                        sweep_tap <= sweep_tap - 1'b1;
                    end
                end
            end
        end
    end

    // OSERDES pattern: 0xF0 = 100MHz square wave @800Mbps
    // 4 bits high (5ns) + 4 bits low (5ns) = 10ns period
    localparam [7:0] SQUARE_100M = 8'hF0;

    // ================================================================
    // Channel 0: OSERDES3 + ODELAYE3 (被测通道, delay swept)
    // ================================================================
    channel_serdes u_ch0 (
        .clk_100     (clk_100),
        .clk_400     (clk_400),
        .rst         (~rst_n),
        .tx_data     (SQUARE_100M),
        .tx_out_p    (test_ch0_p),
        .tx_out_n    (test_ch0_n),
        .odelay_tap  (sweep_tap),
        .odelay_load (tap_load_pulse),
        .rx_in_p     (1'b0),
        .rx_in_n     (1'b1),
        .rx_data     (),
        .idelay_tap  (9'd0),
        .idelay_load (1'b0)
    );

    // ================================================================
    // Channel 1: OSERDES3 only, no delay (参考通道, scope trigger)
    // ================================================================
    logic ch1_serial;

    OSERDESE3 #(
        .DATA_WIDTH(8),
        .INIT(1'b0),
        .IS_CLKDIV_INVERTED(1'b0),
        .IS_CLK_INVERTED(1'b0),
        .IS_RST_INVERTED(1'b0),
        .SIM_DEVICE("ULTRASCALE")
    ) u_ch1_oserdes (
        .OQ     (ch1_serial),
        .T_OUT  (),
        .CLK    (clk_400),
        .CLKDIV (clk_100),
        .D      (SQUARE_100M),
        .RST    (~rst_n),
        .T      (1'b0)
    );

    OBUFDS u_ch1_obuf (
        .O  (test_ch1_p),
        .OB (test_ch1_n),
        .I  (ch1_serial)
    );

endmodule
