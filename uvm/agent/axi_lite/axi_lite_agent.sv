// AXI-Lite agent
class axi_lite_agent extends uvm_agent;
    `uvm_component_utils(axi_lite_agent)

    axi_lite_driver    driver;
    axi_lite_monitor   monitor;
    uvm_sequencer #(axi_lite_item) sequencer;
    uvm_analysis_port #(axi_lite_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor   = axi_lite_monitor::type_id::create("monitor", this);
        ap        = new("ap", this);
        if (get_is_active() == UVM_ACTIVE) begin
            driver    = axi_lite_driver::type_id::create("driver", this);
            sequencer = uvm_sequencer #(axi_lite_item)::type_id::create("sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        if (get_is_active() == UVM_ACTIVE)
            driver.seq_item_port.connect(sequencer.seq_item_export);
        monitor.ap.connect(ap);
    endfunction
endclass
