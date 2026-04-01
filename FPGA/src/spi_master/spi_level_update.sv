// SPI Level Update Engine
// Monitors channel register changes and pushes updated DAC values to ADATE305 via SPI
// Each ADATE305 chip has 2 channels, addressed as chip_id = channel / 2

module spi_level_update
    import ate_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,

    // Level update requests from channel registers
    input  logic [NUM_CHANNELS-1:0] levels_updated,   // Pulse when levels change

    // Channel level values (from channel_regs)
    input  logic [15:0] ch_vih   [NUM_CHANNELS],
    input  logic [15:0] ch_vil   [NUM_CHANNELS],
    input  logic [15:0] ch_vterm [NUM_CHANNELS],
    input  logic [15:0] ch_voh   [NUM_CHANNELS],
    input  logic [15:0] ch_vol   [NUM_CHANNELS],
    input  logic [15:0] ch_ioh   [NUM_CHANNELS],
    input  logic [15:0] ch_iol   [NUM_CHANNELS],
    input  logic [15:0] ch_vcom  [NUM_CHANNELS],

    // Calibration offsets
    input  logic signed [15:0] ch_cal_off_vih [NUM_CHANNELS],
    input  logic signed [15:0] ch_cal_off_vil [NUM_CHANNELS],
    input  logic signed [15:0] ch_cal_off_vt  [NUM_CHANNELS],

    // Pin function (to determine which registers to update)
    input  pin_func_t   ch_pin_func [NUM_CHANNELS],

    // PPMU levels
    input  logic [15:0] ch_ppmu_vlevel [NUM_CHANNELS],
    input  logic [15:0] ch_ppmu_ilevel [NUM_CHANNELS],
    input  ppmu_mode_t  ch_ppmu_mode   [NUM_CHANNELS],

    // SPI command interface (to spi_master)
    output logic        cmd_valid,
    output logic [2:0]  cmd_chip_sel,
    output logic        cmd_rw,
    output logic [6:0]  cmd_addr,
    output logic [15:0] cmd_wdata,
    input  logic        cmd_ready,
    input  logic        cmd_done,

    // Status
    output logic        busy,
    output logic        update_done
);

    // -----------------------------------------------------------
    // Pending update tracker
    // -----------------------------------------------------------
    logic [NUM_CHANNELS-1:0] pending;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pending <= '0;
        else begin
            // Set pending on level change
            pending <= (pending | levels_updated) & ~clear_mask;
        end
    end

    logic [NUM_CHANNELS-1:0] clear_mask;

    // -----------------------------------------------------------
    // State machine: scan channels, push registers
    // -----------------------------------------------------------
    typedef enum logic [3:0] {
        ST_IDLE,
        ST_PICK_CH,
        ST_SEND_VH,
        ST_WAIT_VH,
        ST_SEND_VL,
        ST_WAIT_VL,
        ST_SEND_VT,
        ST_WAIT_VT,
        ST_SEND_VOH,
        ST_WAIT_VOH,
        ST_SEND_VOL,
        ST_WAIT_VOL,
        ST_SEND_IOH,
        ST_WAIT_IOH,
        ST_SEND_IOL,
        ST_WAIT_IOL
    } state_t;

    state_t state;
    logic [3:0] cur_ch;        // Current channel being updated (0~15)
    logic [2:0] cur_chip;      // ADATE305 chip = cur_ch / 2
    logic       cur_ch_sel;    // Channel within chip: 0 or 1

    assign cur_chip   = cur_ch[3:1];
    assign cur_ch_sel = cur_ch[0];

    assign busy = (state != ST_IDLE);

    // Calibrated DAC value calculation
    logic [15:0] cal_vih, cal_vil, cal_vt;

    always_comb begin
        cal_vih = ch_vih[cur_ch] + ch_cal_off_vih[cur_ch];
        cal_vil = ch_vil[cur_ch] + ch_cal_off_vil[cur_ch];
        cal_vt  = ch_vterm[cur_ch] + ch_cal_off_vt[cur_ch];
    end

    // ADATE305 channel-dependent register address offset
    // CH0 registers: base addresses; CH1 registers: base + channel offset
    // Simplified: ADATE305 uses different register addresses for CH0 and CH1
    logic [6:0] reg_vh_addr, reg_vl_addr, reg_vt_addr;
    logic [6:0] reg_voh_addr, reg_vol_addr;
    logic [6:0] reg_ioh_addr, reg_iol_addr;

    always_comb begin
        if (!cur_ch_sel) begin
            // Channel 0 of ADATE305
            reg_vh_addr  = ADATE_REG_VH;
            reg_vl_addr  = ADATE_REG_VL;
            reg_vt_addr  = ADATE_REG_VT;
            reg_voh_addr = ADATE_REG_VOH;
            reg_vol_addr = ADATE_REG_VOL;
            reg_ioh_addr = ADATE_REG_IOH;
            reg_iol_addr = ADATE_REG_IOL;
        end else begin
            // Channel 1: offset by 0x40 in ADATE305 address space
            reg_vh_addr  = ADATE_REG_VH  + 7'h40;
            reg_vl_addr  = ADATE_REG_VL  + 7'h40;
            reg_vt_addr  = ADATE_REG_VT  + 7'h40;
            reg_voh_addr = ADATE_REG_VOH + 7'h40;
            reg_vol_addr = ADATE_REG_VOL + 7'h40;
            reg_ioh_addr = ADATE_REG_IOH + 7'h40;
            reg_iol_addr = ADATE_REG_IOL + 7'h40;
        end
    end

    // -----------------------------------------------------------
    // Main state machine
    // -----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_IDLE;
            cur_ch      <= '0;
            cmd_valid   <= 1'b0;
            cmd_chip_sel<= '0;
            cmd_rw      <= 1'b0;
            cmd_addr    <= '0;
            cmd_wdata   <= '0;
            clear_mask  <= '0;
            update_done <= 1'b0;
        end else begin
            clear_mask  <= '0;
            update_done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    cmd_valid <= 1'b0;
                    if (|pending) begin
                        state <= ST_PICK_CH;
                    end
                end

                ST_PICK_CH: begin
                    // Priority encoder: find lowest pending channel
                    cur_ch <= '0;
                    for (int i = NUM_CHANNELS-1; i >= 0; i--) begin
                        if (pending[i]) cur_ch <= i[3:0];
                    end
                    state <= ST_SEND_VH;
                end

                // --- VH ---
                ST_SEND_VH: begin
                    if (cmd_ready) begin
                        cmd_valid    <= 1'b1;
                        cmd_chip_sel <= cur_chip;
                        cmd_rw       <= 1'b0;  // Write
                        cmd_addr     <= reg_vh_addr;
                        cmd_wdata    <= cal_vih;
                        state        <= ST_WAIT_VH;
                    end
                end
                ST_WAIT_VH: begin
                    cmd_valid <= 1'b0;
                    if (cmd_done) state <= ST_SEND_VL;
                end

                // --- VL ---
                ST_SEND_VL: begin
                    if (cmd_ready) begin
                        cmd_valid    <= 1'b1;
                        cmd_chip_sel <= cur_chip;
                        cmd_rw       <= 1'b0;
                        cmd_addr     <= reg_vl_addr;
                        cmd_wdata    <= cal_vil;
                        state        <= ST_WAIT_VL;
                    end
                end
                ST_WAIT_VL: begin
                    cmd_valid <= 1'b0;
                    if (cmd_done) state <= ST_SEND_VT;
                end

                // --- VT ---
                ST_SEND_VT: begin
                    if (cmd_ready) begin
                        cmd_valid    <= 1'b1;
                        cmd_chip_sel <= cur_chip;
                        cmd_rw       <= 1'b0;
                        cmd_addr     <= reg_vt_addr;
                        cmd_wdata    <= cal_vt;
                        state        <= ST_WAIT_VT;
                    end
                end
                ST_WAIT_VT: begin
                    cmd_valid <= 1'b0;
                    if (cmd_done) state <= ST_SEND_VOH;
                end

                // --- VOH ---
                ST_SEND_VOH: begin
                    if (cmd_ready) begin
                        cmd_valid    <= 1'b1;
                        cmd_chip_sel <= cur_chip;
                        cmd_rw       <= 1'b0;
                        cmd_addr     <= reg_voh_addr;
                        cmd_wdata    <= ch_voh[cur_ch];
                        state        <= ST_WAIT_VOH;
                    end
                end
                ST_WAIT_VOH: begin
                    cmd_valid <= 1'b0;
                    if (cmd_done) state <= ST_SEND_VOL;
                end

                // --- VOL ---
                ST_SEND_VOL: begin
                    if (cmd_ready) begin
                        cmd_valid    <= 1'b1;
                        cmd_chip_sel <= cur_chip;
                        cmd_rw       <= 1'b0;
                        cmd_addr     <= reg_vol_addr;
                        cmd_wdata    <= ch_vol[cur_ch];
                        state        <= ST_WAIT_VOL;
                    end
                end
                ST_WAIT_VOL: begin
                    cmd_valid <= 1'b0;
                    if (cmd_done) state <= ST_SEND_IOH;
                end

                // --- IOH ---
                ST_SEND_IOH: begin
                    if (cmd_ready) begin
                        cmd_valid    <= 1'b1;
                        cmd_chip_sel <= cur_chip;
                        cmd_rw       <= 1'b0;
                        cmd_addr     <= reg_ioh_addr;
                        cmd_wdata    <= ch_ioh[cur_ch];
                        state        <= ST_WAIT_IOH;
                    end
                end
                ST_WAIT_IOH: begin
                    cmd_valid <= 1'b0;
                    if (cmd_done) state <= ST_SEND_IOL;
                end

                // --- IOL ---
                ST_SEND_IOL: begin
                    if (cmd_ready) begin
                        cmd_valid    <= 1'b1;
                        cmd_chip_sel <= cur_chip;
                        cmd_rw       <= 1'b0;
                        cmd_addr     <= reg_iol_addr;
                        cmd_wdata    <= ch_iol[cur_ch];
                        state        <= ST_WAIT_IOL;
                    end
                end
                ST_WAIT_IOL: begin
                    cmd_valid <= 1'b0;
                    if (cmd_done) begin
                        // Clear pending for this channel
                        clear_mask[cur_ch] <= 1'b1;
                        update_done        <= 1'b1;
                        state              <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
