// AXI4-Stream monitor
class axis_monitor extends uvm_monitor;
    `uvm_component_utils(axis_monitor)

    virtual axis_if vif;
    uvm_analysis_port #(axis_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual axis_if)::get(this, "", "axis_vif", vif))
            `uvm_fatal("CFG", "axis_vif not found")
    endfunction

    localparam BYTES = $bits(vif.tdata)/8;

    task run_phase(uvm_phase phase);
        forever begin
            axis_item item = axis_item::type_id::create("item");
            item.data = new[0];
            do begin
                @(vif.slave_cb iff vif.slave_cb.tvalid && vif.tready);
                for (int k = 0; k < BYTES; k++)
                    if (vif.slave_cb.tkeep[k]) begin
                        item.data = new[item.data.size()+1](item.data);
                        item.data[item.data.size()-1] = vif.slave_cb.tdata[k*8 +: 8];
                    end
            end while (!vif.slave_cb.tlast);
            ap.write(item);
        end
    endtask
endclass
