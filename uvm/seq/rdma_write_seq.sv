// RDMA Write sequence — posts a WQE to the SQ and rings doorbell
`include "ernic_csr.svh"

// WQE layout for RDMA Write (64 bytes)
typedef struct packed {
    bit [7:0]  opcode;
    bit [7:0]  flags;
    bit [15:0] wqe_id;
    bit [31:0] len;
    bit [63:0] local_addr;
    bit [31:0] local_key;
    bit [63:0] remote_addr;
    bit [31:0] remote_key;
    bit [31:0] imm_data;
    bit [7:0]  pad[16]; // padding to 64 bytes
} wqe_rdma_write_t;

class rdma_write_seq extends ernic_base_seq;
    `uvm_object_utils(rdma_write_seq)

    int unsigned qpn          = 0;
    longint unsigned sq_addr  = 64'h1000_0000;
    longint unsigned local_addr;
    bit [31:0]       local_key  = 32'h1;
    longint unsigned remote_addr;
    bit [31:0]       remote_key  = 32'h1;
    int unsigned     length     = 64;
    bit              with_imm   = 0;
    bit [31:0]       imm_data   = 0;

    // AXI4 mem model handle for WQE backdoor write
    axi4_mem_model mem_model;

    function new(string name = "rdma_write_seq");
        super.new(name);
    endfunction

    task body();
        wqe_rdma_write_t wqe;
        byte unsigned wqe_bytes[];

        wqe.opcode      = with_imm ? `WQE_OP_RDMA_WRITE_IMM : `WQE_OP_RDMA_WRITE;
        wqe.flags       = 8'h0;
        wqe.wqe_id      = 16'h0;
        wqe.len         = length;
        wqe.local_addr  = local_addr;
        wqe.local_key   = local_key;
        wqe.remote_addr = remote_addr;
        wqe.remote_key  = remote_key;
        wqe.imm_data    = imm_data;

        // Write WQE into SQ memory via backdoor
        wqe_bytes = {>>byte{wqe}};
        mem_model.backdoor_write(sq_addr, wqe_bytes);

        // Ring doorbell: post 1 WQE
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_WQE_CNT,  32'h1);
        csr_write(`ERNIC_QP_BASE(qpn) + `ERNIC_QP_DOORBELL, 32'h1);
        `uvm_info("RDMA_WRITE", $sformatf("QP%0d: posted RDMA Write len=%0d", qpn, length), UVM_MEDIUM)
    endtask
endclass
