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
    always #5 clk = ~clk;   // 100 MHz
    initial begin
        #100 rst_n = 1;
    end

    // ----------------------------------------------------------------
    // Interfaces
    // ----------------------------------------------------------------
    axi_lite_if  #(.AW(32), .DW(32))   csr_if  (.clk(clk), .rst_n(rst_n));
    axis_if      #(.DW(512))            net_tx  (.clk(clk), .rst_n(rst_n));  // ERNIC -> network
    axis_if      #(.DW(512))            net_rx  (.clk(clk), .rst_n(rst_n));  // network -> ERNIC
    axi4_if      #(.AW(64), .DW(512))   mem_if  (.clk(clk), .rst_n(rst_n));

    // ----------------------------------------------------------------
    // DUT — Xilinx ERNIC v4.0 (encrypted IP, pre-compiled via gen_ip.tcl)
    // ----------------------------------------------------------------
    ernic_v4_0 dut (
        // Clocks / resets
        .aclk                    (clk),
        .aresetn                 (rst_n),

        // AXI-Lite CSR
        .s_axi_awaddr            (csr_if.awaddr),
        .s_axi_awprot            (csr_if.awprot),
        .s_axi_awvalid           (csr_if.awvalid),
        .s_axi_awready           (csr_if.awready),
        .s_axi_wdata             (csr_if.wdata),
        .s_axi_wstrb             (csr_if.wstrb),
        .s_axi_wvalid            (csr_if.wvalid),
        .s_axi_wready            (csr_if.wready),
        .s_axi_bresp             (csr_if.bresp),
        .s_axi_bvalid            (csr_if.bvalid),
        .s_axi_bready            (csr_if.bready),
        .s_axi_araddr            (csr_if.araddr),
        .s_axi_arprot            (csr_if.arprot),
        .s_axi_arvalid           (csr_if.arvalid),
        .s_axi_arready           (csr_if.arready),
        .s_axi_rdata             (csr_if.rdata),
        .s_axi_rresp             (csr_if.rresp),
        .s_axi_rvalid            (csr_if.rvalid),
        .s_axi_rready            (csr_if.rready),

        // AXI4-Stream TX (ERNIC -> MAC)
        .m_axis_tx_tdata         (net_tx.tdata),
        .m_axis_tx_tkeep         (net_tx.tkeep),
        .m_axis_tx_tvalid        (net_tx.tvalid),
        .m_axis_tx_tready        (net_tx.tready),
        .m_axis_tx_tlast         (net_tx.tlast),
        .m_axis_tx_tuser         (net_tx.tuser),

        // AXI4-Stream RX (MAC -> ERNIC)
        .s_axis_rx_tdata         (net_rx.tdata),
        .s_axis_rx_tkeep         (net_rx.tkeep),
        .s_axis_rx_tvalid        (net_rx.tvalid),
        .s_axis_rx_tready        (net_rx.tready),
        .s_axis_rx_tlast         (net_rx.tlast),
        .s_axis_rx_tuser         (net_rx.tuser),

        // AXI4 memory master
        .m_axi_awid              (mem_if.awid),
        .m_axi_awaddr            (mem_if.awaddr),
        .m_axi_awlen             (mem_if.awlen),
        .m_axi_awsize            (mem_if.awsize),
        .m_axi_awburst           (mem_if.awburst),
        .m_axi_awvalid           (mem_if.awvalid),
        .m_axi_awready           (mem_if.awready),
        .m_axi_wdata             (mem_if.wdata),
        .m_axi_wstrb             (mem_if.wstrb),
        .m_axi_wlast             (mem_if.wlast),
        .m_axi_wvalid            (mem_if.wvalid),
        .m_axi_wready            (mem_if.wready),
        .m_axi_bid               (mem_if.bid),
        .m_axi_bresp             (mem_if.bresp),
        .m_axi_bvalid            (mem_if.bvalid),
        .m_axi_bready            (mem_if.bready),
        .m_axi_arid              (mem_if.arid),
        .m_axi_araddr            (mem_if.araddr),
        .m_axi_arlen             (mem_if.arlen),
        .m_axi_arsize            (mem_if.arsize),
        .m_axi_arburst           (mem_if.arburst),
        .m_axi_arvalid           (mem_if.arvalid),
        .m_axi_arready           (mem_if.arready),
        .m_axi_rid               (mem_if.rid),
        .m_axi_rdata             (mem_if.rdata),
        .m_axi_rresp             (mem_if.rresp),
        .m_axi_rlast             (mem_if.rlast),
        .m_axi_rvalid            (mem_if.rvalid),
        .m_axi_rready            (mem_if.rready)
    );

    // ----------------------------------------------------------------
    // UVM config DB — publish interfaces
    // ----------------------------------------------------------------
    initial begin
        uvm_config_db #(virtual axi_lite_if)::set(null, "uvm_test_top.env.csr_agt.*", "axi_lite_vif", csr_if);
        uvm_config_db #(virtual axis_if)::set(null, "uvm_test_top.env.tx_agt.*",      "axis_vif",     net_tx);
        uvm_config_db #(virtual axis_if)::set(null, "uvm_test_top.env.rx_agt.*",      "axis_vif",     net_rx);
        uvm_config_db #(virtual axi4_if)::set(null, "uvm_test_top.env.mem",           "axi4_vif",     mem_if);
        run_test();
    end

    // ----------------------------------------------------------------
    // TX loopback tready (always accept) when no RX driver is active
    // ----------------------------------------------------------------
    assign net_tx.tready = 1'b1;

endmodule
