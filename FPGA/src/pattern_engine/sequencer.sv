// Pattern Sequencer
// Fetches vectors from memory, decodes opcodes, and outputs per-channel pin states
// This is the core execution engine of the pattern card

module sequencer
    import ate_pkg::*;
(
    input  logic        clk,          // Pattern clock (100MHz)
    input  logic        rst_n,

    // Control
    input  logic        pat_start,    // Start pattern execution
    input  logic        pat_stop,     // Graceful stop
    input  logic        pat_abort,    // Immediate abort
    output logic        pat_running,
    output logic        pat_done,
    output logic        pat_fail,

    // Pattern config
    input  logic [VECTOR_ADDR_W-1:0] start_addr,
    input  logic [VECTOR_ADDR_W-1:0] pat_length,
    input  logic [NUM_CHANNELS-1:0]  site_enable,

    // Vector memory read interface (to DDR3 controller)
    output logic                       vmem_rd_req,
    output logic [VECTOR_ADDR_W-1:0]  vmem_rd_addr,
    input  logic [VECTOR_WIDTH-1:0]   vmem_rd_data,
    input  logic                       vmem_rd_valid,

    // Per-channel outputs (active each vector cycle)
    output logic                       vec_valid,      // New vector cycle
    output logic [4:0]                vec_timeset,    // TimeSet ID for this vector
    output pin_state_t                vec_pin_state [NUM_CHANNELS], // Per-channel state
    output logic [NUM_CHANNELS-1:0]   vec_compare_en, // Compare enable mask

    // Compare results input (from channel controllers)
    input  logic [NUM_CHANNELS-1:0]   compare_pass,   // 1=pass per channel
    input  logic                       compare_valid,

    // Sequencer flags and registers
    output logic [3:0]                seq_flags,
    output logic [31:0]               seq_registers [4],

    // History RAM write interface
    output logic                       hram_wr_en,
    output logic [12:0]               hram_wr_addr,
    output logic [VECTOR_ADDR_W-1:0]  hram_wr_cycle,   // Cycle number of failure
    output logic [NUM_CHANNELS-1:0]   hram_wr_fail_mask // Which channels failed
);

    // ============================================================
    // Vector format decode
    // ============================================================
    // [127:112] Opcode (16 bits)
    // [111:96]  Operand (16 bits)
    // [95:91]   TimeSet ID (5 bits)
    // [90:88]   Reserved
    // [87:56]   Channel 15~0 pin states (2 bits × 16 = 32 bits)
    // [55:32]   Reserved / flags
    // [31:0]    Loop count / Jump address

    logic [15:0] vec_opcode;
    logic [15:0] vec_operand;
    logic [4:0]  vec_ts_id;
    logic [31:0] vec_pin_data;
    logic [31:0] vec_aux_data;

    assign vec_opcode   = vmem_rd_data[127:112];
    assign vec_operand  = vmem_rd_data[111:96];
    assign vec_ts_id    = vmem_rd_data[95:91];
    assign vec_pin_data = vmem_rd_data[87:56];
    assign vec_aux_data = vmem_rd_data[31:0];

    // Opcode definitions
    localparam OP_NOP        = 16'h0000;
    localparam OP_VECTOR     = 16'h0001;  // Normal vector (drive/compare)
    localparam OP_REPEAT     = 16'h0010;  // Repeat N times
    localparam OP_JUMP       = 16'h0020;  // Unconditional jump
    localparam OP_JUMP_IF    = 16'h0021;  // Conditional jump
    localparam OP_SET_LOOP   = 16'h0030;  // Set loop counter
    localparam OP_END_LOOP   = 16'h0031;  // End loop (decrement & branch)
    localparam OP_EXIT_LOOP  = 16'h0032;  // Exit loop early
    localparam OP_CALL       = 16'h0040;  // Call subroutine
    localparam OP_RETURN     = 16'h0041;  // Return from subroutine
    localparam OP_HALT       = 16'h00FF;  // Stop execution
    localparam OP_MATCH      = 16'h0050;  // Wait for match condition
    localparam OP_SET_FLAG   = 16'h0060;  // Set sequencer flag
    localparam OP_CLR_FLAG   = 16'h0061;  // Clear sequencer flag
    localparam OP_WRITE_REG  = 16'h0062;  // Write sequencer register
    localparam OP_CAP_START  = 16'h0070;  // Start capture
    localparam OP_CAPTURE    = 16'h0071;  // Capture data
    localparam OP_CAP_STOP   = 16'h0072;  // Stop capture
    localparam OP_SRC_START  = 16'h0080;  // Start source
    localparam OP_SOURCE     = 16'h0081;  // Source data
    localparam OP_KEEP_ALIVE = 16'h0090;  // Keep-alive (no-op vector)

    // ============================================================
    // Execution state machine
    // ============================================================
    typedef enum logic [3:0] {
        SEQ_IDLE,
        SEQ_FETCH,
        SEQ_WAIT_DATA,
        SEQ_DECODE,
        SEQ_EXECUTE,
        SEQ_WAIT_COMPARE,
        SEQ_REPEAT_WAIT,
        SEQ_MATCH_WAIT,
        SEQ_DONE,
        SEQ_FAIL
    } seq_state_t;

    seq_state_t state;

    // Program counter
    logic [VECTOR_ADDR_W-1:0] pc;
    logic [VECTOR_ADDR_W-1:0] cycle_count;

    // Loop stack (8 levels)
    logic [VECTOR_ADDR_W-1:0] loop_start [8];
    logic [31:0]              loop_count [8];
    logic [2:0]               loop_sp;

    // Call stack (8 levels)
    logic [VECTOR_ADDR_W-1:0] call_stack [8];
    logic [2:0]               call_sp;

    // Repeat counter
    logic [31:0] repeat_count;

    // Fail tracking
    logic any_fail;
    logic [NUM_CHANNELS-1:0] fail_accum;

    // History RAM write pointer
    logic [12:0] hram_ptr;

    // Match pipeline counter
    logic [6:0] match_pipe_cnt;

    // ============================================================
    // Main state machine
    // ============================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= SEQ_IDLE;
            pc            <= '0;
            cycle_count   <= '0;
            loop_sp       <= '0;
            call_sp       <= '0;
            repeat_count  <= '0;
            pat_running   <= 1'b0;
            pat_done      <= 1'b0;
            pat_fail      <= 1'b0;
            vmem_rd_req   <= 1'b0;
            vmem_rd_addr  <= '0;
            vec_valid     <= 1'b0;
            vec_timeset   <= '0;
            vec_compare_en <= '0;
            any_fail      <= 1'b0;
            fail_accum    <= '0;
            hram_wr_en    <= 1'b0;
            hram_ptr      <= '0;
            seq_flags     <= '0;
            match_pipe_cnt <= '0;

            for (int i = 0; i < NUM_CHANNELS; i++)
                vec_pin_state[i] <= PS_HIZ;
            for (int i = 0; i < 4; i++)
                seq_registers[i] <= '0;
            for (int i = 0; i < 8; i++) begin
                loop_start[i] <= '0;
                loop_count[i] <= '0;
                call_stack[i] <= '0;
            end
        end else begin
            // Default: deassert pulses
            vec_valid    <= 1'b0;
            vmem_rd_req  <= 1'b0;
            hram_wr_en   <= 1'b0;
            pat_done     <= 1'b0;

            // Abort overrides everything
            if (pat_abort) begin
                state       <= SEQ_IDLE;
                pat_running <= 1'b0;
                pat_fail    <= any_fail;
            end

            case (state)
                // ----------------------------------------
                SEQ_IDLE: begin
                    pat_running <= 1'b0;
                    if (pat_start) begin
                        pc          <= start_addr;
                        cycle_count <= '0;
                        loop_sp     <= '0;
                        call_sp     <= '0;
                        any_fail    <= 1'b0;
                        fail_accum  <= '0;
                        hram_ptr    <= '0;
                        pat_running <= 1'b1;
                        pat_fail    <= 1'b0;
                        state       <= SEQ_FETCH;
                    end
                end

                // ----------------------------------------
                SEQ_FETCH: begin
                    if (pat_stop) begin
                        state <= SEQ_DONE;
                    end else begin
                        vmem_rd_req  <= 1'b1;
                        vmem_rd_addr <= pc;
                        state        <= SEQ_WAIT_DATA;
                    end
                end

                // ----------------------------------------
                SEQ_WAIT_DATA: begin
                    if (vmem_rd_valid) begin
                        state <= SEQ_DECODE;
                    end
                end

                // ----------------------------------------
                SEQ_DECODE: begin
                    case (vec_opcode)
                        OP_HALT: begin
                            state <= SEQ_DONE;
                        end

                        OP_NOP, OP_KEEP_ALIVE: begin
                            pc    <= pc + 1'b1;
                            state <= SEQ_FETCH;
                        end

                        OP_VECTOR: begin
                            state <= SEQ_EXECUTE;
                        end

                        OP_REPEAT: begin
                            repeat_count <= vec_aux_data;
                            state        <= SEQ_EXECUTE;
                        end

                        OP_JUMP: begin
                            pc    <= vec_aux_data[VECTOR_ADDR_W-1:0];
                            state <= SEQ_FETCH;
                        end

                        OP_JUMP_IF: begin
                            if (seq_flags[vec_operand[1:0]]) begin
                                pc <= vec_aux_data[VECTOR_ADDR_W-1:0];
                            end else begin
                                pc <= pc + 1'b1;
                            end
                            state <= SEQ_FETCH;
                        end

                        OP_SET_LOOP: begin
                            loop_start[loop_sp] <= pc + 1'b1;
                            loop_count[loop_sp] <= vec_aux_data;
                            loop_sp             <= loop_sp + 1'b1;
                            pc                  <= pc + 1'b1;
                            state               <= SEQ_FETCH;
                        end

                        OP_END_LOOP: begin
                            if (loop_sp > 0) begin
                                if (loop_count[loop_sp-1] > 1) begin
                                    loop_count[loop_sp-1] <= loop_count[loop_sp-1] - 1'b1;
                                    pc    <= loop_start[loop_sp-1];
                                end else begin
                                    loop_sp <= loop_sp - 1'b1;
                                    pc      <= pc + 1'b1;
                                end
                            end else begin
                                pc <= pc + 1'b1;
                            end
                            state <= SEQ_FETCH;
                        end

                        OP_EXIT_LOOP: begin
                            if (loop_sp > 0)
                                loop_sp <= loop_sp - 1'b1;
                            pc    <= pc + 1'b1;
                            state <= SEQ_FETCH;
                        end

                        OP_CALL: begin
                            call_stack[call_sp] <= pc + 1'b1;
                            call_sp             <= call_sp + 1'b1;
                            pc                  <= vec_aux_data[VECTOR_ADDR_W-1:0];
                            state               <= SEQ_FETCH;
                        end

                        OP_RETURN: begin
                            if (call_sp > 0) begin
                                call_sp <= call_sp - 1'b1;
                                pc      <= call_stack[call_sp-1];
                            end else begin
                                pc <= pc + 1'b1;
                            end
                            state <= SEQ_FETCH;
                        end

                        OP_MATCH: begin
                            match_pipe_cnt <= '0;
                            state          <= SEQ_MATCH_WAIT;
                        end

                        OP_SET_FLAG: begin
                            seq_flags[vec_operand[1:0]] <= 1'b1;
                            pc    <= pc + 1'b1;
                            state <= SEQ_FETCH;
                        end

                        OP_CLR_FLAG: begin
                            seq_flags[vec_operand[1:0]] <= 1'b0;
                            pc    <= pc + 1'b1;
                            state <= SEQ_FETCH;
                        end

                        OP_WRITE_REG: begin
                            seq_registers[vec_operand[1:0]] <= vec_aux_data;
                            pc    <= pc + 1'b1;
                            state <= SEQ_FETCH;
                        end

                        default: begin
                            // Unknown opcode: treat as NOP
                            pc    <= pc + 1'b1;
                            state <= SEQ_FETCH;
                        end
                    endcase
                end

                // ----------------------------------------
                SEQ_EXECUTE: begin
                    // Output pin states to channel controllers
                    vec_valid   <= 1'b1;
                    vec_timeset <= vec_ts_id;

                    // Decode per-channel pin states
                    for (int i = 0; i < NUM_CHANNELS; i++) begin
                        vec_pin_state[i] <= pin_state_t'(vec_pin_data[i*2 +: 2]);
                        // Compare enable: active for Compare state on enabled sites
                        vec_compare_en[i] <= (vec_pin_data[i*2 +: 2] == PS_COMPARE) && site_enable[i];
                    end

                    cycle_count <= cycle_count + 1'b1;
                    state       <= SEQ_WAIT_COMPARE;
                end

                // ----------------------------------------
                SEQ_WAIT_COMPARE: begin
                    if (compare_valid) begin
                        // Check for failures
                        logic [NUM_CHANNELS-1:0] fail_this;
                        fail_this = vec_compare_en & ~compare_pass;

                        if (|fail_this) begin
                            any_fail   <= 1'b1;
                            fail_accum <= fail_accum | fail_this;

                            // Write to History RAM
                            if (hram_ptr < 13'h1FFF) begin
                                hram_wr_en        <= 1'b1;
                                hram_wr_addr      <= hram_ptr;
                                hram_wr_cycle     <= cycle_count;
                                hram_wr_fail_mask <= fail_this;
                                hram_ptr          <= hram_ptr + 1'b1;
                            end
                        end

                        // Handle repeat
                        if (vec_opcode == OP_REPEAT && repeat_count > 1) begin
                            repeat_count <= repeat_count - 1'b1;
                            state        <= SEQ_EXECUTE;
                        end else begin
                            pc    <= pc + 1'b1;

                            // Check if we've exceeded pattern length
                            if (cycle_count >= pat_length) begin
                                state <= SEQ_DONE;
                            end else begin
                                state <= SEQ_FETCH;
                            end
                        end
                    end
                end

                // ----------------------------------------
                SEQ_MATCH_WAIT: begin
                    // Wait for all channels to match (80 cycle pipeline)
                    match_pipe_cnt <= match_pipe_cnt + 1'b1;
                    if ((&compare_pass & vec_compare_en) == vec_compare_en) begin
                        pc    <= pc + 1'b1;
                        state <= SEQ_FETCH;
                    end else if (match_pipe_cnt >= 7'd80) begin
                        // Timeout: match failed
                        any_fail <= 1'b1;
                        pc       <= pc + 1'b1;
                        state    <= SEQ_FETCH;
                    end
                end

                // ----------------------------------------
                SEQ_DONE: begin
                    pat_running <= 1'b0;
                    pat_done    <= 1'b1;
                    pat_fail    <= any_fail;
                    state       <= SEQ_IDLE;
                end

                SEQ_FAIL: begin
                    pat_running <= 1'b0;
                    pat_done    <= 1'b1;
                    pat_fail    <= 1'b1;
                    state       <= SEQ_IDLE;
                end

                default: state <= SEQ_IDLE;
            endcase
        end
    end

endmodule
