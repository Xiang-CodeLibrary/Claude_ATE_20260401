// Timing Engine Hardware Verification Top-Level
//
// 验证目标:
//   1. MMCM 800/400/100 MHz 时钟锁定
//   2. IDELAYCTRL 校准完成
//   3. OSERDES3 输出正确波形
//   4. ODELAYE3 延迟步进可观测 (示波器)
//   5. 39.0625 ps 单步延迟可测量
//   6. Vector period 精度
//
// 测试方法:
//   VIO控制: 选择测试模式、设置edge位置、设置delay tap
//   ILA抓取: 内部信号状态
//   示波器:  在BTB连接器LVDS输出端测量波形
//
// 使用2个LVDS通道: CH0和CH1
//   CH0: 测试输出 (被测通道)
//   CH1: 参考输出 (固定时序,作为示波器触发)

module timing_test_top (
    // 200 MHz system clock (G3 oscillator, LVDS)
    input  logic        sys_clk_p,
    input  logic        sys_clk_n,

    // Test LVDS outputs (Bank 47, to BTB connector → DLC board/测试点)
    // CH0: test channel (delay swept)
    output logic        test_ch0_p,
    output logic        test_ch0_n,
    // CH1: reference channel (fixed timing, scope trigger)
    output logic        test_ch1_p,
    output logic        test_ch1_n,

    // Status LEDs
    output logic        led_mmcm_locked,
    output logic        led_idelayctrl_rdy,
    output logic        led_test_running
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

    assign led_mmcm_locked    = mmcm_locked;
    assign led_idelayctrl_rdy = idelayctrl_rdy;

    // ================================================================
    // VIO — Virtual I/O for runtime control via JTAG
    // ================================================================
    // VIO outputs (FPGA→user control):
    logic [3:0]  vio_test_mode;    // 0=idle, 1=固定频率, 2=delay扫描, 3=period测试
    logic [7:0]  vio_oserdes_pat;  // 直接OSERDES pattern (mode 1)
    logic [8:0]  vio_delay_tap;    // ODELAYE3 tap value (0~511)
    logic        vio_delay_load;   // Pulse to load delay
    logic [31:0] vio_period_reg;   // DDS period register
    logic [13:0] vio_edge_coarse;  // Edge coarse position (clock cycles)
    logic [2:0]  vio_edge_slot;    // Edge OSERDES bit slot (0~7)
    logic        vio_enable;       // Enable output

    // VIO inputs (FPGA→Vivado display):
    logic [31:0] vio_status;

    // Xilinx VIO IP (generated in Vivado, instantiation template)
    // Replace with actual generated IP name
    vio_timing_test u_vio (
        .clk        (clk_100),
        .probe_in0  (vio_status),           // [31:0] status
        .probe_out0 (vio_test_mode),        // [3:0]  test mode
        .probe_out1 (vio_oserdes_pat),      // [7:0]  oserdes pattern
        .probe_out2 (vio_delay_tap),        // [8:0]  delay tap
        .probe_out3 ({31'b0, vio_delay_load}), // [0] delay load
        .probe_out4 (vio_period_reg),       // [31:0] period
        .probe_out5 ({18'b0, vio_edge_coarse}), // [13:0] coarse
        .probe_out6 ({29'b0, vio_edge_slot}),   // [2:0] slot
        .probe_out7 ({31'b0, vio_enable})   // [0] enable
    );

    assign vio_status = {
        20'b0,
        4'b0,           // [11:8] reserved
        rst_n,          // [7]
        idelayctrl_rdy, // [6]
        mmcm_locked,    // [5]
        vio_enable,     // [4]
        vio_test_mode   // [3:0]
    };

    assign led_test_running = vio_enable;

    // ================================================================
    // Test Pattern Generator
    // ================================================================
    // Mode 1: 固定OSERDES pattern输出 (验证OSERDES功能)
    // Mode 2: 延迟扫描 (固定pattern,扫描ODELAYE3 tap,示波器看边沿移动)
    // Mode 3: 周期测试 (DDS产生不同vector周期的方波)

    logic [7:0] ch0_oserdes_data;
    logic [7:0] ch1_oserdes_data;
    logic [8:0] ch0_delay_tap;
    logic       ch0_delay_load;

    // Free-running counter for generating test patterns
    logic [31:0] free_counter;
    logic [13:0] coarse_cnt;
    logic        period_tick;

    // DDS for vector period
    logic [31:0] dds_acc;
    logic [31:0] dds_period;

    always_ff @(posedge clk_100 or negedge rst_n) begin
        if (!rst_n) begin
            free_counter <= '0;
            dds_acc      <= '0;
            dds_period   <= 32'h0004_0000; // 10ns default
            coarse_cnt   <= '0;
            period_tick  <= 1'b0;
        end else begin
            free_counter <= free_counter + 1'b1;
            period_tick  <= 1'b0;

            dds_period <= (vio_period_reg != '0) ? vio_period_reg : 32'h0004_0000;

            dds_acc <= dds_acc + 32'h0004_0000; // +1 clock cycle
            if (dds_acc >= dds_period) begin
                dds_acc     <= dds_acc - dds_period;
                period_tick <= 1'b1;
                coarse_cnt  <= '0;
            end else begin
                coarse_cnt <= coarse_cnt + 1'b1;
            end
        end
    end

    // Generate OSERDES patterns based on test mode
    always_comb begin
        ch0_oserdes_data = 8'h00;
        ch1_oserdes_data = 8'h00;
        ch0_delay_tap    = '0;
        ch0_delay_load   = 1'b0;

        if (vio_enable) begin
            case (vio_test_mode)
                // Mode 1: 直接pattern控制
                // 用于验证OSERDES输出, 例如设0xF0→方波@400MHz
                4'd1: begin
                    ch0_oserdes_data = vio_oserdes_pat;
                    ch1_oserdes_data = 8'hF0; // Reference: 400MHz方波
                    ch0_delay_tap    = vio_delay_tap;
                    ch0_delay_load   = vio_delay_load;
                end

                // Mode 2: 延迟扫描测试
                // 固定输出100MHz方波, 扫描ODELAYE3 tap
                // 示波器CH1触发, 观察CH0边沿相对CH1的偏移
                4'd2: begin
                    // 100MHz方波: 每个CLKDIV周期5个高+5个低→近似
                    // 8-bit pattern: 0xF0 = 1111_0000 → 4high+4low @800Mbps=每5ns翻转
                    ch0_oserdes_data = 8'hF0;
                    ch1_oserdes_data = 8'hF0; // Reference (fixed delay)
                    ch0_delay_tap    = vio_delay_tap;
                    ch0_delay_load   = vio_delay_load;
                end

                // Mode 3: 边沿定位测试
                // 在指定的coarse cycle和slot位置产生单次边沿
                // 验证边沿定位精度
                4'd3: begin
                    ch1_oserdes_data = 8'hFF; // Reference: 持续高,period_tick时翻低
                    if (period_tick)
                        ch1_oserdes_data = 8'h00; // 低一个CLKDIV周期

                    // CH0: 在指定位置产生上升沿
                    if (coarse_cnt < vio_edge_coarse) begin
                        ch0_oserdes_data = 8'h00; // 低
                    end else if (coarse_cnt == vio_edge_coarse) begin
                        // 在指定bit-slot产生上升沿
                        ch0_oserdes_data = 8'hFF << vio_edge_slot; // 从slot开始拉高
                    end else begin
                        ch0_oserdes_data = 8'hFF; // 高
                    end

                    ch0_delay_tap  = vio_delay_tap;
                    ch0_delay_load = vio_delay_load;
                end

                // Mode 4: 39ps步进验证
                // 输出固定pattern, 每次VIO改变delay tap +1
                // 示波器无限余辉模式, 预期看到等间距边沿
                4'd4: begin
                    ch0_oserdes_data = 8'hF0;
                    ch1_oserdes_data = 8'hF0;
                    ch0_delay_tap    = vio_delay_tap;
                    ch0_delay_load   = vio_delay_load;
                end

                default: begin
                    ch0_oserdes_data = 8'h00;
                    ch1_oserdes_data = 8'h00;
                end
            endcase
        end
    end

    // ================================================================
    // Channel 0: OSERDES3 + ODELAYE3 (被测通道)
    // ================================================================
    channel_serdes u_ch0_serdes (
        .clk_100     (clk_100),
        .clk_400     (clk_400),
        .rst         (~rst_n),
        .tx_data     (ch0_oserdes_data),
        .tx_out_p    (test_ch0_p),
        .tx_out_n    (test_ch0_n),
        .odelay_tap  (ch0_delay_tap),
        .odelay_load (ch0_delay_load),
        // RX not used in this test
        .rx_in_p     (1'b0),
        .rx_in_n     (1'b1),
        .rx_data     (),
        .idelay_tap  (9'd0),
        .idelay_load (1'b0)
    );

    // ================================================================
    // Channel 1: OSERDES3 only, no delay (参考通道)
    // ================================================================
    logic ch1_serial;

    OSERDESE3 #(
        .DATA_WIDTH(8), .INIT(1'b0), .SIM_DEVICE("ULTRASCALE")
    ) u_ch1_oserdes (
        .OQ(ch1_serial), .T_OUT(), .CLK(clk_400), .CLKDIV(clk_100),
        .D(ch1_oserdes_data), .RST(~rst_n), .T(1'b0)
    );

    OBUFDS u_ch1_obuf (.O(test_ch1_p), .OB(test_ch1_n), .I(ch1_serial));

    // ================================================================
    // ILA — 内部逻辑分析仪 (可选,在Vivado中生成)
    // ================================================================
    // 抓取信号: clk_100域
    //   - vio_test_mode, vio_enable
    //   - ch0_oserdes_data, ch1_oserdes_data
    //   - ch0_delay_tap, ch0_delay_load
    //   - dds_acc, coarse_cnt, period_tick
    //   - mmcm_locked, idelayctrl_rdy

    ila_timing_test u_ila (
        .clk    (clk_100),
        .probe0 ({vio_test_mode, vio_enable, mmcm_locked, idelayctrl_rdy, rst_n}), // [7:0]
        .probe1 (ch0_oserdes_data),  // [7:0]
        .probe2 (ch1_oserdes_data),  // [7:0]
        .probe3 ({ch0_delay_load, ch0_delay_tap}), // [9:0]
        .probe4 (coarse_cnt),        // [13:0]
        .probe5 (dds_acc)            // [31:0]
    );

endmodule
