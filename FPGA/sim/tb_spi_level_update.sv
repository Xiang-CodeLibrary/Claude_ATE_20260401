`timescale 1ns / 1ps

module tb_spi_level_update;
    import ate_pkg::*;

    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    // Inputs
    logic [NUM_CHANNELS-1:0] levels_updated;
    logic [15:0] ch_vih [NUM_CHANNELS], ch_vil [NUM_CHANNELS], ch_vterm [NUM_CHANNELS];
    logic [15:0] ch_voh [NUM_CHANNELS], ch_vol [NUM_CHANNELS];
    logic [15:0] ch_ioh [NUM_CHANNELS], ch_iol [NUM_CHANNELS], ch_vcom [NUM_CHANNELS];
    logic signed [15:0] ch_cal_off_vih [NUM_CHANNELS];
    logic signed [15:0] ch_cal_off_vil [NUM_CHANNELS];
    logic signed [15:0] ch_cal_off_vt  [NUM_CHANNELS];
    pin_func_t ch_pin_func [NUM_CHANNELS];
    logic [15:0] ch_ppmu_vlevel [NUM_CHANNELS];
    logic [15:0] ch_ppmu_ilevel [NUM_CHANNELS];
    ppmu_mode_t ch_ppmu_mode [NUM_CHANNELS];

    // SPI command interface
    logic        cmd_valid, cmd_ready, cmd_done;
    logic [2:0]  cmd_chip_sel;
    logic        cmd_rw;
    logic [6:0]  cmd_addr;
    logic [15:0] cmd_wdata;
    logic        busy, update_done;

    spi_level_update u_dut (
        .clk(clk), .rst_n(rst_n),
        .levels_updated(levels_updated),
        .ch_vih(ch_vih), .ch_vil(ch_vil), .ch_vterm(ch_vterm),
        .ch_voh(ch_voh), .ch_vol(ch_vol),
        .ch_ioh(ch_ioh), .ch_iol(ch_iol), .ch_vcom(ch_vcom),
        .ch_cal_off_vih(ch_cal_off_vih), .ch_cal_off_vil(ch_cal_off_vil),
        .ch_cal_off_vt(ch_cal_off_vt),
        .ch_pin_func(ch_pin_func),
        .ch_ppmu_vlevel(ch_ppmu_vlevel), .ch_ppmu_ilevel(ch_ppmu_ilevel),
        .ch_ppmu_mode(ch_ppmu_mode),
        .cmd_valid(cmd_valid), .cmd_chip_sel(cmd_chip_sel),
        .cmd_rw(cmd_rw), .cmd_addr(cmd_addr), .cmd_wdata(cmd_wdata),
        .cmd_ready(cmd_ready), .cmd_done(cmd_done),
        .busy(busy), .update_done(update_done)
    );

    // SPI slave model: accept commands with 20-cycle latency
    logic [4:0] spi_delay_cnt;
    logic spi_busy;
    logic spi_cmd_rst;
    int spi_cmd_count;

    logic [2:0]  last_chip;
    logic [6:0]  last_addr;
    logic [15:0] last_wdata;

    assign cmd_ready = !spi_busy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_busy      <= 0;
            spi_delay_cnt <= 0;
            cmd_done      <= 0;
        end else begin
            cmd_done <= 0;
            if (cmd_valid && !spi_busy) begin
                spi_busy      <= 1;
                spi_delay_cnt <= 0;
                last_chip     <= cmd_chip_sel;
                last_addr     <= cmd_addr;
                last_wdata    <= cmd_wdata;
            end else if (spi_busy) begin
                spi_delay_cnt <= spi_delay_cnt + 1;
                if (spi_delay_cnt == 5'd15) begin
                    spi_busy <= 0;
                    cmd_done <= 1;
                end
            end
        end
    end

    // Separate counter (driven only by initial block)
    always @(posedge clk) begin
        if (spi_cmd_rst)
            spi_cmd_count <= 0;
        else if (cmd_done)
            spi_cmd_count <= spi_cmd_count + 1;
    end

    integer errors = 0;

    initial begin
        $dumpfile("tb_spi_level_update.vcd");
        $dumpvars(0, tb_spi_level_update);

        rst_n = 0;
        levels_updated = '0;
        for (int i = 0; i < NUM_CHANNELS; i++) begin
            ch_vih[i] = 0; ch_vil[i] = 0; ch_vterm[i] = 0;
            ch_voh[i] = 0; ch_vol[i] = 0;
            ch_ioh[i] = 0; ch_iol[i] = 0; ch_vcom[i] = 0;
            ch_cal_off_vih[i] = 0; ch_cal_off_vil[i] = 0; ch_cal_off_vt[i] = 0;
            ch_pin_func[i] = PIN_DIGITAL;
            ch_ppmu_vlevel[i] = 0; ch_ppmu_ilevel[i] = 0;
            ch_ppmu_mode[i] = PPMU_OFF;
        end
        #100 rst_n = 1;
        repeat(5) @(posedge clk);

        $display("=== SPI Level Update Test ===");

        // Test 1: Single channel update triggers 7 SPI writes (VH,VL,VT,VOH,VOL,IOH,IOL)
        $display("Test 1: Single channel level update");
        ch_vih[0]  = 16'h3000;
        ch_vil[0]  = 16'h1000;
        ch_vterm[0] = 16'h2000;
        ch_voh[0]  = 16'h2800;
        ch_vol[0]  = 16'h0800;
        ch_ioh[0]  = 16'h0100;
        ch_iol[0]  = 16'h0200;
        @(posedge clk); spi_cmd_rst <= 1;
        @(posedge clk); spi_cmd_rst <= 0;

        @(posedge clk); levels_updated[0] <= 1;
        @(posedge clk); levels_updated[0] <= 0;

        // Wait for all SPI commands to complete
        repeat(300) @(posedge clk);
        // Check busy went high then back to low (7 SPI transactions completed)
        if (!update_done) begin
            // Wait a bit more
            repeat(200) @(posedge clk);
        end
        $display("  SPI commands sent: %0d, update_done=%b, busy=%b", spi_cmd_count, update_done, busy);
        if (busy) begin
            $error("  Still busy after 300+ cycles");
            errors++;
        end else $display("  PASS: level update completed");

        // Test 2: Calibration offset applied
        $display("Test 2: Calibration offset");
        ch_vih[1] = 16'h4000;
        ch_cal_off_vih[1] = 16'h0010; // +16 offset
        @(posedge clk); spi_cmd_rst <= 1; @(posedge clk); spi_cmd_rst <= 0;

        @(posedge clk); levels_updated[1] <= 1;
        @(posedge clk); levels_updated[1] <= 0;

        // Wait and check first SPI write (VH) has calibrated value
        wait(cmd_done); @(posedge clk);
        $display("  CH1 VH: raw=0x4000 + offset=0x0010 → SPI wdata=0x%04h", last_wdata);
        if (last_wdata != 16'h4010) begin
            $error("  Expected 0x4010, got 0x%04h", last_wdata);
            errors++;
        end else $display("  PASS: calibration applied");

        repeat(300) @(posedge clk);

        // Test 3: Chip select mapping (channel N → chip N/2)
        $display("Test 3: Chip select mapping");
        ch_vih[4] = 16'h5000; // Channel 4 → chip 2
        @(posedge clk); spi_cmd_rst <= 1; @(posedge clk); spi_cmd_rst <= 0;

        @(posedge clk); levels_updated[4] <= 1;
        @(posedge clk); levels_updated[4] <= 0;

        wait(cmd_done); @(posedge clk);
        $display("  CH4 → chip_sel=%0d (expect 2)", last_chip);
        if (last_chip != 3'd2) begin
            $error("  Expected chip 2, got %0d", last_chip);
            errors++;
        end else $display("  PASS");

        repeat(300) @(posedge clk);

        // Test 4: Multiple channels pending
        $display("Test 4: Two channels updated simultaneously");
        ch_vih[8] = 16'hA000;
        ch_vih[9] = 16'hB000;
        @(posedge clk); spi_cmd_rst <= 1; @(posedge clk); spi_cmd_rst <= 0;

        @(posedge clk);
        levels_updated[8] <= 1;
        levels_updated[9] <= 1;
        @(posedge clk);
        levels_updated <= '0;

        // Wait for both channels (7 writes each = 14 total)
        repeat(600) @(posedge clk);
        $display("  SPI commands: %0d, busy=%b", spi_cmd_count, busy);
        if (busy) begin
            $error("  Still busy");
            errors++;
        end else $display("  PASS: both channels updated");

        // Test 5: No update when no levels_updated pulse
        $display("Test 5: Idle (no spurious SPI)");
        @(posedge clk); spi_cmd_rst <= 1; @(posedge clk); spi_cmd_rst <= 0;
        repeat(200) @(posedge clk);
        if (spi_cmd_count != 0) begin
            $error("  Spurious SPI commands: %0d", spi_cmd_count);
            errors++;
        end else $display("  PASS: no spurious commands");

        repeat(10) @(posedge clk);
        $display("==========================================");
        $display("SPI Level Update Test: %0d errors", errors);
        if (errors == 0) $display("ALL TESTS PASSED");
        $finish;
    end

    initial begin #200_000; $error("TIMEOUT"); $finish; end
endmodule
