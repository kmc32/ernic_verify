// ERNIC scoreboard — checks TX packets carry correct RoCEv2 headers
`uvm_analysis_imp_decl(_csr)
class ernic_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(ernic_scoreboard)

    uvm_analysis_imp #(axis_item, ernic_scoreboard) tx_export;
    uvm_analysis_imp_csr #(axi_lite_item, ernic_scoreboard) csr_export;

    int pass_cnt, fail_cnt;  // RoCEv2-valid / invalid
    int pkt_cnt;             // Total packets seen on TX

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tx_export  = new("tx_export",  this);
        csr_export = new("csr_export", this);
    endfunction

    function void write(axis_item item);
        pkt_cnt++;
        check_rocev2_header(item);
    endfunction

    function void write_csr(axi_lite_item item); endfunction

    // Dump first N bytes of packet as hex for debug
    function void dump_pkt_hex(byte unsigned data[], int unsigned n);
        string s;
        int unsigned len = (n < data.size()) ? n : data.size();
        for (int i = 0; i < len; i++) begin
            if (i % 16 == 0) s = {s, $sformatf("\n  %04d: ", i)};
            s = {s, $sformatf("%02h ", data[i])};
        end
        `uvm_info("SB", s, UVM_NONE)
    endfunction

    function void check_rocev2_header(axis_item item);
        bit [15:0] udp_dport;

        // Minimum RoCEv2 frame: 14(ETH)+20(IP)+8(UDP)+12(BTH) = 54 bytes
        if (item.data.size() < 54) begin
            `uvm_error("SB", $sformatf("Packet too short: %0d bytes", item.data.size()))
            fail_cnt++;
            return;
        end

        // Verify UDP dest port = 4791 (0x12B7) — RoCEv2 indicator
        udp_dport = {item.data[36], item.data[37]};
        if (udp_dport !== 16'h12B7) begin
            `uvm_warning("SB", $sformatf("UDP dport=0x%04h at offset 36-37, expected 0x12B7", udp_dport))
            `uvm_info("SB", $sformatf("Packet total len=%0d, first 96 bytes:", item.data.size()), UVM_NONE)
            dump_pkt_hex(item.data, 96);
            fail_cnt++;
            return;
        end
        `uvm_info("SB", $sformatf("RoCEv2 pkt OK len=%0d", item.data.size()), UVM_HIGH)
        pass_cnt++;
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SB", $sformatf("Scoreboard: TOTAL=%0d PASS=%0d FAIL=%0d", pkt_cnt, pass_cnt, fail_cnt), UVM_NONE)
        if (fail_cnt > 0 && pass_cnt == 0)
            `uvm_warning("SB", "All TX packets failed RoCEv2 header check — ERNIC format TBD")
    endfunction
endclass
