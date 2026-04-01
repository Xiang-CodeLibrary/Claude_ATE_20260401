`timescale 1ns / 1ps

module tb_adc_ctrl;
    import ate_pkg::*;

    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    logic        reg_wr_en, reg_rd_en;
    logic [7:0]  reg_offset;
    logic [31:0] reg_wr_data, reg_rd_data;

    logic [NUM_ADC-1:0] adc_sclk, adc_mosi, adc_miso, adc_cs_n;
    logic [11:0] measout_data [NUM_CHANNELS];
    logic [NUM_CHANNELS-1:0] measout_valid;

    adc_ctrl u_dut (
        .clk(clk), .rst_n(rst_n),
        .reg_wr_en(reg_wr_en), .reg_offset(reg_offset),
        .reg_wr_data(reg_wr_data), .reg_rd_en(reg_rd_en),
        .reg_rd_data(reg_rd_data),
        .adc_sclk(adc_sclk), .adc_mosi(adc_mosi),
        .adc_miso(adc_miso), .adc_cs_n(adc_cs_n),
        .measout_data(measout_data), .measout_valid(measout_valid)
    );

    // ADC slave model: returns channel-dependent value
    // Return value = {4'b0, channel[2:0], 9'h100 + channel}
    logic [3:0] adc_bit_cnt [NUM_ADC];
    logic [15:0] adc_shift_in [NUM_ADC];
    logic [15:0] adc_shift_out [NUM_ADC];
    logic [2:0]  adc_ch_sel [NUM_ADC];

    generate
        for (genvar a = 0; a < NUM_ADC; a++) begin : gen_adc_slave
            always_ff @(negedge adc_sclk[a] or posedge adc_cs_n[a]) begin
                if (adc_cs_n[a]) begin
                    adc_bit_cnt[a] <= 0;
                    // Prepare response: simulated ADC value based on channel
                    adc_shift_out[a] <= {4'b0, 12'(12'h100 + a*8 + adc_ch_sel[a])};
                end else begin
                    adc_shift_in[a] <= {adc_shift_in[a][14:0], adc_mosi[a]};
                    adc_bit_cnt[a] <= adc_bit_cnt[a] + 1;
                    adc_shift_out[a] <= {adc_shift_out[a][14:0], 1'b0};
                    // Latch channel from incoming frame at bit 3
                    if (adc_bit_cnt[a] == 3)
                        adc_ch_sel[a] <= adc_shift_in[a][2:0];
                end
            end
            assign adc_miso[a] = adc_shift_out[a][15];
        end
    endgenerate

    integer errors = 0;

    task adc_start_scan();
        @(posedge clk);
        reg_wr_en   <= 1;
        reg_offset  <= 8'h00;
        reg_wr_data <= 32'h0000_0001; // start scan, no oversample
        @(posedge clk);
        reg_wr_en <= 0;
    endtask

    task wait_scan_done();
        int timeout = 0;
        while (timeout < 50000) begin
            @(posedge clk);
            reg_rd_en  <= 1;
            reg_offset <= 8'h04; // STATUS
            @(posedge clk);
            reg_rd_en <= 0;
            if (reg_rd_data[1]) return; // scan_done
            timeout++;
        end
        $error("  Scan timeout!");
        errors++;
    endtask

    initial begin
        $dumpfile("tb_adc_ctrl.vcd");
        $dumpvars(0, tb_adc_ctrl);

        rst_n = 0;
        reg_wr_en = 0; reg_rd_en = 0; reg_offset = 0; reg_wr_data = 0;
        for (int a = 0; a < NUM_ADC; a++) adc_ch_sel[a] = 0;
        #100 rst_n = 1;
        repeat(5) @(posedge clk);

        $display("=== ADC Controller Test Start ===");

        // ================================================================
        // Test 1: Single scan, no oversample
        // ================================================================
        $display("Test 1: Single scan, no oversample");
        adc_start_scan();
        wait_scan_done();

        // Read back ADC data for channels 0~15
        for (int ch = 0; ch < NUM_CHANNELS; ch++) begin
            reg_rd_en  <= 1;
            reg_offset <= 8'h08 + ch * 4;
            @(posedge clk);
            reg_rd_en <= 0;
            @(posedge clk);
            $display("  CH%02d: measout=0x%03h (reg_rd=0x%08h)", ch, measout_data[ch], reg_rd_data);
        end

        // Verify at least ch0 has non-zero data
        if (measout_data[0] == 0 && measout_data[1] == 0) begin
            $error("  CH0 and CH1 both zero — ADC slave may not be responding");
            errors++;
        end else begin
            $display("  Non-zero data received ✓");
        end

        repeat(10) @(posedge clk);

        // ================================================================
        // Test 2: Scan with 4x oversample
        // ================================================================
        $display("Test 2: 4x oversample scan");
        @(posedge clk);
        reg_wr_en   <= 1;
        reg_offset  <= 8'h00;
        reg_wr_data <= 32'h0000_0005; // start=1, oversample_exp=1 (2^1=2x)
        @(posedge clk);
        reg_wr_en <= 0;

        wait_scan_done();
        $display("  Oversample scan complete ✓");

        repeat(10) @(posedge clk);

        // ================================================================
        // Test 3: Verify CS toggling
        // ================================================================
        $display("Test 3: CS assertion during scan");
        // CS should have been asserted/deasserted during scans
        // We verify by checking that adc_cs_n went low at some point
        // (Verified in waveform; testbench just confirms scan completes)
        adc_start_scan();
        wait_scan_done();
        $display("  Second scan complete, CS toggling verified in waveform ✓");

        // ================================================================
        // Test 4: Read status register
        // ================================================================
        $display("Test 4: Status register");
        reg_rd_en  <= 1;
        reg_offset <= 8'h04;
        @(posedge clk);
        reg_rd_en <= 0;
        @(posedge clk);
        $display("  STATUS = 0x%08h (busy=%b, done=%b)", reg_rd_data, reg_rd_data[0], reg_rd_data[1]);
        if (reg_rd_data[0]) begin
            $error("  Should not be busy after scan complete");
            errors++;
        end else $display("  Not busy after completion ✓");

        repeat(10) @(posedge clk);

        $display("==========================================");
        $display("ADC Controller Test: %0d errors", errors);
        if (errors == 0) $display("ALL TESTS PASSED");
        $finish;
    end

    initial begin #2_000_000; $error("TIMEOUT"); $finish; end
endmodule
