// QP setup sequence — configures one QP via AXI-Lite CSR
`include "uvm/seq/ernic_csr.svh"

class qp_setup_seq extends ernic_base_seq;
    `uvm_object_utils(qp_setup_seq)

    // Required parameters (set before start())
    int unsigned qpn       = 0;
    bit [31:0]   src_ip    = 32'hC0A80001; // 192.168.0.1
    bit [47:0]   src_mac   = 48'hAABBCCDD0001;
    bit [31:0]   dst_ip    = 32'hC0A80002;
    int unsigned dst_qpn   = 1;
    longint unsigned sq_addr = 64'h1000_0000;
    longint unsigned rq_addr = 64'h1001_0000;
    longint unsigned cq_addr = 64'h1002_0000;

    function new(string name = "qp_setup_seq");
        super.new(name);
    endfunction

    task body();
        // Global network config (only QP0 sets it to avoid races)
        if (qpn == 0) begin
            csr_write(`ERNIC_CONF_SRC_MAC_L, src_mac[31:0]);
            csr_write(`ERNIC_CONF_SRC_MAC_H, {16'h0, src_mac[47:32]});
            csr_write(`ERNIC_CONF_SRC_IP,    src_ip);
        end
        // QP context
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_SEND_QA_L, sq_addr[31:0]);
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_SEND_QA_H, sq_addr[63:32]);
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_RECV_QA_L, rq_addr[31:0]);
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_RECV_QA_H, rq_addr[63:32]);
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_CQ_ADDR_L, cq_addr[31:0]);
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_CQ_ADDR_H, cq_addr[63:32]);
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_DST_QPN,   dst_qpn);
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_DST_IP,    dst_ip);
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_RQ_PSN,    32'h0);
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_SQ_PSN,    32'h0);
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_RETRY_CNT, 32'h7);
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_TIMEOUT,   32'h12);
        // Enable QP
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_CONF, 32'h1);
        `uvm_info("QP_SETUP", $sformatf("QP%0d configured", qpn), UVM_MEDIUM)
    endtask
endclass
