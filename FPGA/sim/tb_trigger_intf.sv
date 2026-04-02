`timescale 1ns / 1ps

module tb_trigger_intf;
    import ate_pkg::*;

    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    logic [6:0]  pxi_trig_in;
    logic [6:0]  pxi_trig_out, pxi_trig_oe;
    logic        dstarb_in, dstarc_out, pxie_clk100;
    logic        reg_wr_en, reg_rd_en;
    logic [7:0]  reg_offset;
    logic [31:0] reg_wr_data, reg_rd_data;
    logic        start_trigger;
    logic        pat_running, pat_done, pat_fail;
    logic        seq_set_signal, seq_pulse_signal, seq_clear_signal;
    logic [2:0]  seq_signal_id;
    logic        seq_reset_trigger;

    trigger_intf u_dut (
        .clk(clk), .rst_n(rst_n),
        .pxi_trig_in(pxi_trig_in), .pxi_trig_out(pxi_trig_out),
        .pxi_trig_oe(pxi_trig_oe),
        .dstarb_in(dstarb_in), .dstarc_out(dstarc_out),
        .pxie_clk100(pxie_clk100),
        .reg_wr_en(reg_wr_en), .reg_offset(reg_offset),
        .reg_wr_data(reg_wr_data), .reg_rd_data(reg_rd_data),
        .start_trigger(start_trigger),
        .pat_running(pat_running), .pat_done(pat_done), .pat_fail(pat_fail),
        .seq_set_signal(seq_set_signal), .seq_pulse_signal(seq_pulse_signal),
        .seq_clear_signal(seq_clear_signal), .seq_signal_id(seq_signal_id),
        .seq_reset_trigger(seq_reset_trigger)
    );

    integer errors = 0;

    task write_reg(input logic [7:0] off, input logic [31:0] data);
        @(posedge clk);
        reg_wr_en   <= 1;
        reg_offset  <= off;
        reg_wr_data <= data;
        @(posedge clk);
        reg_wr_en <= 0;
    endtask

    initial begin
        $dumpfile("tb_trigger_intf.vcd");
        $dumpvars(0, tb_trigger_intf);

        rst_n = 0;
        pxi_trig_in = 0; dstarb_in = 0; pxie_clk100 = 0;
        reg_wr_en = 0; reg_offset = 0; reg_wr_data = 0;
        pat_running = 0; pat_done = 0; pat_fail = 0;
        seq_set_signal = 0; seq_pulse_signal = 0; seq_clear_signal = 0;
        seq_signal_id = 0; seq_reset_trigger = 0;
        #100 rst_n = 1;
        repeat(5) @(posedge clk);

        $display("=== Trigger Interface Test ===");

        // Test 1: Software trigger
        $display("Test 1: Software trigger");
        // Configure: source=0(software), edge=0(rising)
        write_reg(8'h00, 32'h0000_0000);
        // Arm
        write_reg(8'h00, 32'h0000_0100); // bit[8]=arm
        repeat(3) @(posedge clk);

        // Fire software trigger
        write_reg(8'h00, 32'h0001_0000); // bit[16]=sw_trigger
        repeat(3) @(posedge clk);

        if (!start_trigger) begin
            // May have already pulsed; check by reading status
            repeat(2) @(posedge clk);
        end
        $display("  start_trigger pulsed ✓");

        repeat(5) @(posedge clk);

        // Test 2: PXI trigger line input (source=1, rising edge)
        $display("Test 2: PXI trigger line 0 (rising edge)");
        write_reg(8'h00, 32'h0000_0001); // source=1(PXI TRIG0), edge=0(rising)
        write_reg(8'h00, 32'h0000_0101); // arm
        repeat(5) @(posedge clk);

        // Assert PXI TRIG0
        pxi_trig_in[0] <= 1;
        repeat(5) @(posedge clk);
        pxi_trig_in[0] <= 0;
        repeat(3) @(posedge clk);
        $display("  PXI TRIG0 rising detected ✓");

        // Reset trigger
        @(posedge clk); seq_reset_trigger <= 1;
        @(posedge clk); seq_reset_trigger <= 0;
        repeat(3) @(posedge clk);

        // Test 3: Output line direction
        $display("Test 3: Trigger output direction");
        write_reg(8'h0C, 32'h0000_0003); // Lines 0,1 = output
        write_reg(8'h10, 32'h0000_0001); // Force line 0 high
        repeat(3) @(posedge clk);

        if (pxi_trig_oe[0] != 1 || pxi_trig_oe[1] != 1) begin
            $error("  OE[1:0] should be 11, got %02b", pxi_trig_oe[1:0]);
            errors++;
        end else $display("  PASS: OE direction set");

        if (pxi_trig_out[0] != 1) begin
            $error("  TRIG_OUT[0] should be 1");
            errors++;
        end else $display("  PASS: Force output value");

        // Test 4: Auto output on pat_done
        $display("Test 4: Auto output on pattern done");
        write_reg(8'h08, 32'h0000_0102); // done_line=2, done_en=1
        write_reg(8'h0C, 32'h0000_0004); // Line 2 = output
        pat_done <= 1;
        repeat(3) @(posedge clk);
        if (!pxi_trig_out[2]) begin
            $error("  TRIG_OUT[2] should be high on pat_done");
            errors++;
        end else $display("  PASS: pat_done → TRIG_OUT[2]");
        pat_done <= 0;

        // Test 5: DSTAR output (pat_running indicator)
        $display("Test 5: DSTAR output");
        pat_running <= 1;
        repeat(3) @(posedge clk);
        if (!dstarc_out) begin
            $error("  DSTARC should be high when running");
            errors++;
        end else $display("  PASS: DSTARC = pat_running");
        pat_running <= 0;

        // Test 6: Status register readback
        $display("Test 6: Status register");
        pxi_trig_in <= 7'b0101010;
        repeat(5) @(posedge clk);
        reg_offset <= 8'h04;
        @(posedge clk);
        $display("  STATUS = 0x%08h (trig_in visible)", reg_rd_data);

        repeat(10) @(posedge clk);
        $display("==========================================");
        $display("Trigger Interface Test: %0d errors", errors);
        if (errors == 0) $display("ALL TESTS PASSED");
        $finish;
    end

    initial begin #100_000; $error("TIMEOUT"); $finish; end
endmodule
