// AXI4-Stream sequence item (network packet)
class axis_item extends uvm_sequence_item;
    `uvm_object_utils(axis_item)

    rand byte unsigned data[];
    rand bit            user;

    constraint c_len { data.size() inside {[64:1024]}; }

    function new(string name = "axis_item");
        super.new(name);
    endfunction
endclass
