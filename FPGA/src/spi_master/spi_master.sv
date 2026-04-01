`timescale 1ns / 1ps
// SPI Master Controller for ADATE305
// Supports 8 chip selects, 24-bit frames (1-bit R/W + 7-bit addr + 16-bit data)

module spi_master
    import ate_pkg::*;
(
    input  logic        clk,        // System clock (200MHz)
    input  logic        rst_n,

    // Register interface
    input  logic        reg_wr_en,
    input  logic [7:0]  reg_offset,
    input  logic [31:0] reg_wr_data,
    input  logic        reg_rd_en,
    output logic [31:0] reg_rd_data,

    // Command interface (from channel controllers)
    input  logic        cmd_valid,
    input  logic [2:0]  cmd_chip_sel,   // 0~7 = ADATE305 chip select
    input  logic        cmd_rw,         // 0=write, 1=read
    input  logic [6:0]  cmd_addr,       // ADATE305 register address
    input  logic [15:0] cmd_wdata,      // Write data
    output logic        cmd_ready,
    output logic        cmd_done,
    output logic [15:0] cmd_rdata,      // Read data (valid when cmd_done=1)

    // SPI physical interface
    output logic        spi_sclk,
    output logic        spi_mosi,       // SDIN to ADATE305
    input  logic        spi_miso,       // SDOUT from ADATE305
    output logic [NUM_ADATE305-1:0] spi_cs_n,  // Active low chip selects
    output logic        spi_rst_n       // ADATE305 global reset
);

    // -----------------------------------------------------------
    // Register interface (0x2000 - 0x2FFF)
    // -----------------------------------------------------------
    // 0x00: SPI_CTRL  [0]=start, [1]=busy, [2]=reset
    // 0x04: SPI_STATUS [0]=busy, [1]=done, [7:4]=error
    // 0x08: SPI_TX_DATA {rw(1), addr(7), wdata(16), cs(3), reserved(5)}
    // 0x0C: SPI_RX_DATA {16'b0, rdata(16)}
    // 0x10: SPI_CS_SELECT  direct CS control
    // 0x14: SPI_CLK_DIV  clock divider

    logic [31:0] spi_ctrl_r;
    logic [31:0] spi_tx_data_r;
    logic [31:0] spi_clk_div_r;
    logic [31:0] spi_rx_data_r;
    logic        reg_start;
    logic        spi_busy;
    logic        spi_done_r;

    assign spi_rst_n = ~spi_ctrl_r[2];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_ctrl_r    <= '0;
            spi_tx_data_r <= '0;
            spi_clk_div_r <= 32'd4;  // 200MHz / (2*(4+1)) = 20MHz
            reg_start     <= 1'b0;
        end else begin
            reg_start <= 1'b0;
            if (reg_wr_en) begin
                case (reg_offset)
                    8'h00: begin
                        spi_ctrl_r <= reg_wr_data;
                        if (reg_wr_data[0]) reg_start <= 1'b1;
                    end
                    8'h08: spi_tx_data_r <= reg_wr_data;
                    8'h14: spi_clk_div_r <= reg_wr_data;
                    default: ;
                endcase
            end
        end
    end

    always_comb begin
        reg_rd_data = '0;
        case (reg_offset)
            8'h00: reg_rd_data = {30'b0, spi_ctrl_r[2], spi_busy};
            8'h04: reg_rd_data = {30'b0, spi_done_r, spi_busy};
            8'h08: reg_rd_data = spi_tx_data_r;
            8'h0C: reg_rd_data = spi_rx_data_r;
            8'h14: reg_rd_data = spi_clk_div_r;
            default: reg_rd_data = '0;
        endcase
    end

    // -----------------------------------------------------------
    // SPI command arbitration: register vs command interface
    // -----------------------------------------------------------
    logic        arb_valid;
    logic [2:0]  arb_cs;
    logic        arb_rw;
    logic [6:0]  arb_addr;
    logic [15:0] arb_wdata;
    logic        arb_done;
    logic [15:0] arb_rdata;
    logic        arb_src;       // 0=register, 1=command interface (combinational)
    logic        arb_src_r;     // Latched source (valid during entire SPI transaction)

    always_comb begin
        if (cmd_valid && !spi_busy) begin
            arb_valid = 1'b1;
            arb_cs    = cmd_chip_sel;
            arb_rw    = cmd_rw;
            arb_addr  = cmd_addr;
            arb_wdata = cmd_wdata;
            arb_src   = 1'b1;
        end else if (reg_start && !spi_busy) begin
            arb_valid = 1'b1;
            arb_cs    = spi_tx_data_r[18:16];
            arb_rw    = spi_tx_data_r[23];
            arb_addr  = spi_tx_data_r[22:16];
            arb_wdata = spi_tx_data_r[15:0];
            arb_src   = 1'b0;
        end else begin
            arb_valid = 1'b0;
            arb_cs    = '0;
            arb_rw    = 1'b0;
            arb_addr  = '0;
            arb_wdata = '0;
            arb_src   = 1'b0;
        end
    end

    // Latch arb_src at transaction start so cmd_done stays correct
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            arb_src_r <= 1'b0;
        else if (arb_valid && !spi_busy)
            arb_src_r <= arb_src;
    end

    assign cmd_ready = !spi_busy;
    assign cmd_done  = arb_done && arb_src_r;
    assign cmd_rdata = arb_rdata;

    // -----------------------------------------------------------
    // SPI engine
    // -----------------------------------------------------------
    typedef enum logic [2:0] {
        S_IDLE,
        S_CS_SETUP,
        S_SHIFT,
        S_CS_HOLD,
        S_DONE
    } spi_state_t;

    spi_state_t state;
    logic [SPI_FRAME_WIDTH-1:0] shift_out;
    logic [SPI_FRAME_WIDTH-1:0] shift_in;
    logic [4:0]  bit_cnt;
    logic [15:0] clk_div_cnt;
    logic        sclk_en;
    logic [2:0]  active_cs;
    logic [7:0]  setup_cnt;

    assign spi_busy = (state != S_IDLE);

    // Clock divider
    logic clk_tick;  // Generates SPI clock edges
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_cnt <= '0;
            clk_tick    <= 1'b0;
        end else begin
            clk_tick <= 1'b0;
            if (sclk_en) begin
                if (clk_div_cnt >= spi_clk_div_r[15:0]) begin
                    clk_div_cnt <= '0;
                    clk_tick    <= 1'b1;
                end else begin
                    clk_div_cnt <= clk_div_cnt + 1'b1;
                end
            end else begin
                clk_div_cnt <= '0;
            end
        end
    end

    // SPI state machine
    logic sclk_phase;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            shift_out  <= '0;
            shift_in   <= '0;
            bit_cnt    <= '0;
            sclk_en    <= 1'b0;
            sclk_phase <= 1'b0;
            spi_sclk   <= 1'b0;
            spi_mosi   <= 1'b0;
            spi_cs_n   <= {NUM_ADATE305{1'b1}};
            active_cs  <= '0;
            arb_done   <= 1'b0;
            arb_rdata  <= '0;
            spi_done_r <= 1'b0;
            spi_rx_data_r <= '0;
            setup_cnt  <= '0;
        end else begin
            arb_done <= 1'b0;

            case (state)
                S_IDLE: begin
                    spi_sclk   <= 1'b0;
                    spi_cs_n   <= {NUM_ADATE305{1'b1}};
                    sclk_en    <= 1'b0;
                    sclk_phase <= 1'b0;

                    if (arb_valid) begin
                        shift_out <= {arb_rw, arb_addr, arb_wdata};
                        active_cs <= arb_cs;
                        bit_cnt   <= '0;
                        setup_cnt <= '0;
                        state     <= S_CS_SETUP;
                    end
                end

                S_CS_SETUP: begin
                    // Assert CS, wait setup time
                    spi_cs_n[active_cs] <= 1'b0;
                    setup_cnt <= setup_cnt + 1'b1;
                    if (setup_cnt >= 8'd3) begin
                        sclk_en <= 1'b1;
                        state   <= S_SHIFT;
                    end
                end

                S_SHIFT: begin
                    if (clk_tick) begin
                        if (!sclk_phase) begin
                            // Rising edge: drive MOSI
                            spi_sclk  <= 1'b1;
                            spi_mosi  <= shift_out[SPI_FRAME_WIDTH-1];
                            sclk_phase <= 1'b1;
                        end else begin
                            // Falling edge: sample MISO, shift
                            spi_sclk   <= 1'b0;
                            shift_in   <= {shift_in[SPI_FRAME_WIDTH-2:0], spi_miso};
                            shift_out  <= {shift_out[SPI_FRAME_WIDTH-2:0], 1'b0};
                            sclk_phase <= 1'b0;
                            bit_cnt    <= bit_cnt + 1'b1;

                            if (bit_cnt == SPI_FRAME_WIDTH - 1) begin
                                sclk_en   <= 1'b0;
                                setup_cnt <= '0;
                                state     <= S_CS_HOLD;
                            end
                        end
                    end
                end

                S_CS_HOLD: begin
                    spi_sclk <= 1'b0;
                    setup_cnt <= setup_cnt + 1'b1;
                    if (setup_cnt >= 8'd3) begin
                        spi_cs_n  <= {NUM_ADATE305{1'b1}};
                        arb_rdata <= shift_in[15:0];
                        arb_done  <= 1'b1;
                        spi_done_r    <= 1'b1;
                        spi_rx_data_r <= {16'b0, shift_in[15:0]};
                        state     <= S_DONE;
                    end
                end

                S_DONE: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
