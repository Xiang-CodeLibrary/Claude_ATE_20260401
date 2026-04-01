`timescale 1ns / 1ps

// Drive Format testbench
// Verifies NR/RL/RH/SBC output patterns with timing edge events

module tb_drive_format;
    import ate_pkg::*;

    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    drive_fmt_t  format;
    term_mode_t  termination;
    pin_func_t   pin_function;
    pin_state_t  pin_state;
    logic        vec_valid;
    logic        evt_drive_on, evt_drive_data, evt_drive_return, evt_drive_off;
    logic        evt_compare_strobe;
    logic [1:0]  static_state;
    logic        static_state_wr;
    logic        drv_enable, drv_data, comp_sample, comp_enable, load_active;

    drive_format u_dut (
        .clk(clk), .rst_n(rst_n),
        .format(format), .termination(termination), .pin_function(pin_function),
        .pin_state(pin_state), .vec_valid(vec_valid),
        .evt_drive_on(evt_drive_on), .evt_drive_data(evt_drive_data),
        .evt_drive_return(evt_drive_return), .evt_drive_off(evt_drive_off),
        .evt_compare_strobe(evt_compare_strobe),
        .static_state(static_state), .static_state_wr(static_state_wr),
        .drv_enable(drv_enable), .drv_data(drv_data),
        .comp_sample(comp_sample), .comp_enable(comp_enable),
        .load_active(load_active)
    );

    integer errors = 0;

    task automatic drive_cycle(
        input pin_state_t ps,
        input drive_fmt_t fmt,
        input string test_name
    );
        format      <= fmt;
        pin_function <= PIN_DIGITAL;
        termination <= TERM_HIZ;
        pin_state   <= ps;

        // vec_valid pulse
        @(posedge clk); vec_valid <= 1;
        @(posedge clk); vec_valid <= 0;

        // Timing edge sequence: on → data → return → off
        repeat(3) @(posedge clk);
        @(posedge clk); evt_drive_on <= 1;
        @(posedge clk); evt_drive_on <= 0;

        repeat(3) @(posedge clk);
        @(posedge clk); evt_drive_data <= 1;
        @(posedge clk); evt_drive_data <= 0;

        repeat(3) @(posedge clk);
        @(posedge clk); evt_drive_return <= 1;
        @(posedge clk); evt_drive_return <= 0;

        repeat(3) @(posedge clk);
        @(posedge clk); evt_drive_off <= 1;
        @(posedge clk); evt_drive_off <= 0;

        repeat(3) @(posedge clk);
    endtask

    // Check drv_data at specific phase
    task automatic check_at_edge(input string phase, input logic expected_data, input logic expected_en);
        @(posedge clk);
        if (drv_data !== expected_data || drv_enable !== expected_en) begin
            $error("  %s: drv_data=%b (exp %b), drv_enable=%b (exp %b)",
                   phase, drv_data, expected_data, drv_enable, expected_en);
            errors++;
        end
    endtask

    initial begin
        $dumpfile("tb_drive_format.vcd");
        $dumpvars(0, tb_drive_format);

        rst_n = 0;
        vec_valid = 0; evt_drive_on = 0; evt_drive_data = 0;
        evt_drive_return = 0; evt_drive_off = 0; evt_compare_strobe = 0;
        format = DRV_NR; termination = TERM_HIZ; pin_function = PIN_DIGITAL;
        pin_state = PS_HIZ; static_state = 0; static_state_wr = 0;
        #100 rst_n = 1;
        repeat(5) @(posedge clk);

        // ================================================================
        // Test 1: NR (Non-Return) Drive 1
        // Expected: on→low(default), data→HIGH, return→HIGH(NR stays), off→disabled
        // ================================================================
        $display("=== Test 1: NR Drive 1 ===");
        format <= DRV_NR; pin_function <= PIN_DIGITAL; termination <= TERM_HIZ;
        pin_state <= PS_DRIVE1;

        @(posedge clk); vec_valid <= 1;
        @(posedge clk); vec_valid <= 0;
        repeat(2) @(posedge clk);

        @(posedge clk); evt_drive_on <= 1;
        @(posedge clk); evt_drive_on <= 0;
        repeat(2) @(posedge clk);

        @(posedge clk); evt_drive_data <= 1;
        @(posedge clk); evt_drive_data <= 0;
        @(posedge clk);
        // After data edge: drv_data should be 1 (Drive 1)
        if (!drv_data || !drv_enable) begin
            $error("  After DATA edge: drv_data=%b drv_enable=%b, expected 1,1", drv_data, drv_enable);
            errors++;
        end else $display("  DATA edge: drv_data=1 ✓");

        repeat(2) @(posedge clk);
        @(posedge clk); evt_drive_return <= 1;
        @(posedge clk); evt_drive_return <= 0;
        @(posedge clk);
        // NR: return value = drive value = 1
        if (!drv_data) begin
            $error("  After RETURN edge: NR should stay HIGH, got %b", drv_data);
            errors++;
        end else $display("  RETURN edge: NR stays HIGH ✓");

        repeat(2) @(posedge clk);
        @(posedge clk); evt_drive_off <= 1;
        @(posedge clk); evt_drive_off <= 0;
        repeat(2) @(posedge clk);

        // ================================================================
        // Test 2: RL (Return to Low) Drive 1
        // Expected: data→HIGH, return→LOW
        // ================================================================
        $display("=== Test 2: RL Drive 1 ===");
        format <= DRV_RL;
        pin_state <= PS_DRIVE1;

        @(posedge clk); vec_valid <= 1;
        @(posedge clk); vec_valid <= 0;
        repeat(2) @(posedge clk);
        @(posedge clk); evt_drive_on <= 1;
        @(posedge clk); evt_drive_on <= 0;
        repeat(2) @(posedge clk);
        @(posedge clk); evt_drive_data <= 1;
        @(posedge clk); evt_drive_data <= 0;
        @(posedge clk);
        if (!drv_data) begin $error("  DATA: expected HIGH"); errors++; end
        else $display("  DATA edge: HIGH ✓");

        repeat(2) @(posedge clk);
        @(posedge clk); evt_drive_return <= 1;
        @(posedge clk); evt_drive_return <= 0;
        @(posedge clk);
        if (drv_data !== 1'b0) begin
            $error("  RETURN: RL should go LOW, got %b", drv_data);
            errors++;
        end else $display("  RETURN edge: RL goes LOW ✓");

        repeat(2) @(posedge clk);
        @(posedge clk); evt_drive_off <= 1;
        @(posedge clk); evt_drive_off <= 0;
        repeat(2) @(posedge clk);

        // ================================================================
        // Test 3: RH (Return to High) Drive 0
        // Expected: data→LOW, return→HIGH
        // ================================================================
        $display("=== Test 3: RH Drive 0 ===");
        format <= DRV_RH;
        pin_state <= PS_DRIVE0;

        @(posedge clk); vec_valid <= 1;
        @(posedge clk); vec_valid <= 0;
        repeat(2) @(posedge clk);
        @(posedge clk); evt_drive_on <= 1;
        @(posedge clk); evt_drive_on <= 0;
        repeat(2) @(posedge clk);
        @(posedge clk); evt_drive_data <= 1;
        @(posedge clk); evt_drive_data <= 0;
        @(posedge clk);
        if (drv_data !== 1'b0) begin $error("  DATA: expected LOW"); errors++; end
        else $display("  DATA edge: LOW ✓");

        repeat(2) @(posedge clk);
        @(posedge clk); evt_drive_return <= 1;
        @(posedge clk); evt_drive_return <= 0;
        @(posedge clk);
        if (drv_data !== 1'b1) begin
            $error("  RETURN: RH should go HIGH, got %b", drv_data);
            errors++;
        end else $display("  RETURN edge: RH goes HIGH ✓");

        repeat(2) @(posedge clk);
        @(posedge clk); evt_drive_off <= 1;
        @(posedge clk); evt_drive_off <= 0;
        repeat(5) @(posedge clk);

        // ================================================================
        // Test 4: SBC (Surround by Complement) Drive 1
        // Expected: pre-data→LOW(complement), data→HIGH, return→LOW(complement)
        // ================================================================
        $display("=== Test 4: SBC Drive 1 ===");
        format <= DRV_SBC;
        pin_state <= PS_DRIVE1;

        @(posedge clk); vec_valid <= 1;
        @(posedge clk); vec_valid <= 0;
        @(posedge clk);
        // SBC: immediately starts with complement (LOW for drive-1)
        if (drv_data !== 1'b0 || !drv_enable) begin
            $error("  SBC pre-data: expected complement LOW, got drv_data=%b en=%b", drv_data, drv_enable);
            errors++;
        end else $display("  SBC pre-data: complement LOW ✓");

        repeat(2) @(posedge clk);
        @(posedge clk); evt_drive_data <= 1;
        @(posedge clk); evt_drive_data <= 0;
        @(posedge clk);
        if (drv_data !== 1'b1) begin $error("  SBC DATA: expected HIGH"); errors++; end
        else $display("  SBC DATA edge: HIGH ✓");

        repeat(2) @(posedge clk);
        @(posedge clk); evt_drive_return <= 1;
        @(posedge clk); evt_drive_return <= 0;
        @(posedge clk);
        if (drv_data !== 1'b0) begin
            $error("  SBC RETURN: expected complement LOW, got %b", drv_data);
            errors++;
        end else $display("  SBC RETURN: complement LOW ✓");

        repeat(5) @(posedge clk);

        // ================================================================
        // Test 5: Compare state with Hi-Z termination
        // ================================================================
        $display("=== Test 5: Compare + Hi-Z termination ===");
        format <= DRV_NR;
        termination <= TERM_HIZ;
        pin_state <= PS_COMPARE;

        @(posedge clk); vec_valid <= 1;
        @(posedge clk); vec_valid <= 0;
        @(posedge clk);
        if (drv_enable) begin
            $error("  Compare+HiZ: driver should be disabled");
            errors++;
        end else $display("  Compare+HiZ: driver disabled ✓");
        if (!comp_enable) begin
            $error("  Compare+HiZ: comparator should be enabled");
            errors++;
        end else $display("  Compare+HiZ: comparator enabled ✓");

        // Fire compare strobe
        repeat(3) @(posedge clk);
        @(posedge clk); evt_compare_strobe <= 1;
        @(posedge clk); evt_compare_strobe <= 0;
        @(posedge clk);
        if (!comp_sample) begin
            $error("  Compare strobe not generated");
            errors++;
        end else $display("  Compare strobe fired ✓");

        repeat(5) @(posedge clk);

        // ================================================================
        // Test 6: Active Load termination
        // ================================================================
        $display("=== Test 6: Compare + Active Load ===");
        termination <= TERM_ACTIVE;
        pin_state <= PS_COMPARE;

        @(posedge clk); vec_valid <= 1;
        @(posedge clk); vec_valid <= 0;
        @(posedge clk);
        if (!load_active) begin
            $error("  Active load should be enabled");
            errors++;
        end else $display("  Active load enabled ✓");

        repeat(5) @(posedge clk);

        // ================================================================
        // Test 7: Disconnect mode
        // ================================================================
        $display("=== Test 7: Disconnect ===");
        pin_function <= PIN_DISCONNECT;
        @(posedge clk); @(posedge clk);
        if (drv_enable || comp_enable || load_active) begin
            $error("  Disconnect: all should be off");
            errors++;
        end else $display("  Disconnect: all outputs disabled ✓");

        repeat(5) @(posedge clk);

        // ================================================================
        // Test 8: Static state write
        // ================================================================
        $display("=== Test 8: Static state ===");
        pin_function <= PIN_DIGITAL;
        static_state <= 2'b01; // Drive high
        @(posedge clk); static_state_wr <= 1;
        @(posedge clk); static_state_wr <= 0;
        @(posedge clk);
        if (!drv_enable || !drv_data) begin
            $error("  Static high: drv_en=%b drv_data=%b", drv_enable, drv_data);
            errors++;
        end else $display("  Static drive HIGH ✓");

        repeat(5) @(posedge clk);

        $display("==========================================");
        $display("Drive Format Test: %0d errors", errors);
        if (errors == 0) $display("ALL TESTS PASSED");
        $finish;
    end

    initial begin #100_000; $error("TIMEOUT"); $finish; end
endmodule
