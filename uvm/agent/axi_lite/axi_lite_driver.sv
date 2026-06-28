// AXI-Lite driver
`define DRV_WAIT(signal, name, addr) \
    begin \
        int _c = 0; \
        while (_c < HANDSHAKE_TIMEOUT) begin \
            @(vif.master_cb); \
            if (signal) break; \
            _c++; \
        end \
        if (_c >= HANDSHAKE_TIMEOUT) begin \
            `uvm_error("DRV", $sformatf("TIMEOUT waiting for %s (addr=0x%08h)", name, addr)) \
        end \
    end

class axi_lite_driver extends uvm_driver #(axi_lite_item);
    `uvm_component_utils(axi_lite_driver)

    virtual axi_lite_if vif;

    // Timeout in clock cycles for AXI-Lite handshake
    localparam int HANDSHAKE_TIMEOUT = 100000;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual axi_lite_if)::get(this, "", "axi_lite_vif", vif))
            `uvm_fatal("CFG", "axi_lite_vif not found")
        `uvm_info("DRV", "AXI-Lite driver build complete", UVM_NONE)
    endfunction

    task run_phase(uvm_phase phase);
        axi_lite_item item;
        _idle();
        // Wait for reset deassertion before driving any AXI-Lite traffic
        @(posedge vif.rst_n);
        `uvm_info("DRV", "Reset released, AXI-Lite driver starting", UVM_NONE)
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
        `uvm_info("DRV", $sformatf("WRITE addr=0x%08h data=0x%08h strb=0x%01h",
                   item.addr, item.data, item.strb), UVM_NONE)
        // AW + W drive on first posedge after item received
        @(vif.master_cb);
        vif.master_cb.awaddr  <= item.addr;
        vif.master_cb.awprot  <= 0;
        vif.master_cb.awvalid <= 1;
        vif.master_cb.wdata   <= item.data;
        vif.master_cb.wstrb   <= item.strb;
        vif.master_cb.wvalid  <= 1;

        // Wait for awready + wready (in parallel)
        `uvm_info("DRV", "AW+W driven, waiting for awready/wready...", UVM_NONE)
        fork
            `DRV_WAIT(vif.master_cb.awready, "awready", item.addr)
            `DRV_WAIT(vif.master_cb.wready,  "wready",  item.addr)
        join
        vif.master_cb.awvalid <= 0;
        vif.master_cb.wvalid  <= 0;

        // Wait for write response
        `uvm_info("DRV", "AW+W handshake complete, waiting for bvalid...", UVM_NONE)
        `DRV_WAIT(vif.master_cb.bvalid, "bvalid", item.addr)
        item.resp = vif.master_cb.bresp;
        `uvm_info("DRV", $sformatf("WRITE complete addr=0x%08h resp=%0d", item.addr, item.resp), UVM_NONE)
    endtask

    task do_read(axi_lite_item item);
        `uvm_info("DRV", $sformatf("READ addr=0x%08h", item.addr), UVM_NONE)
        @(vif.master_cb);
        vif.master_cb.araddr  <= item.addr;
        vif.master_cb.arprot  <= 0;
        vif.master_cb.arvalid <= 1;

        `DRV_WAIT(vif.master_cb.arready, "arready", item.addr)
        vif.master_cb.arvalid <= 0;

        `uvm_info("DRV", "AR handshake complete, waiting for rvalid...", UVM_NONE)
        `DRV_WAIT(vif.master_cb.rvalid, "rvalid", item.addr)
        item.rdata = vif.master_cb.rdata;
        item.resp  = vif.master_cb.rresp;
        `uvm_info("DRV", $sformatf("READ complete addr=0x%08h rdata=0x%08h resp=%0d",
                   item.addr, item.rdata, item.resp), UVM_NONE)
    endtask
endclass
`undef DRV_WAIT
