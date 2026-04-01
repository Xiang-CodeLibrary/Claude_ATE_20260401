// ATE Pattern Card - Top Level Module
// Target: XCKU035-2FFVA1156I on Ku035_Board

module ate_top
    import ate_pkg::*;
(
    // System clocks
    input  logic        sys_clk_p,      // 200MHz LVDS (G3)
    input  logic        sys_clk_n,
    input  logic        pcie_refclk_p,  // 125MHz (G2)
    input  logic        pcie_refclk_n,
    input  logic        pxie_clk100_p,  // PXIe 100MHz
    input  logic        pxie_clk100_n,

    // PCIe Gen2x4
    output logic [3:0]  pcie_tx_p,
    output logic [3:0]  pcie_tx_n,
    input  logic [3:0]  pcie_rx_p,
    input  logic [3:0]  pcie_rx_n,
    input  logic        pcie_perst_n,

    // DDR3 Interface (directly driven by MIG IP - not expanded here)
    // Defined in constraints file

    // SPI to ADATE305 (active-low CS accent accent for 8 chips)
    output logic        adate_spi_sclk,
    output logic        adate_spi_mosi,
    input  logic        adate_spi_miso,
    output logic [NUM_ADATE305-1:0] adate_spi_cs_n,
    output logic        adate_spi_rst_n,

    // SPI to ADC (ADS7959 x2)
    output logic [NUM_ADC-1:0] adc_spi_sclk,
    output logic [NUM_ADC-1:0] adc_spi_mosi,
    input  logic [NUM_ADC-1:0] adc_spi_miso,
    output logic [NUM_ADC-1:0] adc_spi_cs_n,

    // LVDS data to/from ADATE305 (16 channels x 2 diff pairs each direction)
    // Channel N data output (FPGA → ADATE305 driver)
    output logic [NUM_CHANNELS-1:0] data0_p,
    output logic [NUM_CHANNELS-1:0] data0_n,

    // Channel N receive input (ADATE305 comparator → FPGA)
    input  logic [NUM_CHANNELS-1:0] rcv0_p,
    input  logic [NUM_CHANNELS-1:0] rcv0_n,

    // Comparator results (ADATE305 → FPGA)
    input  logic [NUM_CHANNELS-1:0] comp_qh0_p,
    input  logic [NUM_CHANNELS-1:0] comp_qh0_n,
    input  logic [NUM_CHANNELS-1:0] comp_ql0_p,
    input  logic [NUM_CHANNELS-1:0] comp_ql0_n,

    // OVD signals from ADATE305 (active high)
    input  logic [NUM_CHANNELS-1:0] ovd_ch0,
    input  logic [NUM_CHANNELS-1:0] ovd_ch1,

    // PXI Trigger Bus
    inout  logic [6:0]  pxi_trig,

    // DSTAR differential triggers
    input  logic        dstarb_p,
    input  logic        dstarb_n,
    output logic        dstarc_p,
    output logic        dstarc_n,

    // Status LEDs
    output logic        led_access,
    output logic        led_active
);

    // ============================================================
    // Clock infrastructure
    // ============================================================
    logic sys_clk;       // 200MHz buffered
    logic sys_clk_100;   // 100MHz for AXI/registers
    logic pxie_clk100;   // PXIe 100MHz buffered
    logic pll_locked;
    logic sys_rst_n;

    // Differential clock buffers
    IBUFDS #(.DIFF_TERM("TRUE")) u_sys_clk_buf (
        .I  (sys_clk_p),
        .IB (sys_clk_n),
        .O  (sys_clk)
    );

    IBUFDS #(.DIFF_TERM("TRUE")) u_pxie_clk_buf (
        .I  (pxie_clk100_p),
        .IB (pxie_clk100_n),
        .O  (pxie_clk100)
    );

    // MMCM: 200MHz → 100MHz (AXI clock), 200MHz (pattern clock)
    logic pattern_clk;
    logic axi_clk;
    logic mmcm_locked;

    MMCME3_BASE #(
        .CLKIN1_PERIOD  (5.0),     // 200MHz input
        .CLKFBOUT_MULT_F(5.0),    // VCO = 1000MHz
        .CLKOUT0_DIVIDE_F(10.0),  // 100MHz AXI clock
        .CLKOUT1_DIVIDE (5)       // 200MHz pattern clock
    ) u_mmcm (
        .CLKIN1   (sys_clk),
        .CLKFBIN  (mmcm_fb),
        .CLKFBOUT (mmcm_fb),
        .CLKOUT0  (axi_clk_unbuf),
        .CLKOUT1  (pattern_clk_unbuf),
        .LOCKED   (mmcm_locked),
        .PWRDWN   (1'b0),
        .RST      (1'b0),
        // Unused outputs
        .CLKOUT0B (), .CLKOUT1B (),
        .CLKOUT2  (), .CLKOUT2B (),
        .CLKOUT3  (), .CLKOUT3B (),
        .CLKOUT4  (), .CLKOUT5  (),
        .CLKOUT6  (), .CLKFBOUTB()
    );

    logic mmcm_fb, axi_clk_unbuf, pattern_clk_unbuf;

    BUFG u_axi_clk_buf     (.I(axi_clk_unbuf),     .O(axi_clk));
    BUFG u_pattern_clk_buf (.I(pattern_clk_unbuf),  .O(pattern_clk));

    // System reset synchronizer
    logic [3:0] rst_sync;
    always_ff @(posedge axi_clk or negedge pcie_perst_n) begin
        if (!pcie_perst_n)
            rst_sync <= 4'b0;
        else
            rst_sync <= {rst_sync[2:0], mmcm_locked};
    end
    assign sys_rst_n = rst_sync[3];

    // ============================================================
    // PCIe Endpoint (placeholder - instantiate Xilinx IP in Vivado)
    // ============================================================
    // In real design: instantiate pcie4_uscale_plus or pcie3_ultrascale IP
    // with AXI4-MM bridge to provide s_axi_* signals below

    // AXI4-Lite signals (from PCIe BAR0)
    logic [AXI_ADDR_W-1:0] s_axi_awaddr;
    logic [2:0]            s_axi_awprot;
    logic                   s_axi_awvalid;
    logic                   s_axi_awready;
    logic [AXI_DATA_W-1:0] s_axi_wdata;
    logic [3:0]            s_axi_wstrb;
    logic                   s_axi_wvalid;
    logic                   s_axi_wready;
    logic [1:0]            s_axi_bresp;
    logic                   s_axi_bvalid;
    logic                   s_axi_bready;
    logic [AXI_ADDR_W-1:0] s_axi_araddr;
    logic [2:0]            s_axi_arprot;
    logic                   s_axi_arvalid;
    logic                   s_axi_arready;
    logic [AXI_DATA_W-1:0] s_axi_rdata;
    logic [1:0]            s_axi_rresp;
    logic                   s_axi_rvalid;
    logic                   s_axi_rready;

    // TODO: Replace with actual PCIe IP instantiation
    // pcie_wrapper u_pcie ( ... );

    // ============================================================
    // AXI-Lite Slave → Register Interface
    // ============================================================
    logic                   reg_wr_en;
    logic [AXI_ADDR_W-1:0] reg_wr_addr;
    logic [AXI_DATA_W-1:0] reg_wr_data;
    logic [3:0]            reg_wr_strb;
    logic                   reg_rd_en;
    logic [AXI_ADDR_W-1:0] reg_rd_addr;
    logic [AXI_DATA_W-1:0] reg_rd_data;
    logic                   reg_rd_valid;

    axi_lite_slave u_axi_slave (
        .aclk           (axi_clk),
        .aresetn        (sys_rst_n),
        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awprot   (s_axi_awprot),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),
        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arprot   (s_axi_arprot),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),
        .reg_wr_en      (reg_wr_en),
        .reg_wr_addr    (reg_wr_addr),
        .reg_wr_data    (reg_wr_data),
        .reg_wr_strb    (reg_wr_strb),
        .reg_rd_en      (reg_rd_en),
        .reg_rd_addr    (reg_rd_addr),
        .reg_rd_data    (reg_rd_data),
        .reg_rd_valid   (reg_rd_valid)
    );

    // ============================================================
    // Register Map
    // ============================================================
    logic                   global_reset, global_enable;
    logic [31:0]           global_status, irq_enable, irq_status, irq_clear;
    logic                   self_cal_start, self_cal_done;
    logic [NUM_CHANNELS-1:0] ch_reg_wr_en, ch_reg_rd_en;
    logic [7:0]            ch_reg_wr_offset, ch_reg_rd_offset;
    logic [AXI_DATA_W-1:0] ch_reg_wr_data_bus;
    logic [AXI_DATA_W-1:0] ch_reg_rd_data [NUM_CHANNELS];
    logic                   spi_reg_wr_en, spi_reg_rd_en;
    logic [7:0]            spi_reg_offset;
    logic [31:0]           spi_reg_wr_data, spi_reg_rd_data;
    logic                   adc_reg_wr_en, adc_reg_rd_en;
    logic [7:0]            adc_reg_offset;
    logic [31:0]           adc_reg_wr_data, adc_reg_rd_data;
    logic                   pat_start, pat_stop, pat_abort;
    logic                   pat_running, pat_done, pat_fail;
    logic [VECTOR_ADDR_W-1:0] pat_start_addr, pat_length;
    logic [NUM_CHANNELS-1:0]  site_enable;
    logic [31:0]           vector_period, vector_period_fine;

    reg_map u_reg_map (
        .clk             (axi_clk),
        .rst_n           (sys_rst_n),
        .reg_wr_en       (reg_wr_en),
        .reg_wr_addr     (reg_wr_addr),
        .reg_wr_data     (reg_wr_data),
        .reg_wr_strb     (reg_wr_strb),
        .reg_rd_en       (reg_rd_en),
        .reg_rd_addr     (reg_rd_addr),
        .reg_rd_data     (reg_rd_data),
        .reg_rd_valid    (reg_rd_valid),
        .global_reset    (global_reset),
        .global_enable   (global_enable),
        .global_status   (global_status),
        .irq_enable      (irq_enable),
        .irq_status      (irq_status),
        .irq_clear       (irq_clear),
        .self_cal_start  (self_cal_start),
        .self_cal_done   (self_cal_done),
        .ch_reg_wr_en    (ch_reg_wr_en),
        .ch_reg_wr_offset(ch_reg_wr_offset),
        .ch_reg_wr_data  (ch_reg_wr_data_bus),
        .ch_reg_rd_en    (ch_reg_rd_en),
        .ch_reg_rd_offset(ch_reg_rd_offset),
        .ch_reg_rd_data  (ch_reg_rd_data),
        .spi_reg_wr_en   (spi_reg_wr_en),
        .spi_reg_offset  (spi_reg_offset),
        .spi_reg_wr_data (spi_reg_wr_data),
        .spi_reg_rd_en   (spi_reg_rd_en),
        .spi_reg_rd_data (spi_reg_rd_data),
        .adc_reg_wr_en   (adc_reg_wr_en),
        .adc_reg_offset  (adc_reg_offset),
        .adc_reg_wr_data (adc_reg_wr_data),
        .adc_reg_rd_en   (adc_reg_rd_en),
        .adc_reg_rd_data (adc_reg_rd_data),
        .pat_start       (pat_start),
        .pat_stop        (pat_stop),
        .pat_abort       (pat_abort),
        .pat_running     (pat_running),
        .pat_done        (pat_done),
        .pat_fail        (pat_fail),
        .pat_start_addr  (pat_start_addr),
        .pat_length      (pat_length),
        .site_enable     (site_enable),
        .vector_period   (vector_period),
        .vector_period_fine(vector_period_fine)
    );

    // ============================================================
    // SPI Master (ADATE305)
    // ============================================================
    // Command interface from channel controllers (TODO: add arbiter)
    logic        spi_cmd_valid;
    logic [2:0]  spi_cmd_chip_sel;
    logic        spi_cmd_rw;
    logic [6:0]  spi_cmd_addr;
    logic [15:0] spi_cmd_wdata;
    logic        spi_cmd_ready;
    logic        spi_cmd_done;
    logic [15:0] spi_cmd_rdata;

    spi_master u_spi_master (
        .clk          (axi_clk),
        .rst_n        (sys_rst_n),
        .reg_wr_en    (spi_reg_wr_en),
        .reg_offset   (spi_reg_offset),
        .reg_wr_data  (spi_reg_wr_data),
        .reg_rd_en    (spi_reg_rd_en),
        .reg_rd_data  (spi_reg_rd_data),
        .cmd_valid    (spi_cmd_valid),
        .cmd_chip_sel (spi_cmd_chip_sel),
        .cmd_rw       (spi_cmd_rw),
        .cmd_addr     (spi_cmd_addr),
        .cmd_wdata    (spi_cmd_wdata),
        .cmd_ready    (spi_cmd_ready),
        .cmd_done     (spi_cmd_done),
        .cmd_rdata    (spi_cmd_rdata),
        .spi_sclk     (adate_spi_sclk),
        .spi_mosi     (adate_spi_mosi),
        .spi_miso     (adate_spi_miso),
        .spi_cs_n     (adate_spi_cs_n),
        .spi_rst_n    (adate_spi_rst_n)
    );

    // Tie off command interface for now (will be driven by level update engine)
    assign spi_cmd_valid    = 1'b0;
    assign spi_cmd_chip_sel = '0;
    assign spi_cmd_rw       = 1'b0;
    assign spi_cmd_addr     = '0;
    assign spi_cmd_wdata    = '0;

    // ============================================================
    // Channel Register Instances (16 channels)
    // ============================================================
    generate
        for (genvar ch = 0; ch < NUM_CHANNELS; ch++) begin : gen_ch_regs
            channel_regs #(
                .CHANNEL_ID(ch)
            ) u_ch_regs (
                .clk              (axi_clk),
                .rst_n            (sys_rst_n),
                .reg_wr_en        (ch_reg_wr_en[ch]),
                .reg_offset       (ch_reg_wr_offset),
                .reg_wr_data      (ch_reg_wr_data_bus),
                .reg_rd_en        (ch_reg_rd_en[ch]),
                .reg_rd_offset    (ch_reg_rd_offset),
                .reg_rd_data      (ch_reg_rd_data[ch]),
                // Configuration outputs - TODO: connect to channel controllers
                .pin_function     (),
                .termination_mode (),
                .drive_format     (),
                .edge_multiplier  (),
                .level_vih        (),
                .level_vil        (),
                .level_vterm      (),
                .level_voh        (),
                .level_vol        (),
                .level_ioh        (),
                .level_iol        (),
                .level_vcom       (),
                .ppmu_mode        (),
                .ppmu_voltage_level(),
                .ppmu_current_level(),
                .ppmu_current_range(),
                .ppmu_vclamp_h    (),
                .ppmu_vclamp_l    (),
                .ppmu_aperture_time(),
                .ppmu_measure_result(32'b0),  // TODO: from ADC
                .static_state     (),
                .static_state_wr  (),
                .cal_offset_vih   (),
                .cal_offset_vil   (),
                .cal_offset_vt    (),
                .cal_gain_i       (),
                .cal_offset_i     (),
                .ovd_status       ({ovd_ch1[ch], ovd_ch0[ch]}),
                .levels_updated   ()
            );
        end
    endgenerate

    // ============================================================
    // Status and placeholders
    // ============================================================
    // Global status: {OVD flags, cal status, ...}
    assign global_status = {16'b0, ovd_ch0[15:0]} | {ovd_ch1[15:0], 16'b0};
    assign irq_status    = '0;  // TODO
    assign self_cal_done = 1'b0; // TODO
    assign pat_running   = 1'b0; // TODO
    assign pat_done      = 1'b0; // TODO
    assign pat_fail      = 1'b0; // TODO
    assign adc_reg_rd_data = '0; // TODO

    // LED indicators
    assign led_access = sys_rst_n;  // Green when ready
    assign led_active = pat_running; // Green when bursting

    // Placeholder tie-offs for unimplemented outputs
    assign data0_p  = '0;
    assign data0_n  = '1;
    assign dstarc_p = 1'b0;
    assign dstarc_n = 1'b1;
    assign pxi_trig = 7'bzzzzzzz;  // High-Z when not driving

endmodule
