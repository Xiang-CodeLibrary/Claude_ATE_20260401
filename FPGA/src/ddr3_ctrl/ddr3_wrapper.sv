`timescale 1ns / 1ps
// DDR3 Memory Controller Wrapper
// Wraps Xilinx MIG IP, provides vector memory read/write interfaces
// When USE_MIG_IP is not defined, uses stub for synthesis without MIG

module ddr3_wrapper
    import ate_pkg::*;
(
    input  logic        sys_clk_200,    // 200 MHz reference
    input  logic        sys_rst_n,

    output logic        ui_clk,
    output logic        ui_rst_n,
    output logic        init_calib_complete,

    // DDR3 physical (directly to pins, active when USE_MIG_IP defined)
    output logic [14:0] ddr3_addr,
    output logic [2:0]  ddr3_ba,
    output logic        ddr3_ras_n,
    output logic        ddr3_cas_n,
    output logic        ddr3_we_n,
    output logic        ddr3_reset_n,
    output logic [0:0]  ddr3_ck_p,
    output logic [0:0]  ddr3_ck_n,
    output logic [0:0]  ddr3_cke,
    output logic [0:0]  ddr3_cs_n,
    output logic [7:0]  ddr3_dm,
    inout  wire  [63:0] ddr3_dq,
    inout  wire  [7:0]  ddr3_dqs_p,
    inout  wire  [7:0]  ddr3_dqs_n,
    output logic [0:0]  ddr3_odt,

    // Vector memory read (from vector_prefetch)
    input  logic                      pa_rd_req,
    input  logic [VECTOR_ADDR_W-1:0] pa_rd_addr,
    output logic [VECTOR_WIDTH-1:0]  pa_rd_data,
    output logic                      pa_rd_valid,
    output logic                      pa_rd_ready,

    // DMA write (from PCIe host)
    input  logic                      pb_wr_req,
    input  logic [VECTOR_ADDR_W-1:0] pb_wr_addr,
    input  logic [VECTOR_WIDTH-1:0]  pb_wr_data,
    output logic                      pb_wr_ready
);

`ifdef USE_MIG_IP
    // ================================================================
    // MIG IP instantiation
    // ================================================================
    logic        mig_ui_clk, mig_ui_rst;
    logic        mig_calib_complete;

    // AXI4 interface to MIG
    logic [3:0]   axi_awid, axi_arid, axi_bid, axi_rid;
    logic [29:0]  axi_awaddr, axi_araddr;
    logic [7:0]   axi_awlen, axi_arlen;
    logic [2:0]   axi_awsize, axi_arsize;
    logic [1:0]   axi_awburst, axi_arburst;
    logic         axi_awvalid, axi_awready;
    logic         axi_arvalid, axi_arready;
    logic [127:0] axi_wdata, axi_rdata;
    logic [15:0]  axi_wstrb;
    logic         axi_wlast, axi_wvalid, axi_wready;
    logic [1:0]   axi_bresp, axi_rresp;
    logic         axi_bvalid, axi_bready;
    logic         axi_rlast, axi_rvalid, axi_rready;

    assign ui_clk              = mig_ui_clk;
    assign ui_rst_n            = ~mig_ui_rst;
    assign init_calib_complete = mig_calib_complete;

    mig_ddr3 u_mig (
        // DDR3 physical
        .c0_ddr3_addr          (ddr3_addr),
        .c0_ddr3_ba            (ddr3_ba),
        .c0_ddr3_ras_n         (ddr3_ras_n),
        .c0_ddr3_cas_n         (ddr3_cas_n),
        .c0_ddr3_we_n          (ddr3_we_n),
        .c0_ddr3_reset_n       (ddr3_reset_n),
        .c0_ddr3_ck_p          (ddr3_ck_p),
        .c0_ddr3_ck_n          (ddr3_ck_n),
        .c0_ddr3_cke           (ddr3_cke),
        .c0_ddr3_cs_n          (ddr3_cs_n),
        .c0_ddr3_dm            (ddr3_dm),
        .c0_ddr3_dq            (ddr3_dq),
        .c0_ddr3_dqs_p         (ddr3_dqs_p),
        .c0_ddr3_dqs_n         (ddr3_dqs_n),
        .c0_ddr3_odt           (ddr3_odt),

        // System
        .c0_sys_clk_i          (sys_clk_200),
        .sys_rst               (~sys_rst_n),
        .c0_init_calib_complete(mig_calib_complete),
        .c0_ddr3_ui_clk        (mig_ui_clk),
        .c0_ddr3_ui_clk_sync_rst(mig_ui_rst),

        // AXI4 slave interface
        .c0_ddr3_aresetn       (sys_rst_n),
        .c0_ddr3_s_axi_awid    (axi_awid),
        .c0_ddr3_s_axi_awaddr  (axi_awaddr),
        .c0_ddr3_s_axi_awlen   (axi_awlen),
        .c0_ddr3_s_axi_awsize  (axi_awsize),
        .c0_ddr3_s_axi_awburst (axi_awburst),
        .c0_ddr3_s_axi_awlock  (1'b0),
        .c0_ddr3_s_axi_awcache (4'b0011),
        .c0_ddr3_s_axi_awprot  (3'b000),
        .c0_ddr3_s_axi_awqos   (4'b0000),
        .c0_ddr3_s_axi_awvalid (axi_awvalid),
        .c0_ddr3_s_axi_awready (axi_awready),
        .c0_ddr3_s_axi_wdata   (axi_wdata),
        .c0_ddr3_s_axi_wstrb   (axi_wstrb),
        .c0_ddr3_s_axi_wlast   (axi_wlast),
        .c0_ddr3_s_axi_wvalid  (axi_wvalid),
        .c0_ddr3_s_axi_wready  (axi_wready),
        .c0_ddr3_s_axi_bid     (axi_bid),
        .c0_ddr3_s_axi_bresp   (axi_bresp),
        .c0_ddr3_s_axi_bvalid  (axi_bvalid),
        .c0_ddr3_s_axi_bready  (axi_bready),
        .c0_ddr3_s_axi_arid    (axi_arid),
        .c0_ddr3_s_axi_araddr  (axi_araddr),
        .c0_ddr3_s_axi_arlen   (axi_arlen),
        .c0_ddr3_s_axi_arsize  (axi_arsize),
        .c0_ddr3_s_axi_arburst (axi_arburst),
        .c0_ddr3_s_axi_arlock  (1'b0),
        .c0_ddr3_s_axi_arcache (4'b0011),
        .c0_ddr3_s_axi_arprot  (3'b000),
        .c0_ddr3_s_axi_arqos   (4'b0000),
        .c0_ddr3_s_axi_arvalid (axi_arvalid),
        .c0_ddr3_s_axi_arready (axi_arready),
        .c0_ddr3_s_axi_rid     (axi_rid),
        .c0_ddr3_s_axi_rdata   (axi_rdata),
        .c0_ddr3_s_axi_rresp   (axi_rresp),
        .c0_ddr3_s_axi_rlast   (axi_rlast),
        .c0_ddr3_s_axi_rvalid  (axi_rvalid),
        .c0_ddr3_s_axi_rready  (axi_rready)
    );

`else
    // ================================================================
    // Stub mode (no MIG IP)
    // ================================================================
    assign ui_clk              = sys_clk_200;
    assign ui_rst_n            = sys_rst_n;
    assign init_calib_complete = 1'b1;

    // AXI4 signals for read/write state machines
    logic [3:0]   axi_awid, axi_arid, axi_bid, axi_rid;
    logic [29:0]  axi_awaddr, axi_araddr;
    logic [7:0]   axi_awlen, axi_arlen;
    logic [2:0]   axi_awsize, axi_arsize;
    logic [1:0]   axi_awburst, axi_arburst;
    logic         axi_awvalid, axi_awready;
    logic         axi_arvalid, axi_arready;
    logic [127:0] axi_wdata, axi_rdata;
    logic [15:0]  axi_wstrb;
    logic         axi_wlast, axi_wvalid, axi_wready;
    logic [1:0]   axi_bresp, axi_rresp;
    logic         axi_bvalid, axi_bready;
    logic         axi_rlast, axi_rvalid, axi_rready;

    // Stub AXI responses
    assign axi_arready = 1'b1;
    assign axi_rdata   = '0;
    assign axi_rvalid  = axi_arvalid;
    assign axi_rid     = '0;
    assign axi_rresp   = '0;
    assign axi_rlast   = 1'b1;
    assign axi_awready = 1'b1;
    assign axi_wready  = 1'b1;
    assign axi_bvalid  = 1'b1;
    assign axi_bid     = '0;
    assign axi_bresp   = '0;

    // DDR3 pins: tie off in stub mode
    assign ddr3_addr    = '0;
    assign ddr3_ba      = '0;
    assign ddr3_ras_n   = 1'b1;
    assign ddr3_cas_n   = 1'b1;
    assign ddr3_we_n    = 1'b1;
    assign ddr3_reset_n = 1'b0;
    assign ddr3_ck_p    = 1'b0;
    assign ddr3_ck_n    = 1'b1;
    assign ddr3_cke     = 1'b0;
    assign ddr3_cs_n    = 1'b1;
    assign ddr3_dm      = '0;
    assign ddr3_odt     = 1'b0;
`endif

    // ================================================================
    // Port A: Vector read → AXI4 read channel
    // ================================================================
    typedef enum logic [1:0] { RD_IDLE, RD_ADDR, RD_DATA } rd_state_t;
    rd_state_t rd_state;

    always_ff @(posedge ui_clk or negedge ui_rst_n) begin
        if (!ui_rst_n) begin
            rd_state    <= RD_IDLE;
            axi_arvalid <= 1'b0;
            axi_rready  <= 1'b0;
            pa_rd_valid <= 1'b0;
            pa_rd_data  <= '0;
            pa_rd_ready <= 1'b1;
        end else begin
            pa_rd_valid <= 1'b0;
            case (rd_state)
                RD_IDLE: begin
                    pa_rd_ready <= 1'b1;
                    if (pa_rd_req) begin
                        axi_araddr  <= {pa_rd_addr[25:0], 4'b0000};
                        axi_arid    <= 4'd0;
                        axi_arlen   <= 8'd0;
                        axi_arsize  <= 3'b100;
                        axi_arburst <= 2'b01;
                        axi_arvalid <= 1'b1;
                        pa_rd_ready <= 1'b0;
                        rd_state    <= RD_ADDR;
                    end
                end
                RD_ADDR: begin
                    if (axi_arready) begin
                        axi_arvalid <= 1'b0;
                        axi_rready  <= 1'b1;
                        rd_state    <= RD_DATA;
                    end
                end
                RD_DATA: begin
                    if (axi_rvalid) begin
                        pa_rd_data  <= axi_rdata;
                        pa_rd_valid <= 1'b1;
                        axi_rready  <= 1'b0;
                        rd_state    <= RD_IDLE;
                    end
                end
            endcase
        end
    end

    // ================================================================
    // Port B: DMA write → AXI4 write channel
    // ================================================================
    typedef enum logic [1:0] { WR_IDLE, WR_ADDR, WR_DATA, WR_RESP } wr_state_t;
    wr_state_t wr_state;

    always_ff @(posedge ui_clk or negedge ui_rst_n) begin
        if (!ui_rst_n) begin
            wr_state    <= WR_IDLE;
            axi_awvalid <= 1'b0;
            axi_wvalid  <= 1'b0;
            axi_bready  <= 1'b0;
            pb_wr_ready <= 1'b1;
        end else begin
            case (wr_state)
                WR_IDLE: begin
                    pb_wr_ready <= 1'b1;
                    if (pb_wr_req) begin
                        axi_awaddr  <= {pb_wr_addr[25:0], 4'b0000};
                        axi_awid    <= 4'd1;
                        axi_awlen   <= 8'd0;
                        axi_awsize  <= 3'b100;
                        axi_awburst <= 2'b01;
                        axi_awvalid <= 1'b1;
                        axi_wdata   <= pb_wr_data;
                        axi_wstrb   <= 16'hFFFF;
                        axi_wlast   <= 1'b1;
                        axi_wvalid  <= 1'b1;
                        pb_wr_ready <= 1'b0;
                        wr_state    <= WR_ADDR;
                    end
                end
                WR_ADDR: begin
                    if (axi_awready) axi_awvalid <= 1'b0;
                    if (axi_wready)  axi_wvalid  <= 1'b0;
                    if (!axi_awvalid && !axi_wvalid) begin
                        axi_bready <= 1'b1;
                        wr_state   <= WR_RESP;
                    end
                end
                WR_RESP: begin
                    if (axi_bvalid) begin
                        axi_bready <= 1'b0;
                        wr_state   <= WR_IDLE;
                    end
                end
                default: wr_state <= WR_IDLE;
            endcase
        end
    end

endmodule
