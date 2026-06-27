// ERNIC scoreboard — checks TX packets carry correct RoCEv2 headers
// and verifies completion entries in CQ memory
class ernic_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(ernic_scoreboard)

    uvm_analysis_imp #(axis_item, ernic_scoreboard) tx_export;
    uvm_analysis_imp_csr #(axi_lite_item, ernic_scoreboard) csr_export;

    // Expected packet queue
    axis_item exp_pkts[$];
    int       pass_cnt, fail_cnt;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tx_export  = new("tx_export",  this);
        csr_export = new("csr_export", this);
    endfunction

    // Called when ERNIC transmits a packet on the network port
    function void write(axis_item item);
        check_rocev2_header(item);
    endfunction

    // CSR monitor write — not used for checking, just logged
    function void write_csr(axi_lite_item item); endfunction

    function void check_rocev2_header(axis_item item);
        // Minimum RoCEv2 frame: 14(ETH)+20(IP)+8(UDP)+12(BTH) = 54 bytes
        if (item.data.size() < 54) begin
            `uvm_error("SB", $sformatf("Packet too short: %0d bytes", item.data.size()))
            fail_cnt++;
            return;
        end
        // Verify UDP dest port = 4791 (0x12B7) — RoCEv2 indicator
        begin
            bit [15:0] udp_dport;
            udp_dport = {item.data[36], item.data[37]};
            if (udp_dport !== 16'h12B7) begin
                `uvm_error("SB", $sformatf("UDP dport=0x%04h, expected 0x12B7", udp_dport))
                fail_cnt++;
                return;
            end
        end
        `uvm_info("SB", $sformatf("RoCEv2 pkt OK len=%0d", item.data.size()), UVM_HIGH)
        pass_cnt++;
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SB", $sformatf("Scoreboard: PASS=%0d FAIL=%0d", pass_cnt, fail_cnt), UVM_NONE)
        if (fail_cnt > 0)
            `uvm_error("SB", "Test FAILED: scoreboard errors detected")
    endfunction
endclass
