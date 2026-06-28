// RDMA Read sequence
`include "uvm/seq/ernic_csr.svh"

typedef struct packed {
    bit [7:0]  opcode;
    bit [7:0]  flags;
    bit [15:0] wqe_id;
    bit [31:0] len;
    bit [63:0] local_addr;
    bit [31:0] local_key;
    bit [63:0] remote_addr;
    bit [31:0] remote_key;
    bit [63:0] pad;
} wqe_rdma_read_t;

class rdma_read_seq extends ernic_base_seq;
    `uvm_object_utils(rdma_read_seq)

    int unsigned     qpn         = 0;
    longint unsigned sq_addr     = 64'h1000_0000;
    longint unsigned local_addr;
    bit [31:0]       local_key   = 32'h1;
    longint unsigned remote_addr;
    bit [31:0]       remote_key  = 32'h1;
    int unsigned     length      = 64;

    axi4_mem_model mem_model;

    function new(string name = "rdma_read_seq");
        super.new(name);
    endfunction

    task body();
        wqe_rdma_read_t wqe;
        byte unsigned wqe_bytes[];

        wqe.opcode      = `WQE_OP_RDMA_READ;
        wqe.flags       = 8'h0;
        wqe.wqe_id      = 16'h0;
        wqe.len         = length;
        wqe.local_addr  = local_addr;
        wqe.local_key   = local_key;
        wqe.remote_addr = remote_addr;
        wqe.remote_key  = remote_key;

        wqe_bytes = {>>byte{wqe}};
        mem_model.backdoor_write(sq_addr, wqe_bytes);

        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_WQE_CNT,  32'h1);
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_DOORBELL, 32'h1);
        `uvm_info("RDMA_READ", $sformatf("QP%0d: posted RDMA Read len=%0d", qpn, length), UVM_MEDIUM)
    endtask
endclass
