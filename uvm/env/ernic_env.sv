// ERNIC verification environment
class ernic_env extends uvm_env;
    `uvm_component_utils(ernic_env)

    axi_lite_agent   csr_agt;
    axis_agent       tx_agt;   // network TX (ERNIC -> loopback)
    axis_agent       rx_agt;   // network RX (loopback -> ERNIC)
    axi4_mem_model   mem;
    ernic_scoreboard sb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        csr_agt = axi_lite_agent::type_id::create("csr_agt", this);
        tx_agt  = axis_agent::type_id::create("tx_agt", this);
        rx_agt  = axis_agent::type_id::create("rx_agt", this);
        mem     = axi4_mem_model::type_id::create("mem",  this);
        sb      = ernic_scoreboard::type_id::create("sb", this);
        uvm_config_db #(uvm_active_passive_enum)::set(this, "tx_agt", "is_active", UVM_PASSIVE);
        uvm_config_db #(uvm_active_passive_enum)::set(this, "rx_agt", "is_active", UVM_ACTIVE);
    endfunction

    function void connect_phase(uvm_phase phase);
        tx_agt.ap.connect(sb.tx_export);
        csr_agt.ap.connect(sb.csr_export);
    endfunction
endclass
