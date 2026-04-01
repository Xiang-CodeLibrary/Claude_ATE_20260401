// AXI4-Lite Slave Interface
// Bridges AXI4-Lite bus to simple register read/write interface

module axi_lite_slave
    import ate_pkg::*;
(
    input  logic                    aclk,
    input  logic                    aresetn,

    // AXI4-Lite slave interface
    input  logic [AXI_ADDR_W-1:0]  s_axi_awaddr,
    input  logic [2:0]             s_axi_awprot,
    input  logic                    s_axi_awvalid,
    output logic                    s_axi_awready,

    input  logic [AXI_DATA_W-1:0]  s_axi_wdata,
    input  logic [3:0]             s_axi_wstrb,
    input  logic                    s_axi_wvalid,
    output logic                    s_axi_wready,

    output logic [1:0]             s_axi_bresp,
    output logic                    s_axi_bvalid,
    input  logic                    s_axi_bready,

    input  logic [AXI_ADDR_W-1:0]  s_axi_araddr,
    input  logic [2:0]             s_axi_arprot,
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,

    output logic [AXI_DATA_W-1:0]  s_axi_rdata,
    output logic [1:0]             s_axi_rresp,
    output logic                    s_axi_rvalid,
    input  logic                    s_axi_rready,

    // Simple register interface
    output logic                    reg_wr_en,
    output logic [AXI_ADDR_W-1:0]  reg_wr_addr,
    output logic [AXI_DATA_W-1:0]  reg_wr_data,
    output logic [3:0]             reg_wr_strb,

    output logic                    reg_rd_en,
    output logic [AXI_ADDR_W-1:0]  reg_rd_addr,
    input  logic [AXI_DATA_W-1:0]  reg_rd_data,
    input  logic                    reg_rd_valid
);

    // Write channel state machine
    logic aw_done, w_done;
    logic [AXI_ADDR_W-1:0] wr_addr_r;

    // Write address handshake
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready <= 1'b0;
            aw_done       <= 1'b0;
            wr_addr_r     <= '0;
        end else begin
            if (s_axi_awvalid && !aw_done) begin
                s_axi_awready <= 1'b1;
                aw_done       <= 1'b1;
                wr_addr_r     <= s_axi_awaddr;
            end else begin
                s_axi_awready <= 1'b0;
            end

            if (s_axi_bvalid && s_axi_bready)
                aw_done <= 1'b0;
        end
    end

    // Write data handshake
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_wready <= 1'b0;
            w_done       <= 1'b0;
        end else begin
            if (s_axi_wvalid && !w_done) begin
                s_axi_wready <= 1'b1;
                w_done       <= 1'b1;
            end else begin
                s_axi_wready <= 1'b0;
            end

            if (s_axi_bvalid && s_axi_bready)
                w_done <= 1'b0;
        end
    end

    // Write response
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00;
        end else begin
            if (aw_done && w_done && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // Register write pulse
    assign reg_wr_en   = aw_done && w_done && !s_axi_bvalid;
    assign reg_wr_addr = wr_addr_r;
    assign reg_wr_data = s_axi_wdata;
    assign reg_wr_strb = s_axi_wstrb;

    // Read channel
    logic rd_pending;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_arready <= 1'b0;
            rd_pending    <= 1'b0;
            reg_rd_en     <= 1'b0;
            reg_rd_addr   <= '0;
        end else begin
            reg_rd_en <= 1'b0;

            if (s_axi_arvalid && !rd_pending) begin
                s_axi_arready <= 1'b1;
                rd_pending    <= 1'b1;
                reg_rd_en     <= 1'b1;
                reg_rd_addr   <= s_axi_araddr;
            end else begin
                s_axi_arready <= 1'b0;
            end

            if (s_axi_rvalid && s_axi_rready)
                rd_pending <= 1'b0;
        end
    end

    // Read response
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rdata  <= '0;
            s_axi_rresp  <= 2'b00;
        end else begin
            if (reg_rd_valid && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rdata  <= reg_rd_data;
                s_axi_rresp  <= 2'b00; // OKAY
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
