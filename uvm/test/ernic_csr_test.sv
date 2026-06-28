// CSR smoke test — read/write global register
class ernic_csr_test extends ernic_base_test;
    `uvm_component_utils(ernic_csr_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        bit [31:0] rdata;
        phase.raise_objection(this);
        begin
            ernic_base_seq s = ernic_base_seq::type_id::create("s");
            s.start(csr_seqr());
            // Write then read back IPv4 address register (fully writable)
            s.csr_write(`ERNIC_IPv4XADD, 32'hC0A8010A);
            s.csr_read (`ERNIC_IPv4XADD, rdata);
            if (rdata !== 32'hC0A8010A)
                `uvm_error("CSR_TEST", $sformatf("CSR rd/wr mismatch: got 0x%08h", rdata))
            else
                `uvm_info("CSR_TEST", "CSR read-back PASS", UVM_NONE)
        end
        phase.drop_objection(this);
    endtask
endclass
