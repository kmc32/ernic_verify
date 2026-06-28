// RDMA Read sequence — posts a WQE to the SQ and rings doorbell
`include "uvm/seq/ernic_csr.svh"

// WQE layout per PG332 Table 2-1 (64 bytes = 512 bits)
// RDMA Read uses: LADDR (local buffer for read response data),
//                 LENGTH, OPCODE, ROFFSET (remote addr), RTAG (remote key)
typedef struct packed {
    bit [95:0]  reserved_hi;   // [511:416]
    bit [31:0]  immdt_data;    // [415:384]
    bit [127:0] sdata;         // [383:256]
    bit [31:0]  rtag;          // [255:224] Remote Key
    bit [63:0]  roffset;       // [223:160] Remote Offset
    bit [23:0]  reserved_mid;  // [159:136]
    bit [7:0]   opcode;        // [135:128]
    bit [31:0]  length;        // [127:96]
    bit [63:0]  laddr;         // [95:32]  Local Address
    bit [15:0]  reserved_lo;   // [31:16]
    bit [15:0]  wrid;          // [15:0]
} wqe_rdma_read_t;

class rdma_read_seq extends ernic_base_seq;
    `uvm_object_utils(rdma_read_seq)

    int unsigned     qpn         = 2;   // 1-based QP number
    longint unsigned sq_addr     = 64'h1000_0000;
    longint unsigned local_addr;
    bit [31:0]       rkey        = 32'h1;  // Remote Key (RTAG)
    longint unsigned remote_addr;
    int unsigned     length      = 64;

    axi4_mem_model mem_model;

    // Track SQ producer index per QP
    static bit [15:0] sq_pi[longint unsigned];

    function new(string name = "rdma_read_seq");
        super.new(name);
    endfunction

    task body();
        wqe_rdma_read_t wqe;
        byte unsigned wqe_bytes[];
        bit [15:0] pi;

        // Build WQE per Table 2-1
        wqe = '0;
        wqe.wrid     = 16'h0;
        wqe.laddr    = local_addr;
        wqe.length   = length;
        wqe.opcode   = `WQE_OP_RDMA_READ;
        wqe.roffset  = remote_addr;
        wqe.rtag     = rkey;

        // Write WQE into SQ memory via backdoor
        wqe_bytes = {>>byte{wqe}};
        mem_model.backdoor_write(sq_addr, wqe_bytes);

        // Ring doorbell: increment SQ Producer Index and write to SQPI register
        if (!sq_pi.exists(qpn)) sq_pi[qpn] = 16'h0;
        pi = sq_pi[qpn] + 16'h1;
        sq_pi[qpn] = pi;
        csr_write(`ERNIC_PER_QP_BASE(qpn) + `ERNIC_QP_SQPI, {16'h0, pi});

        `uvm_info("RDMA_READ", $sformatf("QP%0d: posted RDMA Read len=%0d PI=%0d", qpn, length, pi), UVM_MEDIUM)
    endtask
endclass
