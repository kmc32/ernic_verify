// Base test
class ernic_base_test extends uvm_test;
    `uvm_component_utils(ernic_base_test)

    ernic_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = ernic_env::type_id::create("env", this);
    endfunction

    // Helper: get CSR sequencer handle
    function uvm_sequencer #(axi_lite_item) csr_seqr();
        return env.csr_agt.sequencer;
    endfunction

    // Setup one QP (1-based QP number, QP2+ for RC QPs)
    task setup_qp(int unsigned qpn = 2,
                  bit [31:0] dst_ip = 32'hC0A80002,
                  int unsigned dst_qpn = 3);
        qp_setup_seq seq = qp_setup_seq::type_id::create("qp_setup");
        seq.qpn     = qpn;
        seq.dst_ip  = dst_ip;
        seq.dst_qpn = dst_qpn;
        seq.start(csr_seqr());
    endtask
endclass
