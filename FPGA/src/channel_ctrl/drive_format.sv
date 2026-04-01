`timescale 1ns / 1ps
// Drive Format Logic
// Generates the actual output pin state based on drive format (NR/RL/RH/SBC)
// and timing engine edge events

module drive_format
    import ate_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,

    // Configuration
    input  drive_fmt_t  format,
    input  term_mode_t  termination,
    input  pin_func_t   pin_function,

    // Pin state from sequencer
    input  pin_state_t  pin_state,
    input  logic        vec_valid,     // New vector cycle

    // Timing edge events
    input  logic        evt_drive_on,
    input  logic        evt_drive_data,
    input  logic        evt_drive_return,
    input  logic        evt_drive_off,
    input  logic        evt_compare_strobe,

    // Static state (software-driven)
    input  logic [1:0]  static_state,
    input  logic        static_state_wr,

    // Output
    output logic        drv_enable,    // Driver output enable
    output logic        drv_data,      // Driver data (0 or 1)
    output logic        comp_sample,   // Compare strobe pulse
    output logic        comp_enable,   // Compare active
    output logic        load_active    // Active load enabled
);

    // Latched pin state for current vector
    pin_state_t cur_state;
    logic       is_drive;
    logic       is_compare;
    logic       drive_value;    // 0 or 1 for drive states
    logic       return_value;   // Value during return phase

    always_comb begin
        is_drive   = (cur_state == PS_DRIVE0) || (cur_state == PS_DRIVE1);
        is_compare = (cur_state == PS_COMPARE);
        drive_value = (cur_state == PS_DRIVE1);

        case (format)
            DRV_NR:  return_value = drive_value;  // Non-Return: hold
            DRV_RL:  return_value = 1'b0;         // Return Low
            DRV_RH:  return_value = 1'b1;         // Return High
            DRV_SBC: return_value = ~drive_value;  // Surround by Complement
            default: return_value = drive_value;
        endcase
    end

    // -----------------------------------------------------------
    // Drive state machine
    // -----------------------------------------------------------
    typedef enum logic [2:0] {
        DRV_IDLE,
        DRV_PREDATA,    // SBC: output complement before data
        DRV_ON,         // Driver enabled, waiting for data edge
        DRV_DATA,       // Driving data value
        DRV_RETURN,     // Return phase
        DRV_OFF,        // Driver off (Hi-Z or terminated)
        DRV_STATIC      // Static software-driven state
    } drv_state_t;

    drv_state_t drv_fsm;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            drv_fsm     <= DRV_IDLE;
            drv_enable  <= 1'b0;
            drv_data    <= 1'b0;
            comp_sample <= 1'b0;
            comp_enable <= 1'b0;
            load_active <= 1'b0;
            cur_state   <= PS_HIZ;
        end else begin
            comp_sample <= 1'b0;

            // Static state write override
            if (static_state_wr && pin_function == PIN_DIGITAL) begin
                drv_fsm    <= DRV_STATIC;
                drv_enable <= (static_state != 2'b10); // Not Hi-Z
                drv_data   <= static_state[0];
            end

            // Disconnect mode
            if (pin_function == PIN_DISCONNECT || pin_function == PIN_OFF) begin
                drv_enable  <= 1'b0;
                comp_enable <= 1'b0;
                load_active <= 1'b0;
                drv_fsm     <= DRV_IDLE;
            end

            // PPMU mode
            if (pin_function == PIN_PPMU) begin
                drv_enable  <= 1'b0;
                comp_enable <= 1'b0;
                load_active <= 1'b0;
                drv_fsm     <= DRV_IDLE;
            end

            // Digital mode - pattern driven
            if (pin_function == PIN_DIGITAL) begin
                // New vector: latch state
                if (vec_valid) begin
                    cur_state <= pin_state;

                    if (pin_state == PS_DRIVE0 || pin_state == PS_DRIVE1) begin
                        // Drive state
                        comp_enable <= 1'b0;
                        load_active <= 1'b0;
                        if (format == DRV_SBC) begin
                            // SBC: start with complement
                            drv_enable <= 1'b1;
                            drv_data   <= ~(pin_state == PS_DRIVE1);
                            drv_fsm    <= DRV_PREDATA;
                        end else begin
                            drv_fsm <= DRV_ON;
                        end
                    end else if (pin_state == PS_COMPARE) begin
                        // Compare state: driver follows termination mode
                        comp_enable <= 1'b1;
                        case (termination)
                            TERM_HIZ: begin
                                drv_enable  <= 1'b0;
                                load_active <= 1'b0;
                            end
                            TERM_VTERM: begin
                                drv_enable  <= 1'b1; // Drive through 50R to VTERM
                                drv_data    <= 1'b0; // VTERM level set via SPI
                                load_active <= 1'b0;
                            end
                            TERM_ACTIVE: begin
                                drv_enable  <= 1'b0;
                                load_active <= 1'b1;
                            end
                        endcase
                        drv_fsm <= DRV_OFF;
                    end else begin
                        // Hi-Z state
                        drv_enable  <= 1'b0;
                        comp_enable <= 1'b0;
                        load_active <= (termination == TERM_ACTIVE);
                        drv_fsm     <= DRV_OFF;
                    end
                end

                // Edge event processing
                case (drv_fsm)
                    DRV_ON: begin
                        if (evt_drive_on) begin
                            drv_enable <= 1'b1;
                            drv_data   <= return_value; // Start with return value
                        end
                        if (evt_drive_data) begin
                            drv_data <= drive_value;
                            drv_fsm  <= DRV_DATA;
                        end
                    end

                    DRV_PREDATA: begin
                        // SBC: complement already being driven
                        if (evt_drive_data) begin
                            drv_data <= drive_value;
                            drv_fsm  <= DRV_DATA;
                        end
                    end

                    DRV_DATA: begin
                        if (evt_drive_return) begin
                            drv_data <= return_value;
                            drv_fsm  <= DRV_RETURN;
                        end
                    end

                    DRV_RETURN: begin
                        if (evt_drive_off) begin
                            drv_enable <= 1'b0;
                            drv_fsm    <= DRV_OFF;
                        end
                    end

                    DRV_OFF: begin
                        // Wait for next vector
                    end

                    DRV_STATIC: begin
                        // Hold static state until new vector or another write
                    end

                    default: ;
                endcase

                // Compare strobe (independent of drive state)
                if (evt_compare_strobe && comp_enable) begin
                    comp_sample <= 1'b1;
                end
            end
        end
    end

endmodule
