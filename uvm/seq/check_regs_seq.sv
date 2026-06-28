// Read back and verify all key ERNIC registers after test
`include "uvm/seq/ernic_csr.svh"

class check_regs_seq extends ernic_base_seq;
    `uvm_object_utils(check_regs_seq)

    function new(string name = "check_regs_seq");
        super.new(name);
    endfunction

    // Helper: read and check one register
    task check_reg(string name, bit [31:0] addr, bit [31:0] expected, input bit [31:0] mask = 32'hFFFF_FFFF);
        bit [31:0] r;
        csr_read(addr, r);
        if ((r & mask) == (expected & mask))
            `uvm_info("REGCHK", $sformatf("[PASS] %-30s @0x%08h = 0x%08h", name, addr, r), UVM_NONE)
        else
            `uvm_error("REGCHK", $sformatf("[FAIL] %-30s @0x%08h GOT=0x%08h EXP=0x%08h (mask=0x%08h)", name, addr, r, expected, mask))
    endtask

    task body();
        `uvm_info("REGCHK", "===== Post-Test Register Check =====", UVM_NONE)

        // ---- Global Registers ----
        check_reg("XRNICCONF",       32'h10_0000, 32'h00e3488b);
        check_reg("XRNICADCONF",     32'h10_0004, 32'h000a0000);
        check_reg("MACXADDLSB",      32'h10_0010, 32'h17dc5e9a);
        check_reg("MACXADDMSB",      32'h10_0014, 32'h00002f76);
        check_reg("IPv4XADD",        32'h10_0070, 32'hf38590ba);
        check_reg("DATBUFBA",        32'h10_00A0, 32'h0c000000);
        check_reg("DATBUFSZ",        32'h10_00A8, 32'h10000080);
        check_reg("ERRBUFBA",        32'h10_0060, 32'h00110000);
        check_reg("ERRBUFSZ",        32'h10_0068, 32'h01000040);
        check_reg("OUTIOPKTCNT",     32'h10_0108, 32'h00000000, 32'h0000_0000);  // no expected value, just log

        // ---- IPv6 Addresses ----
        check_reg("IPv6_ADDR0",      32'h10_0020, 32'hf38590ba);
        check_reg("IPv6_ADDR1",      32'h10_0024, 32'hac92135d);
        check_reg("IPv6_ADDR2",      32'h10_0028, 32'h013248eb);
        check_reg("IPv6_ADDR3",      32'h10_002C, 32'hafb1f367);

        // ---- QP0 Memory Region ----
        check_reg("QP0_VirtAddr",    32'h0000_0004, 32'hcad53074);
        check_reg("QP0_BufBase",     32'h0000_000C, 32'h40000000);
        check_reg("QP0_R_Key",       32'h0000_0014, 32'h00000098);
        check_reg("QP0_BufLen",      32'h0000_0018, 32'h00100000);
        check_reg("QP0_AccessDesc",  32'h0000_001C, 32'h00000002);

        // ---- QP1 Config ----
        // QP1 at 0x180000 (ERNIC_PER_QP_BASE(1))
        check_reg("QP1_SQBA",        32'h18_0010, 32'h0b000000);
        check_reg("QP1_QPCONF",      32'h18_0000, 32'h024f0435);
        check_reg("QP1_QPADVCONF",   32'h18_0004, 32'h00000000, 32'hFFFF_0000); // low bits changeable
        check_reg("QP1_QDEPTH",      32'h18_003C, 32'h00800040);

        // ---- QP2 Config (our test QP) ----
        // QP2 at 0x180100 (ERNIC_PER_QP_BASE(2))
        check_reg("QP2_SQBA",        32'h18_0110, 32'h00600000);
        check_reg("QP2_RQBA",        32'h18_0108, 32'h02000000);
        check_reg("QP2_CQBA",        32'h18_0118, 32'h00140000);
        check_reg("QP2_QPCONF",      32'h18_0100, 32'h04f80407);
        check_reg("QP2_QPADVCONF",   32'h18_0104, 32'h9bf1b002);
        check_reg("QP2_QDEPTH",      32'h18_013C, 32'h00400100);
        check_reg("QP2_SQPSN",       32'h18_0140, 32'h00774471);  // PSN increments after WQE consumed
        check_reg("QP2_LSTRQREQ",    32'h18_0144, 32'h04a02aa9);
        check_reg("QP2_DESTQPCONF",  32'h18_0148, 32'h00000002);
        check_reg("QP2_TIMEOUTCONF", 32'h18_014C, 32'h00020b18);
        check_reg("QP2_STATQP",      32'h18_0188, 32'h00000000, 32'h0000_0000); // log only

        // ---- QP3 Config ----
        check_reg("QP3_QPCONF",      32'h18_0200, 32'h01dd0407);
        check_reg("QP3_SQBA",        32'h18_0210, 32'h00604000);
        check_reg("QP3_QDEPTH",      32'h18_023C, 32'h00400100);

        // ---- MR for QP2 ----
        check_reg("QP2_MR_PDNum",    32'h0000_0200, 32'h00000002);
        check_reg("QP2_MR_VirtAddr", 32'h0000_0204, 32'hcadd3074);
        check_reg("QP2_MR_BufBase",  32'h0000_020C, 32'h40080000);
        check_reg("QP2_MR_R_Key",    32'h0000_0214, 32'h00000018);
        check_reg("QP2_MR_BufLen",   32'h0000_0218, 32'h00100000);
        check_reg("QP2_MR_Access",   32'h0000_021C, 32'h00000002);

        // ---- Interrupt Enable ----
        check_reg("INTR_ENABLE",     32'h10_0180, 32'h00000070);

        // ---- Alarm / Status Registers (log-only, no expected value) ----
        check_reg("CON_IO_CONF",     32'h10_00AC, 32'h00000000, 32'h0000_0000);
        check_reg("XRNIC_XRNICCONF", 32'h10_0000, 32'h00e3488b);
        // Per-QP status
        check_reg("QP1_STATQP",      32'h18_0088, 32'h00000000, 32'h0000_0000);
        check_reg("QP3_STATQP",      32'h18_0288, 32'h00000000, 32'h0000_0000);
        // QP2 SQPI (doorbell — should reflect PI=1 after posting)
        check_reg("QP2_SQPI",        32'h18_0138, 32'h00000000, 32'h0000_0000);
        // QP2 CQ CI (consumer index)
        check_reg("QP2_RQCI",        32'h18_0134, 32'h00000000, 32'h0000_0000);
        // XRNICBUFBA / XRNICBUFBAMSB
        check_reg("DATBUFBAMSB",     32'h10_00A4, 32'h00000000);
        check_reg("ERRBUFBAMSB",     32'h10_0064, 32'h00000000);
        // Global registers 0x1000B0, 0x1000B4, 0x1000B8
        check_reg("GLOBAL_B0",       32'h10_00B0, 32'h02000000);
        check_reg("GLOBAL_B4",       32'h10_00B4, 32'h00000000);
        check_reg("GLOBAL_B8",       32'h10_00B8, 32'h00000100);

        `uvm_info("REGCHK", "===== Register Check Complete =====", UVM_NONE)
    endtask
endclass
