// AXI-Lite sequence item
class axi_lite_item extends uvm_sequence_item;
    `uvm_object_utils(axi_lite_item)

    typedef enum {READ, WRITE} kind_e;
    rand kind_e   kind;
    rand bit [31:0] addr;
    rand bit [31:0] data;
    rand bit [3:0]  strb;
         bit [31:0] rdata;
         bit [1:0]  resp;

    constraint c_strb { kind == WRITE -> strb != 0; }

    function new(string name = "axi_lite_item");
        super.new(name);
        strb = 4'hf;
    endfunction
endclass
