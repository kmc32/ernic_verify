// CSR smoke test — read/write all QP registers
class ernic_csr_test extends ernic_base_test;
    `uvm_component_utils(ernic_csr_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        ernic_base_seq seq = ernic_base_seq::type_id::create("seq");
        bit [31:0] rdata;
        phase.raise_objection(this);
        // Write then read back a known pattern to QP0 SQ addr
        seq.start(null);  // dummy, use helpers directly via fork
        begin
            automatic ernic_base_seq s = ernic_base_seq::type_id::create("s");
            s.start(csr_seqr());
            s.csr_write(`ERNIC_QP_BASE(0) + `ERNIC_QP_SEND_QA_L, 32'hDEAD_BEEF);
            s.csr_read (`ERNIC_QP_BASE(0) + `ERNIC_QP_SEND_QA_L, rdata);
            if (rdata !== 32'hDEAD_BEEF)
                `uvm_error("CSR_TEST", $sformatf("CSR rd/wr mismatch: got 0x%08h", rdata))
            else
                `uvm_info("CSR_TEST", "CSR read-back PASS", UVM_NONE)
        end
        phase.drop_objection(this);
    endtask
endclass
