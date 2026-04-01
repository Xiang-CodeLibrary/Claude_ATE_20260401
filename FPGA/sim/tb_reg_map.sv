// Testbench: Register Map + AXI-Lite Slave + SPI Master
// Verifies basic register read/write through AXI4-Lite interface

`timescale 1ns / 1ps

module tb_reg_map;
    import ate_pkg::*;

    logic clk, rst_n;

    // AXI4-Lite signals
    logic [AXI_ADDR_W-1:0] awaddr;
    logic [2:0]            awprot;
    logic                   awvalid, awready;
    logic [AXI_DATA_W-1:0] wdata;
    logic [3:0]            wstrb;
    logic                   wvalid, wready;
    logic [1:0]            bresp;
    logic                   bvalid, bready;
    logic [AXI_ADDR_W-1:0] araddr;
    logic [2:0]            arprot;
    logic                   arvalid, arready;
    logic [AXI_DATA_W-1:0] rdata;
    logic [1:0]            rresp;
    logic                   rvalid, rready;

    // Register interface
    logic                   reg_wr_en;
    logic [AXI_ADDR_W-1:0] reg_wr_addr;
    logic [AXI_DATA_W-1:0] reg_wr_data;
    logic [3:0]            reg_wr_strb;
    logic                   reg_rd_en;
    logic [AXI_ADDR_W-1:0] reg_rd_addr;
    logic [AXI_DATA_W-1:0] reg_rd_data;
    logic                   reg_rd_valid;

    // Clock generation: 100MHz
    initial clk = 0;
    always #5 clk = ~clk;

    // Reset
    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
    end

    // DUT: AXI-Lite Slave
    axi_lite_slave u_dut (
        .aclk          (clk),
        .aresetn       (rst_n),
        .s_axi_awaddr  (awaddr),
        .s_axi_awprot  (awprot),
        .s_axi_awvalid (awvalid),
        .s_axi_awready (awready),
        .s_axi_wdata   (wdata),
        .s_axi_wstrb   (wstrb),
        .s_axi_wvalid  (wvalid),
        .s_axi_wready  (wready),
        .s_axi_bresp   (bresp),
        .s_axi_bvalid  (bvalid),
        .s_axi_bready  (bready),
        .s_axi_araddr  (araddr),
        .s_axi_arprot  (arprot),
        .s_axi_arvalid (arvalid),
        .s_axi_arready (arready),
        .s_axi_rdata   (rdata),
        .s_axi_rresp   (rresp),
        .s_axi_rvalid  (rvalid),
        .s_axi_rready  (rready),
        .reg_wr_en     (reg_wr_en),
        .reg_wr_addr   (reg_wr_addr),
        .reg_wr_data   (reg_wr_data),
        .reg_wr_strb   (reg_wr_strb),
        .reg_rd_en     (reg_rd_en),
        .reg_rd_addr   (reg_rd_addr),
        .reg_rd_data   (reg_rd_data),
        .reg_rd_valid  (reg_rd_valid)
    );

    // Simple loopback: read returns write data for testing
    logic [31:0] test_mem [256];

    always_ff @(posedge clk) begin
        if (reg_wr_en)
            test_mem[reg_wr_addr[9:2]] <= reg_wr_data;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_rd_data  <= '0;
            reg_rd_valid <= 1'b0;
        end else begin
            reg_rd_valid <= reg_rd_en;
            if (reg_rd_en)
                reg_rd_data <= test_mem[reg_rd_addr[9:2]];
        end
    end

    // AXI write task
    task axi_write(input logic [15:0] addr, input logic [31:0] data);
        @(posedge clk);
        awaddr  <= addr;
        awprot  <= 3'b0;
        awvalid <= 1'b1;
        wdata   <= data;
        wstrb   <= 4'hF;
        wvalid  <= 1'b1;
        bready  <= 1'b1;

        // Wait for both handshakes
        fork
            begin: aw_hs
                wait(awready);
                @(posedge clk);
                awvalid <= 1'b0;
            end
            begin: w_hs
                wait(wready);
                @(posedge clk);
                wvalid <= 1'b0;
            end
        join

        // Wait for write response
        wait(bvalid);
        @(posedge clk);
        bready <= 1'b0;

        $display("[%0t] WRITE addr=0x%04h data=0x%08h resp=%0d", $time, addr, data, bresp);
    endtask

    // AXI read task
    task axi_read(input logic [15:0] addr, output logic [31:0] data);
        @(posedge clk);
        araddr  <= addr;
        arprot  <= 3'b0;
        arvalid <= 1'b1;
        rready  <= 1'b1;

        wait(arready);
        @(posedge clk);
        arvalid <= 1'b0;

        wait(rvalid);
        data = rdata;
        @(posedge clk);
        rready <= 1'b0;

        $display("[%0t] READ  addr=0x%04h data=0x%08h resp=%0d", $time, addr, data, rresp);
    endtask

    // Test sequence
    logic [31:0] rd_val;
    integer errors;

    initial begin
        // Initialize
        awaddr = 0; awprot = 0; awvalid = 0;
        wdata = 0; wstrb = 0; wvalid = 0;
        bready = 0;
        araddr = 0; arprot = 0; arvalid = 0;
        rready = 0;
        errors = 0;

        // Wait for reset
        @(posedge rst_n);
        repeat(10) @(posedge clk);

        $display("=== AXI-Lite Register Test Start ===");

        // Test 1: Write and read back
        axi_write(16'h0000, 32'hCAFE_BABE);
        axi_read (16'h0000, rd_val);
        if (rd_val !== 32'hCAFE_BABE) begin
            $error("Test 1 FAIL: expected 0xCAFEBABE, got 0x%08h", rd_val);
            errors++;
        end

        // Test 2: Write to different addresses
        axi_write(16'h0004, 32'h1234_5678);
        axi_write(16'h0008, 32'hDEAD_BEEF);

        axi_read(16'h0004, rd_val);
        if (rd_val !== 32'h1234_5678) begin
            $error("Test 2a FAIL: expected 0x12345678, got 0x%08h", rd_val);
            errors++;
        end

        axi_read(16'h0008, rd_val);
        if (rd_val !== 32'hDEAD_BEEF) begin
            $error("Test 2b FAIL: expected 0xDEADBEEF, got 0x%08h", rd_val);
            errors++;
        end

        // Test 3: Channel register address range
        axi_write(16'h1000, 32'h0000_0001);  // Channel 0, offset 0
        axi_write(16'h1100, 32'h0000_0002);  // Channel 1, offset 0
        axi_write(16'h1F00, 32'h0000_000F);  // Channel 15, offset 0

        axi_read(16'h1000, rd_val);
        if (rd_val !== 32'h0000_0001) begin
            $error("Test 3a FAIL: CH0 expected 0x1, got 0x%08h", rd_val);
            errors++;
        end

        axi_read(16'h1100, rd_val);
        if (rd_val !== 32'h0000_0002) begin
            $error("Test 3b FAIL: CH1 expected 0x2, got 0x%08h", rd_val);
            errors++;
        end

        // Test 4: Burst writes
        for (int i = 0; i < 16; i++) begin
            axi_write(16'h0100 + i*4, 32'hA000_0000 + i);
        end
        for (int i = 0; i < 16; i++) begin
            axi_read(16'h0100 + i*4, rd_val);
            if (rd_val !== 32'hA000_0000 + i) begin
                $error("Test 4 FAIL at offset %0d: expected 0x%08h, got 0x%08h",
                       i, 32'hA000_0000 + i, rd_val);
                errors++;
            end
        end

        repeat(20) @(posedge clk);

        $display("=== Test Complete: %0d errors ===", errors);
        if (errors == 0) $display("ALL TESTS PASSED");

        $finish;
    end

    // Timeout
    initial begin
        #100_000;
        $error("TIMEOUT");
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("tb_reg_map.vcd");
        $dumpvars(0, tb_reg_map);
    end

endmodule
