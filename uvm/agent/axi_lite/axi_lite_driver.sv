// AXI-Lite driver
class axi_lite_driver extends uvm_driver #(axi_lite_item);
    `uvm_component_utils(axi_lite_driver)

    virtual axi_lite_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual axi_lite_if)::get(this, "", "axi_lite_vif", vif))
            `uvm_fatal("CFG", "axi_lite_vif not found")
    endfunction

    task run_phase(uvm_phase phase);
        axi_lite_item item;
        _idle();
        forever begin
            seq_item_port.get_next_item(item);
            if (item.kind == axi_lite_item::WRITE) do_write(item);
            else                                   do_read(item);
            seq_item_port.item_done();
        end
    endtask

    task _idle();
        vif.master_cb.awvalid <= 0;
        vif.master_cb.wvalid  <= 0;
        vif.master_cb.bready  <= 1;
        vif.master_cb.arvalid <= 0;
        vif.master_cb.rready  <= 1;
    endtask

    task do_write(axi_lite_item item);
        // AW
        @(vif.master_cb);
        vif.master_cb.awaddr  <= item.addr;
        vif.master_cb.awprot  <= 0;
        vif.master_cb.awvalid <= 1;
        vif.master_cb.wdata   <= item.data;
        vif.master_cb.wstrb   <= item.strb;
        vif.master_cb.wvalid  <= 1;
        fork
            begin @(vif.master_cb iff vif.master_cb.awready); vif.master_cb.awvalid <= 0; end
            begin @(vif.master_cb iff vif.master_cb.wready);  vif.master_cb.wvalid  <= 0; end
        join
        @(vif.master_cb iff vif.master_cb.bvalid);
        item.resp = vif.master_cb.bresp;
    endtask

    task do_read(axi_lite_item item);
        @(vif.master_cb);
        vif.master_cb.araddr  <= item.addr;
        vif.master_cb.arprot  <= 0;
        vif.master_cb.arvalid <= 1;
        @(vif.master_cb iff vif.master_cb.arready);
        vif.master_cb.arvalid <= 0;
        @(vif.master_cb iff vif.master_cb.rvalid);
        item.rdata = vif.master_cb.rdata;
        item.resp  = vif.master_cb.rresp;
    endtask
endclass
