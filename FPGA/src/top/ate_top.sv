// ATE Pattern Card — Top Level Module (Full System Integration)
// Target: XCKU035-2FFVA1156I on Ku035_Board
// All M1~M10 modules wired together

module ate_top
    import ate_pkg::*;
(
    // System clocks
    input  logic        sys_clk_p,      // 200MHz LVDS (G3, Bank45 AH18/AH17)
    input  logic        sys_clk_n,
    input  logic        pcie_refclk_p,  // 125MHz (G2)
    input  logic        pcie_refclk_n,
    input  logic        pxie_clk100_p,  // PXIe 100MHz (Bank68 E18/E17)
    input  logic        pxie_clk100_n,

    // PCIe Gen2x4
    output logic [3:0]  pcie_tx_p,
    output logic [3:0]  pcie_tx_n,
    input  logic [3:0]  pcie_rx_p,
    input  logic [3:0]  pcie_rx_n,
    input  logic        pcie_perst_n,

    // SPI to ADATE305
    output logic        adate_spi_sclk,
    output logic        adate_spi_mosi,
    input  logic        adate_spi_miso,
    output logic [NUM_ADATE305-1:0] adate_spi_cs_n,
    output logic        adate_spi_rst_n,

    // SPI to ADC (ADS7959 x2, shared SCLK/MOSI/MISO bus, separate CS)
    output logic        adc_spi_sclk,
    output logic        adc_spi_mosi,
    input  logic        adc_spi_miso,
    output logic [NUM_ADC-1:0] adc_spi_cs_n,

    // LVDS to/from ADATE305 (16 channels × 2 sub-channels)
    output logic [NUM_CHANNELS-1:0] data0_p, data0_n,   // Drive data ch0
    output logic [NUM_CHANNELS-1:0] data1_p, data1_n,   // Drive data ch1 (2x mode)
    input  logic [NUM_CHANNELS-1:0] rcv0_p,  rcv0_n,    // Compare result ch0
    input  logic [NUM_CHANNELS-1:0] rcv1_p,  rcv1_n,    // Compare result ch1
    input  logic [NUM_CHANNELS-1:0] comp_qh0_p, comp_qh0_n, // Comparator high ch0
    input  logic [NUM_CHANNELS-1:0] comp_qh1_p, comp_qh1_n, // Comparator high ch1
    input  logic [NUM_CHANNELS-1:0] comp_ql0_p, comp_ql0_n, // Comparator low ch0
    input  logic [NUM_CHANNELS-1:0] comp_ql1_p, comp_ql1_n, // Comparator low ch1

    // OVD from ADATE305
    input  logic [NUM_CHANNELS-1:0] ovd_ch0, ovd_ch1,

    // PXI Trigger
    inout  logic [6:0]  pxi_trig,

    // DSTAR
    input  logic        dstarb_p, dstarb_n,
    output logic        dstarc_p, dstarc_n,

    // Status LEDs
    output logic        led_access,
    output logic        led_active
);

    // ================================================================
    // Clocks & Reset
    // ================================================================
    logic sys_clk_200;
    IBUFDS #(.DIFF_TERM("TRUE")) u_sys_buf (
        .I(sys_clk_p), .IB(sys_clk_n), .O(sys_clk_200)
    );

    // Timing clocks: 800/400/100 MHz
    logic clk_800, clk_400, clk_100;
    logic mmcm_locked, idelayctrl_rdy;

    timing_clocks u_timing_clocks (
        .sys_clk_200    (sys_clk_200),
        .rst            (1'b0),
        .clk_800        (clk_800),
        .clk_400        (clk_400),
        .clk_100        (clk_100),
        .locked         (mmcm_locked),
        .idelayctrl_rdy (idelayctrl_rdy)
    );

    // PXIe CLK100
    logic pxie_clk100;
    IBUFDS #(.DIFF_TERM("TRUE")) u_pxie_buf (
        .I(pxie_clk100_p), .IB(pxie_clk100_n), .O(pxie_clk100)
    );

    // System reset
    logic rst_n;
    logic [3:0] rst_pipe;
    always_ff @(posedge clk_100 or negedge mmcm_locked) begin
        if (!mmcm_locked) rst_pipe <= '0;
        else rst_pipe <= {rst_pipe[2:0], idelayctrl_rdy};
    end
    assign rst_n = rst_pipe[3];

    // ================================================================
    // PCIe → AXI-Lite (placeholder, replace with Xilinx IP)
    // ================================================================
    logic [AXI_ADDR_W-1:0] s_axi_awaddr, s_axi_araddr;
    logic [2:0]  s_axi_awprot, s_axi_arprot;
    logic        s_axi_awvalid, s_axi_awready;
    logic [AXI_DATA_W-1:0] s_axi_wdata;
    logic [3:0]  s_axi_wstrb;
    logic        s_axi_wvalid, s_axi_wready;
    logic [1:0]  s_axi_bresp;
    logic        s_axi_bvalid, s_axi_bready;
    logic        s_axi_arvalid, s_axi_arready;
    logic [AXI_DATA_W-1:0] s_axi_rdata;
    logic [1:0]  s_axi_rresp;
    logic        s_axi_rvalid, s_axi_rready;

    // PCIe Wrapper (placeholder until IP generated)
    logic pcie_user_clk, pcie_user_rst_n, pcie_lnk_up;

    pcie_wrapper u_pcie (
        .pcie_refclk_p(pcie_refclk_p), .pcie_refclk_n(pcie_refclk_n),
        .pcie_tx_p(pcie_tx_p), .pcie_tx_n(pcie_tx_n),
        .pcie_rx_p(pcie_rx_p), .pcie_rx_n(pcie_rx_n),
        .pcie_perst_n(pcie_perst_n),
        .user_clk(pcie_user_clk), .user_reset_n(pcie_user_rst_n),
        .user_lnk_up(pcie_lnk_up),
        .m_axi_awaddr(s_axi_awaddr), .m_axi_awprot(s_axi_awprot),
        .m_axi_awvalid(s_axi_awvalid), .m_axi_awready(s_axi_awready),
        .m_axi_wdata(s_axi_wdata), .m_axi_wstrb(s_axi_wstrb),
        .m_axi_wvalid(s_axi_wvalid), .m_axi_wready(s_axi_wready),
        .m_axi_bresp(s_axi_bresp), .m_axi_bvalid(s_axi_bvalid),
        .m_axi_bready(s_axi_bready),
        .m_axi_araddr(s_axi_araddr), .m_axi_arprot(s_axi_arprot),
        .m_axi_arvalid(s_axi_arvalid), .m_axi_arready(s_axi_arready),
        .m_axi_rdata(s_axi_rdata), .m_axi_rresp(s_axi_rresp),
        .m_axi_rvalid(s_axi_rvalid), .m_axi_rready(s_axi_rready),
        .dma_h2c_valid(), .dma_h2c_addr(), .dma_h2c_data(), .dma_h2c_ready(1'b1),
        .dma_c2h_valid(1'b0), .dma_c2h_data('0), .dma_c2h_ready(),
        .irq_req(irq_status[3:0]), .irq_ack()
    );

    // ================================================================
    // AXI-Lite Slave → Register Bus
    // ================================================================
    logic        reg_wr_en, reg_rd_en;
    logic [AXI_ADDR_W-1:0] reg_wr_addr, reg_rd_addr;
    logic [AXI_DATA_W-1:0] reg_wr_data, reg_rd_data;
    logic [3:0]  reg_wr_strb;
    logic        reg_rd_valid;

    axi_lite_slave u_axi_slave (
        .aclk(clk_100), .aresetn(rst_n),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        .reg_wr_en(reg_wr_en), .reg_wr_addr(reg_wr_addr),
        .reg_wr_data(reg_wr_data), .reg_wr_strb(reg_wr_strb),
        .reg_rd_en(reg_rd_en), .reg_rd_addr(reg_rd_addr),
        .reg_rd_data(reg_rd_data), .reg_rd_valid(reg_rd_valid)
    );

    // ================================================================
    // Register Map
    // ================================================================
    logic        global_reset, global_enable, self_cal_start, self_cal_done;
    logic [31:0] global_status, irq_enable, irq_status, irq_clear;
    logic [NUM_CHANNELS-1:0] ch_reg_wr_en, ch_reg_rd_en;
    logic [7:0]  ch_reg_wr_offset, ch_reg_rd_offset;
    logic [31:0] ch_reg_wr_data_bus;
    logic [31:0] ch_reg_rd_data [NUM_CHANNELS];
    logic        spi_reg_wr_en, spi_reg_rd_en, adc_reg_wr_en, adc_reg_rd_en;
    logic [7:0]  spi_reg_offset, adc_reg_offset;
    logic [31:0] spi_reg_wr_data, spi_reg_rd_data, adc_reg_wr_data, adc_reg_rd_data;
    logic        pat_start, pat_stop, pat_abort, pat_running, pat_done, pat_fail;
    logic [VECTOR_ADDR_W-1:0] pat_start_addr, pat_length;
    logic [NUM_CHANNELS-1:0] site_enable;
    logic [31:0] vector_period, vector_period_fine;

    reg_map u_reg_map (
        .clk(clk_100), .rst_n(rst_n),
        .reg_wr_en(reg_wr_en), .reg_wr_addr(reg_wr_addr),
        .reg_wr_data(reg_wr_data), .reg_wr_strb(reg_wr_strb),
        .reg_rd_en(reg_rd_en), .reg_rd_addr(reg_rd_addr),
        .reg_rd_data(reg_rd_data), .reg_rd_valid(reg_rd_valid),
        .global_reset(global_reset), .global_enable(global_enable),
        .global_status(global_status), .irq_enable(irq_enable),
        .irq_status(irq_status), .irq_clear(irq_clear),
        .self_cal_start(self_cal_start), .self_cal_done(self_cal_done),
        .ch_reg_wr_en(ch_reg_wr_en), .ch_reg_wr_offset(ch_reg_wr_offset),
        .ch_reg_wr_data(ch_reg_wr_data_bus),
        .ch_reg_rd_en(ch_reg_rd_en), .ch_reg_rd_offset(ch_reg_rd_offset),
        .ch_reg_rd_data(ch_reg_rd_data),
        .spi_reg_wr_en(spi_reg_wr_en), .spi_reg_offset(spi_reg_offset),
        .spi_reg_wr_data(spi_reg_wr_data), .spi_reg_rd_en(spi_reg_rd_en),
        .spi_reg_rd_data(spi_reg_rd_data),
        .adc_reg_wr_en(adc_reg_wr_en), .adc_reg_offset(adc_reg_offset),
        .adc_reg_wr_data(adc_reg_wr_data), .adc_reg_rd_en(adc_reg_rd_en),
        .adc_reg_rd_data(adc_reg_rd_data),
        .pat_start(pat_start), .pat_stop(pat_stop), .pat_abort(pat_abort),
        .pat_running(pat_running), .pat_done(pat_done), .pat_fail(pat_fail),
        .pat_start_addr(pat_start_addr), .pat_length(pat_length),
        .site_enable(site_enable),
        .vector_period(vector_period), .vector_period_fine(vector_period_fine)
    );

    // ================================================================
    // Channel Registers × 16
    // ================================================================
    // Per-channel configuration signals
    pin_func_t   ch_pin_func   [NUM_CHANNELS];
    term_mode_t  ch_term_mode  [NUM_CHANNELS];
    drive_fmt_t  ch_drive_fmt  [NUM_CHANNELS];
    logic [1:0]  ch_edge_mult  [NUM_CHANNELS];
    logic [15:0] ch_vih [NUM_CHANNELS], ch_vil [NUM_CHANNELS], ch_vterm [NUM_CHANNELS];
    logic [15:0] ch_voh [NUM_CHANNELS], ch_vol [NUM_CHANNELS];
    logic [15:0] ch_ioh [NUM_CHANNELS], ch_iol [NUM_CHANNELS], ch_vcom [NUM_CHANNELS];
    logic signed [15:0] ch_cal_off_vih [NUM_CHANNELS];
    logic signed [15:0] ch_cal_off_vil [NUM_CHANNELS];
    logic signed [15:0] ch_cal_off_vt  [NUM_CHANNELS];
    logic [NUM_CHANNELS-1:0] ch_levels_updated;
    logic [1:0]  ch_ovd [NUM_CHANNELS];

    generate
        for (genvar ch = 0; ch < NUM_CHANNELS; ch++) begin : g_ch
            assign ch_ovd[ch] = {ovd_ch1[ch], ovd_ch0[ch]};

            channel_regs #(.CHANNEL_ID(ch)) u_ch_regs (
                .clk(clk_100), .rst_n(rst_n),
                .reg_wr_en(ch_reg_wr_en[ch]), .reg_offset(ch_reg_wr_offset),
                .reg_wr_data(ch_reg_wr_data_bus),
                .reg_rd_en(ch_reg_rd_en[ch]), .reg_rd_offset(ch_reg_rd_offset),
                .reg_rd_data(ch_reg_rd_data[ch]),
                .pin_function(ch_pin_func[ch]), .termination_mode(ch_term_mode[ch]),
                .drive_format(ch_drive_fmt[ch]), .edge_multiplier(ch_edge_mult[ch]),
                .level_vih(ch_vih[ch]), .level_vil(ch_vil[ch]), .level_vterm(ch_vterm[ch]),
                .level_voh(ch_voh[ch]), .level_vol(ch_vol[ch]),
                .level_ioh(ch_ioh[ch]), .level_iol(ch_iol[ch]), .level_vcom(ch_vcom[ch]),
                .ppmu_mode(), .ppmu_voltage_level(), .ppmu_current_level(),
                .ppmu_current_range(), .ppmu_vclamp_h(), .ppmu_vclamp_l(),
                .ppmu_aperture_time(), .ppmu_measure_result(32'b0),
                .static_state(), .static_state_wr(),
                .cal_offset_vih(ch_cal_off_vih[ch]),
                .cal_offset_vil(ch_cal_off_vil[ch]),
                .cal_offset_vt(ch_cal_off_vt[ch]),
                .cal_gain_i(), .cal_offset_i(),
                .ovd_status(ch_ovd[ch]),
                .levels_updated(ch_levels_updated[ch])
            );
        end
    endgenerate

    // ================================================================
    // SPI Master + Level Update Engine
    // ================================================================
    logic        spi_cmd_valid, spi_cmd_ready, spi_cmd_done;
    logic [2:0]  spi_cmd_chip;
    logic        spi_cmd_rw;
    logic [6:0]  spi_cmd_addr;
    logic [15:0] spi_cmd_wdata, spi_cmd_rdata;

    // Level update engine drives SPI commands
    logic        lvl_cmd_valid, lvl_cmd_ready, lvl_cmd_done;
    logic [2:0]  lvl_cmd_chip;
    logic [6:0]  lvl_cmd_addr;
    logic [15:0] lvl_cmd_wdata;

    spi_level_update u_lvl_update (
        .clk(clk_100), .rst_n(rst_n),
        .levels_updated(ch_levels_updated),
        .ch_vih(ch_vih), .ch_vil(ch_vil), .ch_vterm(ch_vterm),
        .ch_voh(ch_voh), .ch_vol(ch_vol),
        .ch_ioh(ch_ioh), .ch_iol(ch_iol), .ch_vcom(ch_vcom),
        .ch_cal_off_vih(ch_cal_off_vih), .ch_cal_off_vil(ch_cal_off_vil),
        .ch_cal_off_vt(ch_cal_off_vt),
        .ch_pin_func(ch_pin_func),
        .ch_ppmu_vlevel('{default: '0}), .ch_ppmu_ilevel('{default: '0}),
        .ch_ppmu_mode('{default: PPMU_OFF}),
        .cmd_valid(lvl_cmd_valid), .cmd_chip_sel(lvl_cmd_chip),
        .cmd_rw(1'b0), .cmd_addr(lvl_cmd_addr), .cmd_wdata(lvl_cmd_wdata),
        .cmd_ready(spi_cmd_ready), .cmd_done(spi_cmd_done),
        .busy(), .update_done()
    );

    spi_master u_spi (
        .clk(clk_100), .rst_n(rst_n),
        .reg_wr_en(spi_reg_wr_en), .reg_offset(spi_reg_offset),
        .reg_wr_data(spi_reg_wr_data), .reg_rd_en(spi_reg_rd_en),
        .reg_rd_data(spi_reg_rd_data),
        .cmd_valid(lvl_cmd_valid), .cmd_chip_sel(lvl_cmd_chip),
        .cmd_rw(1'b0), .cmd_addr(lvl_cmd_addr), .cmd_wdata(lvl_cmd_wdata),
        .cmd_ready(spi_cmd_ready), .cmd_done(spi_cmd_done), .cmd_rdata(),
        .spi_sclk(adate_spi_sclk), .spi_mosi(adate_spi_mosi),
        .spi_miso(adate_spi_miso), .spi_cs_n(adate_spi_cs_n),
        .spi_rst_n(adate_spi_rst_n)
    );

    // ================================================================
    // ADC Controller
    // ================================================================
    logic [11:0] measout_data [NUM_CHANNELS];
    logic [NUM_CHANNELS-1:0] measout_valid;

    // ADC has shared bus: map single-wire ports to adc_ctrl's array ports
    logic [NUM_ADC-1:0] adc_sclk_int, adc_mosi_int;
    logic [NUM_ADC-1:0] adc_miso_int;

    adc_ctrl u_adc (
        .clk(clk_100), .rst_n(rst_n),
        .reg_wr_en(adc_reg_wr_en), .reg_offset(adc_reg_offset),
        .reg_wr_data(adc_reg_wr_data), .reg_rd_en(adc_reg_rd_en),
        .reg_rd_data(adc_reg_rd_data),
        .adc_sclk(adc_sclk_int), .adc_mosi(adc_mosi_int),
        .adc_miso(adc_miso_int), .adc_cs_n(adc_spi_cs_n),
        .measout_data(measout_data), .measout_valid(measout_valid)
    );

    // Shared bus: both ADCs on same physical SCLK/MOSI/MISO
    assign adc_spi_sclk = adc_sclk_int[0];
    assign adc_spi_mosi = adc_mosi_int[0];
    assign adc_miso_int = {adc_spi_miso, adc_spi_miso}; // Both read same MISO line

    // ================================================================
    // Sequencer + Vector Prefetch
    // ================================================================
    logic        vmem_rd_req;
    logic [VECTOR_ADDR_W-1:0] vmem_rd_addr;
    logic [VECTOR_WIDTH-1:0]  vmem_rd_data;
    logic        vmem_rd_valid;
    logic        vec_valid;
    logic [4:0]  vec_timeset;
    pin_state_t  vec_pin_state [NUM_CHANNELS];
    logic [NUM_CHANNELS-1:0] vec_compare_en;
    logic [NUM_CHANNELS-1:0] compare_pass;
    logic        compare_valid;

    // Trigger → start
    logic start_trigger;
    logic effective_start;
    assign effective_start = pat_start | start_trigger;

    sequencer u_sequencer (
        .clk(clk_100), .rst_n(rst_n),
        .pat_start(effective_start), .pat_stop(pat_stop), .pat_abort(pat_abort),
        .pat_running(pat_running), .pat_done(pat_done), .pat_fail(pat_fail),
        .start_addr(pat_start_addr), .pat_length(pat_length), .site_enable(site_enable),
        .vmem_rd_req(vmem_rd_req), .vmem_rd_addr(vmem_rd_addr),
        .vmem_rd_data(vmem_rd_data), .vmem_rd_valid(vmem_rd_valid),
        .vec_valid(vec_valid), .vec_timeset(vec_timeset),
        .vec_pin_state(vec_pin_state), .vec_compare_en(vec_compare_en),
        .compare_pass(compare_pass), .compare_valid(compare_valid),
        .seq_flags(), .seq_registers(),
        .hram_wr_en(), .hram_wr_addr(), .hram_wr_cycle(), .hram_wr_fail_mask()
    );

    // Vector prefetch (DDR3 → Sequencer)
    // DDR3 side signals (connect to MIG IP)
    logic        ddr_rd_req;
    logic [VECTOR_ADDR_W-1:0] ddr_rd_addr;
    logic [VECTOR_WIDTH-1:0]  ddr_rd_data;
    logic        ddr_rd_valid, ddr_rd_ready;

    vector_prefetch u_prefetch (
        .clk(clk_100), .rst_n(rst_n),
        .seq_rd_req(vmem_rd_req), .seq_rd_addr(vmem_rd_addr),
        .seq_rd_data(vmem_rd_data), .seq_rd_valid(vmem_rd_valid),
        .ddr_rd_req(ddr_rd_req), .ddr_rd_addr(ddr_rd_addr),
        .ddr_rd_data(ddr_rd_data), .ddr_rd_valid(ddr_rd_valid),
        .ddr_rd_ready(ddr_rd_ready),
        .flush(effective_start | pat_abort),
        .fifo_empty(), .fifo_level()
    );

    // DDR3 Memory Controller
    ddr3_wrapper u_ddr3 (
        .sys_clk_200(sys_clk_200), .sys_rst_n(rst_n),
        .ui_clk(), .ui_rst_n(), .init_calib_complete(),
        // DDR3 physical pins (directly connected in constraints)
        .ddr3_addr(), .ddr3_ba(), .ddr3_ras_n(), .ddr3_cas_n(), .ddr3_we_n(),
        .ddr3_reset_n(), .ddr3_ck_p(), .ddr3_ck_n(), .ddr3_cke(), .ddr3_cs_n(),
        .ddr3_dm(), .ddr3_dq(), .ddr3_dqs_p(), .ddr3_dqs_n(), .ddr3_odt(),
        // Vector read port
        .pa_rd_req(ddr_rd_req), .pa_rd_addr(ddr_rd_addr),
        .pa_rd_data(ddr_rd_data), .pa_rd_valid(ddr_rd_valid),
        .pa_rd_ready(ddr_rd_ready),
        // DMA write port (from PCIe)
        .pb_wr_req(1'b0), .pb_wr_addr('0), .pb_wr_data('0), .pb_wr_ready()
    );

    // ================================================================
    // Timing Engine — generates per-channel OSERDES patterns + delay taps
    // ================================================================
    logic [7:0]  te_ch_oserdes_d [NUM_CHANNELS];
    logic [8:0]  te_ch_odelay_tap [NUM_CHANNELS];
    logic [NUM_CHANNELS-1:0] te_ch_odelay_load;
    logic [8:0]  te_ch_idelay_tap [NUM_CHANNELS];
    logic [NUM_CHANNELS-1:0] te_ch_idelay_load;
    logic [NUM_CHANNELS-1:0] te_ch_compare_strobe;
    logic        te_cycle_start, te_cycle_end;

    // Convert edge_mult from 2-bit to bool for timing engine
    logic ch_edge_2x [NUM_CHANNELS];
    generate
        for (genvar i = 0; i < NUM_CHANNELS; i++)
            assign ch_edge_2x[i] = ch_edge_mult[i][0];
    endgenerate

    timing_engine u_timing_engine (
        .clk_100(clk_100), .clk_400(clk_400), .clk_800(clk_800), .rst_n(rst_n),
        .period_reg(vector_period),
        .ts_wr_en(1'b0), .ts_wr_id(5'd0), .ts_wr_edge_sel(3'd0),
        .ts_wr_ch(4'd0), .ts_wr_value(26'd0),
        .tdr_wr_en(1'b0), .tdr_wr_ch(4'd0), .tdr_wr_value(9'd0),
        .vec_valid(vec_valid), .vec_timeset(vec_timeset),
        .ch_pin_state(vec_pin_state), .ch_drive_fmt(ch_drive_fmt),
        .ch_edge_2x(ch_edge_2x),
        .ch_oserdes_d(te_ch_oserdes_d),
        .ch_odelay_tap(te_ch_odelay_tap), .ch_odelay_load(te_ch_odelay_load),
        .ch_idelay_tap(te_ch_idelay_tap), .ch_idelay_load(te_ch_idelay_load),
        .ch_compare_strobe(te_ch_compare_strobe),
        .cycle_start(te_cycle_start), .cycle_end(te_cycle_end)
    );

    // ================================================================
    // Per-Channel SERDES + Compare Logic
    // ================================================================
    logic [7:0] ch_rx_data [NUM_CHANNELS];

    generate
        for (genvar ch = 0; ch < NUM_CHANNELS; ch++) begin : g_serdes
            // Channel 0: OSERDES3 + ODELAYE3 (drive) / ISERDES3 + IDELAYE3 (compare)
            channel_serdes u_serdes_ch0 (
                .clk_100(clk_100), .clk_400(clk_400), .rst(~rst_n),
                .tx_data(te_ch_oserdes_d[ch]),
                .tx_out_p(data0_p[ch]), .tx_out_n(data0_n[ch]),
                .odelay_tap(te_ch_odelay_tap[ch]),
                .odelay_load(te_ch_odelay_load[ch]),
                .rx_in_p(rcv0_p[ch]), .rx_in_n(rcv0_n[ch]),
                .rx_data(ch_rx_data[ch]),
                .idelay_tap(te_ch_idelay_tap[ch]),
                .idelay_load(te_ch_idelay_load[ch])
            );

            // Channel 1: second data/rcv pair (for 2x edge multiplier mode)
            channel_serdes u_serdes_ch1 (
                .clk_100(clk_100), .clk_400(clk_400), .rst(~rst_n),
                .tx_data(8'h00),  // TODO: ch1 pattern from timing engine
                .tx_out_p(data1_p[ch]), .tx_out_n(data1_n[ch]),
                .odelay_tap(9'd0), .odelay_load(1'b0),
                .rx_in_p(rcv1_p[ch]), .rx_in_n(rcv1_n[ch]),
                .rx_data(),
                .idelay_tap(9'd0), .idelay_load(1'b0)
            );

            // Compare logic per channel (uses ch0 comparator outputs)
            compare_logic u_compare (
                .clk(clk_100), .rst_n(rst_n),
                .comp_qh(comp_qh0_p[ch]),
                .comp_ql(comp_ql0_p[ch]),
                .comp_sample(te_ch_compare_strobe[ch]),
                .comp_enable(vec_compare_en[ch]),
                .expected_state(vec_pin_state[ch]),
                .compare_pass(compare_pass[ch]),
                .compare_valid(),
                .compare_fail_latch()
            );
        end
    endgenerate

    // Compare valid: one cycle after all compare strobes fire
    logic [NUM_CHANNELS-1:0] strobe_d;
    always_ff @(posedge clk_100) strobe_d <= te_ch_compare_strobe;
    assign compare_valid = |strobe_d;

    // ================================================================
    // Trigger Interface
    // ================================================================
    logic [6:0] trig_out, trig_oe;
    logic       dstarb_in, dstarc_out_int;

    IBUFDS u_dstarb_buf (.I(dstarb_p), .IB(dstarb_n), .O(dstarb_in));

    trigger_intf u_trigger (
        .clk(clk_100), .rst_n(rst_n),
        .pxi_trig_in(pxi_trig), .pxi_trig_out(trig_out), .pxi_trig_oe(trig_oe),
        .dstarb_in(dstarb_in), .dstarc_out(dstarc_out_int),
        .pxie_clk100(pxie_clk100),
        .reg_wr_en(1'b0), .reg_offset(8'h0), .reg_wr_data(32'h0), .reg_rd_data(),
        .start_trigger(start_trigger),
        .pat_running(pat_running), .pat_done(pat_done), .pat_fail(pat_fail),
        .seq_set_signal(1'b0), .seq_pulse_signal(1'b0), .seq_clear_signal(1'b0),
        .seq_signal_id(3'b0), .seq_reset_trigger(1'b0)
    );

    // PXI trigger tristate control
    generate
        for (genvar t = 0; t < 7; t++) begin : g_trig
            assign pxi_trig[t] = trig_oe[t] ? trig_out[t] : 1'bz;
        end
    endgenerate

    OBUFDS u_dstarc_buf (.O(dstarc_p), .OB(dstarc_n), .I(dstarc_out_int));

    // ================================================================
    // Status
    // ================================================================
    assign global_status = {ovd_ch1, ovd_ch0};
    assign irq_status    = {28'b0, pat_fail, pat_done, pat_running, self_cal_done};
    assign self_cal_done = 1'b0; // TODO: from cal_controller
    assign led_access    = rst_n;
    assign led_active    = pat_running;

endmodule
