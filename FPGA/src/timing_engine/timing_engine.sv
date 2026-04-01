// Timing Engine
// Generates timed drive/compare edges based on TimeSet configuration
// Supports 31 TimeSets, each with 8 programmable edges
// Edge resolution: 39.0625 ps (using ODELAYE3 in actual implementation)

module timing_engine
    import ate_pkg::*;
(
    input  logic        clk,          // Pattern clock (100~200MHz)
    input  logic        rst_n,

    // Configuration (from registers)
    input  logic [31:0] vector_period,     // Vector period in clock cycles
    input  logic [31:0] vector_period_fine, // Sub-cycle fine adjustment

    // TimeSet programming interface
    input  logic        ts_wr_en,
    input  logic [4:0]  ts_wr_id,          // TimeSet ID (0~30)
    input  logic [2:0]  ts_wr_edge_sel,    // Edge index (0~7)
    input  logic [31:0] ts_wr_value,       // Edge position (ps from vector start)

    // Sequencer interface
    input  logic        vec_valid,
    input  logic [4:0]  vec_timeset,

    // Per-channel drive format
    input  drive_fmt_t  ch_drive_fmt [NUM_CHANNELS],
    input  pin_state_t  ch_pin_state [NUM_CHANNELS],
    input  logic [1:0]  ch_edge_mult [NUM_CHANNELS],

    // Timed output events to channel I/O
    output logic        cycle_start,       // Start of vector cycle
    output logic        cycle_end,         // End of vector cycle
    output logic        evt_drive_on,      // Drive enable edge
    output logic        evt_drive_data,    // Data edge
    output logic        evt_drive_return,  // Return edge
    output logic        evt_drive_off,     // Drive disable edge
    output logic        evt_compare_strobe, // Compare sampling edge
    output logic        evt_drive_data2,   // 2x mode second data edge
    output logic        evt_drive_return2, // 2x mode second return edge
    output logic        evt_compare_strobe2 // 2x mode second strobe
);

    // -----------------------------------------------------------
    // TimeSet storage: 31 sets × 8 edges
    // -----------------------------------------------------------
    // Edge indices:
    //   0 = drive_on
    //   1 = drive_data
    //   2 = drive_return
    //   3 = drive_off
    //   4 = compare_strobe
    //   5 = drive_data2 (2x mode)
    //   6 = drive_return2 (2x mode)
    //   7 = compare_strobe2 (2x mode)

    logic [31:0] timeset_edges [NUM_TIMESETS][8];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int ts = 0; ts < NUM_TIMESETS; ts++)
                for (int e = 0; e < 8; e++)
                    timeset_edges[ts][e] <= '0;
        end else if (ts_wr_en) begin
            timeset_edges[ts_wr_id][ts_wr_edge_sel] <= ts_wr_value;
        end
    end

    // -----------------------------------------------------------
    // Vector cycle counter
    // -----------------------------------------------------------
    logic [31:0] cycle_counter;
    logic [4:0]  active_timeset;
    logic        cycle_active;

    // Latch timeset at start of vector
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_timeset <= '0;
        end else if (vec_valid) begin
            active_timeset <= vec_timeset;
        end
    end

    // Cycle counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_counter <= '0;
            cycle_active  <= 1'b0;
            cycle_start   <= 1'b0;
            cycle_end     <= 1'b0;
        end else begin
            cycle_start <= 1'b0;
            cycle_end   <= 1'b0;

            if (vec_valid) begin
                cycle_counter <= '0;
                cycle_active  <= 1'b1;
                cycle_start   <= 1'b1;
            end else if (cycle_active) begin
                if (cycle_counter >= vector_period - 1) begin
                    cycle_counter <= '0;
                    cycle_end     <= 1'b1;
                    cycle_active  <= 1'b0;
                end else begin
                    cycle_counter <= cycle_counter + 1'b1;
                end
            end
        end
    end

    // -----------------------------------------------------------
    // Edge comparators
    // -----------------------------------------------------------
    // Convert edge position from ps to clock cycles for comparison
    // In actual implementation, fine position would use ODELAYE3
    // Here we use integer clock cycle comparison

    // Current position in ps (approximation: assume 10ns = 10000ps per clock at 100MHz)
    localparam PS_PER_CLK = 32'd5000; // 5ns per clock at 200MHz

    logic [31:0] current_edge_positions [8];

    always_comb begin
        for (int e = 0; e < 8; e++) begin
            current_edge_positions[e] = timeset_edges[active_timeset][e];
        end
    end

    // Edge event generation: compare cycle counter against edge positions
    logic [31:0] cycle_pos_ps;
    assign cycle_pos_ps = cycle_counter * PS_PER_CLK;

    // Generate edge events (single-cycle pulses)
    logic [7:0] edge_fired;  // Track which edges have fired this cycle

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || cycle_start) begin
            edge_fired <= '0;
        end else if (cycle_active) begin
            for (int e = 0; e < 8; e++) begin
                if (!edge_fired[e] && cycle_pos_ps >= current_edge_positions[e]) begin
                    edge_fired[e] <= 1'b1;
                end
            end
        end
    end

    // Rising-edge detect on edge_fired bits
    logic [7:0] edge_fired_d;
    always_ff @(posedge clk) edge_fired_d <= edge_fired;

    logic [7:0] edge_events;
    assign edge_events = edge_fired & ~edge_fired_d;

    // Map edge events to named outputs
    assign evt_drive_on        = edge_events[0] & cycle_active;
    assign evt_drive_data      = edge_events[1] & cycle_active;
    assign evt_drive_return    = edge_events[2] & cycle_active;
    assign evt_drive_off       = edge_events[3] & cycle_active;
    assign evt_compare_strobe  = edge_events[4] & cycle_active;
    assign evt_drive_data2     = edge_events[5] & cycle_active;
    assign evt_drive_return2   = edge_events[6] & cycle_active;
    assign evt_compare_strobe2 = edge_events[7] & cycle_active;

endmodule
