// AXI-Lite monitor
class axi_lite_monitor extends uvm_monitor;
    `uvm_component_utils(axi_lite_monitor)

    virtual axi_lite_if vif;
    uvm_analysis_port #(axi_lite_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual axi_lite_if)::get(this, "", "axi_lite_vif", vif))
            `uvm_fatal("CFG", "axi_lite_vif not found")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            axi_lite_item item = axi_lite_item::type_id::create("item");
            // Detect write vs read
            fork
                begin : wr
                    @(vif.slave_cb iff vif.slave_cb.awvalid && vif.awready);
                    item.kind = axi_lite_item::WRITE;
                    item.addr = vif.slave_cb.awaddr;
                    @(vif.slave_cb iff vif.slave_cb.wvalid && vif.wready);
                    item.data = vif.slave_cb.wdata;
                    item.strb = vif.slave_cb.wstrb;
                    @(vif.slave_cb iff vif.bvalid && vif.slave_cb.bready);
                    item.resp = vif.bresp;
                    disable rd;
                end
                begin : rd
                    @(vif.slave_cb iff vif.slave_cb.arvalid && vif.arready);
                    item.kind = axi_lite_item::READ;
                    item.addr = vif.slave_cb.araddr;
                    @(vif.slave_cb iff vif.rvalid && vif.slave_cb.rready);
                    item.rdata = vif.rdata;
                    item.resp  = vif.rresp;
                    disable wr;
                end
            join_any
            ap.write(item);
        end
    endtask
endclass
