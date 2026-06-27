// Send/Receive test
class ernic_send_recv_test extends ernic_base_test;
    `uvm_component_utils(ernic_send_recv_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        send_recv_seq seq;
        byte unsigned payload[];
        phase.raise_objection(this);

        payload = new[64];
        foreach (payload[i]) payload[i] = 8'hA0 + i[7:0];
        env.mem.backdoor_write(64'h5000_0000, payload);

        setup_qp(0);

        seq            = send_recv_seq::type_id::create("seq");
        seq.qpn        = 0;
        seq.sq_addr    = 64'h1000_0000;
        seq.rq_addr    = 64'h1001_0000;
        seq.send_buf   = 64'h5000_0000;
        seq.recv_buf   = 64'h5001_0000;
        seq.lkey       = 32'h1;
        seq.length     = 64;
        seq.mem_model  = env.mem;
        seq.start(csr_seqr());

        #50000;
        phase.drop_objection(this);
    endtask
endclass
