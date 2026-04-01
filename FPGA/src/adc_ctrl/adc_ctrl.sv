// ADC Controller for ADS7959 (×2)
// 12-bit SAR ADC, SPI interface, 8-channel MUX per chip
// Used to read ADATE305 MEASOUT and DAC16_MON signals

module adc_ctrl
    import ate_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,

    // Register interface
    input  logic        reg_wr_en,
    input  logic [7:0]  reg_offset,
    input  logic [31:0] reg_wr_data,
    input  logic        reg_rd_en,
    output logic [31:0] reg_rd_data,

    // ADC SPI physical interface (active low CS)
    output logic [NUM_ADC-1:0] adc_sclk,
    output logic [NUM_ADC-1:0] adc_mosi,
    input  logic [NUM_ADC-1:0] adc_miso,
    output logic [NUM_ADC-1:0] adc_cs_n,

    // Measurement results (available to channel controllers)
    output logic [11:0] measout_data [NUM_CHANNELS],
    output logic [NUM_CHANNELS-1:0] measout_valid
);

    // -----------------------------------------------------------
    // Registers
    // -----------------------------------------------------------
    // 0x00: ADC_CTRL  [0]=start_scan, [1]=continuous, [3:2]=oversample(2^N)
    // 0x04: ADC_STATUS [0]=busy, [1]=scan_done
    // 0x08~0x44: ADC_DATA[0..15] (16 channels, read-only)

    logic [31:0] adc_ctrl_r;
    logic        start_scan;
    logic        continuous;
    logic [1:0]  oversample_exp;
    logic        scan_busy;
    logic        scan_done;

    assign continuous     = adc_ctrl_r[1];
    assign oversample_exp = adc_ctrl_r[3:2];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            adc_ctrl_r <= '0;
            start_scan <= 1'b0;
        end else begin
            start_scan <= 1'b0;
            if (reg_wr_en && reg_offset == 8'h00) begin
                adc_ctrl_r <= reg_wr_data;
                if (reg_wr_data[0]) start_scan <= 1'b1;
            end
        end
    end

    // Read mux
    always_comb begin
        reg_rd_data = '0;
        case (reg_offset)
            8'h00: reg_rd_data = adc_ctrl_r;
            8'h04: reg_rd_data = {30'b0, scan_done, scan_busy};
            default: begin
                // 0x08 + ch*4 → measout_data[ch]
                if (reg_offset >= 8'h08 && reg_offset < 8'h48) begin
                    logic [3:0] ch_idx;
                    ch_idx = (reg_offset - 8'h08) >> 2;
                    reg_rd_data = {20'b0, measout_data[ch_idx]};
                end
            end
        endcase
    end

    // -----------------------------------------------------------
    // ADC SPI engine (simplified: one engine shared for both ADCs)
    // ADS7959: 16-bit SPI frame, SCLK up to 18MHz
    // -----------------------------------------------------------
    typedef enum logic [2:0] {
        ADC_IDLE,
        ADC_SELECT_CH,
        ADC_CONVERT,
        ADC_SHIFT,
        ADC_STORE,
        ADC_NEXT_CH,
        ADC_DONE
    } adc_state_t;

    adc_state_t adc_state;
    logic [3:0] scan_ch;       // Current channel being scanned (0~15)
    logic [3:0] bit_cnt;       // SPI bit counter
    logic [15:0] spi_shift_out;
    logic [15:0] spi_shift_in [NUM_ADC];
    logic [7:0] clk_div;
    logic       clk_tick;
    logic       sclk_phase;

    // Oversample accumulator
    logic [3:0]  os_count;
    logic [3:0]  os_target;
    logic [23:0] os_accum [NUM_CHANNELS]; // 12-bit × max 16 samples = 16-bit + headroom

    assign os_target = (4'd1 << oversample_exp) - 1'b1;  // 0,1,3,15

    // Clock divider: 100MHz / (2*(5+1)) ≈ 8.3MHz SPI clock
    localparam CLK_DIV_VAL = 8'd5;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div  <= '0;
            clk_tick <= 1'b0;
        end else begin
            clk_tick <= 1'b0;
            if (adc_state != ADC_IDLE) begin
                if (clk_div >= CLK_DIV_VAL) begin
                    clk_div  <= '0;
                    clk_tick <= 1'b1;
                end else begin
                    clk_div <= clk_div + 1'b1;
                end
            end else begin
                clk_div <= '0;
            end
        end
    end

    assign scan_busy = (adc_state != ADC_IDLE);

    // -----------------------------------------------------------
    // Scan state machine
    // -----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            adc_state    <= ADC_IDLE;
            scan_ch      <= '0;
            bit_cnt      <= '0;
            spi_shift_out <= '0;
            adc_cs_n     <= {NUM_ADC{1'b1}};
            adc_sclk     <= '0;
            adc_mosi     <= '0;
            sclk_phase   <= 1'b0;
            scan_done    <= 1'b0;
            measout_valid <= '0;
            os_count     <= '0;

            for (int i = 0; i < NUM_CHANNELS; i++) begin
                measout_data[i] <= '0;
                os_accum[i]     <= '0;
            end
            for (int i = 0; i < NUM_ADC; i++)
                spi_shift_in[i] <= '0;
        end else begin
            scan_done     <= 1'b0;
            measout_valid <= '0;

            case (adc_state)
                ADC_IDLE: begin
                    adc_cs_n <= {NUM_ADC{1'b1}};
                    adc_sclk <= '0;
                    if (start_scan || (continuous && scan_done)) begin
                        scan_ch   <= '0;
                        os_count  <= '0;
                        for (int i = 0; i < NUM_CHANNELS; i++)
                            os_accum[i] <= '0;
                        adc_state <= ADC_SELECT_CH;
                    end
                end

                ADC_SELECT_CH: begin
                    // ADS7959 channel select: write channel address in SPI frame
                    // Frame: [15:12]=channel, [11:0]=don't care for write
                    // ADC0 handles ch 0~7, ADC1 handles ch 8~15
                    spi_shift_out <= {scan_ch[2:0], 1'b0, 12'h000};
                    bit_cnt       <= '0;
                    sclk_phase    <= 1'b0;
                    adc_cs_n      <= '0; // Assert both CS
                    adc_state     <= ADC_SHIFT;
                end

                ADC_SHIFT: begin
                    if (clk_tick) begin
                        if (!sclk_phase) begin
                            // Rising edge: drive MOSI
                            adc_sclk  <= {NUM_ADC{1'b1}};
                            adc_mosi  <= {NUM_ADC{spi_shift_out[15]}};
                            sclk_phase <= 1'b1;
                        end else begin
                            // Falling edge: sample MISO, shift
                            adc_sclk   <= '0;
                            for (int i = 0; i < NUM_ADC; i++)
                                spi_shift_in[i] <= {spi_shift_in[i][14:0], adc_miso[i]};
                            spi_shift_out <= {spi_shift_out[14:0], 1'b0};
                            sclk_phase   <= 1'b0;
                            bit_cnt      <= bit_cnt + 1'b1;

                            if (bit_cnt == 4'd15) begin
                                adc_cs_n  <= {NUM_ADC{1'b1}};
                                adc_state <= ADC_STORE;
                            end
                        end
                    end
                end

                ADC_STORE: begin
                    // Accumulate for oversampling
                    // ADC0 result → channel scan_ch[2:0]
                    // ADC1 result → channel scan_ch[2:0] + 8
                    os_accum[{1'b0, scan_ch[2:0]}] <= os_accum[{1'b0, scan_ch[2:0]}] +
                                                       {12'b0, spi_shift_in[0][11:0]};
                    os_accum[{1'b1, scan_ch[2:0]}] <= os_accum[{1'b1, scan_ch[2:0]}] +
                                                       {12'b0, spi_shift_in[1][11:0]};

                    if (os_count >= os_target) begin
                        adc_state <= ADC_NEXT_CH;
                    end else begin
                        os_count  <= os_count + 1'b1;
                        adc_state <= ADC_SELECT_CH; // Re-sample same channel
                    end
                end

                ADC_NEXT_CH: begin
                    // Store averaged result
                    // Right-shift accumulator by oversample_exp to get average
                    measout_data[{1'b0, scan_ch[2:0]}] <= os_accum[{1'b0, scan_ch[2:0]}] >> oversample_exp;
                    measout_data[{1'b1, scan_ch[2:0]}] <= os_accum[{1'b1, scan_ch[2:0]}] >> oversample_exp;
                    measout_valid[{1'b0, scan_ch[2:0]}] <= 1'b1;
                    measout_valid[{1'b1, scan_ch[2:0]}] <= 1'b1;

                    if (scan_ch[2:0] == 3'd7) begin
                        adc_state <= ADC_DONE;
                    end else begin
                        scan_ch   <= scan_ch + 1'b1;
                        os_count  <= '0;
                        os_accum[{1'b0, scan_ch[2:0]} + 1] <= '0;
                        os_accum[{1'b1, scan_ch[2:0]} + 1] <= '0;
                        adc_state <= ADC_SELECT_CH;
                    end
                end

                ADC_DONE: begin
                    scan_done <= 1'b1;
                    adc_state <= ADC_IDLE;
                end

                default: adc_state <= ADC_IDLE;
            endcase
        end
    end

endmodule
