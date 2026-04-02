`timescale 1ns / 1ps

module tb_vector_prefetch;
    import ate_pkg::*;

    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    // Sequencer interface
    logic                      seq_rd_req;
    logic [VECTOR_ADDR_W-1:0] seq_rd_addr;
    logic [VECTOR_WIDTH-1:0]  seq_rd_data;
    logic                      seq_rd_valid;

    // DDR3 interface
    logic                      ddr_rd_req;
    logic [VECTOR_ADDR_W-1:0] ddr_rd_addr;
    logic [VECTOR_WIDTH-1:0]  ddr_rd_data;
    logic                      ddr_rd_valid;
    logic                      ddr_rd_ready;

    logic flush, fifo_empty;
    logic [7:0] fifo_level;

    vector_prefetch u_dut (.*);

    // DDR3 model: responds after 3 cycles with addr-dependent data
    logic [2:0] ddr_delay;
    logic ddr_pending;
    logic [VECTOR_ADDR_W-1:0] ddr_pending_addr;

    assign ddr_rd_ready = !ddr_pending;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ddr_pending  <= 0;
            ddr_rd_valid <= 0;
            ddr_rd_data  <= '0;
            ddr_delay    <= 0;
        end else begin
            ddr_rd_valid <= 0;
            if (ddr_rd_req && !ddr_pending) begin
                ddr_pending      <= 1;
                ddr_pending_addr <= ddr_rd_addr;
                ddr_delay        <= 0;
            end else if (ddr_pending) begin
                ddr_delay <= ddr_delay + 1;
                if (ddr_delay == 3'd2) begin
                    ddr_pending  <= 0;
                    ddr_rd_valid <= 1;
                    ddr_rd_data  <= {4{5'b0, ddr_pending_addr}};
                end
            end
        end
    end

    integer errors = 0;

    initial begin
        $dumpfile("tb_vector_prefetch.vcd");
        $dumpvars(0, tb_vector_prefetch);

        rst_n = 0; seq_rd_req = 0; seq_rd_addr = 0; flush = 0;
        #100 rst_n = 1;
        repeat(5) @(posedge clk);

        $display("=== Vector Prefetch Test ===");

        // Test 1: Single read — verify data arrives
        $display("Test 1: Single read");
        @(posedge clk);
        seq_rd_req  <= 1;
        seq_rd_addr <= 27'd100;
        @(posedge clk);
        seq_rd_req <= 0;

        begin
            int timeout = 0;
            while (!seq_rd_valid && timeout < 1000) begin
                @(posedge clk); timeout++;
            end
            if (timeout >= 1000) begin
                $error("  Read timeout"); errors++;
            end else begin
                $display("  Read addr=100: data=0x%032h (arrived in %0d cycles)", seq_rd_data, timeout);
                $display("  PASS: data received");
            end
        end

        repeat(20) @(posedge clk);

        // Test 2: 5 sequential reads complete without timeout
        $display("Test 2: Sequential reads");
        for (int i = 0; i < 5; i++) begin
            @(posedge clk);
            seq_rd_req  <= 1;
            seq_rd_addr <= 27'd200 + i;
            @(posedge clk);
            seq_rd_req <= 0;

            begin
                int to2 = 0;
                while (!seq_rd_valid && to2 < 1000) begin
                    @(posedge clk); to2++;
                end
                if (to2 >= 1000) begin
                    $error("  Read[%0d] timeout", i); errors++;
                end
            end
        end
        if (errors == 0) $display("  PASS: 5 reads completed");

        repeat(20) @(posedge clk);

        // Test 3: Flush
        $display("Test 3: Flush FIFO");
        @(posedge clk); flush <= 1;
        @(posedge clk); flush <= 0;
        // Wait for in-flight DDR3 responses to drain
        repeat(20) @(posedge clk);
        if (!fifo_empty) begin
            $error("  FIFO not empty after flush+drain"); errors++;
        end else $display("  PASS: FIFO empty after flush");

        repeat(10) @(posedge clk);

        // Test 4: Read after flush
        $display("Test 4: Read after flush");
        @(posedge clk);
        seq_rd_req  <= 1;
        seq_rd_addr <= 27'd500;
        @(posedge clk);
        seq_rd_req <= 0;

        begin
            int to3 = 0;
            while (!seq_rd_valid && to3 < 1000) begin
                @(posedge clk); to3++;
            end
            if (to3 >= 1000) begin
                $error("  Read after flush timeout"); errors++;
            end else $display("  PASS: read after flush OK");
        end

        repeat(20) @(posedge clk);

        $display("==========================================");
        $display("Vector Prefetch Test: %0d errors", errors);
        if (errors == 0) $display("ALL TESTS PASSED");
        $finish;
    end

    initial begin #200_000; $error("TIMEOUT"); $finish; end
endmodule
