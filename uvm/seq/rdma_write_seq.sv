// RDMA Write sequence — posts a WQE to the SQ and rings doorbell
`include "uvm/seq/ernic_csr.svh"

// WQE layout per PG332 Table 2-1 (64 bytes = 512 bits, packed MSB→LSB)
// [511:416] Reserved (12B)
// [415:384] IMMDT DATA (4B)
// [383:256] SDATA — inline SEND data (16B)
// [255:224] RTAG — Remote Key (4B)
// [223:160] ROFFSET — Remote Offset (8B)
// [159:136] Reserved (3B)
// [135:128] OPCODE (1B)
// [127:96]  LENGTH — DMA length (4B)
// [95:32]   LADDR — Local buffer address (8B)
// [31:16]   Reserved (2B)
// [15:0]    WRID — Work Request ID (2B)
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
} wqe_rdma_write_t;

class rdma_write_seq extends ernic_base_seq;
    `uvm_object_utils(rdma_write_seq)

    int unsigned qpn          = 2;   // 1-based QP number (QP2 = first RC QP)
    longint unsigned sq_addr  = 64'h1000_0000;
    longint unsigned local_addr;
    bit [31:0]       rkey     = 32'h1;  // Remote Key (RTAG)
    longint unsigned remote_addr;
    int unsigned     length   = 64;
    bit              with_imm = 0;
    bit [31:0]       imm_data = 0;

    // AXI4 mem model handle for WQE backdoor write
    axi4_mem_model mem_model;

    // Track producer index per QP
    static bit [15:0] sq_pi[longint unsigned];

    function new(string name = "rdma_write_seq");
        super.new(name);
    endfunction

    task body();
        wqe_rdma_write_t wqe;
        byte unsigned wqe_bytes[];
        bit [15:0] pi;

        // Build WQE per Table 2-1
        wqe = '0;
        wqe.wrid     = 16'h0;
        wqe.laddr    = local_addr;
        wqe.length   = length;
        wqe.opcode   = with_imm ? `WQE_OP_RDMA_WRITE_IMM : `WQE_OP_RDMA_WRITE;
        wqe.roffset  = remote_addr;
        wqe.rtag     = rkey;
        wqe.immdt_data = with_imm ? imm_data : 32'h0;

        // Write WQE into SQ memory via backdoor
        wqe_bytes = {>>byte{wqe}};
        mem_model.backdoor_write(sq_addr, wqe_bytes);

        // Ring doorbell: increment SQ Producer Index and write to SQPI register
        if (!sq_pi.exists(qpn)) sq_pi[qpn] = 16'h0;
        pi = sq_pi[qpn] + 16'h1;
        sq_pi[qpn] = pi;
        csr_write(`ERNIC_PER_QP_BASE(qpn) + `ERNIC_QP_SQPI, {16'h0, pi});

        `uvm_info("RDMA_WRITE", $sformatf("QP%0d: posted RDMA Write len=%0d PI=%0d", qpn, length, pi), UVM_MEDIUM)
    endtask
endclass
