`timescale 1ns / 1ps

module tb_sequencer;
    import ate_pkg::*;

    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    // Control
    logic pat_start, pat_stop, pat_abort;
    logic pat_running, pat_done, pat_fail;
    logic [VECTOR_ADDR_W-1:0] start_addr, pat_length;
    logic [NUM_CHANNELS-1:0] site_enable;

    // Vector memory
    logic vmem_rd_req;
    logic [VECTOR_ADDR_W-1:0] vmem_rd_addr;
    logic [VECTOR_WIDTH-1:0] vmem_rd_data;
    logic vmem_rd_valid;

    // Outputs
    logic vec_valid;
    logic [4:0] vec_timeset;
    pin_state_t vec_pin_state [NUM_CHANNELS];
    logic [NUM_CHANNELS-1:0] vec_compare_en;

    // Compare
    logic [NUM_CHANNELS-1:0] compare_pass;
    logic compare_valid;

    // Sequencer flags/regs
    logic [3:0] seq_flags;
    logic [31:0] seq_registers [4];

    // HRAM
    logic hram_wr_en;
    logic [12:0] hram_wr_addr;
    logic [VECTOR_ADDR_W-1:0] hram_wr_cycle;
    logic [NUM_CHANNELS-1:0] hram_wr_fail_mask;

    sequencer u_dut (.*);

    // ================================================================
    // Vector memory model (simple array)
    // ================================================================
    logic [VECTOR_WIDTH-1:0] vmem [0:1023];
    logic vmem_rd_req_d;

    always_ff @(posedge clk) begin
        vmem_rd_req_d <= vmem_rd_req;
        vmem_rd_valid <= vmem_rd_req_d;
        if (vmem_rd_req)
            vmem_rd_data <= vmem[vmem_rd_addr[9:0]];
    end

    // Compare: always pass by default, can inject failures
    logic inject_fail;
    assign compare_pass  = inject_fail ? 16'hFFFE : 16'hFFFF; // ch0 fails if injected
    assign compare_valid = vec_valid; // Immediate compare

    // ================================================================
    // Helper: build vector word
    // ================================================================
    function automatic logic [VECTOR_WIDTH-1:0] make_vector(
        input logic [15:0] opcode,
        input logic [15:0] operand,
        input logic [4:0]  timeset,
        input logic [31:0] pin_data,
        input logic [31:0] aux_data
    );
        logic [VECTOR_WIDTH-1:0] v;
        v[127:112] = opcode;
        v[111:96]  = operand;
        v[95:91]   = timeset;
        v[90:88]   = 3'b0;
        v[87:56]   = pin_data;
        v[55:32]   = 24'b0;
        v[31:0]    = aux_data;
        return v;
    endfunction

    // Opcodes (must match sequencer.sv)
    localparam OP_VECTOR    = 16'h0001;
    localparam OP_REPEAT    = 16'h0010;
    localparam OP_JUMP      = 16'h0020;
    localparam OP_SET_LOOP  = 16'h0030;
    localparam OP_END_LOOP  = 16'h0031;
    localparam OP_CALL      = 16'h0040;
    localparam OP_RETURN    = 16'h0041;
    localparam OP_HALT      = 16'h00FF;
    localparam OP_SET_FLAG  = 16'h0060;
    localparam OP_JUMP_IF   = 16'h0021;

    // Pin data: all ch0 drive-1, rest hi-z
    localparam [31:0] PIN_CH0_DRV1 = 32'h0000_0001;  // ch0=01(drive1)
    localparam [31:0] PIN_ALL_HIZ  = 32'hFFFF_FFFF;   // all hi-z (11)
    localparam [31:0] PIN_CH0_CMP  = 32'h0000_0002;   // ch0=10(compare)

    integer errors = 0;
    integer cycle_count;

    // Count vector outputs
    always_ff @(posedge clk) begin
        if (pat_start) cycle_count <= 0;
        else if (vec_valid) cycle_count <= cycle_count + 1;
    end

    initial begin
        $dumpfile("tb_sequencer.vcd");
        $dumpvars(0, tb_sequencer);

        rst_n = 0; pat_start = 0; pat_stop = 0; pat_abort = 0;
        start_addr = 0; pat_length = 100; site_enable = 16'hFFFF;
        inject_fail = 0;
        #100 rst_n = 1;
        repeat(5) @(posedge clk);

        // ================================================================
        // Test 1: Simple 5-vector pattern + HALT
        // ================================================================
        $display("=== Test 1: Simple 5 vectors + HALT ===");
        vmem[0] = make_vector(OP_VECTOR, 0, 5'd0, PIN_CH0_DRV1, 0);
        vmem[1] = make_vector(OP_VECTOR, 0, 5'd0, PIN_ALL_HIZ,  0);
        vmem[2] = make_vector(OP_VECTOR, 0, 5'd1, PIN_CH0_DRV1, 0);
        vmem[3] = make_vector(OP_VECTOR, 0, 5'd1, PIN_ALL_HIZ,  0);
        vmem[4] = make_vector(OP_HALT,   0, 5'd0, 0,            0);

        start_addr = 0; pat_length = 100;
        @(posedge clk); pat_start = 1;
        @(posedge clk); pat_start = 0;

        wait(pat_done);
        @(posedge clk);
        $display("  Vectors executed: %0d, pat_fail=%0b", cycle_count, pat_fail);
        if (cycle_count !== 4) begin $error("  Expected 4 vectors, got %0d", cycle_count); errors++; end
        if (pat_fail)          begin $error("  Unexpected fail"); errors++; end
        else $display("  PASS");

        repeat(10) @(posedge clk);

        // ================================================================
        // Test 2: SET_LOOP / END_LOOP (3 iterations)
        // ================================================================
        $display("=== Test 2: Loop 3x ===");
        vmem[0] = make_vector(OP_SET_LOOP, 0, 0, 0, 32'd3);  // loop 3 times
        vmem[1] = make_vector(OP_VECTOR,   0, 0, PIN_CH0_DRV1, 0);
        vmem[2] = make_vector(OP_END_LOOP, 0, 0, 0, 0);
        vmem[3] = make_vector(OP_HALT,     0, 0, 0, 0);

        start_addr = 0;
        @(posedge clk); pat_start = 1;
        @(posedge clk); pat_start = 0;

        wait(pat_done);
        @(posedge clk);
        $display("  Vectors executed: %0d", cycle_count);
        if (cycle_count !== 3) begin $error("  Expected 3, got %0d", cycle_count); errors++; end
        else $display("  PASS");

        repeat(10) @(posedge clk);

        // ================================================================
        // Test 3: CALL / RETURN
        // ================================================================
        $display("=== Test 3: Call/Return ===");
        vmem[0] = make_vector(OP_VECTOR, 0, 0, PIN_CH0_DRV1, 0);  // vec 0
        vmem[1] = make_vector(OP_CALL,   0, 0, 0, 32'd10);        // call addr 10
        vmem[2] = make_vector(OP_VECTOR, 0, 0, PIN_CH0_DRV1, 0);  // vec after return
        vmem[3] = make_vector(OP_HALT,   0, 0, 0, 0);

        vmem[10] = make_vector(OP_VECTOR, 0, 0, PIN_ALL_HIZ, 0);  // subroutine vec
        vmem[11] = make_vector(OP_VECTOR, 0, 0, PIN_ALL_HIZ, 0);  // subroutine vec
        vmem[12] = make_vector(OP_RETURN, 0, 0, 0, 0);            // return

        start_addr = 0;
        @(posedge clk); pat_start = 1;
        @(posedge clk); pat_start = 0;

        wait(pat_done);
        @(posedge clk);
        $display("  Vectors executed: %0d (expect 4: v0, sub0, sub1, v_after_ret)", cycle_count);
        if (cycle_count !== 4) begin $error("  Expected 4, got %0d", cycle_count); errors++; end
        else $display("  PASS");

        repeat(10) @(posedge clk);

        // ================================================================
        // Test 4: Compare failure → HRAM write
        // ================================================================
        $display("=== Test 4: Compare fail → HRAM ===");
        vmem[0] = make_vector(OP_VECTOR, 0, 0, PIN_CH0_CMP, 0);  // compare ch0
        vmem[1] = make_vector(OP_VECTOR, 0, 0, PIN_CH0_CMP, 0);  // compare ch0
        vmem[2] = make_vector(OP_HALT,   0, 0, 0, 0);

        inject_fail = 1;  // ch0 will fail
        start_addr = 0;
        @(posedge clk); pat_start = 1;
        @(posedge clk); pat_start = 0;

        wait(pat_done);
        inject_fail = 0;
        @(posedge clk);
        $display("  pat_fail=%0b, HRAM writes observed in waveform", pat_fail);
        if (!pat_fail) begin $error("  Expected pat_fail=1"); errors++; end
        else $display("  PASS: failure detected");

        repeat(10) @(posedge clk);

        // ================================================================
        // Test 5: SET_FLAG + JUMP_IF
        // ================================================================
        $display("=== Test 5: Set flag + conditional jump ===");
        vmem[0] = make_vector(OP_SET_FLAG, 16'd0, 0, 0, 0);      // set flag[0]
        vmem[1] = make_vector(OP_JUMP_IF,  16'd0, 0, 0, 32'd5);  // if flag[0] jump to 5
        vmem[2] = make_vector(OP_VECTOR,   0, 0, PIN_CH0_DRV1, 0); // should be skipped
        vmem[3] = make_vector(OP_HALT,     0, 0, 0, 0);            // should be skipped

        vmem[5] = make_vector(OP_VECTOR,   0, 0, PIN_ALL_HIZ, 0);  // jump target
        vmem[6] = make_vector(OP_HALT,     0, 0, 0, 0);

        start_addr = 0;
        @(posedge clk); pat_start = 1;
        @(posedge clk); pat_start = 0;

        wait(pat_done);
        @(posedge clk);
        $display("  Vectors executed: %0d (expect 1: only the jump target vec)", cycle_count);
        if (cycle_count !== 1) begin $error("  Expected 1, got %0d", cycle_count); errors++; end
        else $display("  PASS");

        repeat(10) @(posedge clk);

        // ================================================================
        // Test 6: Abort mid-pattern
        // ================================================================
        $display("=== Test 6: Abort ===");
        vmem[0] = make_vector(OP_SET_LOOP, 0, 0, 0, 32'd1000);
        vmem[1] = make_vector(OP_VECTOR,   0, 0, PIN_CH0_DRV1, 0);
        vmem[2] = make_vector(OP_END_LOOP, 0, 0, 0, 0);
        vmem[3] = make_vector(OP_HALT,     0, 0, 0, 0);

        start_addr = 0;
        @(posedge clk); pat_start = 1;
        @(posedge clk); pat_start = 0;

        // Let it run a bit then abort
        repeat(50) @(posedge clk);
        if (!pat_running) begin $error("  Should still be running"); errors++; end

        @(posedge clk); pat_abort = 1;
        @(posedge clk); pat_abort = 0;
        repeat(5) @(posedge clk);

        if (pat_running) begin $error("  Should have stopped after abort"); errors++; end
        else $display("  PASS: abort stopped execution after %0d vectors", cycle_count);

        repeat(10) @(posedge clk);

        $display("==========================================");
        $display("=== Sequencer Test Done: %0d errors ===", errors);
        if (errors == 0) $display("ALL TESTS PASSED");
        $finish;
    end

    initial begin #500_000; $error("TIMEOUT"); $finish; end
endmodule
