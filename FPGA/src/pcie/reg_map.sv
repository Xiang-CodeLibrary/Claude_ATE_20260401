`timescale 1ns / 1ps
// Register Map Module
// Decodes register addresses and routes to sub-modules

module reg_map
    import ate_pkg::*;
(
    input  logic                    clk,
    input  logic                    rst_n,

    // Register interface from AXI-Lite slave
    input  logic                    reg_wr_en,
    input  logic [AXI_ADDR_W-1:0]  reg_wr_addr,
    input  logic [AXI_DATA_W-1:0]  reg_wr_data,
    input  logic [3:0]             reg_wr_strb,

    input  logic                    reg_rd_en,
    input  logic [AXI_ADDR_W-1:0]  reg_rd_addr,
    output logic [AXI_DATA_W-1:0]  reg_rd_data,
    output logic                    reg_rd_valid,

    // Global control outputs
    output logic                    global_reset,
    output logic                    global_enable,
    input  logic [31:0]            global_status,
    output logic [31:0]            irq_enable,
    input  logic [31:0]            irq_status,
    output logic [31:0]            irq_clear,
    output logic                    self_cal_start,
    input  logic                    self_cal_done,

    // Per-channel register interface (directly exposed to channel controllers)
    output logic [NUM_CHANNELS-1:0]          ch_reg_wr_en,
    output logic [7:0]                       ch_reg_wr_offset,
    output logic [AXI_DATA_W-1:0]            ch_reg_wr_data,
    output logic [NUM_CHANNELS-1:0]          ch_reg_rd_en,
    output logic [7:0]                       ch_reg_rd_offset,
    input  logic [AXI_DATA_W-1:0]            ch_reg_rd_data [NUM_CHANNELS],

    // SPI control register interface
    output logic                    spi_reg_wr_en,
    output logic [7:0]             spi_reg_offset,
    output logic [AXI_DATA_W-1:0]  spi_reg_wr_data,
    output logic                    spi_reg_rd_en,
    input  logic [AXI_DATA_W-1:0]  spi_reg_rd_data,

    // ADC control register interface
    output logic                    adc_reg_wr_en,
    output logic [7:0]             adc_reg_offset,
    output logic [AXI_DATA_W-1:0]  adc_reg_wr_data,
    output logic                    adc_reg_rd_en,
    input  logic [AXI_DATA_W-1:0]  adc_reg_rd_data,

    // Pattern control
    output logic                    pat_start,
    output logic                    pat_stop,
    output logic                    pat_abort,
    input  logic                    pat_running,
    input  logic                    pat_done,
    input  logic                    pat_fail,
    output logic [VECTOR_ADDR_W-1:0] pat_start_addr,
    output logic [VECTOR_ADDR_W-1:0] pat_length,
    output logic [NUM_CHANNELS-1:0]  site_enable,

    // Timing control
    output logic [31:0]            vector_period,
    output logic [31:0]            vector_period_fine
);

    // -----------------------------------------------------------
    // Global registers
    // -----------------------------------------------------------
    logic [31:0] global_ctrl_r;
    logic [31:0] irq_enable_r;
    logic [31:0] irq_clear_r;
    logic        self_cal_start_r;

    // Pattern registers
    logic [31:0] pat_ctrl_r;
    logic [31:0] pat_start_addr_r;
    logic [31:0] pat_length_r;
    logic [31:0] site_enable_r;

    // Timing registers
    logic [31:0] vector_period_r;
    logic [31:0] vector_period_fine_r;

    // Output assignments
    assign global_reset      = global_ctrl_r[0];
    assign global_enable     = global_ctrl_r[1];
    assign irq_enable        = irq_enable_r;
    assign irq_clear         = irq_clear_r;
    assign self_cal_start    = self_cal_start_r;
    assign pat_start         = pat_ctrl_r[0];
    assign pat_stop          = pat_ctrl_r[1];
    assign pat_abort         = pat_ctrl_r[2];
    assign pat_start_addr    = pat_start_addr_r[VECTOR_ADDR_W-1:0];
    assign pat_length        = pat_length_r[VECTOR_ADDR_W-1:0];
    assign site_enable       = site_enable_r[NUM_CHANNELS-1:0];
    assign vector_period     = vector_period_r;
    assign vector_period_fine = vector_period_fine_r;

    // Address decode helpers
    logic [3:0]  addr_block;   // upper nibble selects block
    logic [3:0]  ch_id;        // channel id (0~15)
    logic [7:0]  ch_offset;    // register offset within channel

    assign addr_block = reg_wr_en ? reg_wr_addr[15:12] : reg_rd_addr[15:12];
    assign ch_id      = reg_wr_en ? reg_wr_addr[11:8]  : reg_rd_addr[11:8];
    assign ch_offset  = reg_wr_en ? reg_wr_addr[7:0]   : reg_rd_addr[7:0];

    // -----------------------------------------------------------
    // Write logic
    // -----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            global_ctrl_r      <= '0;
            irq_enable_r       <= '0;
            irq_clear_r        <= '0;
            self_cal_start_r   <= 1'b0;
            pat_ctrl_r         <= '0;
            pat_start_addr_r   <= '0;
            pat_length_r       <= '0;
            site_enable_r      <= '0;
            vector_period_r    <= 32'd10;  // Default 10ns = 100MHz
            vector_period_fine_r <= '0;
        end else begin
            // Auto-clear pulse registers
            self_cal_start_r <= 1'b0;
            irq_clear_r      <= '0;
            pat_ctrl_r       <= '0;  // start/stop/abort are pulses

            if (reg_wr_en) begin
                case (reg_wr_addr[15:8])
                    // Global registers 0x0000 - 0x00FF
                    8'h00: begin
                        case (reg_wr_addr[7:0])
                            8'h04: global_ctrl_r      <= reg_wr_data;
                            8'h0C: irq_enable_r       <= reg_wr_data;
                            8'h10: irq_clear_r        <= reg_wr_data;
                            8'h14: self_cal_start_r   <= reg_wr_data[0];
                            default: ;
                        endcase
                    end

                    // Timing registers 0x0100 - 0x01FF
                    8'h01: begin
                        case (reg_wr_addr[7:0])
                            8'h04: vector_period_r      <= reg_wr_data;
                            8'h08: vector_period_fine_r  <= reg_wr_data;
                            default: ;
                        endcase
                    end

                    // Pattern registers 0x0200 - 0x02FF
                    8'h02: begin
                        case (reg_wr_addr[7:0])
                            8'h00: pat_ctrl_r        <= reg_wr_data;
                            8'h08: pat_start_addr_r  <= reg_wr_data;
                            8'h0C: pat_length_r      <= reg_wr_data;
                            8'h10: site_enable_r     <= reg_wr_data;
                            default: ;
                        endcase
                    end

                    default: ;
                endcase
            end
        end
    end

    // Channel write decode
    always_comb begin
        ch_reg_wr_en     = '0;
        ch_reg_wr_offset = reg_wr_addr[7:0];
        ch_reg_wr_data   = reg_wr_data;

        spi_reg_wr_en    = 1'b0;
        spi_reg_offset   = reg_wr_addr[7:0];
        spi_reg_wr_data  = reg_wr_data;

        adc_reg_wr_en    = 1'b0;
        adc_reg_offset   = reg_wr_addr[7:0];
        adc_reg_wr_data  = reg_wr_data;

        if (reg_wr_en) begin
            case (reg_wr_addr[15:12])
                4'h1: ch_reg_wr_en[reg_wr_addr[11:8]] = 1'b1;  // 0x1000-0x1FFF
                4'h2: spi_reg_wr_en = 1'b1;                     // 0x2000-0x2FFF
                4'h3: adc_reg_wr_en = 1'b1;                     // 0x3000-0x3FFF
                default: ;
            endcase
        end
    end

    // -----------------------------------------------------------
    // Read logic
    // -----------------------------------------------------------
    logic        rd_valid_d;
    logic [31:0] rd_data_mux;

    // Channel read decode
    always_comb begin
        ch_reg_rd_en     = '0;
        ch_reg_rd_offset = reg_rd_addr[7:0];
        spi_reg_rd_en    = 1'b0;
        adc_reg_rd_en    = 1'b0;

        if (reg_rd_en) begin
            case (reg_rd_addr[15:12])
                4'h1: ch_reg_rd_en[reg_rd_addr[11:8]] = 1'b1;
                4'h2: spi_reg_rd_en = 1'b1;
                4'h3: adc_reg_rd_en = 1'b1;
                default: ;
            endcase
        end
    end

    // Read data mux
    always_comb begin
        rd_data_mux = 32'hDEAD_BEEF; // Default for unmapped

        case (reg_rd_addr[15:12])
            // Global registers
            4'h0: begin
                case (reg_rd_addr[7:0])
                    8'h00: rd_data_mux = DEVICE_ID;
                    8'h04: rd_data_mux = global_ctrl_r;
                    8'h08: rd_data_mux = global_status;
                    8'h0C: rd_data_mux = irq_enable_r;
                    8'h10: rd_data_mux = irq_status;
                    8'h14: rd_data_mux = {31'b0, self_cal_done};
                    8'h18: rd_data_mux = FPGA_VERSION;
                    default: rd_data_mux = '0;
                endcase

                // Timing registers at 0x01xx
                if (reg_rd_addr[11:8] == 4'h1) begin
                    case (reg_rd_addr[7:0])
                        8'h04: rd_data_mux = vector_period_r;
                        8'h08: rd_data_mux = vector_period_fine_r;
                        default: rd_data_mux = '0;
                    endcase
                end

                // Pattern registers at 0x02xx
                if (reg_rd_addr[11:8] == 4'h2) begin
                    case (reg_rd_addr[7:0])
                        8'h04: rd_data_mux = {29'b0, pat_fail, pat_done, pat_running};
                        8'h08: rd_data_mux = pat_start_addr_r;
                        8'h0C: rd_data_mux = pat_length_r;
                        8'h10: rd_data_mux = site_enable_r;
                        default: rd_data_mux = '0;
                    endcase
                end
            end

            // Channel registers
            4'h1: rd_data_mux = ch_reg_rd_data[reg_rd_addr[11:8]];

            // SPI registers
            4'h2: rd_data_mux = spi_reg_rd_data;

            // ADC registers
            4'h3: rd_data_mux = adc_reg_rd_data;

            default: rd_data_mux = 32'hDEAD_BEEF;
        endcase
    end

    // Read valid pipeline (1 cycle latency)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_valid_d  <= 1'b0;
            reg_rd_data <= '0;
        end else begin
            rd_valid_d  <= reg_rd_en;
            reg_rd_data <= rd_data_mux;
        end
    end

    assign reg_rd_valid = rd_valid_d;

endmodule
