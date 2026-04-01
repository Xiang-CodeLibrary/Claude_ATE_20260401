// Source & Capture Engine
// Source: Loads waveform data from memory, replaces pin states during pattern execution
// Capture: Stores comparison results into capture memory for host readback
//
// Source memory: 32 MB BRAM (shared across sites), up to 512 waveforms
// Capture memory: 1M samples per site

module source_capture
    import ate_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,

    // Source control (from sequencer opcodes)
    input  logic        src_start,      // source_start opcode
    input  logic        src_active,     // source opcode (each vector)
    input  logic        src_stop,       // implicit stop or end of waveform
    input  logic [3:0]  src_site_id,    // Active site for source

    // Capture control
    input  logic        cap_start,      // capture_start opcode
    input  logic        cap_active,     // capture opcode (each vector)
    input  logic        cap_stop,       // capture_stop opcode
    input  logic [3:0]  cap_site_id,

    // Source data output (overrides sequencer pin states)
    output logic                       src_valid,
    output pin_state_t                src_pin_data [NUM_CHANNELS],

    // Capture data input (from compare results)
    input  logic [NUM_CHANNELS-1:0]   cap_compare_pass,
    input  logic                       cap_compare_valid,

    // Source memory write interface (from DMA / host)
    input  logic        smem_wr_en,
    input  logic [19:0] smem_wr_addr,   // 1M entries
    input  logic [31:0] smem_wr_data,   // Packed pin states (16ch × 2bit = 32bit)

    // Capture memory read interface (to DMA / host)
    input  logic        cmem_rd_en,
    input  logic [19:0] cmem_rd_addr,
    output logic [31:0] cmem_rd_data,

    // Status
    output logic        src_running,
    output logic        cap_running,
    output logic [19:0] cap_sample_count  // Number of captured samples
);

    // ================================================================
    // Source Memory — BRAM, 1M × 32-bit
    // ================================================================
    // Packed format: {ch15[1:0], ch14[1:0], ..., ch1[1:0], ch0[1:0]} = 32 bits
    // Each entry = one vector cycle of source data for all 16 channels

    (* ram_style = "block" *)
    logic [31:0] source_mem [1048576]; // 1M entries = 4 MB BRAM

    logic [19:0] src_rd_addr;
    logic [31:0] src_rd_data;

    // Source memory: dual port (write from host, read for pattern)
    always_ff @(posedge clk) begin
        if (smem_wr_en)
            source_mem[smem_wr_addr] <= smem_wr_data;
        src_rd_data <= source_mem[src_rd_addr];
    end

    // ================================================================
    // Source Controller
    // ================================================================
    logic [19:0] src_ptr;
    logic [19:0] src_length;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            src_running <= 1'b0;
            src_ptr     <= '0;
            src_valid   <= 1'b0;
        end else begin
            src_valid <= 1'b0;

            if (src_start) begin
                src_running <= 1'b1;
                src_ptr     <= '0;
            end

            if (src_stop || !src_running) begin
                src_running <= 1'b0;
            end

            if (src_active && src_running) begin
                src_rd_addr <= src_ptr;
                src_ptr     <= src_ptr + 1'b1;
                src_valid   <= 1'b1;
            end
        end
    end

    // Unpack source data to per-channel pin states
    always_comb begin
        for (int ch = 0; ch < NUM_CHANNELS; ch++) begin
            src_pin_data[ch] = pin_state_t'(src_rd_data[ch*2 +: 2]);
        end
    end

    // ================================================================
    // Capture Memory — BRAM, 1M × 32-bit
    // ================================================================
    // Stores comparison pass/fail mask per vector cycle
    // {16'b0, ch15_pass, ch14_pass, ..., ch0_pass} = 32 bits (lower 16 bits)

    (* ram_style = "block" *)
    logic [31:0] capture_mem [1048576];

    logic [19:0] cap_wr_addr;
    logic [31:0] cap_wr_data;
    logic        cap_wr_en;

    // Capture memory: write from capture engine, read from host
    always_ff @(posedge clk) begin
        if (cap_wr_en)
            capture_mem[cap_wr_addr] <= cap_wr_data;
        cmem_rd_data <= capture_mem[cmem_rd_addr];
    end

    // ================================================================
    // Capture Controller
    // ================================================================
    logic [19:0] cap_ptr;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cap_running      <= 1'b0;
            cap_ptr          <= '0;
            cap_sample_count <= '0;
            cap_wr_en        <= 1'b0;
        end else begin
            cap_wr_en <= 1'b0;

            if (cap_start) begin
                cap_running      <= 1'b1;
                cap_ptr          <= '0;
                cap_sample_count <= '0;
            end

            if (cap_stop) begin
                cap_running <= 1'b0;
            end

            if (cap_active && cap_running && cap_compare_valid) begin
                cap_wr_en   <= 1'b1;
                cap_wr_addr <= cap_ptr;
                cap_wr_data <= {16'b0, cap_compare_pass};
                cap_ptr     <= cap_ptr + 1'b1;
                cap_sample_count <= cap_sample_count + 1'b1;

                // Auto-stop at memory boundary
                if (cap_ptr == 20'hFFFFF) begin
                    cap_running <= 1'b0;
                end
            end
        end
    end

endmodule
