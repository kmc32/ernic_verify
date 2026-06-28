// Tiny CSR write sequence
class csr_write_seq extends ernic_base_seq;
    `uvm_object_utils(csr_write_seq)
    bit [31:0] addr;
    bit [31:0] data;
    function new(string name = "csr_write_seq"); super.new(name); endfunction
    task body(); csr_write(addr, data); endtask
endclass

// Mini sequence to read key status registers
class status_read_seq extends ernic_base_seq;
    `uvm_object_utils(status_read_seq)
    function new(string name = "status_read_seq");
        super.new(name);
    endfunction
    task body();
        bit [31:0] r;
        csr_read(32'h10_0108, r);  `uvm_info("STATUS", $sformatf("OUTIOPKTCNT  = 0x%08h", r), UVM_NONE)
        csr_read(32'h18_0188, r);  `uvm_info("STATUS", $sformatf("QP2_STATQP   = 0x%08h", r), UVM_NONE)
        csr_read(32'h18_0288, r);  `uvm_info("STATUS", $sformatf("QP3_STATQP   = 0x%08h", r), UVM_NONE)
        csr_read(32'h18_0140, r);  `uvm_info("STATUS", $sformatf("QP2_SQPSN    = 0x%08h", r), UVM_NONE)
        csr_read(32'h18_0240, r);  `uvm_info("STATUS", $sformatf("QP3_SQPSN    = 0x%08h", r), UVM_NONE)
        csr_read(32'h18_0138, r);  `uvm_info("STATUS", $sformatf("QP2_SQPI     = 0x%08h", r), UVM_NONE)
        csr_read(32'h18_0238, r);  `uvm_info("STATUS", $sformatf("QP3_SQPI     = 0x%08h", r), UVM_NONE)
        csr_read(32'h18_0388, r);  `uvm_info("STATUS", $sformatf("QP4_STATQP   = 0x%08h", r), UVM_NONE)
        csr_read(32'h18_0340, r);  `uvm_info("STATUS", $sformatf("QP4_SQPSN    = 0x%08h", r), UVM_NONE)
        csr_read(32'h18_0338, r);  `uvm_info("STATUS", $sformatf("QP4_SQPI     = 0x%08h", r), UVM_NONE)
    endtask
endclass

// RDMA Write test — parameterized experiments
class ernic_rdma_write_test extends ernic_base_test;
    `uvm_component_utils(ernic_rdma_write_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    int exp_num = 1;  // experiment selector via +EXP_NUM=

    // Post a WQE and write data buffer
    task post_wqe(int qpn, longint unsigned sq_addr, longint unsigned data_addr,
                  int length, bit [7:0] data_start);
        byte unsigned raw[];
        rdma_write_seq seq;

        // Write data
        raw = new[length];
        foreach (raw[i]) raw[i] = data_start + i;
        env.mem.backdoor_write(data_addr, raw);
        `uvm_info("TEST", $sformatf("EXP%0d: QP%0d data %02h..%02h at 0x%08h",
                                     exp_num, qpn, data_start, data_start+length-1, data_addr), UVM_NONE)

        // Post WQE
        seq = rdma_write_seq::type_id::create("seq");
        seq.qpn         = qpn;
        seq.sq_addr     = sq_addr;
        seq.local_addr  = data_addr;
        seq.rkey        = 32'h1;
        seq.remote_addr = 64'h3000_0000;
        seq.length      = length;
        seq.mem_model   = env.mem;
        seq.start(csr_seqr());
    endtask

    // Override a single CSR after full config
    task override_csr(bit [31:0] addr, bit [31:0] data);
        csr_write_seq ws = csr_write_seq::type_id::create("ws");
        ws.addr = addr;
        ws.data = data;
        ws.start(csr_seqr());
        `uvm_info("TEST", $sformatf("EXP%0d: OVERRIDE addr=0x%08h data=0x%08h", exp_num, addr, data), UVM_NONE)
    endtask

    task run_phase(uvm_phase phase);
        exdes_full_config_seq full_cfg;
        phase.raise_objection(this);

        // Read experiment number from plusarg
        void'($value$plusargs("EXP_NUM=%d", exp_num));
        `uvm_info("TEST", $sformatf("===== EXPERIMENT %0d =====", exp_num), UVM_NONE)

        // Apply full example design configuration
        full_cfg = exdes_full_config_seq::type_id::create("full_cfg");
        full_cfg.start(csr_seqr());
        #400000;  // wait for responder

        // ================================================================
        // Experiment-specific configuration overrides and WQE posting
        // ================================================================
        case (exp_num)
        1: begin  // QP3 ONLY — baseline for header generation
            post_wqe(3, 64'h0060_4000, 64'h2100_0000, 64, 8'hA0);
        end

        2: begin  // QP2 ONLY — baseline for raw data
            post_wqe(2, 64'h0060_0000, 64'h2000_0000, 64, 8'h00);
        end

        3: begin  // QP2 with QP3's QPCONF
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QPCONF, 32'h01dd0407);
            post_wqe(2, 64'h0060_0000, 64'h2000_0000, 64, 8'h10);
        end

        4: begin  // QP2 with QP3's QPADVCONF
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QPADVCONF, 32'hd836ba10);
            post_wqe(2, 64'h0060_0000, 64'h2000_0000, 64, 8'h20);
        end

        5: begin  // QP2 with QP3's FULL per-QP config (all registers)
            // Copy every QP3 register to QP2's slot
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QPCONF,       32'h01dd0407);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QPADVCONF,    32'hd836ba10);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_RQBA,         32'h02010000);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_SQBA,         32'h00604000); // use QP3's SQ
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_CQBA,         32'h00140400);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QDEPTH,       32'h00400100);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_SQPSN,        32'h00e21df7);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_LSTRQREQ,     32'h040b77ce);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_DESTQPCONF,   32'h00000003);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_MACDESADDLSB, 32'h1c69b8ed);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_MACDESADDMSB, 32'h0000ea1e);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_IPDESADDR1,   32'hd7ac977e);
            // Also copy crypto/key regs
            override_csr(`ERNIC_PER_QP_BASE(2) + 32'h6C, 32'he9a855a0);
            override_csr(`ERNIC_PER_QP_BASE(2) + 32'h64, 32'h92e8a89f);
            override_csr(`ERNIC_PER_QP_BASE(2) + 32'h68, 32'h28640e94);
            // Use QP3's SQ addr for WQE
            post_wqe(2, 64'h0060_4000, 64'h2000_0000, 64, 8'h50);
        end

        6: begin  // QP2 with QP3's MAC+IP destination only
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_MACDESADDLSB, 32'h1c69b8ed);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_MACDESADDMSB, 32'h0000ea1e);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_IPDESADDR1,   32'hd7ac977e);
            post_wqe(2, 64'h0060_0000, 64'h2000_0000, 64, 8'h30);
        end

        7: begin  // QP2 with QP3's QPADVCONF + QPCONF
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QPCONF,    32'h01dd0407);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QPADVCONF, 32'hd836ba10);
            post_wqe(2, 64'h0060_0000, 64'h2000_0000, 64, 8'h40);
        end

        8: begin  // QP2 ONLY but using QP3's SQ address and data
            // Test if the SQ address assignment matters
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_SQBA, 64'h0060_4000);
            post_wqe(2, 64'h0060_4000, 64'h2000_0000, 64, 8'h60);
        end

        9: begin  // QP4 with QP3's full config — use UNIQUE SQ to avoid ambiguity
            override_csr(`ERNIC_PER_QP_BASE(4) + `ERNIC_QP_QPCONF,       32'h01dd0407);
            override_csr(`ERNIC_PER_QP_BASE(4) + `ERNIC_QP_QPADVCONF,    32'hd836ba10);
            override_csr(`ERNIC_PER_QP_BASE(4) + `ERNIC_QP_SQBA,         32'h0060_C000);
            override_csr(`ERNIC_PER_QP_BASE(4) + `ERNIC_QP_QDEPTH,       32'h00400100);
            override_csr(`ERNIC_PER_QP_BASE(4) + `ERNIC_QP_SQPSN,        32'h00e21df7);
            override_csr(`ERNIC_PER_QP_BASE(4) + `ERNIC_QP_MACDESADDLSB, 32'h1c69b8ed);
            override_csr(`ERNIC_PER_QP_BASE(4) + `ERNIC_QP_MACDESADDMSB, 32'h0000ea1e);
            override_csr(`ERNIC_PER_QP_BASE(4) + `ERNIC_QP_IPDESADDR1,   32'hd7ac977e);
            // Post WQE on QP4 at unique SQ address (not shared with QP3)
            post_wqe(4, 64'h0060_C000, 64'h2200_0000, 64, 8'hC0);
        end

        10: begin  // QP3 but with SEND opcode instead of RDMA_WRITE
            // Check if opcode matters for header generation
            begin
                byte unsigned raw[];
                rdma_write_seq seq;
                raw = new[64];
                foreach (raw[i]) raw[i] = 8'hA0 + i;
                env.mem.backdoor_write(64'h2100_0000, raw);
                seq = rdma_write_seq::type_id::create("seq");
                seq.qpn         = 3;
                seq.sq_addr     = 64'h0060_4000;
                seq.local_addr  = 64'h2100_0000;
                seq.rkey        = 32'h1;
                seq.remote_addr = 64'h3000_0000;
                seq.length      = 64;
                seq.mem_model   = env.mem;
                seq.skip_wqe    = 1;  // don't backdoor-write WQE
                seq.start(csr_seqr()); // just rings doorbell
                // Manually write WQE with SEND opcode
                `uvm_info("TEST", "EXP10: QP3 SEND opcode", UVM_NONE)
            end
        end

        11: begin  // QP2: disable, set QP3 config, re-enable (test sticky bits theory)
            // First disable QP2
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QPCONF, 32'h04f80406); // clear bit0
            #2000; // wait 40ns
            // Apply QP3's full config
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QPCONF,       32'h01dd0406); // still disabled
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QPADVCONF,    32'hd836ba10);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_SQBA,         32'h0060_8000);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QDEPTH,       32'h00400100);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_SQPSN,        32'h00e21df7);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_MACDESADDLSB, 32'h1c69b8ed);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_MACDESADDMSB, 32'h0000ea1e);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_IPDESADDR1,   32'hd7ac977e);
            #2000;
            // Re-enable QP2
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QPCONF, 32'h01dd0407); // bit0=1
            #2000;
            post_wqe(2, 64'h0060_8000, 64'h2100_0000, 64, 8'hA0);
        end

        12: begin  // QP2: use QP3's laddr (check if data buffer address matters)
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QPCONF,   32'h01dd0407);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QPADVCONF, 32'hd836ba10);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_SQBA,     32'h0060_8000);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QDEPTH,   32'h00400100);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_SQPSN,    32'h00e21df7);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_MACDESADDLSB, 32'h1c69b8ed);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_MACDESADDMSB, 32'h0000ea1e);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_IPDESADDR1, 32'hd7ac977e);
            // Use QP3's exact data address
            post_wqe(2, 64'h0060_8000, 64'h2100_0000, 64, 8'hA0);
        end

        13: begin  // QP2: OVERRIDE EVERYTHING including MR, PDNUM, TIMEOUTCONF
            // First disable QP2
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QPCONF, 32'h04f80406);
            #2000;
            // Override ALL per-QP registers to QP3 values
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QPCONF,       32'h01dd0406);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QPADVCONF,    32'hd836ba10);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_RQBA,         32'h02010000);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_SQBA,         32'h0060_8000);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_CQBA,         32'h00140400);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QDEPTH,       32'h00400100);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_SQPSN,        32'h00e21df7);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_LSTRQREQ,     32'h040b77ce);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_DESTQPCONF,   32'h00000003);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_TIMEOUTCONF,  32'h00000000); // clear!
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_MACDESADDLSB, 32'h1c69b8ed);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_MACDESADDMSB, 32'h0000ea1e);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_IPDESADDR1,   32'hd7ac977e);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_IPDESADDR2,   32'h92e8a89f);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_IPDESADDR3,   32'h28640e94);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_IPDESADDR4,   32'he9a855a0);
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_PDNUM,        32'h00000000);
            // Also override RQWPTRDBADD and CQDBADD
            override_csr(`ERNIC_PER_QP_BASE(2) + 32'h20, 32'h0fff0008);
            override_csr(`ERNIC_PER_QP_BASE(2) + 32'h28, 32'h0fff1008);
            // Override QP2's MR to match QP3's MR
            override_csr(32'h0000_0200, 32'h00000003); // PDNum = 3 (like QP3)
            override_csr(32'h0000_020C, 32'h400c0000); // BufBase
            override_csr(32'h0000_0214, 32'h000000eb); // R_Key
            #2000;
            // Re-enable
            override_csr(`ERNIC_PER_QP_BASE(2) + `ERNIC_QP_QPCONF, 32'h01dd0407);
            #4000;
            post_wqe(2, 64'h0060_8000, 64'h2100_0000, 64, 8'hA0);
        end

        14: begin  // QP3 with QP2's config — reverse test (already run, keep for reference)
            override_csr(`ERNIC_PER_QP_BASE(3) + `ERNIC_QP_QPCONF, 32'h01dd0406); // disable
            #2000;
            override_csr(`ERNIC_PER_QP_BASE(3) + `ERNIC_QP_QPCONF,       32'h04f80406);
            override_csr(`ERNIC_PER_QP_BASE(3) + `ERNIC_QP_QPADVCONF,    32'h9bf1b002);
            override_csr(`ERNIC_PER_QP_BASE(3) + `ERNIC_QP_SQBA,         32'h0060_8000);
            override_csr(`ERNIC_PER_QP_BASE(3) + `ERNIC_QP_QDEPTH,       32'h00400100);
            override_csr(`ERNIC_PER_QP_BASE(3) + `ERNIC_QP_SQPSN,        32'h00774470);
            override_csr(`ERNIC_PER_QP_BASE(3) + `ERNIC_QP_MACDESADDLSB, 32'h50560f2e);
            override_csr(`ERNIC_PER_QP_BASE(3) + `ERNIC_QP_MACDESADDMSB, 32'h000016c4);
            override_csr(`ERNIC_PER_QP_BASE(3) + `ERNIC_QP_IPDESADDR1,   32'h610c6007);
            override_csr(`ERNIC_PER_QP_BASE(3) + `ERNIC_QP_DESTQPCONF,   32'h00000002);
            override_csr(`ERNIC_PER_QP_BASE(3) + `ERNIC_QP_LSTRQREQ,     32'h04a02aa9);
            #2000;
            override_csr(`ERNIC_PER_QP_BASE(3) + `ERNIC_QP_QPCONF, 32'h04f80407); // re-enable
            #4000;
            post_wqe(3, 64'h0060_8000, 64'h2000_0000, 64, 8'h00);
        end

        15: begin  // QP5 with QP3 config — test if QP5+ works
            override_csr(`ERNIC_PER_QP_BASE(5) + `ERNIC_QP_QPCONF,       32'h01dd0407);
            override_csr(`ERNIC_PER_QP_BASE(5) + `ERNIC_QP_QPADVCONF,    32'hd836ba10);
            override_csr(`ERNIC_PER_QP_BASE(5) + `ERNIC_QP_SQBA,         32'h0060_C000);
            override_csr(`ERNIC_PER_QP_BASE(5) + `ERNIC_QP_QDEPTH,       32'h00400100);
            override_csr(`ERNIC_PER_QP_BASE(5) + `ERNIC_QP_SQPSN,        32'h00e21df7);
            override_csr(`ERNIC_PER_QP_BASE(5) + `ERNIC_QP_MACDESADDLSB, 32'h1c69b8ed);
            override_csr(`ERNIC_PER_QP_BASE(5) + `ERNIC_QP_MACDESADDMSB, 32'h0000ea1e);
            override_csr(`ERNIC_PER_QP_BASE(5) + `ERNIC_QP_IPDESADDR1,   32'hd7ac977e);
            post_wqe(5, 64'h0060_C000, 64'h2200_0000, 64, 8'hE0);
        end

        default: begin
            `uvm_info("TEST", $sformatf("Unknown experiment %0d", exp_num), UVM_NONE)
        end
        endcase

        // Wait for TX
        #500000;

        // Read status
        begin
            status_read_seq sseq = status_read_seq::type_id::create("sseq");
            sseq.start(csr_seqr());
        end

        // Full register check (expect QP2_SQPSN increment for QP2 experiments)
        begin
            check_regs_seq cseq = check_regs_seq::type_id::create("cseq");
            cseq.start(csr_seqr());
        end

        phase.drop_objection(this);
    endtask
endclass
