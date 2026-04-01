// Channel SERDES Wrapper
// Instantiates OSERDES3 + ODELAYE3 for drive output
// and ISERDES3 + IDELAYE3 for compare input
// One instance per channel

module channel_serdes (
    // Clocks
    input  logic        clk_100,     // CLKDIV (parallel)
    input  logic        clk_400,     // CLK (OSERDES/ISERDES, DDR → 800Mbps)
    input  logic        rst,         // Active high

    // Drive output (to ADATE305 DATA pin)
    input  logic [7:0]  tx_data,     // 8-bit parallel data to OSERDES3
    output logic        tx_out_p,    // LVDS output
    output logic        tx_out_n,

    // ODELAYE3 fine delay control
    input  logic [8:0]  odelay_tap,
    input  logic        odelay_load,

    // Compare input (from ADATE305 RCV pin)
    input  logic        rx_in_p,     // LVDS input
    input  logic        rx_in_n,
    output logic [7:0]  rx_data,     // 8-bit parallel data from ISERDES3

    // IDELAYE3 fine delay control
    input  logic [8:0]  idelay_tap,
    input  logic        idelay_load
);

    // ================================================================
    // TX path: OSERDES3 → ODELAYE3 → OBUFDS
    // ================================================================
    logic oserdes_out;
    logic odelayed_out;

    // OSERDES3: 8:1 serializer
    OSERDESE3 #(
        .DATA_WIDTH     (8),
        .INIT           (1'b0),
        .IS_CLKDIV_INVERTED(1'b0),
        .IS_CLK_INVERTED(1'b0),
        .IS_RST_INVERTED(1'b0),
        .SIM_DEVICE     ("ULTRASCALE")
    ) u_oserdes (
        .OQ     (oserdes_out),
        .T_OUT  (),
        .CLK    (clk_400),
        .CLKDIV (clk_100),
        .D      (tx_data),
        .RST    (rst),
        .T      (1'b0)
    );

    // ODELAYE3: fine delay for edge placement
    // 512 taps × 39.0625 ps = 20 ns max delay @800MHz REFCLK
    ODELAYE3 #(
        .CASCADE          ("NONE"),
        .DELAY_FORMAT     ("COUNT"),
        .DELAY_TYPE       ("VAR_LOAD"),
        .DELAY_VALUE      (0),
        .IS_CLK_INVERTED  (1'b0),
        .IS_RST_INVERTED  (1'b0),
        .REFCLK_FREQUENCY (800.0),
        .SIM_DEVICE       ("ULTRASCALE"),
        .UPDATE_MODE      ("ASYNC")
    ) u_odelay (
        .CASC_OUT    (),
        .CNTVALUEOUT (),
        .DATAOUT     (odelayed_out),
        .CASC_IN     (1'b0),
        .CASC_RETURN (1'b0),
        .CE          (1'b0),
        .CLK         (clk_100),
        .CNTVALUEIN  (odelay_tap),
        .EN_VTC      (1'b1),
        .INC         (1'b0),
        .LOAD        (odelay_load),
        .ODATAIN     (oserdes_out),
        .RST         (rst)
    );

    // OBUFDS: LVDS output buffer
    OBUFDS u_obufds (
        .O  (tx_out_p),
        .OB (tx_out_n),
        .I  (odelayed_out)
    );

    // ================================================================
    // RX path: IBUFDS → IDELAYE3 → ISERDES3
    // ================================================================
    logic ibuf_out;
    logic idelayed_in;

    // IBUFDS: LVDS input buffer
    IBUFDS #(
        .DIFF_TERM ("TRUE")
    ) u_ibufds (
        .O  (ibuf_out),
        .I  (rx_in_p),
        .IB (rx_in_n)
    );

    // IDELAYE3: fine delay for compare strobe positioning
    IDELAYE3 #(
        .CASCADE          ("NONE"),
        .DELAY_FORMAT     ("COUNT"),
        .DELAY_TYPE       ("VAR_LOAD"),
        .DELAY_VALUE      (0),
        .IS_CLK_INVERTED  (1'b0),
        .IS_RST_INVERTED  (1'b0),
        .REFCLK_FREQUENCY (800.0),
        .SIM_DEVICE       ("ULTRASCALE"),
        .UPDATE_MODE      ("ASYNC")
    ) u_idelay (
        .CASC_OUT    (),
        .CNTVALUEOUT (),
        .DATAOUT     (idelayed_in),
        .CASC_IN     (1'b0),
        .CASC_RETURN (1'b0),
        .CE          (1'b0),
        .CLK         (clk_100),
        .CNTVALUEIN  (idelay_tap),
        .DATAIN      (1'b0),
        .EN_VTC      (1'b1),
        .IDATAIN     (ibuf_out),        // From IBUFDS
        .INC         (1'b0),
        .LOAD        (idelay_load),
        .RST         (rst)
    );

    // ISERDESE3: 8:1 deserializer
    ISERDESE3 #(
        .DATA_WIDTH       (8),
        .FIFO_ENABLE      ("FALSE"),
        .FIFO_SYNC_MODE   ("FALSE"),
        .IS_CLK_B_INVERTED(1'b1),       // Inverted for DDR
        .IS_CLK_INVERTED  (1'b0),
        .IS_RST_INVERTED  (1'b0),
        .SIM_DEVICE       ("ULTRASCALE")
    ) u_iserdes (
        .FIFO_EMPTY     (),
        .INTERNAL_DIVCLK(),
        .Q              (rx_data),       // 8-bit parallel output
        .CLK            (clk_400),
        .CLK_B          (clk_400),       // Inverted via parameter
        .CLKDIV         (clk_100),
        .D              (idelayed_in),   // From IDELAYE3
        .FIFO_RD_CLK   (1'b0),
        .FIFO_RD_EN    (1'b0),
        .RST            (rst)
    );

endmodule
