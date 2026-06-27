// Base sequence — CSR read/write helpers
class ernic_base_seq extends uvm_sequence #(axi_lite_item);
    `uvm_object_utils(ernic_base_seq)
    `uvm_declare_p_sequencer(uvm_sequencer #(axi_lite_item))

    function new(string name = "ernic_base_seq");
        super.new(name);
    endfunction

    task csr_write(bit [31:0] addr, bit [31:0] data);
        axi_lite_item item = axi_lite_item::type_id::create("wr");
        start_item(item);
        item.kind = axi_lite_item::WRITE;
        item.addr = addr;
        item.data = data;
        item.strb = 4'hf;
        finish_item(item);
    endtask

    task csr_read(bit [31:0] addr, output bit [31:0] rdata);
        axi_lite_item item = axi_lite_item::type_id::create("rd");
        start_item(item);
        item.kind = axi_lite_item::READ;
        item.addr = addr;
        finish_item(item);
        rdata = item.rdata;
    endtask
endclass
