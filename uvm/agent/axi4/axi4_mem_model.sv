// AXI4 slave memory model — backs ERNIC DMA master port
class axi4_mem_model extends uvm_component;
    `uvm_component_utils(axi4_mem_model)

    virtual axi4_if vif;
    // Sparse byte-addressable memory — static so all instances share the same backing store
    static byte unsigned mem[longint unsigned];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual axi4_if)::get(this, "", "axi4_vif", vif))
            `uvm_fatal("CFG", "axi4_vif not found")
    endfunction

    task run_phase(uvm_phase phase);
        fork
            handle_write();
            handle_read();
        join_none
    endtask

    localparam DBytes = $bits(vif.wdata)/8;

    task handle_write();
        forever begin
            longint unsigned base;
            // AW
            vif.slave_cb.awready <= 0;
            @(vif.slave_cb iff vif.slave_cb.awvalid);
            base = vif.slave_cb.awaddr;
            `uvm_info("MEM_WR", $sformatf("%s AWADDR=0x%08h AWLEN=%0d", get_full_name(), base, vif.slave_cb.awlen), UVM_NONE)
            vif.slave_cb.awready <= 1;
            @(vif.slave_cb); vif.slave_cb.awready <= 0;
            // W beats
            begin
                int beat = 0;
                do begin
                    vif.slave_cb.wready <= 0;
                    @(vif.slave_cb iff vif.slave_cb.wvalid);
                    vif.slave_cb.wready <= 1;
                    for (int k = 0; k < DBytes; k++)
                        if (vif.slave_cb.wstrb[k])
                            mem[base + beat*DBytes + k] = vif.slave_cb.wdata[k*8 +: 8];
                    @(vif.slave_cb); vif.slave_cb.wready <= 0;
                    beat++;
                end while (!vif.slave_cb.wlast);
            end
            // B
            @(vif.slave_cb);
            vif.slave_cb.bid   <= vif.slave_cb.awid;
            vif.slave_cb.bresp <= 0;
            vif.slave_cb.bvalid <= 1;
            @(vif.slave_cb iff vif.slave_cb.bready);
            vif.slave_cb.bvalid <= 0;
        end
    endtask

    task handle_read();
        forever begin
            longint unsigned base;
            int              len;
            vif.slave_cb.arready <= 0;
            @(vif.slave_cb iff vif.slave_cb.arvalid);
            base = vif.slave_cb.araddr;
            len  = vif.slave_cb.arlen + 1;
            `uvm_info("MEM_RD", $sformatf("%s ARADDR=0x%08h ARLEN=%0d", get_full_name(), base, vif.slave_cb.arlen), UVM_NONE)
            vif.slave_cb.arready <= 1;
            @(vif.slave_cb); vif.slave_cb.arready <= 0;
            for (int b = 0; b < len; b++) begin
                logic [$bits(vif.rdata)-1:0] beat = 0;
                for (int k = 0; k < DBytes; k++)
                    beat[k*8 +: 8] = mem.exists(base + b*DBytes + k) ?
                                      mem[base + b*DBytes + k] : 8'h0;
                if (b == 0) `uvm_info("MEM_RD", $sformatf("%s BEAT0 first 32b=0x%08h", get_full_name(), beat[511:480]), UVM_NONE)
                @(vif.slave_cb);
                vif.slave_cb.rid   <= vif.slave_cb.arid;
                vif.slave_cb.rdata <= beat;
                vif.slave_cb.rresp <= 0;
                vif.slave_cb.rlast <= (b == len-1);
                vif.slave_cb.rvalid <= 1;
                @(vif.slave_cb iff vif.slave_cb.rready);
                vif.slave_cb.rvalid <= 0;
            end
        end
    endtask

    // Utility: write a byte array at a given base address
    function void backdoor_write(longint unsigned base, byte unsigned data[]);
        foreach (data[i]) mem[base+i] = data[i];
    endfunction

    function void backdoor_read(longint unsigned base, int len, output byte unsigned data[]);
        data = new[len];
        foreach (data[i]) data[i] = mem.exists(base+i) ? mem[base+i] : 0;
    endfunction
endclass
