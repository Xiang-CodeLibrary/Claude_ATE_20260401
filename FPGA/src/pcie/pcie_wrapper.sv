`timescale 1ns / 1ps
// PCIe Wrapper — Integrates Xilinx XDMA IP
// Provides AXI4-Lite master interface to register map
// PCIe Gen2 x4, BAR0 = 64KB AXI4-Lite register space
//
// When XDMA IP is not yet generated, USE_XDMA_IP is not defined
// and a JTAG-AXI fallback is used for register access during bring-up

module pcie_wrapper
    import ate_pkg::*;
(
    // PCIe reference clock (100 MHz from PXIe backplane)
    input  logic        pcie_refclk_p,  // AB6
    input  logic        pcie_refclk_n,  // AB5

    // PCIe lanes (Bank 224, GTH)
    output logic [3:0]  pcie_tx_p,
    output logic [3:0]  pcie_tx_n,
    input  logic [3:0]  pcie_rx_p,
    input  logic [3:0]  pcie_rx_n,

    // PCIe reset
    input  logic        pcie_perst_n,   // N23

    // User interface clock/reset
    output logic        user_clk,
    output logic        user_reset_n,
    output logic        user_lnk_up,

    // AXI4-Lite master (BAR0 → register space)
    output logic [AXI_ADDR_W-1:0] m_axi_awaddr,
    output logic [2:0]            m_axi_awprot,
    output logic                   m_axi_awvalid,
    input  logic                   m_axi_awready,
    output logic [AXI_DATA_W-1:0] m_axi_wdata,
    output logic [3:0]            m_axi_wstrb,
    output logic                   m_axi_wvalid,
    input  logic                   m_axi_wready,
    input  logic [1:0]            m_axi_bresp,
    input  logic                   m_axi_bvalid,
    output logic                   m_axi_bready,
    output logic [AXI_ADDR_W-1:0] m_axi_araddr,
    output logic [2:0]            m_axi_arprot,
    output logic                   m_axi_arvalid,
    input  logic                   m_axi_arready,
    input  logic [AXI_DATA_W-1:0] m_axi_rdata,
    input  logic [1:0]            m_axi_rresp,
    input  logic                   m_axi_rvalid,
    output logic                   m_axi_rready,

    // DMA interface (simplified)
    output logic        dma_h2c_valid,
    output logic [31:0] dma_h2c_addr,
    output logic [127:0]dma_h2c_data,
    input  logic        dma_h2c_ready,
    input  logic        dma_c2h_valid,
    input  logic [127:0]dma_c2h_data,
    output logic        dma_c2h_ready,

    // Interrupt
    input  logic [3:0]  irq_req,
    output logic        irq_ack
);

    // PCIe refclk buffer
    // XDMA sys_clk_gt → IBUFDS_GTE3.O (goes to GT transceivers)
    // XDMA sys_clk    → IBUFDS_GTE3.ODIV2 (goes to fabric via BUFG_GT)
    logic pcie_refclk_gt, pcie_refclk;

    IBUFDS_GTE3 #(
        .REFCLK_HROW_CK_SEL(2'b00)
    ) u_refclk_buf (
        .O     (pcie_refclk_gt),
        .ODIV2 (pcie_refclk),
        .CEB   (1'b0),
        .I     (pcie_refclk_p),
        .IB    (pcie_refclk_n)
    );

`ifdef USE_XDMA_IP
    // ================================================================
    // XDMA IP instantiation (active when IP is generated)
    // ================================================================
    logic axi_aclk, axi_aresetn;

    // XDMA internal AXI-Lite signals (32-bit addr from XDMA)
    logic [31:0] xdma_m_axil_awaddr;
    logic [31:0] xdma_m_axil_araddr;
    logic [31:0] xdma_m_axil_wdata;
    logic [31:0] xdma_m_axil_rdata;
    logic [3:0]  xdma_m_axil_wstrb;
    logic [2:0]  xdma_m_axil_awprot, xdma_m_axil_arprot;
    logic        xdma_m_axil_awvalid, xdma_m_axil_awready;
    logic        xdma_m_axil_wvalid, xdma_m_axil_wready;
    logic [1:0]  xdma_m_axil_bresp;
    logic        xdma_m_axil_bvalid, xdma_m_axil_bready;
    logic        xdma_m_axil_arvalid, xdma_m_axil_arready;
    logic [1:0]  xdma_m_axil_rresp;
    logic        xdma_m_axil_rvalid, xdma_m_axil_rready;

    logic        pcie_lnk_up;
    logic [3:0]  usr_irq_req;
    logic [3:0]  usr_irq_ack;

    xdma_0 u_xdma (
        // PCIe interface
        .sys_clk    (pcie_refclk),      // ODIV2 → fabric clock path
        .sys_clk_gt (pcie_refclk_gt),   // O → GT transceiver refclk
        .sys_rst_n  (pcie_perst_n),

        .pci_exp_txp(pcie_tx_p),
        .pci_exp_txn(pcie_tx_n),
        .pci_exp_rxp(pcie_rx_p),
        .pci_exp_rxn(pcie_rx_n),

        // AXI clock/reset
        .axi_aclk    (axi_aclk),
        .axi_aresetn (axi_aresetn),

        // AXI4-Lite master (BAR0)
        .m_axil_awaddr  (xdma_m_axil_awaddr),
        .m_axil_awprot  (xdma_m_axil_awprot),
        .m_axil_awvalid (xdma_m_axil_awvalid),
        .m_axil_awready (xdma_m_axil_awready),
        .m_axil_wdata   (xdma_m_axil_wdata),
        .m_axil_wstrb   (xdma_m_axil_wstrb),
        .m_axil_wvalid  (xdma_m_axil_wvalid),
        .m_axil_wready  (xdma_m_axil_wready),
        .m_axil_bresp   (xdma_m_axil_bresp),
        .m_axil_bvalid  (xdma_m_axil_bvalid),
        .m_axil_bready  (xdma_m_axil_bready),
        .m_axil_araddr  (xdma_m_axil_araddr),
        .m_axil_arprot  (xdma_m_axil_arprot),
        .m_axil_arvalid (xdma_m_axil_arvalid),
        .m_axil_arready (xdma_m_axil_arready),
        .m_axil_rdata   (xdma_m_axil_rdata),
        .m_axil_rresp   (xdma_m_axil_rresp),
        .m_axil_rvalid  (xdma_m_axil_rvalid),
        .m_axil_rready  (xdma_m_axil_rready),

        // AXI4-MM DMA interface (tied off — DMA not used yet)
        // Write address
        .m_axi_awaddr  (),
        .m_axi_awlen   (),
        .m_axi_awsize  (),
        .m_axi_awburst (),
        .m_axi_awprot  (),
        .m_axi_awvalid (),
        .m_axi_awready (1'b1),
        .m_axi_awlock  (),
        .m_axi_awcache (),
        .m_axi_awid    (),
        // Write data
        .m_axi_wdata   (),
        .m_axi_wstrb   (),
        .m_axi_wlast   (),
        .m_axi_wvalid  (),
        .m_axi_wready  (1'b1),
        // Write response
        .m_axi_bid     ('0),
        .m_axi_bresp   (2'b00),
        .m_axi_bvalid  (1'b0),
        .m_axi_bready  (),
        // Read address
        .m_axi_araddr  (),
        .m_axi_arlen   (),
        .m_axi_arsize  (),
        .m_axi_arburst (),
        .m_axi_arprot  (),
        .m_axi_arvalid (),
        .m_axi_arready (1'b1),
        .m_axi_arlock  (),
        .m_axi_arcache (),
        .m_axi_arid    (),
        // Read data
        .m_axi_rid     ('0),
        .m_axi_rdata   ('0),
        .m_axi_rresp   (2'b00),
        .m_axi_rlast   (1'b1),
        .m_axi_rvalid  (1'b0),
        .m_axi_rready  (),

        // User interrupt
        .usr_irq_req (usr_irq_req),
        .usr_irq_ack (usr_irq_ack),

        // Link status
        .user_lnk_up (pcie_lnk_up)
    );

    // Map XDMA outputs to wrapper ports
    assign user_clk     = axi_aclk;
    assign user_reset_n = axi_aresetn;
    assign user_lnk_up  = pcie_lnk_up;

    // Truncate 32-bit AXI addr to 16-bit register space
    assign m_axi_awaddr  = xdma_m_axil_awaddr[AXI_ADDR_W-1:0];
    assign m_axi_awprot  = xdma_m_axil_awprot;
    assign m_axi_awvalid = xdma_m_axil_awvalid;
    assign xdma_m_axil_awready = m_axi_awready;

    assign m_axi_wdata   = xdma_m_axil_wdata;
    assign m_axi_wstrb   = xdma_m_axil_wstrb;
    assign m_axi_wvalid  = xdma_m_axil_wvalid;
    assign xdma_m_axil_wready = m_axi_wready;

    assign xdma_m_axil_bresp  = m_axi_bresp;
    assign xdma_m_axil_bvalid = m_axi_bvalid;
    assign m_axi_bready  = xdma_m_axil_bready;

    assign m_axi_araddr  = xdma_m_axil_araddr[AXI_ADDR_W-1:0];
    assign m_axi_arprot  = xdma_m_axil_arprot;
    assign m_axi_arvalid = xdma_m_axil_arvalid;
    assign xdma_m_axil_arready = m_axi_arready;

    assign xdma_m_axil_rdata  = m_axi_rdata;
    assign xdma_m_axil_rresp  = m_axi_rresp;
    assign xdma_m_axil_rvalid = m_axi_rvalid;
    assign m_axi_rready  = xdma_m_axil_rready;

    // Interrupt mapping
    assign usr_irq_req = irq_req;
    assign irq_ack     = |usr_irq_ack;

    // DMA not used yet
    assign dma_h2c_valid = 1'b0;
    assign dma_h2c_addr  = '0;
    assign dma_h2c_data  = '0;
    assign dma_c2h_ready = 1'b1;

`else
    // ================================================================
    // Fallback: no PCIe IP — use JTAG-AXI for register access
    // ================================================================
    // In this mode, PCIe pins are unused, and registers are accessed
    // via Vivado Hardware Manager JTAG-AXI transaction window

    // Tie off PCIe outputs
    assign pcie_tx_p    = 4'b0;
    assign pcie_tx_n    = 4'b1;
    assign user_lnk_up  = 1'b0;
    assign dma_h2c_valid = 1'b0;
    assign dma_h2c_addr  = '0;
    assign dma_h2c_data  = '0;
    assign dma_c2h_ready = 1'b1;
    assign irq_ack       = 1'b0;

    // JTAG-AXI provides the AXI-Lite master
    // user_clk and user_reset_n driven from external (ate_top provides clk_100)
    assign user_clk     = 1'b0;  // Not used in JTAG mode
    assign user_reset_n = 1'b0;

    // AXI-Lite: directly driven by JTAG-AXI IP (instantiated in ate_top)
    assign m_axi_awaddr  = '0;
    assign m_axi_awprot  = '0;
    assign m_axi_awvalid = 1'b0;
    assign m_axi_wdata   = '0;
    assign m_axi_wstrb   = '0;
    assign m_axi_wvalid  = 1'b0;
    assign m_axi_bready  = 1'b1;
    assign m_axi_araddr  = '0;
    assign m_axi_arprot  = '0;
    assign m_axi_arvalid = 1'b0;
    assign m_axi_rready  = 1'b1;

`endif

endmodule
