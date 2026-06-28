// Send/Receive sequence — posts a SEND WQE to the SQ and rings doorbell
// Per PG332, ERNIC HW auto-reposts consumed RQ buffers; no RQ posting needed.
`include "uvm/seq/ernic_csr.svh"

// WQE layout per PG332 Table 2-1 (64 bytes = 512 bits)
// SEND uses: LADDR (data source), LENGTH, OPCODE, SDATA (if <=16B inline)
typedef struct packed {
    bit [95:0]  reserved_hi;   // [511:416]
    bit [31:0]  immdt_data;    // [415:384]
    bit [127:0] sdata;         // [383:256] inline data (if len <= 16B)
    bit [31:0]  rtag;          // [255:224]
    bit [63:0]  roffset;       // [223:160]
    bit [23:0]  reserved_mid;  // [159:136]
    bit [7:0]   opcode;        // [135:128]
    bit [31:0]  length;        // [127:96]
    bit [63:0]  laddr;         // [95:32]  Local Address (data source)
    bit [15:0]  reserved_lo;   // [31:16]
    bit [15:0]  wrid;          // [15:0]
} wqe_send_t;

class send_recv_seq extends ernic_base_seq;
    `uvm_object_utils(send_recv_seq)

    int unsigned     qpn         = 2;   // 1-based QP number
    longint unsigned sq_addr     = 64'h1000_0000;
    longint unsigned rq_addr     = 64'h1001_0000;
    longint unsigned send_buf;
    longint unsigned recv_buf;
    bit [31:0]       rkey        = 32'h1;
    int unsigned     length      = 64;
    bit              with_imm    = 0;
    bit [31:0]       imm_data    = 0;

    axi4_mem_model mem_model;

    // Track SQ producer index per QP
    static bit [15:0] sq_pi[longint unsigned];

    function new(string name = "send_recv_seq");
        super.new(name);
    endfunction

    task body();
        wqe_send_t    sq_wqe;
        byte unsigned b[];
        bit [15:0]    pi;

        // Post SEND WQE on SQ
        sq_wqe = '0;
        sq_wqe.wrid     = 16'h0;
        sq_wqe.laddr    = send_buf;
        sq_wqe.length   = length;
        sq_wqe.opcode   = with_imm ? `WQE_OP_SEND_WITH_IMM : `WQE_OP_SEND;
        sq_wqe.immdt_data = with_imm ? imm_data : 32'h0;

        // Write WQE into SQ memory via backdoor
        b = {<<byte{sq_wqe}};  // AXI4 little-endian: LSB at lowest addr
        mem_model.backdoor_write(sq_addr, b);

        // Ring doorbell: increment SQ Producer Index and write to SQPI register
        if (!sq_pi.exists(qpn)) sq_pi[qpn] = 16'h0;
        pi = sq_pi[qpn] + 16'h1;
        sq_pi[qpn] = pi;
        csr_write(`ERNIC_PER_QP_BASE(qpn) + `ERNIC_QP_SQPI, {16'h0, pi});

        `uvm_info("SEND", $sformatf("QP%0d: posted SEND len=%0d PI=%0d", qpn, length, pi), UVM_MEDIUM)
    endtask
endclass
