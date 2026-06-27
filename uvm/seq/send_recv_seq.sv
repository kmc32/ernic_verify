// Send/Receive sequence
`include "ernic_csr.svh"

typedef struct packed {
    bit [7:0]  opcode;
    bit [7:0]  flags;
    bit [15:0] wqe_id;
    bit [31:0] len;
    bit [63:0] local_addr;
    bit [31:0] local_key;
    bit [31:0] imm_data;
    bit [63:0] pad;
    bit [15:0] pad2;
} wqe_send_t;

// RQ descriptor (receive buffer posted to ERNIC RQ)
typedef struct packed {
    bit [63:0] addr;
    bit [31:0] key;
    bit [31:0] len;
} rq_desc_t;

class send_recv_seq extends ernic_base_seq;
    `uvm_object_utils(send_recv_seq)

    int unsigned     qpn         = 0;
    longint unsigned sq_addr     = 64'h1000_0000;
    longint unsigned rq_addr     = 64'h1001_0000;
    longint unsigned send_buf;
    longint unsigned recv_buf;
    bit [31:0]       lkey        = 32'h1;
    int unsigned     length      = 64;
    bit              with_imm    = 0;
    bit [31:0]       imm_data    = 0;

    axi4_mem_model mem_model;

    function new(string name = "send_recv_seq");
        super.new(name);
    endfunction

    task body();
        wqe_send_t    sq_wqe;
        rq_desc_t     rq_desc;
        byte unsigned b[];

        // Post RQ recv buffer
        rq_desc.addr = recv_buf;
        rq_desc.key  = lkey;
        rq_desc.len  = length;
        b = {>>byte{rq_desc}};
        mem_model.backdoor_write(rq_addr, b);
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_WQE_CNT,  32'hFFFF_0001); // RQ post flag
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_DOORBELL, 32'h0002);

        // Post SQ send
        sq_wqe.opcode   = with_imm ? `WQE_OP_SEND_WITH_IMM : `WQE_OP_SEND;
        sq_wqe.flags    = 8'h0;
        sq_wqe.wqe_id   = 16'h0;
        sq_wqe.len      = length;
        sq_wqe.local_addr = send_buf;
        sq_wqe.local_key  = lkey;
        sq_wqe.imm_data   = imm_data;
        b = {>>byte{sq_wqe}};
        mem_model.backdoor_write(sq_addr, b);
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_WQE_CNT,  32'h1);
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_DOORBELL, 32'h1);
        `uvm_info("SEND", $sformatf("QP%0d: posted Send len=%0d", qpn, length), UVM_MEDIUM)
    endtask
endclass
