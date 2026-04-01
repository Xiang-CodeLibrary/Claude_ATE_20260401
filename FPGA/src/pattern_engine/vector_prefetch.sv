`timescale 1ns / 1ps
// Vector Prefetch Buffer
// Bridges DDR3 memory controller (long latency) to Sequencer (needs data fast)
// Uses a FIFO to hide DDR3 read latency

module vector_prefetch
    import ate_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,

    // Sequencer interface
    input  logic                       seq_rd_req,
    input  logic [VECTOR_ADDR_W-1:0]  seq_rd_addr,
    output logic [VECTOR_WIDTH-1:0]   seq_rd_data,
    output logic                       seq_rd_valid,

    // DDR3 AXI4 read interface (simplified)
    output logic                       ddr_rd_req,
    output logic [VECTOR_ADDR_W-1:0]  ddr_rd_addr,
    input  logic [VECTOR_WIDTH-1:0]   ddr_rd_data,
    input  logic                       ddr_rd_valid,
    input  logic                       ddr_rd_ready,  // DDR can accept request

    // Control
    input  logic        flush,          // Flush FIFO (on pattern start/abort)
    output logic        fifo_empty,
    output logic [7:0]  fifo_level
);

    // -----------------------------------------------------------
    // Prefetch FIFO (128-bit wide, 256 deep)
    // -----------------------------------------------------------
    localparam FIFO_DEPTH     = 256;
    localparam FIFO_ADDR_BITS = 8;

    logic [VECTOR_WIDTH-1:0] fifo_mem [FIFO_DEPTH];
    logic [FIFO_ADDR_BITS:0] wr_ptr, rd_ptr; // Extra bit for full/empty
    logic fifo_full;
    logic fifo_wr_en, fifo_rd_en;

    assign fifo_empty = (wr_ptr == rd_ptr);
    assign fifo_full  = (wr_ptr[FIFO_ADDR_BITS] != rd_ptr[FIFO_ADDR_BITS]) &&
                        (wr_ptr[FIFO_ADDR_BITS-1:0] == rd_ptr[FIFO_ADDR_BITS-1:0]);
    assign fifo_level = wr_ptr - rd_ptr;

    // FIFO write (from DDR3)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            wr_ptr <= '0;
        end else if (fifo_wr_en && !fifo_full) begin
            fifo_mem[wr_ptr[FIFO_ADDR_BITS-1:0]] <= ddr_rd_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // FIFO read (to Sequencer)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            rd_ptr <= '0;
        end else if (fifo_rd_en && !fifo_empty) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end

    assign fifo_wr_en = ddr_rd_valid;

    // -----------------------------------------------------------
    // Prefetch controller
    // -----------------------------------------------------------
    // Tracks the next address to prefetch and issues DDR reads
    // to keep the FIFO as full as possible

    logic [VECTOR_ADDR_W-1:0] prefetch_addr;
    logic [VECTOR_ADDR_W-1:0] target_addr;
    logic                      prefetch_active;
    logic [7:0]               outstanding;  // In-flight DDR requests

    localparam PREFETCH_THRESHOLD = 8'd192;  // Start prefetch when level < this
    localparam MAX_OUTSTANDING    = 8'd32;   // Max in-flight requests

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            prefetch_addr   <= '0;
            prefetch_active <= 1'b0;
            outstanding     <= '0;
            ddr_rd_req      <= 1'b0;
            ddr_rd_addr     <= '0;
        end else begin
            ddr_rd_req <= 1'b0;

            // Track outstanding requests
            if (ddr_rd_req && ddr_rd_ready && !ddr_rd_valid)
                outstanding <= outstanding + 1'b1;
            else if (!ddr_rd_req && ddr_rd_valid && outstanding > 0)
                outstanding <= outstanding - 1'b1;

            // On sequencer request, update target
            if (seq_rd_req) begin
                if (!prefetch_active || seq_rd_addr != target_addr) begin
                    // New address: reset prefetch to this address
                    prefetch_addr   <= seq_rd_addr;
                    target_addr     <= seq_rd_addr;
                    prefetch_active <= 1'b1;
                end
            end

            // Issue prefetch reads when FIFO has room
            if (prefetch_active &&
                fifo_level < PREFETCH_THRESHOLD &&
                outstanding < MAX_OUTSTANDING &&
                ddr_rd_ready) begin
                ddr_rd_req  <= 1'b1;
                ddr_rd_addr <= prefetch_addr;
                prefetch_addr <= prefetch_addr + 1'b1;
            end
        end
    end

    // -----------------------------------------------------------
    // Sequencer read response
    // -----------------------------------------------------------
    // When sequencer requests a read, check if data is in FIFO
    // If sequential access pattern, data should be prefetched already

    typedef enum logic [1:0] {
        RD_IDLE,
        RD_CHECK,
        RD_OUTPUT
    } rd_state_t;

    rd_state_t rd_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            rd_state     <= RD_IDLE;
            seq_rd_data  <= '0;
            seq_rd_valid <= 1'b0;
            fifo_rd_en   <= 1'b0;
        end else begin
            seq_rd_valid <= 1'b0;
            fifo_rd_en   <= 1'b0;

            case (rd_state)
                RD_IDLE: begin
                    if (seq_rd_req) begin
                        rd_state <= RD_CHECK;
                    end
                end

                RD_CHECK: begin
                    if (!fifo_empty) begin
                        seq_rd_data  <= fifo_mem[rd_ptr[FIFO_ADDR_BITS-1:0]];
                        seq_rd_valid <= 1'b1;
                        fifo_rd_en   <= 1'b1;
                        rd_state     <= RD_IDLE;
                    end
                    // else: wait for prefetch to fill FIFO
                end

                default: rd_state <= RD_IDLE;
            endcase
        end
    end

endmodule
