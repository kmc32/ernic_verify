// RDMA Read test
class ernic_rdma_read_test extends ernic_base_test;
    `uvm_component_utils(ernic_rdma_read_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        rdma_read_seq seq;
        phase.raise_objection(this);
        setup_qp(2);

        seq             = rdma_read_seq::type_id::create("seq");
        seq.qpn         = 2;
        seq.sq_addr     = 64'h1000_0000;
        seq.local_addr  = 64'h4000_0000;
        seq.rkey        = 32'h1;
        seq.remote_addr = 64'h3000_0000;
        seq.length      = 128;
        seq.mem_model   = env.mem;
        seq.start(csr_seqr());

        #50000;
        phase.drop_objection(this);
    endtask
endclass
