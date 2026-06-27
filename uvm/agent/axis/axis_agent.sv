// AXI4-Stream agent
class axis_agent extends uvm_agent;
    `uvm_component_utils(axis_agent)

    axis_driver    driver;
    axis_monitor   monitor;
    uvm_sequencer #(axis_item) sequencer;
    uvm_analysis_port #(axis_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = axis_monitor::type_id::create("monitor", this);
        ap      = new("ap", this);
        if (get_is_active() == UVM_ACTIVE) begin
            driver    = axis_driver::type_id::create("driver", this);
            sequencer = uvm_sequencer #(axis_item)::type_id::create("sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        if (get_is_active() == UVM_ACTIVE)
            driver.seq_item_port.connect(sequencer.seq_item_export);
        monitor.ap.connect(ap);
    endfunction
endclass
