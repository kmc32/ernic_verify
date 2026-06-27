// RDMA Write test
class ernic_rdma_write_test extends ernic_base_test;
    `uvm_component_utils(ernic_rdma_write_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        rdma_write_seq seq;
        byte unsigned src_data[];
        phase.raise_objection(this);

        // Initialise source buffer in memory model
        src_data = new[64];
        foreach (src_data[i]) src_data[i] = i;
        env.mem.backdoor_write(64'h2000_0000, src_data);

        setup_qp(0);

        seq             = rdma_write_seq::type_id::create("seq");
        seq.qpn         = 0;
        seq.sq_addr     = 64'h1000_0000;
        seq.local_addr  = 64'h2000_0000;
        seq.local_key   = 32'h1;
        seq.remote_addr = 64'h3000_0000;
        seq.remote_key  = 32'h2;
        seq.length      = 64;
        seq.mem_model   = env.mem;
        seq.start(csr_seqr());

        // Wait for completion packet on TX monitor
        #50000;
        phase.drop_objection(this);
    endtask
endclass
