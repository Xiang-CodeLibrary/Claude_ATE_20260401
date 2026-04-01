// Calibration Controller
// Manages self-calibration sequence and external calibration interface
// Stores calibration constants in Flash via SPI

module cal_controller
    import ate_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,

    // Control interface
    input  logic        self_cal_start,
    output logic        self_cal_done,
    output logic        self_cal_busy,

    // External calibration session
    input  logic        ext_cal_open,       // Open session (with password check)
    input  logic        ext_cal_close,      // Close session & commit
    input  logic [31:0] ext_cal_password,
    output logic        ext_cal_active,

    // Calibration reference path control
    input  logic [3:0]  cal_path_select,    // 0=voltage_ref, 1=resistor_ref, etc.
    input  logic [31:0] cal_reference_val,  // Reference value to write

    // ADC measurement input (from adc_ctrl)
    input  logic [11:0] adc_data [NUM_CHANNELS],
    input  logic [NUM_CHANNELS-1:0] adc_valid,

    // Temperature sensor reading (from ADATE305 via SPI)
    input  logic [15:0] temperature,

    // Calibration constant outputs (to channel_regs)
    output logic signed [15:0] cal_voltage_offset [NUM_CHANNELS],
    output logic signed [15:0] cal_voltage_gain   [NUM_CHANNELS],
    output logic signed [15:0] cal_current_offset [NUM_CHANNELS][5], // 5 ranges
    output logic signed [15:0] cal_current_gain   [NUM_CHANNELS][5],

    // SPI command interface (to spi_master, for ADATE305 reference configuration)
    output logic        spi_cmd_valid,
    output logic [2:0]  spi_cmd_chip,
    output logic [6:0]  spi_cmd_addr,
    output logic [15:0] spi_cmd_wdata,
    input  logic        spi_cmd_ready,
    input  logic        spi_cmd_done,

    // Flash storage interface (calibration constants persist across power cycles)
    output logic        flash_wr_en,
    output logic [15:0] flash_wr_addr,
    output logic [31:0] flash_wr_data,
    output logic        flash_rd_en,
    output logic [15:0] flash_rd_addr,
    input  logic [31:0] flash_rd_data,
    input  logic        flash_rd_valid,

    // Calibration metadata
    output logic [31:0] last_cal_date,      // Unix timestamp of last cal
    output logic [15:0] last_cal_temp       // Temperature at last cal
);

    // ================================================================
    // Password protection
    // ================================================================
    localparam [31:0] CAL_PASSWORD = 32'h4E415449; // "NATI" in ASCII

    logic ext_session_open;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ext_session_open <= 1'b0;
        end else begin
            if (ext_cal_open && ext_cal_password == CAL_PASSWORD)
                ext_session_open <= 1'b1;
            if (ext_cal_close)
                ext_session_open <= 1'b0;
        end
    end

    assign ext_cal_active = ext_session_open;

    // ================================================================
    // Self-Calibration State Machine
    // ================================================================
    typedef enum logic [3:0] {
        SC_IDLE,
        SC_LOAD_CONSTANTS,      // Load existing constants from Flash
        SC_READ_TEMP,           // Read ADATE305 temperature sensor
        SC_MEASURE_VREF_0V,     // Measure 0V reference via ADC
        SC_MEASURE_VREF_5V,     // Measure 5V reference (ADR431) via ADC
        SC_COMPUTE_V_CAL,       // Compute voltage offset/gain
        SC_MEASURE_RREF,        // Measure 50Ω reference resistance
        SC_COMPUTE_R_CAL,       // Compute resistance calibration
        SC_STORE_CONSTANTS,     // Write updated constants to Flash
        SC_DONE
    } selfcal_state_t;

    selfcal_state_t sc_state;
    logic [3:0] sc_ch_idx;          // Current channel being calibrated
    logic [2:0] sc_chip_idx;
    logic [7:0] sc_wait_cnt;

    // ADC measurement accumulators (for averaging)
    logic [23:0] adc_accum_0v [NUM_CHANNELS];
    logic [23:0] adc_accum_5v [NUM_CHANNELS];
    logic [3:0]  adc_sample_cnt;

    // Flash address layout for calibration constants:
    // Base = 0x0000
    // Per channel (0x40 bytes each): offset = ch * 0x40
    //   +0x00: voltage_offset (16-bit signed)
    //   +0x04: voltage_gain (16-bit signed, Q1.15 fixed point)
    //   +0x08: current_offset[0..4] (5 × 16-bit)
    //   +0x1C: current_gain[0..4] (5 × 16-bit)
    //   +0x30: reserved
    // 0x0400: cal_date (32-bit)
    // 0x0404: cal_temp (16-bit)

    localparam FLASH_CAL_BASE = 16'h0000;
    localparam FLASH_CAL_DATE = 16'h0400;
    localparam FLASH_CAL_TEMP = 16'h0404;

    assign self_cal_busy = (sc_state != SC_IDLE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sc_state       <= SC_IDLE;
            self_cal_done  <= 1'b0;
            sc_ch_idx      <= '0;
            sc_wait_cnt    <= '0;
            adc_sample_cnt <= '0;
            spi_cmd_valid  <= 1'b0;
            flash_wr_en    <= 1'b0;
            flash_rd_en    <= 1'b0;
            last_cal_date  <= '0;
            last_cal_temp  <= '0;

            for (int ch = 0; ch < NUM_CHANNELS; ch++) begin
                cal_voltage_offset[ch] <= '0;
                cal_voltage_gain[ch]   <= 16'h4000; // 1.0 in Q1.15
                adc_accum_0v[ch]       <= '0;
                adc_accum_5v[ch]       <= '0;
                for (int r = 0; r < 5; r++) begin
                    cal_current_offset[ch][r] <= '0;
                    cal_current_gain[ch][r]   <= 16'h4000;
                end
            end
        end else begin
            self_cal_done <= 1'b0;
            spi_cmd_valid <= 1'b0;
            flash_wr_en   <= 1'b0;
            flash_rd_en   <= 1'b0;

            case (sc_state)
                SC_IDLE: begin
                    if (self_cal_start) begin
                        sc_state <= SC_LOAD_CONSTANTS;
                        sc_ch_idx <= '0;
                    end
                end

                // Load existing calibration constants from Flash
                SC_LOAD_CONSTANTS: begin
                    flash_rd_en   <= 1'b1;
                    flash_rd_addr <= FLASH_CAL_BASE + {sc_ch_idx, 6'h00};

                    if (flash_rd_valid) begin
                        cal_voltage_offset[sc_ch_idx] <= flash_rd_data[15:0];

                        if (sc_ch_idx == NUM_CHANNELS - 1) begin
                            sc_ch_idx <= '0;
                            sc_state  <= SC_READ_TEMP;
                        end else begin
                            sc_ch_idx <= sc_ch_idx + 1'b1;
                        end
                    end
                end

                // Read temperature from ADATE305 chip 0
                SC_READ_TEMP: begin
                    if (spi_cmd_ready) begin
                        spi_cmd_valid <= 1'b1;
                        spi_cmd_chip  <= 3'd0;
                        spi_cmd_addr  <= ADATE_REG_TEMP;
                        spi_cmd_wdata <= '0;
                        sc_state      <= SC_MEASURE_VREF_0V;
                    end
                end

                // Measure 0V reference on all channels via ADC
                SC_MEASURE_VREF_0V: begin
                    // Configure ADATE305 to output 0V reference to MEASOUT
                    // Then sample ADC multiple times for averaging
                    sc_wait_cnt <= sc_wait_cnt + 1'b1;

                    if (sc_wait_cnt == 8'hFF) begin
                        // After settling time, accumulate ADC readings
                        if (&adc_valid) begin
                            for (int ch = 0; ch < NUM_CHANNELS; ch++)
                                adc_accum_0v[ch] <= adc_accum_0v[ch] + {12'b0, adc_data[ch]};

                            adc_sample_cnt <= adc_sample_cnt + 1'b1;
                            if (adc_sample_cnt == 4'd15) begin
                                sc_state       <= SC_MEASURE_VREF_5V;
                                adc_sample_cnt <= '0;
                                sc_wait_cnt    <= '0;
                            end
                        end
                    end
                end

                // Measure 5V reference (ADR431)
                SC_MEASURE_VREF_5V: begin
                    sc_wait_cnt <= sc_wait_cnt + 1'b1;

                    if (sc_wait_cnt == 8'hFF) begin
                        if (&adc_valid) begin
                            for (int ch = 0; ch < NUM_CHANNELS; ch++)
                                adc_accum_5v[ch] <= adc_accum_5v[ch] + {12'b0, adc_data[ch]};

                            adc_sample_cnt <= adc_sample_cnt + 1'b1;
                            if (adc_sample_cnt == 4'd15) begin
                                sc_state       <= SC_COMPUTE_V_CAL;
                                adc_sample_cnt <= '0;
                            end
                        end
                    end
                end

                // Compute voltage calibration coefficients
                SC_COMPUTE_V_CAL: begin
                    // Two-point calibration:
                    //   offset = measured_0V (averaged, should be 0)
                    //   gain = 5.0V_ideal / measured_5V
                    // Simplified: store offset directly, gain as ratio
                    for (int ch = 0; ch < NUM_CHANNELS; ch++) begin
                        // Offset = average of 0V measurements (>>4 for 16-sample average)
                        cal_voltage_offset[ch] <= -adc_accum_0v[ch][15:0]; // Negate to compensate
                        // Gain: approximate using shift (more precise would need divider)
                        // For now store raw 5V measurement for software to compute
                        cal_voltage_gain[ch] <= adc_accum_5v[ch][15:0];
                    end
                    sc_ch_idx <= '0;
                    sc_state  <= SC_STORE_CONSTANTS;
                end

                // Store calibration constants to Flash
                SC_STORE_CONSTANTS: begin
                    flash_wr_en   <= 1'b1;
                    flash_wr_addr <= FLASH_CAL_BASE + {sc_ch_idx, 6'h00};
                    flash_wr_data <= {cal_voltage_gain[sc_ch_idx], cal_voltage_offset[sc_ch_idx]};

                    sc_ch_idx <= sc_ch_idx + 1'b1;
                    if (sc_ch_idx == NUM_CHANNELS - 1) begin
                        sc_state <= SC_DONE;
                    end
                end

                SC_DONE: begin
                    // Store metadata
                    last_cal_temp <= temperature;
                    self_cal_done <= 1'b1;
                    sc_state      <= SC_IDLE;
                end

                default: sc_state <= SC_IDLE;
            endcase
        end
    end

endmodule
