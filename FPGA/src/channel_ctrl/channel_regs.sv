`timescale 1ns / 1ps
// Per-Channel Register Block
// Each channel has its own instance, holding DCL levels and PPMU configuration

module channel_regs
    import ate_pkg::*;
#(
    parameter CHANNEL_ID = 0
)(
    input  logic        clk,
    input  logic        rst_n,

    // Register interface
    input  logic        reg_wr_en,
    input  logic [7:0]  reg_offset,
    input  logic [31:0] reg_wr_data,
    input  logic        reg_rd_en,
    input  logic [7:0]  reg_rd_offset,
    output logic [31:0] reg_rd_data,

    // Channel configuration outputs
    output pin_func_t   pin_function,
    output term_mode_t  termination_mode,
    output drive_fmt_t  drive_format,
    output logic [1:0]  edge_multiplier,  // 0=1x, 1=2x

    // DCL levels (14-bit DAC values for ADATE305)
    output logic [15:0] level_vih,
    output logic [15:0] level_vil,
    output logic [15:0] level_vterm,
    output logic [15:0] level_voh,
    output logic [15:0] level_vol,
    output logic [15:0] level_ioh,
    output logic [15:0] level_iol,
    output logic [15:0] level_vcom,

    // PPMU configuration
    output ppmu_mode_t  ppmu_mode,
    output logic [15:0] ppmu_voltage_level,
    output logic [15:0] ppmu_current_level,
    output ppmu_irange_t ppmu_current_range,
    output logic [15:0] ppmu_vclamp_h,
    output logic [15:0] ppmu_vclamp_l,
    output logic [31:0] ppmu_aperture_time,
    input  logic [31:0] ppmu_measure_result,

    // Static pin state (software-driven)
    output logic [1:0]  static_state,     // 00=low, 01=high, 10=Hi-Z
    output logic        static_state_wr,  // Pulse when static state written

    // Calibration offsets
    output logic signed [15:0] cal_offset_vih,
    output logic signed [15:0] cal_offset_vil,
    output logic signed [15:0] cal_offset_vt,
    output logic signed [15:0] cal_gain_i,
    output logic signed [15:0] cal_offset_i,

    // OVD status input
    input  logic [1:0]  ovd_status,

    // Level update flag (pulses when any level changes)
    output logic        levels_updated
);

    // -----------------------------------------------------------
    // Register storage
    // -----------------------------------------------------------
    logic [31:0] ch_ctrl_r;
    logic [31:0] term_mode_r;
    logic [31:0] drive_fmt_r;
    logic [31:0] edge_mult_r;
    logic [31:0] vih_r, vil_r, vterm_r, voh_r, vol_r;
    logic [31:0] ioh_r, iol_r, vcom_r;
    logic [31:0] ppmu_ctrl_r, ppmu_vlevel_r, ppmu_ilevel_r;
    logic [31:0] ppmu_irange_r, ppmu_vclh_r, ppmu_vcll_r;
    logic [31:0] ppmu_apert_r;
    logic [31:0] static_r;
    logic [31:0] cal_off_vih_r, cal_off_vil_r, cal_off_vt_r;
    logic [31:0] cal_gain_i_r, cal_off_i_r;

    // Output mappings
    assign pin_function       = pin_func_t'(ch_ctrl_r[1:0]);
    assign termination_mode   = term_mode_t'(term_mode_r[1:0]);
    assign drive_format       = drive_fmt_t'(drive_fmt_r[1:0]);
    assign edge_multiplier    = edge_mult_r[1:0];

    assign level_vih  = vih_r[15:0];
    assign level_vil  = vil_r[15:0];
    assign level_vterm = vterm_r[15:0];
    assign level_voh  = voh_r[15:0];
    assign level_vol  = vol_r[15:0];
    assign level_ioh  = ioh_r[15:0];
    assign level_iol  = iol_r[15:0];
    assign level_vcom = vcom_r[15:0];

    assign ppmu_mode          = ppmu_mode_t'(ppmu_ctrl_r[2:0]);
    assign ppmu_voltage_level = ppmu_vlevel_r[15:0];
    assign ppmu_current_level = ppmu_ilevel_r[15:0];
    assign ppmu_current_range = ppmu_irange_t'(ppmu_irange_r[2:0]);
    assign ppmu_vclamp_h      = ppmu_vclh_r[15:0];
    assign ppmu_vclamp_l      = ppmu_vcll_r[15:0];
    assign ppmu_aperture_time = ppmu_apert_r;

    assign static_state  = static_r[1:0];

    assign cal_offset_vih = cal_off_vih_r[15:0];
    assign cal_offset_vil = cal_off_vil_r[15:0];
    assign cal_offset_vt  = cal_off_vt_r[15:0];
    assign cal_gain_i     = cal_gain_i_r[15:0];
    assign cal_offset_i   = cal_off_i_r[15:0];

    // -----------------------------------------------------------
    // Write logic
    // -----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch_ctrl_r      <= '0;
            term_mode_r    <= '0;
            drive_fmt_r    <= '0;
            edge_mult_r    <= '0;
            vih_r          <= '0;
            vil_r          <= '0;
            vterm_r        <= '0;
            voh_r          <= '0;
            vol_r          <= '0;
            ioh_r          <= '0;
            iol_r          <= '0;
            vcom_r         <= '0;
            ppmu_ctrl_r    <= '0;
            ppmu_vlevel_r  <= '0;
            ppmu_ilevel_r  <= '0;
            ppmu_irange_r  <= '0;
            ppmu_vclh_r    <= '0;
            ppmu_vcll_r    <= '0;
            ppmu_apert_r   <= 32'd4;  // Default 4μs
            static_r       <= '0;
            cal_off_vih_r  <= '0;
            cal_off_vil_r  <= '0;
            cal_off_vt_r   <= '0;
            cal_gain_i_r   <= 32'h0001_0000; // Gain = 1.0 (fixed point)
            cal_off_i_r    <= '0;
            levels_updated <= 1'b0;
            static_state_wr <= 1'b0;
        end else begin
            levels_updated  <= 1'b0;
            static_state_wr <= 1'b0;

            if (reg_wr_en) begin
                case (reg_offset)
                    CH_CTRL:        ch_ctrl_r     <= reg_wr_data;
                    CH_VIH:         begin vih_r   <= reg_wr_data; levels_updated <= 1'b1; end
                    CH_VIL:         begin vil_r   <= reg_wr_data; levels_updated <= 1'b1; end
                    CH_VTERM:       begin vterm_r <= reg_wr_data; levels_updated <= 1'b1; end
                    CH_VOH:         begin voh_r   <= reg_wr_data; levels_updated <= 1'b1; end
                    CH_VOL:         begin vol_r   <= reg_wr_data; levels_updated <= 1'b1; end
                    CH_IOH:         begin ioh_r   <= reg_wr_data; levels_updated <= 1'b1; end
                    CH_IOL:         begin iol_r   <= reg_wr_data; levels_updated <= 1'b1; end
                    CH_VCOM:        begin vcom_r  <= reg_wr_data; levels_updated <= 1'b1; end
                    CH_TERM_MODE:   term_mode_r   <= reg_wr_data;
                    CH_DRIVE_FMT:   drive_fmt_r   <= reg_wr_data;
                    CH_PPMU_CTRL:   ppmu_ctrl_r   <= reg_wr_data;
                    CH_PPMU_VLEVEL: ppmu_vlevel_r <= reg_wr_data;
                    CH_PPMU_ILEVEL: ppmu_ilevel_r <= reg_wr_data;
                    CH_PPMU_IRANGE: ppmu_irange_r <= reg_wr_data;
                    CH_PPMU_VCLH:   ppmu_vclh_r   <= reg_wr_data;
                    CH_PPMU_VCLL:   ppmu_vcll_r   <= reg_wr_data;
                    CH_PPMU_APERT:  ppmu_apert_r  <= reg_wr_data;
                    CH_STATIC_STATE: begin static_r <= reg_wr_data; static_state_wr <= 1'b1; end
                    CH_EDGE_MULT:   edge_mult_r   <= reg_wr_data;
                    CH_CAL_OFF_VIH: cal_off_vih_r <= reg_wr_data;
                    CH_CAL_OFF_VIL: cal_off_vil_r <= reg_wr_data;
                    CH_CAL_OFF_VT:  cal_off_vt_r  <= reg_wr_data;
                    CH_CAL_GAIN_I:  cal_gain_i_r  <= reg_wr_data;
                    CH_CAL_OFF_I:   cal_off_i_r   <= reg_wr_data;
                    default: ;
                endcase
            end
        end
    end

    // -----------------------------------------------------------
    // Read logic
    // -----------------------------------------------------------
    always_comb begin
        reg_rd_data = '0;
        case (reg_rd_offset)
            CH_CTRL:        reg_rd_data = ch_ctrl_r;
            CH_STATUS:      reg_rd_data = {28'b0, CHANNEL_ID[3:0]};
            CH_VIH:         reg_rd_data = vih_r;
            CH_VIL:         reg_rd_data = vil_r;
            CH_VTERM:       reg_rd_data = vterm_r;
            CH_VOH:         reg_rd_data = voh_r;
            CH_VOL:         reg_rd_data = vol_r;
            CH_IOH:         reg_rd_data = ioh_r;
            CH_IOL:         reg_rd_data = iol_r;
            CH_VCOM:        reg_rd_data = vcom_r;
            CH_TERM_MODE:   reg_rd_data = term_mode_r;
            CH_DRIVE_FMT:   reg_rd_data = drive_fmt_r;
            CH_PPMU_CTRL:   reg_rd_data = ppmu_ctrl_r;
            CH_PPMU_VLEVEL: reg_rd_data = ppmu_vlevel_r;
            CH_PPMU_ILEVEL: reg_rd_data = ppmu_ilevel_r;
            CH_PPMU_IRANGE: reg_rd_data = ppmu_irange_r;
            CH_PPMU_VCLH:   reg_rd_data = ppmu_vclh_r;
            CH_PPMU_VCLL:   reg_rd_data = ppmu_vcll_r;
            CH_PPMU_APERT:  reg_rd_data = ppmu_apert_r;
            CH_PPMU_MEAS:   reg_rd_data = ppmu_measure_result;
            CH_OVD_STATUS:  reg_rd_data = {30'b0, ovd_status};
            CH_STATIC_STATE:reg_rd_data = static_r;
            CH_EDGE_MULT:   reg_rd_data = edge_mult_r;
            CH_CAL_OFF_VIH: reg_rd_data = cal_off_vih_r;
            CH_CAL_OFF_VIL: reg_rd_data = cal_off_vil_r;
            CH_CAL_OFF_VT:  reg_rd_data = cal_off_vt_r;
            CH_CAL_GAIN_I:  reg_rd_data = cal_gain_i_r;
            CH_CAL_OFF_I:   reg_rd_data = cal_off_i_r;
            default:        reg_rd_data = '0;
        endcase
    end

endmodule
