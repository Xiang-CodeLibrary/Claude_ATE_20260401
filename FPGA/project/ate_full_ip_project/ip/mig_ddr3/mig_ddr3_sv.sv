// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
// -------------------------------------------------------------------------------
// This file contains confidential and proprietary information
// of AMD and is protected under U.S. and international copyright
// and other intellectual property laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// AMD, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) AMD shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or AMD had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// AMD products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of AMD products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
// DO NOT MODIFY THIS FILE.

// MODULE VLNV: xilinx.com:ip:ddr3:1.4

`timescale 1ps / 1ps

`include "vivado_interfaces.svh"

module mig_ddr3_sv (
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 C0_DDR3_S_AXI" *)
  (* X_INTERFACE_MODE = "slave C0_DDR3_S_AXI" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME C0_DDR3_S_AXI, FREQ_HZ 2.3325e+08, DATA_WIDTH 128, PROTOCOL AXI4, ID_WIDTH 4, ADDR_WIDTH 31, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
  vivado_aximm_v1_0.slave C0_DDR3_S_AXI,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire c0_init_calib_complete,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire dbg_clk,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire c0_sys_clk_i,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire [511:0] dbg_bus,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire [14:0] c0_ddr3_addr,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire [2:0] c0_ddr3_ba,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire c0_ddr3_cas_n,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire [0:0] c0_ddr3_cke,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire [0:0] c0_ddr3_ck_n,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire [0:0] c0_ddr3_ck_p,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire [0:0] c0_ddr3_cs_n,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire [7:0] c0_ddr3_dm,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire [63:0] c0_ddr3_dq,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire [7:0] c0_ddr3_dqs_n,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire [7:0] c0_ddr3_dqs_p,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire [0:0] c0_ddr3_odt,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire c0_ddr3_ras_n,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire c0_ddr3_reset_n,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire c0_ddr3_we_n,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire c0_ddr3_ui_clk,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire c0_ddr3_ui_clk_sync_rst,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire c0_ddr3_aresetn,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire sys_rst
);

  // interface wire assignments
  assign C0_DDR3_S_AXI.BUSER = 0;
  assign C0_DDR3_S_AXI.RUSER = 0;

  mig_ddr3 inst (
    .c0_init_calib_complete(c0_init_calib_complete),
    .dbg_clk(dbg_clk),
    .c0_sys_clk_i(c0_sys_clk_i),
    .dbg_bus(dbg_bus),
    .c0_ddr3_addr(c0_ddr3_addr),
    .c0_ddr3_ba(c0_ddr3_ba),
    .c0_ddr3_cas_n(c0_ddr3_cas_n),
    .c0_ddr3_cke(c0_ddr3_cke),
    .c0_ddr3_ck_n(c0_ddr3_ck_n),
    .c0_ddr3_ck_p(c0_ddr3_ck_p),
    .c0_ddr3_cs_n(c0_ddr3_cs_n),
    .c0_ddr3_dm(c0_ddr3_dm),
    .c0_ddr3_dq(c0_ddr3_dq),
    .c0_ddr3_dqs_n(c0_ddr3_dqs_n),
    .c0_ddr3_dqs_p(c0_ddr3_dqs_p),
    .c0_ddr3_odt(c0_ddr3_odt),
    .c0_ddr3_ras_n(c0_ddr3_ras_n),
    .c0_ddr3_reset_n(c0_ddr3_reset_n),
    .c0_ddr3_we_n(c0_ddr3_we_n),
    .c0_ddr3_ui_clk(c0_ddr3_ui_clk),
    .c0_ddr3_ui_clk_sync_rst(c0_ddr3_ui_clk_sync_rst),
    .c0_ddr3_aresetn(c0_ddr3_aresetn),
    .c0_ddr3_s_axi_awid(C0_DDR3_S_AXI.AWID),
    .c0_ddr3_s_axi_awaddr(C0_DDR3_S_AXI.AWADDR),
    .c0_ddr3_s_axi_awlen(C0_DDR3_S_AXI.AWLEN),
    .c0_ddr3_s_axi_awsize(C0_DDR3_S_AXI.AWSIZE),
    .c0_ddr3_s_axi_awburst(C0_DDR3_S_AXI.AWBURST),
    .c0_ddr3_s_axi_awlock(C0_DDR3_S_AXI.AWLOCK),
    .c0_ddr3_s_axi_awcache(C0_DDR3_S_AXI.AWCACHE),
    .c0_ddr3_s_axi_awprot(C0_DDR3_S_AXI.AWPROT),
    .c0_ddr3_s_axi_awqos(C0_DDR3_S_AXI.AWQOS),
    .c0_ddr3_s_axi_awvalid(C0_DDR3_S_AXI.AWVALID),
    .c0_ddr3_s_axi_awready(C0_DDR3_S_AXI.AWREADY),
    .c0_ddr3_s_axi_wdata(C0_DDR3_S_AXI.WDATA),
    .c0_ddr3_s_axi_wstrb(C0_DDR3_S_AXI.WSTRB),
    .c0_ddr3_s_axi_wlast(C0_DDR3_S_AXI.WLAST),
    .c0_ddr3_s_axi_wvalid(C0_DDR3_S_AXI.WVALID),
    .c0_ddr3_s_axi_wready(C0_DDR3_S_AXI.WREADY),
    .c0_ddr3_s_axi_bready(C0_DDR3_S_AXI.BREADY),
    .c0_ddr3_s_axi_bid(C0_DDR3_S_AXI.BID),
    .c0_ddr3_s_axi_bresp(C0_DDR3_S_AXI.BRESP),
    .c0_ddr3_s_axi_bvalid(C0_DDR3_S_AXI.BVALID),
    .c0_ddr3_s_axi_arid(C0_DDR3_S_AXI.ARID),
    .c0_ddr3_s_axi_araddr(C0_DDR3_S_AXI.ARADDR),
    .c0_ddr3_s_axi_arlen(C0_DDR3_S_AXI.ARLEN),
    .c0_ddr3_s_axi_arsize(C0_DDR3_S_AXI.ARSIZE),
    .c0_ddr3_s_axi_arburst(C0_DDR3_S_AXI.ARBURST),
    .c0_ddr3_s_axi_arlock(C0_DDR3_S_AXI.ARLOCK),
    .c0_ddr3_s_axi_arcache(C0_DDR3_S_AXI.ARCACHE),
    .c0_ddr3_s_axi_arprot(C0_DDR3_S_AXI.ARPROT),
    .c0_ddr3_s_axi_arqos(C0_DDR3_S_AXI.ARQOS),
    .c0_ddr3_s_axi_arvalid(C0_DDR3_S_AXI.ARVALID),
    .c0_ddr3_s_axi_arready(C0_DDR3_S_AXI.ARREADY),
    .c0_ddr3_s_axi_rready(C0_DDR3_S_AXI.RREADY),
    .c0_ddr3_s_axi_rlast(C0_DDR3_S_AXI.RLAST),
    .c0_ddr3_s_axi_rvalid(C0_DDR3_S_AXI.RVALID),
    .c0_ddr3_s_axi_rresp(C0_DDR3_S_AXI.RRESP),
    .c0_ddr3_s_axi_rid(C0_DDR3_S_AXI.RID),
    .c0_ddr3_s_axi_rdata(C0_DDR3_S_AXI.RDATA),
    .sys_rst(sys_rst)
  );

endmodule
