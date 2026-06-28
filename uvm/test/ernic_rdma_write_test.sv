// Mini sequence to read status registers
class status_read_seq extends ernic_base_seq;
    `uvm_object_utils(status_read_seq)
    function new(string name = "status_read_seq");
        super.new(name);
    endfunction
    task body();
        bit [31:0] r;
        csr_read(32'h10_0108, r);  `uvm_info("STATUS", $sformatf("OUTIOPKTCNT  = 0x%08h", r), UVM_NONE)
        csr_read(32'h18_0188, r);  `uvm_info("STATUS", $sformatf("QP2_STATQP   = 0x%08h", r), UVM_NONE)
        csr_read(32'h10_0000, r);  `uvm_info("STATUS", $sformatf("XRNICCONF    = 0x%08h", r), UVM_NONE)
        csr_read(32'h18_0100, r);  `uvm_info("STATUS", $sformatf("QP2_QPCONF   = 0x%08h", r), UVM_NONE)
    endtask
endclass

// RDMA Write test
class ernic_rdma_write_test extends ernic_base_test;
    `uvm_component_utils(ernic_rdma_write_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        exdes_full_config_seq full_cfg;
        rdma_write_seq seq;
        phase.raise_objection(this);

        // Apply full example design register configuration (194 writes)
        full_cfg = exdes_full_config_seq::type_id::create("full_cfg");
        full_cfg.start(csr_seqr());

        // Wait for responder full init: conf_of_reg_done@80us
        // + SEND phase (~40us) + WRITE phase (~40us) + READ phase (~40us)
        #400000;

        // Build complete RoCEv2 packet in data buffer to test if ERNIC
        // passes through pre-formatted packets.
        begin
            byte unsigned pkt[];
            int unsigned idx;
            bit [15:0] ip_csum;
            pkt = new[134];  // 14(ETH)+20(IP)+8(UDP)+12(BTH)+16(RETH)+64(payload)

            // ---- Ethernet header (14B) ----
            // Dest MAC = QP2_MAC_DEST = {16'h16c4, 32'h50560f2e} = 16:c4:50:56:0f:2e
            pkt[0] = 8'h16; pkt[1] = 8'hc4;
            pkt[2] = 8'h50; pkt[3] = 8'h56;
            pkt[4] = 8'h0f; pkt[5] = 8'h2e;
            // Src MAC = ERNIC MAC = {16'h2f76, 32'h17dc5e9a} = 2f:76:17:dc:5e:9a
            pkt[6]  = 8'h2f; pkt[7]  = 8'h76;
            pkt[8]  = 8'h17; pkt[9]  = 8'hdc;
            pkt[10] = 8'h5e; pkt[11] = 8'h9a;
            // EtherType = 0x0800 (IPv4)
            pkt[12] = 8'h08; pkt[13] = 8'h00;

            // ---- IPv4 header (20B) ----
            pkt[14] = 8'h45;  // Version=4, IHL=5
            pkt[15] = 8'h00;  // DSCP/ECN
            pkt[16] = 8'h00;  // Total Length high (will fix later)
            pkt[17] = 8'h78;  // Total Length low = 120 (134-14 Ethernet = 120)
            pkt[18] = 8'h00;  // Identification high
            pkt[19] = 8'h00;  // Identification low
            pkt[20] = 8'h40;  // Flags + Fragment high
            pkt[21] = 8'h00;  // Fragment low
            pkt[22] = 8'h40;  // TTL = 64
            pkt[23] = 8'h11;  // Protocol = UDP
            pkt[24] = 8'h00;  // Checksum high (compute later)
            pkt[25] = 8'h00;  // Checksum low
            // Src IP: IP4H_QP2_SRC = f38590ba
            pkt[26] = 8'hf3; pkt[27] = 8'h85; pkt[28] = 8'h90; pkt[29] = 8'hba;
            // Dest IP: IP4H_QP2_DEST = 610c6007
            pkt[30] = 8'h61; pkt[31] = 8'h0c; pkt[32] = 8'h60; pkt[33] = 8'h07;

            // Compute IPv4 checksum
            begin
                bit [31:0] sum;
                sum = 0;
                // Sum 16-bit words of IP header
                for (int w = 0; w < 10; w++)
                    sum += {pkt[14 + w*2], pkt[14 + w*2 + 1]};
                // Fold carry
                while (sum[31:16] != 0)
                    sum = sum[15:0] + sum[31:16];
                ip_csum = ~sum[15:0];
                pkt[24] = ip_csum[15:8];
                pkt[25] = ip_csum[7:0];
            end

            // ---- UDP header (8B) ----
            pkt[34] = 8'h68; pkt[35] = 8'h51;  // Src Port = 0x6851
            pkt[36] = 8'h12; pkt[37] = 8'hb7;  // Dest Port = 0x12B7 (RoCEv2)
            pkt[38] = 8'h00; pkt[39] = 8'h64;  // UDP Length = 100 (8+12+16+64)
            pkt[40] = 8'h00; pkt[41] = 8'h00;  // UDP Checksum = 0 (RoCEv2)

            // ---- BTH (12B) ----
            pkt[42] = 8'h0a;  // Opcode = RDMA WRITE only
            pkt[43] = 8'h30;  // SE=0, M=0, PadCnt=0, TVer=0
            pkt[44] = 8'h66; pkt[45] = 8'h6f;  // Partition Key = 0x666f (example design value)
            pkt[46] = 8'h05;  // Reserved + DestQP[23:16]
            pkt[47] = 8'h00; pkt[48] = 8'h02;  // Dest QP = 0x000002 → QP2
            // PSN = 0x00774471 (from QP2_SQPSN after WQE processing)
            pkt[49] = 8'h00; pkt[50] = 8'h77; pkt[51] = 8'h44; pkt[52] = 8'h71;
            // Pad + Acknowledge Request (11:10=reserved, 9:0=AckReq)
            pkt[53] = 8'h00;

            // ---- RETH (16B) ----
            // Virtual Address = 0x0000000030000000 (remote_addr)
            pkt[54] = 8'h00; pkt[55] = 8'h00; pkt[56] = 8'h00; pkt[57] = 8'h00;
            pkt[58] = 8'h30; pkt[59] = 8'h00; pkt[60] = 8'h00; pkt[61] = 8'h00;
            // Remote Key = 0x01000000 ({<<8{32'h1}})
            pkt[62] = 8'h01; pkt[63] = 8'h00; pkt[64] = 8'h00; pkt[65] = 8'h00;
            // DMA Length = 64 (LE: 0x40, 0x00, 0x00, 0x00)
            pkt[66] = 8'h40; pkt[67] = 8'h00; pkt[68] = 8'h00; pkt[69] = 8'h00;

            // ---- Payload (64B) ----
            // Fill with pattern 0x00-0x3f
            for (int i = 0; i < 64; i++)
                pkt[70 + i] = i[7:0];

            // Write full packet to data buffer
            env.mem.backdoor_write(64'h2000_0000, pkt);
            `uvm_info("TEST", $sformatf("Pre-formatted RoCEv2 packet (%0d bytes) at 0x20000000", pkt.size()), UVM_NONE)
            `uvm_info("TEST", $sformatf("  UDP dport check: pkt[36:37]=0x%02h%02h", pkt[36], pkt[37]), UVM_NONE)
        end

        // Post WQE with full packet length
        seq             = rdma_write_seq::type_id::create("seq");
        seq.qpn         = 2;
        seq.sq_addr     = 64'h0060_0000;
        seq.local_addr  = 64'h2000_0000;
        seq.rkey        = 32'h1;
        seq.remote_addr = 64'h3000_0000;
        seq.length      = 134;  // full packet size
        seq.mem_model   = env.mem;
        seq.start(csr_seqr());

        // Verify WQE opcode
        begin
            byte unsigned rdback[];
            env.qp_mem.backdoor_read(64'h0060_0000, 64, rdback);
            `uvm_info("TEST", $sformatf("WQE verify: opcode@byte[16]=0x%02h (exp 0x00), length@[12:15]=0x%02h%02h%02h%02h (exp 134=0x86), laddr@[4:11]=0x%02h%02h%02h%02h_%02h%02h%02h%02h (exp 0x20000000)",
                rdback[16], rdback[12],rdback[13],rdback[14],rdback[15], rdback[4],rdback[5],rdback[6],rdback[7],rdback[8],rdback[9],rdback[10],rdback[11]), UVM_NONE)
        end

        // Wait for TX — up to 500 us
        #500000;

        // Read status registers
        begin
            status_read_seq sseq = status_read_seq::type_id::create("sseq");
            sseq.start(csr_seqr());
        end

        // Full register check against example design expected values
        begin
            check_regs_seq cseq = check_regs_seq::type_id::create("cseq");
            cseq.start(csr_seqr());
        end

        phase.drop_objection(this);
    endtask
endclass
