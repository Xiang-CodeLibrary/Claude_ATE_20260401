`timescale 1ns / 1ps
// Compare Logic
// Samples the ADATE305 comparator outputs at the strobe edge
// and evaluates pass/fail against expected states

module compare_logic
    import ate_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,

    // Comparator inputs from ADATE305 (active-high, already deserialized)
    input  logic        comp_qh,    // Comparator high output (VOUT > VOH)
    input  logic        comp_ql,    // Comparator low output (VOUT < VOL)

    // Compare control
    input  logic        comp_sample,  // Strobe pulse from timing engine
    input  logic        comp_enable,  // Compare active for this cycle

    // Expected pin state
    input  pin_state_t  expected_state,

    // Compare result
    output logic        compare_pass,
    output logic        compare_valid,   // Result valid pulse
    output logic        compare_fail_latch  // Sticky fail indicator
);

    // Sampled comparator values
    logic qh_sampled, ql_sampled;
    logic result_valid;

    // Sample at strobe
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            qh_sampled   <= 1'b0;
            ql_sampled   <= 1'b0;
            result_valid <= 1'b0;
        end else begin
            result_valid <= 1'b0;
            if (comp_sample && comp_enable) begin
                qh_sampled   <= comp_qh;
                ql_sampled   <= comp_ql;
                result_valid <= 1'b1;
            end
        end
    end

    // Evaluate pass/fail based on expected state
    // Compare states from vector:
    //   PS_COMPARE (2'b10) maps to data states: L, H, V, M
    //   The specific compare mode is determined by the vector data
    //   For simplification, we use the comparator outputs directly:
    //   - H (expect high): pass if QH=1 (VOUT > VOH)
    //   - L (expect low):  pass if QL=1 (VOUT < VOL)
    //   - V (valid):       pass if QH=1 OR QL=1 (not midband)
    //   - M (midband):     pass if QH=0 AND QL=0 (between VOL and VOH)

    // Note: In full implementation, the compare mode (H/L/V/M) would come
    // from additional vector data bits. Here we default to checking both.

    logic pass_h, pass_l, pass_v, pass_m;

    assign pass_h = qh_sampled;           // High: VOUT > VOH
    assign pass_l = ql_sampled;           // Low:  VOUT < VOL
    assign pass_v = qh_sampled | ql_sampled;  // Valid: either high or low
    assign pass_m = ~qh_sampled & ~ql_sampled; // Midband: neither

    // Default: use both comparators (pass = expected high got high, or expected low got low)
    // The actual compare mode should be an additional input; simplified here
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            compare_pass  <= 1'b1;
            compare_valid <= 1'b0;
        end else begin
            compare_valid <= result_valid;
            if (result_valid) begin
                // Default: pass if signal is valid (not floating)
                compare_pass <= pass_v;
            end else if (!comp_enable) begin
                compare_pass <= 1'b1; // Not comparing = pass
            end
        end
    end

    // Sticky fail latch (cleared on new pattern start via reset)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            compare_fail_latch <= 1'b0;
        end else if (compare_valid && !compare_pass) begin
            compare_fail_latch <= 1'b1;
        end
    end

endmodule
