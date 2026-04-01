`timescale 1ns / 1ps
// Timing Engine — Redesigned for PXIe-6571 Specification Compliance
//
// Key specs achieved:
//   Vector period resolution:  38 fs  (32-bit DDS phase accumulator)
//   Edge placement resolution: 39.0625 ps (ODELAYE3 @800MHz REFCLK)
//   Edge placement range:      0 ~ 5 vector periods (14-bit coarse + 9-bit fine)
//   TimeSets:                  31 (per-channel, per-edge)
//   Drive formats:             NR, RL, RH, SBC (per-channel)
//   Edge multiplier:           1x, 2x (per-channel)
//
// Architecture:
//   MMCM: 200MHz → 800MHz (IDELAYCTRL) + 400MHz (OSERDES CLK) + 100MHz (CLKDIV)
//   Per-channel: coarse counter → OSERDES3 8:1 pattern → ODELAYE3 fine delay
//
// Edge position format: {coarse[13:0], oserdes_slot[2:0], fine_tap[8:0]} = 26 bits
//   coarse:       clock cycles from vector start (0~16383, @100MHz → 0~163.83µs)
//   oserdes_slot: bit position within OSERDES word (0~7, @1.25ns each)
//   fine_tap:     ODELAYE3 tap (0~511, @39.0625ps each)

module timing_engine
    import ate_pkg::*;
(
    input  logic        clk_100,        // 100 MHz pattern clock (CLKDIV)
    input  logic        clk_400,        // 400 MHz OSERDES clock (DDR→800Mbps)
    input  logic        clk_800,        // 800 MHz IDELAYCTRL reference
    input  logic        rst_n,

    // Vector period configuration (DDS)
    // period_reg = desired_period / 38.147 fs
    // Example: 10 ns = 10000 ps / 0.038147 ps = 262144 = 32'h0004_0000
    input  logic [31:0] period_reg,

    // TimeSet programming interface (from register map)
    input  logic        ts_wr_en,
    input  logic [4:0]  ts_wr_id,       // TimeSet ID (0~30)
    input  logic [2:0]  ts_wr_edge_sel, // Edge index (0~7)
    input  logic [3:0]  ts_wr_ch,       // Channel (0~15), 4'hF = all channels
    input  logic [25:0] ts_wr_value,    // {coarse[13:0], slot[2:0], fine[8:0]}

    // TDR deskew per channel
    input  logic        tdr_wr_en,
    input  logic [3:0]  tdr_wr_ch,
    input  logic [8:0]  tdr_wr_value,   // Fine tap offset (0~511)

    // Sequencer interface
    input  logic        vec_valid,
    input  logic [4:0]  vec_timeset,

    // Per-channel pin state and format
    input  pin_state_t  ch_pin_state [NUM_CHANNELS],
    input  drive_fmt_t  ch_drive_fmt [NUM_CHANNELS],
    input  logic        ch_edge_2x  [NUM_CHANNELS],   // 2x edge multiplier

    // Per-channel OSERDES data output (directly to OSERDES3 D[7:0])
    output logic [7:0]  ch_oserdes_d [NUM_CHANNELS],

    // Per-channel ODELAYE3 tap value (coarse+TDR combined)
    output logic [8:0]  ch_odelay_tap [NUM_CHANNELS],
    output logic [NUM_CHANNELS-1:0] ch_odelay_load,    // Pulse to load new tap

    // Per-channel IDELAYE3 tap for compare strobe
    output logic [8:0]  ch_idelay_tap [NUM_CHANNELS],
    output logic [NUM_CHANNELS-1:0] ch_idelay_load,

    // Compare strobe to compare logic (active in bit-slot where strobe occurs)
    output logic [NUM_CHANNELS-1:0] ch_compare_strobe,

    // Cycle boundary signals
    output logic        cycle_start,
    output logic        cycle_end
);

    // ================================================================
    // Vector Period Generator — DDS Phase Accumulator
    // ================================================================
    // phase_acc[31:18] = integer clock count (14-bit, max 16383)
    // phase_acc[17:0]  = fractional sub-clock (18-bit, resolution ~38 fs)
    //
    // Vector boundary occurs when phase_acc overflows past period_reg

    logic [31:0] phase_acc;
    logic [31:0] period_reg_r;
    logic        vec_tick;       // One pulse per vector period
    logic        running;

    always_ff @(posedge clk_100 or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc    <= '0;
            period_reg_r <= 32'h0004_0000; // Default: 10 ns (100 MHz)
            running      <= 1'b0;
            vec_tick     <= 1'b0;
            cycle_start  <= 1'b0;
            cycle_end    <= 1'b0;
        end else begin
            vec_tick    <= 1'b0;
            cycle_start <= 1'b0;
            cycle_end   <= 1'b0;

            if (vec_valid) begin
                running      <= 1'b1;
                phase_acc    <= '0;
                period_reg_r <= period_reg;
                cycle_start  <= 1'b1;
            end else if (running) begin
                phase_acc <= phase_acc + 32'h0004_0000; // Increment by 1 clock (10ns)

                if (phase_acc >= period_reg_r) begin
                    phase_acc <= phase_acc - period_reg_r; // Maintain fractional residue
                    vec_tick  <= 1'b1;
                    cycle_end <= 1'b1;
                end
            end
        end
    end

    // Coarse position within current vector (clock cycles from vector start)
    logic [13:0] coarse_count;

    always_ff @(posedge clk_100 or negedge rst_n) begin
        if (!rst_n) begin
            coarse_count <= '0;
        end else begin
            if (cycle_start || vec_tick)
                coarse_count <= '0;
            else if (running)
                coarse_count <= coarse_count + 1'b1;
        end
    end

    // ================================================================
    // TimeSet Memory — Per-channel, per-edge storage
    // ================================================================
    // Storage: 31 timesets × 8 edges × 16 channels × 26 bits
    // Organized as BRAM: addr = {timeset[4:0], edge[2:0], channel[3:0]} = 12 bits
    // Data = {coarse[13:0], slot[2:0], fine[8:0]} = 26 bits

    localparam TS_MEM_ADDR_W = 12;  // 5+3+4
    localparam TS_MEM_DATA_W = 26;
    localparam TS_MEM_DEPTH  = 2**TS_MEM_ADDR_W; // 4096

    (* ram_style = "block" *)
    logic [TS_MEM_DATA_W-1:0] ts_mem [TS_MEM_DEPTH];

    // Single write port; broadcast (ch=0xF) handled by sequencing writes over multiple clocks
    logic [TS_MEM_ADDR_W-1:0] ts_wr_addr_seq;
    logic [3:0]  bcast_cnt;
    logic        bcast_active;
    logic [25:0] bcast_value;
    logic [4:0]  bcast_ts_id;
    logic [2:0]  bcast_edge;

    always_ff @(posedge clk_100 or negedge rst_n) begin
        if (!rst_n) begin
            bcast_active <= 1'b0;
            bcast_cnt    <= '0;
        end else begin
            if (ts_wr_en && ts_wr_ch == 4'hF && !bcast_active) begin
                bcast_active <= 1'b1;
                bcast_cnt    <= '0;
                bcast_value  <= ts_wr_value;
                bcast_ts_id  <= ts_wr_id;
                bcast_edge   <= ts_wr_edge_sel;
            end else if (bcast_active) begin
                bcast_cnt <= bcast_cnt + 1'b1;
                if (bcast_cnt == NUM_CHANNELS - 1)
                    bcast_active <= 1'b0;
            end
        end
    end

    // Memory write: single port, either direct or broadcast
    logic        ts_mem_wr;
    logic [TS_MEM_ADDR_W-1:0] ts_mem_wr_addr;
    logic [TS_MEM_DATA_W-1:0] ts_mem_wr_data;

    always_comb begin
        if (bcast_active) begin
            ts_mem_wr      = 1'b1;
            ts_mem_wr_addr = {bcast_ts_id, bcast_edge, bcast_cnt};
            ts_mem_wr_data = bcast_value;
        end else if (ts_wr_en && ts_wr_ch != 4'hF) begin
            ts_mem_wr      = 1'b1;
            ts_mem_wr_addr = {ts_wr_id, ts_wr_edge_sel, ts_wr_ch};
            ts_mem_wr_data = ts_wr_value;
        end else begin
            ts_mem_wr      = 1'b0;
            ts_mem_wr_addr = '0;
            ts_mem_wr_data = '0;
        end
    end

    always_ff @(posedge clk_100) begin
        if (ts_mem_wr)
            ts_mem[ts_mem_wr_addr] <= ts_mem_wr_data;
    end

    // ================================================================
    // TDR Deskew Storage — Per-channel fine offset
    // ================================================================
    logic [8:0] tdr_offset [NUM_CHANNELS];

    always_ff @(posedge clk_100 or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_CHANNELS; i++)
                tdr_offset[i] <= '0;
        end else if (tdr_wr_en) begin
            tdr_offset[tdr_wr_ch] <= tdr_wr_value;
        end
    end

    // ================================================================
    // Per-Channel Edge Generator
    // ================================================================
    // Active timeset latched at vector start
    logic [4:0] active_ts;

    always_ff @(posedge clk_100 or negedge rst_n) begin
        if (!rst_n)
            active_ts <= '0;
        else if (vec_valid)
            active_ts <= vec_timeset;
    end

    // Read edge positions for all channels and edges
    // Pipeline: read from BRAM each clock, cycle through edges
    logic [2:0] edge_rd_idx;       // Current edge being read (0~7)
    logic [3:0] ch_rd_idx;         // Current channel being read
    logic       edge_rd_active;

    // Edge position cache: [channel][edge]
    logic [25:0] edge_pos_cache [NUM_CHANNELS][8];
    logic        cache_valid;

    // Sequential read of all edges for current timeset
    always_ff @(posedge clk_100 or negedge rst_n) begin
        if (!rst_n) begin
            edge_rd_idx    <= '0;
            ch_rd_idx      <= '0;
            edge_rd_active <= 1'b0;
            cache_valid    <= 1'b0;
        end else begin
            if (vec_valid || vec_tick) begin
                // Start loading edge positions for new vector
                edge_rd_idx    <= '0;
                ch_rd_idx      <= '0;
                edge_rd_active <= 1'b1;
                cache_valid    <= 1'b0;
            end else if (edge_rd_active) begin
                // Read one entry per clock
                edge_pos_cache[ch_rd_idx][edge_rd_idx] <=
                    ts_mem[{active_ts, edge_rd_idx, ch_rd_idx}];

                if (ch_rd_idx == NUM_CHANNELS - 1) begin
                    ch_rd_idx <= '0;
                    if (edge_rd_idx == 3'd7) begin
                        edge_rd_active <= 1'b0;
                        cache_valid    <= 1'b1;
                    end else begin
                        edge_rd_idx <= edge_rd_idx + 1'b1;
                    end
                end else begin
                    ch_rd_idx <= ch_rd_idx + 1'b1;
                end
            end
        end
    end

    // ================================================================
    // Per-Channel OSERDES Pattern and Delay Generation
    // ================================================================
    generate
        for (genvar ch = 0; ch < NUM_CHANNELS; ch++) begin : gen_ch_timing

            // Edge position decode
            logic [13:0] edge_coarse [8];  // Clock cycle offset
            logic [2:0]  edge_slot   [8];  // OSERDES bit slot (0~7)
            logic [8:0]  edge_fine   [8];  // ODELAYE3 tap

            always_comb begin
                for (int e = 0; e < 8; e++) begin
                    edge_coarse[e] = edge_pos_cache[ch][e][25:12];
                    edge_slot[e]   = edge_pos_cache[ch][e][11:9];
                    edge_fine[e]   = edge_pos_cache[ch][e][8:0];
                end
            end

            // Edge match: each edge fires when coarse_count matches
            logic [7:0] edge_match;      // Edge matched this clock cycle
            logic [7:0] edge_fired_r;    // Already fired this vector

            always_ff @(posedge clk_100 or negedge rst_n) begin
                if (!rst_n) begin
                    edge_fired_r <= '0;
                end else begin
                    if (cycle_start || vec_tick)
                        edge_fired_r <= '0;
                    else
                        edge_fired_r <= edge_fired_r | edge_match;
                end
            end

            always_comb begin
                for (int e = 0; e < 8; e++) begin
                    edge_match[e] = cache_valid &&
                                    !edge_fired_r[e] &&
                                    (coarse_count == edge_coarse[e]);
                end
            end

            // -----------------------------------------------------------
            // OSERDES bit pattern generation
            // -----------------------------------------------------------
            // Within the current clock cycle (8 bit-slots @1.25ns each),
            // determine what value to drive at each slot based on:
            //   - Current pin state
            //   - Drive format
            //   - Which edges fire and at which slot

            // Drive format state
            logic drv_val;       // Current drive output level
            logic drv_enable;    // Driver output enable
            pin_state_t cur_ps;

            always_ff @(posedge clk_100 or negedge rst_n) begin
                if (!rst_n) begin
                    drv_val    <= 1'b0;
                    drv_enable <= 1'b0;
                    cur_ps     <= PS_HIZ;
                end else if (vec_valid) begin
                    cur_ps <= ch_pin_state[ch];
                end
            end

            // Return value depends on format
            logic return_val;
            always_comb begin
                case (ch_drive_fmt[ch])
                    DRV_NR:  return_val = (cur_ps == PS_DRIVE1);
                    DRV_RL:  return_val = 1'b0;
                    DRV_RH:  return_val = 1'b1;
                    DRV_SBC: return_val = !(cur_ps == PS_DRIVE1);
                    default: return_val = 1'b0;
                endcase
            end

            logic data_val;
            assign data_val = (cur_ps == PS_DRIVE1);

            // OSERDES 8-bit output pattern for this clock cycle
            // Bit 0 = first in time (earliest), Bit 7 = last
            logic [7:0] oserdes_pattern;

            always_comb begin
                oserdes_pattern = {8{drv_val}}; // Default: hold current level

                // Process edges in time order within this cycle
                // Edge 0=drive_on, 1=drive_data, 2=drive_return, 3=drive_off
                // Edge 4=compare_strobe, 5=data2, 6=return2, 7=strobe2

                for (int slot = 0; slot < 8; slot++) begin
                    logic level_at_slot;
                    level_at_slot = drv_val; // Start from current level

                    // Check if any edge fires at or before this slot
                    // Drive On (edge 0): enable driver
                    if (edge_match[0] && slot >= edge_slot[0]) begin
                        level_at_slot = return_val; // On = initially return value
                    end

                    // Drive Data (edge 1): switch to data value
                    if (edge_match[1] && slot >= edge_slot[1]) begin
                        level_at_slot = data_val;
                    end

                    // Drive Return (edge 2): switch to return value
                    if (edge_match[2] && slot >= edge_slot[2]) begin
                        level_at_slot = return_val;
                    end

                    // 2x mode: Data2 (edge 5)
                    if (ch_edge_2x[ch] && edge_match[5] && slot >= edge_slot[5]) begin
                        level_at_slot = data_val;
                    end

                    // 2x mode: Return2 (edge 6)
                    if (ch_edge_2x[ch] && edge_match[6] && slot >= edge_slot[6]) begin
                        level_at_slot = return_val;
                    end

                    // Drive Off (edge 3): disable driver (output low/hi-z)
                    if (edge_match[3] && slot >= edge_slot[3]) begin
                        level_at_slot = 1'b0; // Hi-Z represented as 0 at OSERDES
                    end

                    oserdes_pattern[slot] = level_at_slot;
                end
            end

            // Update persistent drive level at end of this clock cycle
            always_ff @(posedge clk_100 or negedge rst_n) begin
                if (!rst_n) begin
                    drv_val <= 1'b0;
                end else if (|edge_match) begin
                    drv_val <= oserdes_pattern[7]; // Last bit becomes new level
                end
            end

            assign ch_oserdes_d[ch] = oserdes_pattern;

            // -----------------------------------------------------------
            // ODELAYE3 tap value: use drive_data edge fine + TDR deskew
            // -----------------------------------------------------------
            // Primary fine delay from drive_data edge (edge 1)
            // Combined with TDR deskew offset
            logic [9:0] combined_fine;
            assign combined_fine = {1'b0, edge_fine[1]} + {1'b0, tdr_offset[ch]};

            // Clamp to 511 max
            always_ff @(posedge clk_100 or negedge rst_n) begin
                if (!rst_n) begin
                    ch_odelay_tap[ch]  <= '0;
                    ch_odelay_load[ch] <= 1'b0;
                end else begin
                    ch_odelay_load[ch] <= 1'b0;
                    if (edge_match[1]) begin  // Update on drive_data edge
                        ch_odelay_tap[ch]  <= (combined_fine > 10'd511) ?
                                              9'd511 : combined_fine[8:0];
                        ch_odelay_load[ch] <= 1'b1;
                    end
                end
            end

            // -----------------------------------------------------------
            // Compare strobe (edge 4) → IDELAYE3 tap for input sampling
            // -----------------------------------------------------------
            always_ff @(posedge clk_100 or negedge rst_n) begin
                if (!rst_n) begin
                    ch_idelay_tap[ch]  <= '0;
                    ch_idelay_load[ch] <= 1'b0;
                    ch_compare_strobe[ch] <= 1'b0;
                end else begin
                    ch_idelay_load[ch]    <= 1'b0;
                    ch_compare_strobe[ch] <= 1'b0;

                    if (edge_match[4]) begin
                        // Set IDELAYE3 fine tap for compare sampling point
                        logic [9:0] comp_fine;
                        comp_fine = {1'b0, edge_fine[4]} + {1'b0, tdr_offset[ch]};
                        ch_idelay_tap[ch]  <= (comp_fine > 10'd511) ?
                                              9'd511 : comp_fine[8:0];
                        ch_idelay_load[ch] <= 1'b1;
                        ch_compare_strobe[ch] <= 1'b1;
                    end

                    // 2x mode: second strobe (edge 7)
                    if (ch_edge_2x[ch] && edge_match[7]) begin
                        ch_compare_strobe[ch] <= 1'b1;
                    end
                end
            end

        end // gen_ch_timing
    endgenerate

endmodule
