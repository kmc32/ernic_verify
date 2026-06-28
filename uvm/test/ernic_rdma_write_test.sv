// RDMA Write test
class ernic_rdma_write_test extends ernic_base_test;
    `uvm_component_utils(ernic_rdma_write_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        rdma_write_seq seq;
        byte unsigned src_data[];
        byte unsigned fill_data[];
        phase.raise_objection(this);

        // Pre-fill all memory regions with known data to avoid all-zero reads
        fill_data = new[4096];
        foreach (fill_data[i]) fill_data[i] = 8'hFF;
        // Fill SQ region (0x1000_0000)
        env.mem.backdoor_write(64'h1000_0000, fill_data);
        // Fill data region (0x2000_0000)
        src_data = new[64];
        foreach (src_data[i]) src_data[i] = i;
        env.mem.backdoor_write(64'h2000_0000, src_data);
        // Fill CQ region (0x1002_0000)
        env.mem.backdoor_write(64'h1002_0000, fill_data);
        // Fill RQ region (0x1001_0000)
        env.mem.backdoor_write(64'h1001_0000, fill_data);

        setup_qp(2);

        seq             = rdma_write_seq::type_id::create("seq");
        seq.qpn         = 2;
        seq.sq_addr     = 64'h1000_0000;
        seq.local_addr  = 64'h2000_0000;
        seq.rkey        = 32'h1;
        seq.remote_addr = 64'h3000_0000;
        seq.length      = 64;
        seq.mem_model   = env.mem;
        seq.start(csr_seqr());

        // Verify WQE was written correctly
        begin
            byte unsigned rdback[];
            env.qp_mem.backdoor_read(64'h1000_0000, 64, rdback);
            // With {<<byte{}}, laddr is at bytes[4:11] (little-endian)
            `uvm_info("TEST", $sformatf("WQE verify: opcode@bytes[16]=0x%02h (exp 0x00), laddr@bytes[4:11]=0x%02h%02h%02h%02h_%02h%02h%02h%02h (exp 0x20000000)",
                rdback[16], rdback[4],rdback[5],rdback[6],rdback[7],rdback[8],rdback[9],rdback[10],rdback[11]), UVM_NONE)
        end

        // Wait for completion packet on TX monitor — up to 200 us
        #200000;
        phase.drop_objection(this);
    endtask
endclass
