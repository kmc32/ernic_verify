// AXI4-Stream driver  (TX side: drives packets into ERNIC rx port)
class axis_driver extends uvm_driver #(axis_item);
    `uvm_component_utils(axis_driver)

    virtual axis_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual axis_if)::get(this, "", "axis_vif", vif))
            `uvm_fatal("CFG", "axis_vif not found")
    endfunction

    task run_phase(uvm_phase phase);
        axis_item item;
        vif.master_cb.tvalid <= 0;
        forever begin
            seq_item_port.get_next_item(item);
            drive_packet(item);
            seq_item_port.item_done();
        end
    endtask

    localparam BYTES = $bits(vif.tdata)/8;

    task drive_packet(axis_item item);
        int bytes = item.data.size();
        int beats = (bytes + BYTES - 1) / BYTES;
        for (int b = 0; b < beats; b++) begin
            logic [BYTES*8-1:0] beat_data = 0;
            logic [BYTES-1:0]   beat_keep = 0;
            int base = b * BYTES;
            for (int k = 0; k < BYTES && (base+k) < bytes; k++) begin
                beat_data[k*8 +: 8] = item.data[base+k];
                beat_keep[k]        = 1;
            end
            @(vif.master_cb);
            vif.master_cb.tdata  <= beat_data;
            vif.master_cb.tkeep  <= beat_keep;
            vif.master_cb.tlast  <= (b == beats-1);
            vif.master_cb.tuser  <= item.user;
            vif.master_cb.tvalid <= 1;
            @(vif.master_cb iff vif.master_cb.tready);
        end
        vif.master_cb.tvalid <= 0;
    endtask
endclass
