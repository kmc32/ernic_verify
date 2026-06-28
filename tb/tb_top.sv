// Testbench top — instantiates ERNIC IP and connects UVM interfaces
`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

// Import all UVM env/test packages
`include "uvm/interface/axi_lite_if.sv"
`include "uvm/interface/axis_if.sv"
`include "uvm/interface/axi4_if.sv"
`include "uvm/agent/axi_lite/axi_lite_item.sv"
`include "uvm/agent/axi_lite/axi_lite_monitor.sv"
`include "uvm/agent/axi_lite/axi_lite_driver.sv"
`include "uvm/agent/axi_lite/axi_lite_agent.sv"
`include "uvm/agent/axis/axis_item.sv"
`include "uvm/agent/axis/axis_monitor.sv"
`include "uvm/agent/axis/axis_driver.sv"
`include "uvm/agent/axis/axis_agent.sv"
`include "uvm/agent/axi4/axi4_mem_model.sv"
`include "uvm/seq/ernic_csr.svh"
`include "uvm/seq/ernic_base_seq.sv"
`include "uvm/seq/qp_setup_seq.sv"
`include "uvm/seq/rdma_write_seq.sv"
`include "uvm/seq/rdma_read_seq.sv"
`include "uvm/seq/send_recv_seq.sv"
`include "uvm/seq/exdes_full_config_seq.sv"
`include "uvm/seq/check_regs_seq.sv"
`include "uvm/env/ernic_scoreboard.sv"
`include "uvm/env/ernic_env.sv"
`include "uvm/test/ernic_base_test.sv"
`include "uvm/test/ernic_csr_test.sv"
`include "uvm/test/ernic_rdma_write_test.sv"
`include "uvm/test/ernic_rdma_read_test.sv"
`include "uvm/test/ernic_send_recv_test.sv"
`include "uvm/test/ernic_reliable_transport_test.sv"

module tb_top;
    // ----------------------------------------------------------------
    // Clock & reset
    // ----------------------------------------------------------------
    logic clk   = 0;
    logic rst_n = 0;
    always #10 clk = ~clk;   // 50 MHz — matching example design
    initial begin
        automatic string test_name;
        if (!$value$plusargs("UVM_TESTNAME=%s", test_name))
            test_name = "unknown_test";
        $fsdbDumpfile($sformatf("build/%s.fsdb", test_name));
        $fsdbDumpvars(0, tb_top);
        // Reset: 400ns active — matching example design
        #400 rst_n = 1;
    end

    // ----------------------------------------------------------------
    // Interfaces
    // ----------------------------------------------------------------
    axi_lite_if  #(.AW(32), .DW(32))   csr_if  (.clk(clk), .rst_n(rst_n));
    axis_if      #(.DW(512))            net_tx  (.clk(clk), .rst_n(rst_n));  // ERNIC -> network
    axis_if      #(.DW(512))            net_rx  (.clk(clk), .rst_n(rst_n));  // network -> ERNIC
    // ERNIC AXI4 masters use 32-bit addresses; pad to 64-bit for UVM env
    axi4_if      #(.AW(64), .DW(512))   mem_if      (.clk(clk), .rst_n(rst_n));
    axi4_if      #(.AW(64), .DW(512))   wqe_mem_if  (.clk(clk), .rst_n(rst_n));
    axi4_if      #(.AW(64), .DW(512))   qp_mem_if   (.clk(clk), .rst_n(rst_n));
    axi4_if      #(.AW(64), .DW(512))   resp_mem_if (.clk(clk), .rst_n(rst_n));

    // ----------------------------------------------------------------
    // ERNIC v4.0 tie-off wires for unused ports
    // ----------------------------------------------------------------
    // Unused AXI4 master interfaces — tie off AW/AR ready and W ready
    logic [0:0]  tie_awready = 1'b1;
    logic        tie_wready  = 1'b1;
    logic [0:0]  tie_bid     = 1'b0;
    logic [1:0]  tie_bresp   = 2'b0;
    logic        tie_bvalid  = 1'b1;
    logic [0:0]  tie_arready = 1'b1;
    logic [0:0]  tie_rid     = 1'b0;
    logic [511:0] tie_rdata  = 512'b0;
    logic [1:0]  tie_rresp   = 2'b0;
    logic        tie_rlast   = 1'b1;
    logic        tie_rvalid  = 1'b1;

    // Unused AXI4-Stream RX inputs
    logic        tie_s_axis_tvalid = 1'b0;
    logic [511:0] tie_s_axis_tdata = 512'b0;
    logic [63:0]  tie_s_axis_tkeep = 64'b0;
    logic         tie_s_axis_tlast = 1'b0;

    // Handshake tie-offs — drive ready signals high so ERNIC's internal
    // pipelines can complete their handshakes. With these at 0, ERNIC stalls
    // after WQE fetch (the response handler blocks on CQ DB acknowledgment).
    logic        tie_resp_hndler_i_send_cq_db_rdy = 1'b1;
    logic [15:0] tie_i_qp_rq_cidb_hndshk = 16'b0;
    logic [31:0] tie_i_qp_rq_cidb_wr_addr_hndshk = 32'b0;
    logic        tie_i_qp_rq_cidb_wr_valid_hndshk = 1'b0;
    logic        tie_rx_pkt_hndler_i_rq_db_rdy = 1'b1;
    logic        tie_ieth_immdt_axis_trdy = 1'b1;  // must be 1 (example design)
    logic [8:0]  tie_stat_rx_pause_req = 9'b0;

    // Debug probe wires (for TX-side diagnostic)
    wire        dbg_cq_db_cnt_valid;
    wire        dbg_rq_db_data_valid;
    wire        dbg_ieth_tvalid;
    wire        dbg_rnic_intr;
    wire        dbg_system_resetn;

    // SQ PIDB doorbell generator (driven on AXI-Lite write to DOORBELL)
    logic [15:0] pidb_hndshk;
    logic [31:0] pidb_wr_addr;
    logic        pidb_valid;
    logic        pidb_rdy;

    // ----------------------------------------------------------------
    // DUT — Xilinx ERNIC v4.0
    // ----------------------------------------------------------------
    ernic_v4_0 dut (
        // ============================================================
        // Clocks — all driven by single testbench clock
        // ============================================================
        .m_axi_aclk                  (clk),
        .cmac_rx_clk                 (clk),
        .cmac_tx_clk                 (clk),
        .s_axi_lite_aclk             (clk),

        // ============================================================
        // Resets
        // ============================================================
        .cmac_rx_rst                 (~rst_n),   // active high
        .cmac_tx_rst                 (~rst_n),
        .m_axi_aresetn               (rst_n),
        .s_axi_lite_aresetn          (rst_n),
        .system_resetn               (dbg_system_resetn),

        // ============================================================
        // AXI-Lite CSR (slave)
        // ============================================================
        .s_axi_lite_awaddr           (csr_if.awaddr),
        .s_axi_lite_awvalid          (csr_if.awvalid),
        .s_axi_lite_awready          (csr_if.awready),
        .s_axi_lite_wdata            (csr_if.wdata),
        .s_axi_lite_wstrb            (csr_if.wstrb),
        .s_axi_lite_wvalid           (csr_if.wvalid),
        .s_axi_lite_wready           (csr_if.wready),
        .s_axi_lite_bresp            (csr_if.bresp),
        .s_axi_lite_bvalid           (csr_if.bvalid),
        .s_axi_lite_bready           (csr_if.bready),
        .s_axi_lite_araddr           (csr_if.araddr),
        .s_axi_lite_arvalid          (csr_if.arvalid),
        .s_axi_lite_arready          (csr_if.arready),
        .s_axi_lite_rdata            (csr_if.rdata),
        .s_axi_lite_rresp            (csr_if.rresp),
        .s_axi_lite_rvalid           (csr_if.rvalid),
        .s_axi_lite_rready           (csr_if.rready),

        // ============================================================
        // CMAC AXI4-Stream TX (ERNIC -> MAC)
        // ============================================================
        .cmac_m_axis_tdata           (net_tx.tdata),
        .cmac_m_axis_tkeep           (net_tx.tkeep),
        .cmac_m_axis_tvalid          (net_tx.tvalid),
        .cmac_m_axis_tready          (net_tx.tready),
        .cmac_m_axis_tlast           (net_tx.tlast),

        // ============================================================
        // CMAC AXI4-Stream RX: RoCE path (MAC -> ERNIC)
        // ============================================================
        .roce_cmac_s_axis_tvalid     (net_rx.tvalid),
        .roce_cmac_s_axis_tdata      (net_rx.tdata),
        .roce_cmac_s_axis_tkeep      (net_rx.tkeep),
        .roce_cmac_s_axis_tlast      (net_rx.tlast),
        .roce_cmac_s_axis_tuser      (net_rx.tuser),

        // ============================================================
        // AXI4 Memory: RX Packet Handler DDR (master)
        // — primary memory interface, pads 32→64 bit address
        // ============================================================
        .rx_pkt_hndler_ddr_m_axi_awid    (mem_if.awid[0]),
        .rx_pkt_hndler_ddr_m_axi_awaddr  (mem_if.awaddr[31:0]),
        .rx_pkt_hndler_ddr_m_axi_awlen   (mem_if.awlen),
        .rx_pkt_hndler_ddr_m_axi_awsize  (mem_if.awsize),
        .rx_pkt_hndler_ddr_m_axi_awburst (mem_if.awburst),
        .rx_pkt_hndler_ddr_m_axi_awvalid (mem_if.awvalid),
        .rx_pkt_hndler_ddr_m_axi_awready (mem_if.awready),
        .rx_pkt_hndler_ddr_m_axi_wdata   (mem_if.wdata),
        .rx_pkt_hndler_ddr_m_axi_wstrb   (mem_if.wstrb),
        .rx_pkt_hndler_ddr_m_axi_wlast   (mem_if.wlast),
        .rx_pkt_hndler_ddr_m_axi_wvalid  (mem_if.wvalid),
        .rx_pkt_hndler_ddr_m_axi_wready  (mem_if.wready),
        .rx_pkt_hndler_ddr_m_axi_bid     (mem_if.bid[0]),
        .rx_pkt_hndler_ddr_m_axi_bresp   (mem_if.bresp),
        .rx_pkt_hndler_ddr_m_axi_bvalid  (mem_if.bvalid),
        .rx_pkt_hndler_ddr_m_axi_bready  (mem_if.bready),
        .rx_pkt_hndler_ddr_m_axi_arid    (mem_if.arid[0]),
        .rx_pkt_hndler_ddr_m_axi_araddr  (mem_if.araddr[31:0]),
        .rx_pkt_hndler_ddr_m_axi_arlen   (mem_if.arlen),
        .rx_pkt_hndler_ddr_m_axi_arsize  (mem_if.arsize),
        .rx_pkt_hndler_ddr_m_axi_arburst (mem_if.arburst),
        .rx_pkt_hndler_ddr_m_axi_arvalid (mem_if.arvalid),
        .rx_pkt_hndler_ddr_m_axi_arready (mem_if.arready),
        .rx_pkt_hndler_ddr_m_axi_rid     (mem_if.rid[0]),
        .rx_pkt_hndler_ddr_m_axi_rdata   (mem_if.rdata),
        .rx_pkt_hndler_ddr_m_axi_rresp   (mem_if.rresp),
        .rx_pkt_hndler_ddr_m_axi_rlast   (mem_if.rlast),
        .rx_pkt_hndler_ddr_m_axi_rvalid  (mem_if.rvalid),
        .rx_pkt_hndler_ddr_m_axi_rready  (mem_if.rready),
        // Unused AXI4 sideband signals
        .rx_pkt_hndler_ddr_m_axi_awuser  (),
        .rx_pkt_hndler_ddr_m_axi_awcache (),
        .rx_pkt_hndler_ddr_m_axi_awprot  (),
        .rx_pkt_hndler_ddr_m_axi_awlock  (),
        .rx_pkt_hndler_ddr_m_axi_arcache (),
        .rx_pkt_hndler_ddr_m_axi_arprot  (),
        .rx_pkt_hndler_ddr_m_axi_arlock  (),

        // ============================================================
        // Pad upper 32 bits of 64-bit mem_if addresses to zero
        // ============================================================


        // ============================================================
        // Unused AXI4 master: RX packet handler read response
        // ============================================================
        .rx_pkt_hndler_rdrsp_m_axi_awid    (),
        .rx_pkt_hndler_rdrsp_m_axi_awaddr  (),
        .rx_pkt_hndler_rdrsp_m_axi_awlen   (),
        .rx_pkt_hndler_rdrsp_m_axi_awsize  (),
        .rx_pkt_hndler_rdrsp_m_axi_awburst (),
        .rx_pkt_hndler_rdrsp_m_axi_awcache (),
        .rx_pkt_hndler_rdrsp_m_axi_awprot  (),
        .rx_pkt_hndler_rdrsp_m_axi_awvalid (),
        .rx_pkt_hndler_rdrsp_m_axi_awready (tie_awready),
        .rx_pkt_hndler_rdrsp_m_axi_wdata   (),
        .rx_pkt_hndler_rdrsp_m_axi_wstrb   (),
        .rx_pkt_hndler_rdrsp_m_axi_wlast   (),
        .rx_pkt_hndler_rdrsp_m_axi_wvalid  (),
        .rx_pkt_hndler_rdrsp_m_axi_wready  (tie_wready),
        .rx_pkt_hndler_rdrsp_m_axi_awlock  (),
        .rx_pkt_hndler_rdrsp_m_axi_bid     (tie_bid),
        .rx_pkt_hndler_rdrsp_m_axi_bresp   (tie_bresp),
        .rx_pkt_hndler_rdrsp_m_axi_bvalid  (tie_bvalid),
        .rx_pkt_hndler_rdrsp_m_axi_bready  (),
        .rx_pkt_hndler_rdrsp_m_axi_arid    (),
        .rx_pkt_hndler_rdrsp_m_axi_araddr  (),
        .rx_pkt_hndler_rdrsp_m_axi_arlen   (),
        .rx_pkt_hndler_rdrsp_m_axi_arsize  (),
        .rx_pkt_hndler_rdrsp_m_axi_arburst (),
        .rx_pkt_hndler_rdrsp_m_axi_arcache (),
        .rx_pkt_hndler_rdrsp_m_axi_arprot  (),
        .rx_pkt_hndler_rdrsp_m_axi_arvalid (),
        .rx_pkt_hndler_rdrsp_m_axi_arready (tie_arready),
        .rx_pkt_hndler_rdrsp_m_axi_rid     (tie_rid),
        .rx_pkt_hndler_rdrsp_m_axi_rdata   (tie_rdata),
        .rx_pkt_hndler_rdrsp_m_axi_rresp   (tie_rresp),
        .rx_pkt_hndler_rdrsp_m_axi_rlast   (tie_rlast),
        .rx_pkt_hndler_rdrsp_m_axi_rvalid  (tie_rvalid),
        .rx_pkt_hndler_rdrsp_m_axi_rready  (),
        .rx_pkt_hndler_rdrsp_m_axi_arlock  (),

        // ============================================================
        // AXI4 master: WQE processor — connected to shared memory
        // ============================================================
        .wqe_proc_top_m_axi_awid    (wqe_mem_if.awid[0]),
        .wqe_proc_top_m_axi_awaddr  (wqe_mem_if.awaddr[31:0]),
        .wqe_proc_top_m_axi_awlen   (wqe_mem_if.awlen),
        .wqe_proc_top_m_axi_awsize  (wqe_mem_if.awsize),
        .wqe_proc_top_m_axi_awburst (wqe_mem_if.awburst),
        .wqe_proc_top_m_axi_awcache (),
        .wqe_proc_top_m_axi_awprot  (),
        .wqe_proc_top_m_axi_awvalid (wqe_mem_if.awvalid),
        .wqe_proc_top_m_axi_awready (wqe_mem_if.awready),
        .wqe_proc_top_m_axi_wdata   (wqe_mem_if.wdata),
        .wqe_proc_top_m_axi_wstrb   (wqe_mem_if.wstrb),
        .wqe_proc_top_m_axi_wlast   (wqe_mem_if.wlast),
        .wqe_proc_top_m_axi_wvalid  (wqe_mem_if.wvalid),
        .wqe_proc_top_m_axi_wready  (wqe_mem_if.wready),
        .wqe_proc_top_m_axi_awlock  (),
        .wqe_proc_top_m_axi_bid     (wqe_mem_if.bid[0]),
        .wqe_proc_top_m_axi_bresp   (wqe_mem_if.bresp),
        .wqe_proc_top_m_axi_bvalid  (wqe_mem_if.bvalid),
        .wqe_proc_top_m_axi_bready  (wqe_mem_if.bready),
        .wqe_proc_top_m_axi_arid    (wqe_mem_if.arid[0]),
        .wqe_proc_top_m_axi_araddr  (wqe_mem_if.araddr[31:0]),
        .wqe_proc_top_m_axi_arlen   (wqe_mem_if.arlen),
        .wqe_proc_top_m_axi_arsize  (wqe_mem_if.arsize),
        .wqe_proc_top_m_axi_arburst (wqe_mem_if.arburst),
        .wqe_proc_top_m_axi_arcache (),
        .wqe_proc_top_m_axi_arprot  (),
        .wqe_proc_top_m_axi_arvalid (wqe_mem_if.arvalid),
        .wqe_proc_top_m_axi_arready (wqe_mem_if.arready),
        .wqe_proc_top_m_axi_rid     (wqe_mem_if.rid[0]),
        .wqe_proc_top_m_axi_rdata   (wqe_mem_if.rdata),
        .wqe_proc_top_m_axi_rresp   (wqe_mem_if.rresp),
        .wqe_proc_top_m_axi_rlast   (wqe_mem_if.rlast),
        .wqe_proc_top_m_axi_rvalid  (wqe_mem_if.rvalid),
        .wqe_proc_top_m_axi_rready  (wqe_mem_if.rready),
        .wqe_proc_top_m_axi_arlock  (),

        // ============================================================
        // AXI4 master: Response handler — connected to shared memory
        // ============================================================
        .resp_hndler_m_axi_awid    (resp_mem_if.awid[0]),
        .resp_hndler_m_axi_awaddr  (resp_mem_if.awaddr[31:0]),
        .resp_hndler_m_axi_awlen   (resp_mem_if.awlen),
        .resp_hndler_m_axi_awsize  (resp_mem_if.awsize),
        .resp_hndler_m_axi_awburst (resp_mem_if.awburst),
        .resp_hndler_m_axi_awcache (),
        .resp_hndler_m_axi_awprot  (),
        .resp_hndler_m_axi_awvalid (resp_mem_if.awvalid),
        .resp_hndler_m_axi_awready (resp_mem_if.awready),
        .resp_hndler_m_axi_wdata   (resp_mem_if.wdata),
        .resp_hndler_m_axi_wstrb   (resp_mem_if.wstrb),
        .resp_hndler_m_axi_wlast   (resp_mem_if.wlast),
        .resp_hndler_m_axi_wvalid  (resp_mem_if.wvalid),
        .resp_hndler_m_axi_wready  (resp_mem_if.wready),
        .resp_hndler_m_axi_awlock  (),
        .resp_hndler_m_axi_bid     (resp_mem_if.bid[0]),
        .resp_hndler_m_axi_bresp   (resp_mem_if.bresp),
        .resp_hndler_m_axi_bvalid  (resp_mem_if.bvalid),
        .resp_hndler_m_axi_bready  (resp_mem_if.bready),
        .resp_hndler_m_axi_arid    (resp_mem_if.arid[0]),
        .resp_hndler_m_axi_araddr  (resp_mem_if.araddr[31:0]),
        .resp_hndler_m_axi_arlen   (resp_mem_if.arlen),
        .resp_hndler_m_axi_arsize  (resp_mem_if.arsize),
        .resp_hndler_m_axi_arburst (resp_mem_if.arburst),
        .resp_hndler_m_axi_arcache (),
        .resp_hndler_m_axi_arprot  (),
        .resp_hndler_m_axi_arvalid (resp_mem_if.arvalid),
        .resp_hndler_m_axi_arready (resp_mem_if.arready),
        .resp_hndler_m_axi_rid     (resp_mem_if.rid[0]),
        .resp_hndler_m_axi_rdata   (resp_mem_if.rdata),
        .resp_hndler_m_axi_rresp   (resp_mem_if.rresp),
        .resp_hndler_m_axi_rlast   (resp_mem_if.rlast),
        .resp_hndler_m_axi_rvalid  (resp_mem_if.rvalid),
        .resp_hndler_m_axi_rready  (resp_mem_if.rready),
        .resp_hndler_m_axi_arlock  (),

        // ============================================================
        // AXI4 master: QP Manager — connected to shared memory
        // ============================================================
        .qp_mgr_m_axi_awid    (qp_mem_if.awid[0]),
        .qp_mgr_m_axi_awaddr  (qp_mem_if.awaddr[31:0]),
        .qp_mgr_m_axi_awlen   (qp_mem_if.awlen),
        .qp_mgr_m_axi_awsize  (qp_mem_if.awsize),
        .qp_mgr_m_axi_awburst (qp_mem_if.awburst),
        .qp_mgr_m_axi_awcache (),
        .qp_mgr_m_axi_awprot  (),
        .qp_mgr_m_axi_awvalid (qp_mem_if.awvalid),
        .qp_mgr_m_axi_awready (qp_mem_if.awready),
        .qp_mgr_m_axi_wdata   (qp_mem_if.wdata),
        .qp_mgr_m_axi_wstrb   (qp_mem_if.wstrb),
        .qp_mgr_m_axi_wlast   (qp_mem_if.wlast),
        .qp_mgr_m_axi_wvalid  (qp_mem_if.wvalid),
        .qp_mgr_m_axi_wready  (qp_mem_if.wready),
        .qp_mgr_m_axi_awlock  (),
        .qp_mgr_m_axi_bid     (qp_mem_if.bid[0]),
        .qp_mgr_m_axi_bresp   (qp_mem_if.bresp),
        .qp_mgr_m_axi_bvalid  (qp_mem_if.bvalid),
        .qp_mgr_m_axi_bready  (qp_mem_if.bready),
        .qp_mgr_m_axi_arid    (qp_mem_if.arid[0]),
        .qp_mgr_m_axi_araddr  (qp_mem_if.araddr[31:0]),
        .qp_mgr_m_axi_arlen   (qp_mem_if.arlen),
        .qp_mgr_m_axi_arsize  (qp_mem_if.arsize),
        .qp_mgr_m_axi_arburst (qp_mem_if.arburst),
        .qp_mgr_m_axi_arcache (),
        .qp_mgr_m_axi_arprot  (),
        .qp_mgr_m_axi_arvalid (qp_mem_if.arvalid),
        .qp_mgr_m_axi_arready (qp_mem_if.arready),
        .qp_mgr_m_axi_rid     (qp_mem_if.rid[0]),
        .qp_mgr_m_axi_rdata   (qp_mem_if.rdata),
        .qp_mgr_m_axi_rresp   (qp_mem_if.rresp),
        .qp_mgr_m_axi_rlast   (qp_mem_if.rlast),
        .qp_mgr_m_axi_rvalid  (qp_mem_if.rvalid),
        .qp_mgr_m_axi_rready  (qp_mem_if.rready),
        .qp_mgr_m_axi_arlock  (),

        // ============================================================
        // Unused AXI4-Stream RX: non-RoCE paths
        // ============================================================
        .non_roce_cmac_s_axis_tvalid  (tie_s_axis_tvalid),
        .non_roce_cmac_s_axis_tdata   (tie_s_axis_tdata),
        .non_roce_cmac_s_axis_tkeep   (tie_s_axis_tkeep),
        .non_roce_cmac_s_axis_tlast   (tie_s_axis_tlast),
        .non_roce_cmac_s_axis_tuser   (),

        .non_roce_dma_s_axis_tvalid   (tie_s_axis_tvalid),
        .non_roce_dma_s_axis_tdata    (tie_s_axis_tdata),
        .non_roce_dma_s_axis_tkeep    (tie_s_axis_tkeep),
        .non_roce_dma_s_axis_tlast    (tie_s_axis_tlast),
        .non_roce_dma_s_axis_tready   (),

        // ============================================================
        // Unused AXI4-Stream TX: non-RoCE DMA
        // ============================================================
        .non_roce_dma_m_axis_tdata    (),
        .non_roce_dma_m_axis_tkeep    (),
        .non_roce_dma_m_axis_tvalid   (),
        .non_roce_dma_m_axis_tready   (1'b0),  // tie low per example design
        .non_roce_dma_m_axis_tlast    (),

        // ============================================================
        // Handshake / debug interfaces — tied off
        // ============================================================
        .resp_hndler_o_send_cq_db_cnt_valid (dbg_cq_db_cnt_valid),
        .resp_hndler_o_send_cq_db_addr      (),
        .resp_hndler_o_send_cq_db_cnt       (),
        .resp_hndler_i_send_cq_db_rdy       (tie_resp_hndler_i_send_cq_db_rdy),

        .i_qp_rq_cidb_hndshk           (tie_i_qp_rq_cidb_hndshk),
        .i_qp_rq_cidb_wr_addr_hndshk   (tie_i_qp_rq_cidb_wr_addr_hndshk),
        .i_qp_rq_cidb_wr_valid_hndshk  (tie_i_qp_rq_cidb_wr_valid_hndshk),
        .o_qp_rq_cidb_wr_rdy           (),

        // PIDB disabled — matching example design (tied to 0)
        // Doorbell delivered via AXI-Lite SQPI write directly
        .i_qp_sq_pidb_hndshk           (16'd0),
        .i_qp_sq_pidb_wr_addr_hndshk   (32'd0),
        .i_qp_sq_pidb_wr_valid_hndshk  (1'b0),
        .o_qp_sq_pidb_wr_rdy           (),

        .rx_pkt_hndler_o_rq_db_data        (),
        .rx_pkt_hndler_o_rq_db_addr        (),
        .rx_pkt_hndler_o_rq_db_data_valid  (dbg_rq_db_data_valid),
        .rx_pkt_hndler_i_rq_db_rdy         (tie_rx_pkt_hndler_i_rq_db_rdy),

        .rnic_intr                   (dbg_rnic_intr),
        .stat_rx_pause_req           (tie_stat_rx_pause_req),
        .ctl_tx_pause_req            (),
        .ctl_tx_resend_pause         (),
        .ieth_immdt_axis_tvalid      (dbg_ieth_tvalid),
        .ieth_immdt_axis_tlast       (),
        .ieth_immdt_axis_tdata       (),
        .ieth_immdt_axis_trdy        (tie_ieth_immdt_axis_trdy),
        .o_global_dbg_cnt_en         (),
        .o_global_dbg_cnt_clr        ()
    );

    // ----------------------------------------------------------------
    // Pad upper 32 bits of 64-bit mem_if address (ERNIC uses 32-bit)
    // ----------------------------------------------------------------
    assign mem_if.awaddr[63:32] = 32'b0;
    assign mem_if.araddr[63:32] = 32'b0;
    assign wqe_mem_if.awaddr[63:32] = 32'b0;
    assign wqe_mem_if.araddr[63:32] = 32'b0;
    assign qp_mem_if.awaddr[63:32] = 32'b0;
    assign qp_mem_if.araddr[63:32] = 32'b0;
    assign resp_mem_if.awaddr[63:32] = 32'b0;
    assign resp_mem_if.araddr[63:32] = 32'b0;

    // ----------------------------------------------------------------
    // UVM config DB — publish interfaces
    // ----------------------------------------------------------------
    initial begin
        uvm_config_db #(virtual axi_lite_if)::set(null, "uvm_test_top.env.csr_agt.*", "axi_lite_vif", csr_if);
        uvm_config_db #(virtual axis_if)::set(null, "uvm_test_top.env.tx_agt.*",      "axis_vif",     net_tx);
        uvm_config_db #(virtual axis_if)::set(null, "uvm_test_top.env.rx_agt.*",      "axis_vif",     net_rx);
        uvm_config_db #(virtual axi4_if)::set(null, "uvm_test_top.env.mem",           "axi4_vif",     mem_if);
        uvm_config_db #(virtual axi4_if)::set(null, "uvm_test_top.env.wqe_mem",       "axi4_vif",     wqe_mem_if);
        uvm_config_db #(virtual axi4_if)::set(null, "uvm_test_top.env.qp_mem",        "axi4_vif",     qp_mem_if);
        uvm_config_db #(virtual axi4_if)::set(null, "uvm_test_top.env.resp_mem",      "axi4_vif",     resp_mem_if);
        run_test();
    end

    // ----------------------------------------------------------------
    // TX loopback tready (always accept) when no RX driver is active
    // ----------------------------------------------------------------
    assign net_tx.tready = 1'b1;

    // Debug: log full TX beats, PIDB doorbell, and CQ DB so it's easy to see
    // whether ERNIC consumed the WQE and where TX (if any) lands.
    int tx_beat_n = 0;
    always @(posedge clk) begin
        if (net_tx.tvalid && net_tx.tready) begin
            $display("[%0t] TX_BEAT%0d tlast=%0b tkeep=0x%016h",
                     $time, tx_beat_n, net_tx.tlast, net_tx.tkeep);
            tx_beat_n = net_tx.tlast ? 0 : tx_beat_n + 1;
        end
        if (pidb_valid && pidb_rdy)
            $display("[%0t] PIDB_FIRE addr=0x%08h data=0x%04h", $time, pidb_wr_addr, pidb_hndshk);
        if (dbg_cq_db_cnt_valid)
            $display("[%0t] CQ_DB cnt_valid", $time);
    end

    // Extra TX probe: log any tvalid assertion (even without tready)
    always @(posedge clk) begin
        if (net_tx.tvalid !== 1'b0)
            $display("[%0t] TX_TVALID = %b (tready=%b)", $time, net_tx.tvalid, net_tx.tready);
        if (dbg_ieth_tvalid !== 1'b0)
            $display("[%0t] IETH_TVALID = %b", $time, dbg_ieth_tvalid);
    end

    // Interrupt probe
    always @(posedge clk) begin
        if (dbg_rnic_intr !== 1'b0)
            $display("[%0t] RNIC_INTR = %b", $time, dbg_rnic_intr);
    end

    // ----------------------------------------------------------------
    // conf_of_reg_done: asserted after register config completes
    // Register config takes ~79us; assert at 85us to be safe.
    // ----------------------------------------------------------------
    logic conf_of_reg_done;
    int   cfg_timer;
    always @(posedge clk) begin
        if (!rst_n) begin
            conf_of_reg_done <= 1'b0;
            cfg_timer <= 0;
        end else if (!conf_of_reg_done) begin
            if (cfg_timer < 4000)  // 80us at 50MHz (20ns*4000=80us)
                cfg_timer <= cfg_timer + 1;
            else
                conf_of_reg_done <= 1'b1;
        end
    end

    // ----------------------------------------------------------------
    // Responder module — provides remote-side ACK/ReadResponse packets
    // ----------------------------------------------------------------
    wire [511:0] resp_tx_tdata;
    wire [63:0]  resp_tx_tkeep;
    wire         resp_tx_tvalid, resp_tx_tlast;
    wire         resp_post_wr, resp_post_rd;
    wire         resp_rdma_snd_done;

    // Debug: print responder activity
    always @(posedge clk) begin
        if (resp_tx_tvalid)
            $display("[%0t] RESP_TX tlast=%0b tkeep=0x%016h", $time, resp_tx_tlast, resp_tx_tkeep);
        if (conf_of_reg_done)
            $display("[%0t] CONF_OF_REG_DONE", $time);
        if (resp_rdma_snd_done)
            $display("[%0t] RDMA_SND_TST_DONE", $time);
        if (resp_post_wr)
            $display("[%0t] RESP_POST_WR_WQE", $time);
        if (resp_post_rd)
            $display("[%0t] RESP_POST_RD_WQE", $time);
    end

    exdes_send_rdresp_ack_pkt_gen responder_inst (
        .core_clk                     (clk),
        .core_aresetn                 (rst_n),
        .tx_m_axis_tready_send_tst    (1'b1),
        .tx_m_axis_tdata_send_test    (resp_tx_tdata),
        .tx_m_axis_tkeep_send_test    (resp_tx_tkeep),
        .tx_m_axis_tvalid_send_test   (resp_tx_tvalid),
        .tx_m_axis_tlast_send_test    (resp_tx_tlast),
        .conf_of_reg_done             (conf_of_reg_done),

        .MAC_SRC_ADDR_LSB             (32'h17dc5e9a),
        .MAC_SRC_ADDR_MSB             (32'h00002f76),
        // Wire QP3 with same params as QP2 so responder's initial WRITE
        // phase (which targets QP3 first) generates valid packets
        .IP4H_QP3_SRC_ADDR_1          (32'hf38590ba),
        .IP4H_QP3_DEST_ADDR_1         (32'h610c6007),
        .QP3_MAC_DEST_ADDR_LSB        (32'h50560f2e),
        .QP3_MAC_DEST_ADDR_MSB        (32'h000016c4),
        .QP3_PSN                      (32'h00004470),

        .QP2_MAC_DEST_ADDR_LSB        (32'h50560f2e),
        .QP2_MAC_DEST_ADDR_MSB        (32'h000016c4),
        .IP4H_QP2_DEST_ADDR_1         (32'h610c6007),
        .IP4H_QP2_SRC_ADDR_1          (32'hf38590ba),
        .QP2_PSN                      (32'h00774470),

        .QP4_MAC_DEST_ADDR_LSB        (32'h00000000),
        .QP4_MAC_DEST_ADDR_MSB        (32'h00000000),
        .IP4H_QP4_DEST_ADDR_1         (32'h00000000),
        .QP4_PSN                      (32'h00000000),

        .QP5_MAC_DEST_ADDR_LSB        (32'h00000000),
        .QP5_MAC_DEST_ADDR_MSB        (32'h00000000),
        .IP4H_QP5_DEST_ADDR_1         (32'h00000000),
        .QP5_PSN                      (32'h00000000),

        .QP6_MAC_DEST_ADDR_LSB        (32'h00000000),
        .QP6_MAC_DEST_ADDR_MSB        (32'h00000000),
        .IP4H_QP6_DEST_ADDR_1         (32'h00000000),
        .QP6_PSN                      (32'h00000000),

        .QP7_MAC_DEST_ADDR_LSB        (32'h00000000),
        .QP7_MAC_DEST_ADDR_MSB        (32'h00000000),
        .IP4H_QP7_DEST_ADDR_1         (32'h00000000),
        .QP7_PSN                      (32'h00000000),

        .wqe_proc_top_m_axis_tdata    (net_tx.tdata),
        .wqe_proc_top_m_axis_tvalid   (net_tx.tvalid),
        .wqe_proc_top_m_axis_tlast    (net_tx.tlast),
        .write_pkt_psn                (),
        .post_rdma_rd_wqe             (resp_post_rd),
        .post_rdma_wr_wqe             (resp_post_wr),
        .rdma_write_path_done         (),
        .rdma_read_path_done          (),
        .rdma_write_test_done_i       (),
        .rdma_rdrq_test_done_i        (),
        .RDMA_SND_TST_DONE            (resp_rdma_snd_done)
    );

    // ----------------------------------------------------------------
    // RX path: loopback OR responder response
    // ----------------------------------------------------------------
    assign net_rx.tvalid = resp_tx_tvalid ? resp_tx_tvalid : net_tx.tvalid;
    assign net_rx.tdata  = resp_tx_tvalid ? resp_tx_tdata  : net_tx.tdata;
    assign net_rx.tkeep  = resp_tx_tvalid ? resp_tx_tkeep  : net_tx.tkeep;
    assign net_rx.tlast  = resp_tx_tvalid ? resp_tx_tlast  : net_tx.tlast;
    assign net_rx.tuser  = 1'b0;

    // ERNIC system_resetn — pull up (output may be open-drain)
    pullup (dbg_system_resetn);

    // ----------------------------------------------------------------
    // PIDB doorbell generator — bridges AXI-Lite SQPI writes (offset 0x38
    // within per-QP space at 0x0018_xxxx) to ERNIC's native PIDB handshake.
    // Required when QPCONF[4]=0 (HW handshake enabled) — otherwise ERNIC
    // never receives a doorbell and never produces TX.
    // ----------------------------------------------------------------
    logic [31:0] db_pidb_addr;
    logic [15:0] db_pidb_data;
    logic        db_pidb_pend;

    initial begin
        pidb_hndshk  = 16'b0;
        pidb_wr_addr = 32'b0;
        pidb_valid   = 1'b0;
        db_pidb_pend = 1'b0;
    end

    // Stage 1: latch doorbell info on AW+W phase
    always @(posedge clk) begin
        if (csr_if.awvalid && csr_if.awready &&
            csr_if.awaddr[7:0] == 8'h38 &&
            csr_if.awaddr[23:16] == 8'h18) begin
            db_pidb_addr <= csr_if.awaddr;
            db_pidb_data <= csr_if.wdata[15:0];
            db_pidb_pend <= 1'b1;
        end
        if (pidb_valid && pidb_rdy)
            db_pidb_pend <= 1'b0;
    end

    // Stage 2: drive PIDB handshake when AXI-Lite write completes (B response)
    always @(posedge clk) begin
        if (db_pidb_pend && csr_if.bvalid && csr_if.bready) begin
            pidb_hndshk  <= db_pidb_data;
            pidb_wr_addr <= db_pidb_addr;
            pidb_valid   <= 1'b1;
            @(posedge clk iff pidb_rdy);
            pidb_valid   <= 1'b0;
        end
    end

endmodule
