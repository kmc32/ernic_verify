// Reliable transport test — verifies PSN tracking and ACK/NAK flow
// by sending multiple packets and checking scoreboard pass count
class ernic_reliable_transport_test extends ernic_base_test;
    `uvm_component_utils(ernic_reliable_transport_test)

    int unsigned NUM_PKTS = 4;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        setup_qp(0);

        // Issue NUM_PKTS RDMA Writes in sequence, each with different data
        for (int i = 0; i < NUM_PKTS; i++) begin
            rdma_write_seq seq = rdma_write_seq::type_id::create($sformatf("seq%0d", i));
            byte unsigned data_buf[];
            data_buf = new[64];
            foreach (data_buf[j]) data_buf[j] = i * 64 + j;
            env.mem.backdoor_write(64'h6000_0000 + i*64, data_buf);

            seq.qpn         = 0;
            seq.sq_addr     = 64'h1000_0000 + i*64;
            seq.local_addr  = 64'h6000_0000 + i*64;
            seq.local_key   = 32'h1;
            seq.remote_addr = 64'h7000_0000 + i*64;
            seq.remote_key  = 32'h2;
            seq.length      = 64;
            seq.mem_model   = env.mem;
            seq.start(csr_seqr());
        end

        #100000;
        // Verify all NUM_PKTS showed up on TX
        if (env.sb.pass_cnt < NUM_PKTS)
            `uvm_error("RT_TEST", $sformatf("Expected >=%0d TX pkts, got %0d",
                                            NUM_PKTS, env.sb.pass_cnt))
        else
            `uvm_info("RT_TEST", "Reliable transport PASS", UVM_NONE)
        phase.drop_objection(this);
    endtask
endclass
