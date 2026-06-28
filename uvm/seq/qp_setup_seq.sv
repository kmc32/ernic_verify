// QP setup sequence — configures one QP via AXI-Lite CSR
// Follows PG332 v4.0 Chapter 6: ERNIC Software Flow
`include "uvm/seq/ernic_csr.svh"

class qp_setup_seq extends ernic_base_seq;
    `uvm_object_utils(qp_setup_seq)

    // Required parameters (set before start())
    // QP number: 1-based per PG332. QP1=MAD, QP2+=RC. Default QP2.
    int unsigned qpn       = 2;
    bit [31:0]   src_ip    = 32'hC0A80001; // 192.168.0.1
    bit [47:0]   src_mac   = 48'hAABBCCDD0001;
    bit [31:0]   dst_ip    = 32'hC0A80002;
    bit [47:0]   dst_mac   = 48'hAABBCCDD0002;
    int unsigned dst_qpn   = 3;            // remote QP number
    longint unsigned sq_addr = 64'h1000_0000;
    longint unsigned rq_addr = 64'h1001_0000;
    longint unsigned cq_addr = 64'h1002_0000;
    // Doorbell addresses — ERNIC writes CQ head / RQ write ptr here
    longint unsigned cq_db_addr     = 64'hA000_0000;
    longint unsigned rq_wptr_db_addr = 64'hA000_1000;
    // Queue depths
    int unsigned   sq_depth = 128;
    int unsigned   rq_depth = 128;
    // RQ buffer size in multiples of 256B
    int unsigned   rq_buf_size = 64;      // 64 * 256B = 16KB per RQ element

    function new(string name = "qp_setup_seq");
        super.new(name);
    endfunction

    task body();
        bit [31:0] qp_base = `ERNIC_PER_QP_BASE(qpn);
        bit [31:0] qpconf_val;

        // ---- Global config (only once) ----
        if (qpn == 2) begin
            csr_write(`ERNIC_MACXADDLSB, src_mac[31:0]);
            csr_write(`ERNIC_MACXADDMSB, {16'h0, src_mac[47:32]});
            csr_write(`ERNIC_IPv4XADD,   src_ip);

            // QP0 (local QP) minimal config — required before QP1
            csr_write(32'h00000004, 32'hcad53074); // QP0 Virtual Address LSB
            csr_write(32'h0000000c, 32'h40000000); // QP0 Buffer base address LSB
            csr_write(32'h00000014, 32'h00000098); // QP0 Buffer R_Key
            csr_write(32'h00000018, 32'h00100000); // QP0 Write Read Buffer length
            csr_write(32'h0000001c, 32'h00000002); // QP0 Access Description

            // QP1 (MAD QP) creation — required per PG332 Chapter 6 step 2
            csr_write(`ERNIC_PER_QP_BASE(1) + 32'h00, 32'h00000001); // QP1 PD Number
            csr_write(`ERNIC_PER_QP_BASE(1) + 32'h04, 32'hcad93074); // QP1 Virtual Address LSB
            csr_write(`ERNIC_PER_QP_BASE(1) + 32'h0c, 32'h40040000); // QP1 Buffer base address
            csr_write(`ERNIC_PER_QP_BASE(1) + 32'h14, 32'h00000081); // QP1 Buffer R_Key
            csr_write(`ERNIC_PER_QP_BASE(1) + 32'h18, 32'h00100000); // QP1 Write Read Buffer len
            csr_write(`ERNIC_PER_QP_BASE(1) + 32'h1c, 32'h00000002); // QP1 Access Description

            // Global commit (matching example design 0x100044 = 0x07 pattern)
            csr_write(32'h00100044, 32'h00000007);
        end

        // ---- RC QP Creation (Chapter 6) ----

        // 1. Queue base addresses
        // SQ base (32B aligned)
        csr_write(qp_base + `ERNIC_QP_SQBA,    sq_addr[31:0]);
        csr_write(qp_base + `ERNIC_QP_SQBAMSB, sq_addr[63:32]);
        // RQ base (256B aligned)
        csr_write(qp_base + `ERNIC_QP_RQBA,    rq_addr[31:0]);
        csr_write(qp_base + `ERNIC_QP_RQBAMSB, rq_addr[63:32]);
        // CQ base (32B aligned)
        csr_write(qp_base + `ERNIC_QP_CQBA,    cq_addr[31:0]);
        csr_write(qp_base + `ERNIC_QP_CQBAMSB, cq_addr[63:32]);

        // 2. Queue depths: [15:0]=SQ depth, [31:16]=RQ depth
        csr_write(qp_base + `ERNIC_QP_QDEPTH, {rq_depth[15:0], sq_depth[15:0]});

        // 3. Doorbell address pointers (where ERNIC writes CQ head / RQ write ptr)
        csr_write(qp_base + `ERNIC_QP_CQDBADD,     cq_db_addr[31:0]);
        csr_write(qp_base + `ERNIC_QP_CQDBADDMSB,  cq_db_addr[63:32]);
        csr_write(qp_base + `ERNIC_QP_RQWPTRDBADD,    rq_wptr_db_addr[31:0]);
        csr_write(qp_base + `ERNIC_QP_RQWPTRDBADDMSB, rq_wptr_db_addr[63:32]);

        // 4. Remote host configuration
        csr_write(qp_base + `ERNIC_QP_MACDESADDLSB, dst_mac[31:0]);
        csr_write(qp_base + `ERNIC_QP_MACDESADDMSB, {16'h0, dst_mac[47:32]});
        csr_write(qp_base + `ERNIC_QP_DESTQPCONF,   dst_qpn[23:0]);
        csr_write(qp_base + `ERNIC_QP_IPDESADDR1,   dst_ip);

        // 5. PSN initialization
        csr_write(qp_base + `ERNIC_QP_SQPSN,    24'h0);
        csr_write(qp_base + `ERNIC_QP_LSTRQREQ, 32'h0);

        // 5a. Protection Domain number (per-QP, offset 0xB0) — required
        csr_write(qp_base + `ERNIC_QP_PDNUM, 24'h0);

        // 6. Timeout configuration
        // [5:0]=timeout, [10:8]=max_retry(7), [13:11]=RNR retry(7), [20:16]=RNR timeout(0x12)
        // 32-bit value: 11+5+3+3+2+6+2 = 32 bits
        csr_write(qp_base + `ERNIC_QP_TIMEOUTCONF, {11'h0, 5'h12, 3'h7, 3'h7, 2'h0, 6'h12, 2'h0});

        // 7. QP Advanced config — partition key 0xFFFF (default), TTL 64
        // [15:0]=PKey, [23:16]=TTL, [31:24]=Traffic Class
        csr_write(qp_base + `ERNIC_QP_QPADVCONF, 32'h0040_FFFF);

        // 8. Build and write QPCONF:
        //    [31:16] = RQ buffer size in 256B multiples
        //    [10:8]  = PMTU (3-bit field, 011 = 2048B)
        //    [7]     = 0 (IPv4)
        //    [4]     = 0 (HW handshake enabled)
        //    [3]     = 1 (CQ int enable)
        //    [2]     = 1 (RQ int enable)
        //    [0]     = 1 (QP enable)
        // 32-bit value: 16+5+3+4+3+1 = 32 bits
        qpconf_val = {rq_buf_size[15:0], 5'h0, `PMTU_2048B, 4'h0, 3'b110, 1'b1};
        csr_write(qp_base + `ERNIC_QP_QPCONF, qpconf_val);

        // 9. Write retry data buffer config (needed for outgoing WRITE)
        // DATBUFSZ: [31:16]=buf size in bytes, [15:0]=#bufs — must be >= PMTU
        csr_write(`ERNIC_DATBUFBA,    32'h8000_0000);  // data buffer base
        csr_write(`ERNIC_DATBUFBAMSB, 32'h0);
        csr_write(`ERNIC_DATBUFSZ,    {16'd4096, 16'd128});  // 128 buffers x 4KB each

        // 10. Error buffer (optional but recommended) — keep away from doorbell range
        csr_write(`ERNIC_ERRBUFBA,    32'hB000_0000);
        csr_write(`ERNIC_ERRBUFBAMSB, 32'h0);
        csr_write(`ERNIC_ERRBUFSZ,    {16'd256, 16'd256});  // 256 entries x 256B each

        // 11. Enable ERNIC globally (XRNICCONF[0]=1, UDP src port=0x4791)
        // 32-bit value: 8+16+5+2+1 = 32 bits — bit[0]=1 enable, [23:8]=UDP src port
        csr_write(`ERNIC_XRNICCONF, {8'h0, 16'h4791, 5'h0, 2'b00, 1'b1});

        // 12. Final commit triggers — ERNIC latches configuration after these writes
        csr_write(32'h00100044, 32'h00000007);
        csr_write(32'h00100044, 32'h00000007);

        `uvm_info("QP_SETUP", $sformatf("QP%0d configured at base 0x%08h", qpn, qp_base), UVM_MEDIUM)
    endtask
endclass
