// PXI Trigger Bus Interface
// Manages 7 PXI trigger lines + DSTAR differential triggers
// Supports start trigger, conditional trigger, output trigger, and cross-board sync

module trigger_intf
    import ate_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,

    // PXI trigger lines (directly from/to PXIe backplane)
    input  logic [6:0]  pxi_trig_in,
    output logic [6:0]  pxi_trig_out,
    output logic [6:0]  pxi_trig_oe,    // Output enable per line

    // DSTAR differential triggers
    input  logic        dstarb_in,       // DSTARB input (after IBUFDS)
    output logic        dstarc_out,      // DSTARC output (before OBUFDS)

    // PXIe_CLK100 synchronized
    input  logic        pxie_clk100,

    // Register interface
    input  logic        reg_wr_en,
    input  logic [7:0]  reg_offset,
    input  logic [31:0] reg_wr_data,
    output logic [31:0] reg_rd_data,

    // Pattern control interface
    output logic        start_trigger,    // Rising edge = start pattern
    input  logic        pat_running,
    input  logic        pat_done,
    input  logic        pat_fail,

    // Sequencer signal interface
    input  logic        seq_set_signal,
    input  logic        seq_pulse_signal,
    input  logic        seq_clear_signal,
    input  logic [2:0]  seq_signal_id,
    input  logic        seq_reset_trigger
);

    // ================================================================
    // Configuration Registers
    // ================================================================
    // 0x00: TRIG_CTRL
    //   [2:0]   start_source: 0=software, 1=PXI_TRIG0, ..., 7=DSTARB
    //   [4:3]   start_edge: 0=rising, 1=falling, 2=level_high, 3=level_low
    //   [8]     arm: write 1 to arm trigger
    //   [16]    sw_trigger: write 1 for software start
    // 0x04: TRIG_STATUS
    //   [0]     armed
    //   [1]     triggered
    //   [6:0]   pxi_trig_in current state
    // 0x08: TRIG_OUTPUT_MAP
    //   [2:0]   done_output_line: which PXI line to assert on pat_done
    //   [5:3]   fail_output_line: which PXI line to assert on pat_fail
    //   [8]     done_output_en
    //   [9]     fail_output_en
    // 0x0C: TRIG_LINE_DIR
    //   [6:0]   direction per line: 0=input, 1=output
    // 0x10: TRIG_LINE_FORCE
    //   [6:0]   force output value (when direction=output)

    logic [31:0] trig_ctrl_r;
    logic [31:0] trig_output_map_r;
    logic [31:0] trig_line_dir_r;
    logic [31:0] trig_line_force_r;

    logic [2:0]  start_source;
    logic [1:0]  start_edge;
    logic        arm_request;
    logic        sw_trigger;

    assign start_source = trig_ctrl_r[2:0];
    assign start_edge   = trig_ctrl_r[4:3];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            trig_ctrl_r       <= '0;
            trig_output_map_r <= '0;
            trig_line_dir_r   <= '0;
            trig_line_force_r <= '0;
            arm_request       <= 1'b0;
            sw_trigger        <= 1'b0;
        end else begin
            arm_request <= 1'b0;
            sw_trigger  <= 1'b0;

            if (reg_wr_en) begin
                case (reg_offset)
                    8'h00: begin
                        trig_ctrl_r <= reg_wr_data;
                        arm_request <= reg_wr_data[8];
                        sw_trigger  <= reg_wr_data[16];
                    end
                    8'h08: trig_output_map_r <= reg_wr_data;
                    8'h0C: trig_line_dir_r   <= reg_wr_data;
                    8'h10: trig_line_force_r <= reg_wr_data;
                    default: ;
                endcase
            end
        end
    end

    // Read mux
    logic armed_r, triggered_r;

    always_comb begin
        case (reg_offset)
            8'h00: reg_rd_data = trig_ctrl_r;
            8'h04: reg_rd_data = {16'b0, pxi_trig_in, 7'b0, triggered_r, armed_r};
            8'h08: reg_rd_data = trig_output_map_r;
            8'h0C: reg_rd_data = trig_line_dir_r;
            8'h10: reg_rd_data = trig_line_force_r;
            default: reg_rd_data = '0;
        endcase
    end

    // ================================================================
    // Trigger input synchronization
    // ================================================================
    logic [6:0] trig_in_sync, trig_in_d;
    logic       dstarb_sync, dstarb_d;

    always_ff @(posedge clk) begin
        trig_in_sync <= pxi_trig_in;
        trig_in_d    <= trig_in_sync;
        dstarb_sync  <= dstarb_in;
        dstarb_d     <= dstarb_sync;
    end

    // ================================================================
    // Start trigger detection
    // ================================================================
    logic selected_input, selected_input_d;
    logic trigger_event;

    always_comb begin
        case (start_source)
            3'd0: selected_input = sw_trigger;
            3'd1: selected_input = trig_in_sync[0];
            3'd2: selected_input = trig_in_sync[1];
            3'd3: selected_input = trig_in_sync[2];
            3'd4: selected_input = trig_in_sync[3];
            3'd5: selected_input = trig_in_sync[4];
            3'd6: selected_input = trig_in_sync[5];
            3'd7: selected_input = dstarb_sync;
            default: selected_input = 1'b0;
        endcase
    end

    always_ff @(posedge clk) selected_input_d <= selected_input;

    always_comb begin
        case (start_edge)
            2'd0: trigger_event = selected_input & ~selected_input_d;   // Rising
            2'd1: trigger_event = ~selected_input & selected_input_d;   // Falling
            2'd2: trigger_event = selected_input;                        // Level high
            2'd3: trigger_event = ~selected_input;                       // Level low
            default: trigger_event = 1'b0;
        endcase
    end

    // Arm and trigger state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            armed_r     <= 1'b0;
            triggered_r <= 1'b0;
        end else begin
            if (arm_request) begin
                armed_r     <= 1'b1;
                triggered_r <= 1'b0;
            end

            if (armed_r && trigger_event) begin
                armed_r     <= 1'b0;
                triggered_r <= 1'b1;
            end

            if (seq_reset_trigger)
                triggered_r <= 1'b0;
        end
    end

    assign start_trigger = armed_r && trigger_event;

    // ================================================================
    // Trigger output control
    // ================================================================
    logic [6:0] trig_output_val;

    always_comb begin
        trig_output_val = trig_line_force_r[6:0];

        // Auto-assert lines on pattern done/fail
        if (trig_output_map_r[8] && pat_done)
            trig_output_val[trig_output_map_r[2:0]] = 1'b1;
        if (trig_output_map_r[9] && pat_fail)
            trig_output_val[trig_output_map_r[5:3]] = 1'b1;

        // Sequencer signal output
        // Map sequencer signals to trigger lines (simplified)
    end

    assign pxi_trig_out = trig_output_val;
    assign pxi_trig_oe  = trig_line_dir_r[6:0];

    // DSTARC output: pattern running indicator
    assign dstarc_out = pat_running;

endmodule
