// AXI4-Lite Interface for ERNIC CSR access
interface axi_lite_if #(
    parameter AW = 32,
    parameter DW = 32
)(input logic clk, input logic rst_n);

    // Write address channel
    logic [AW-1:0]  awaddr;
    logic [2:0]     awprot;
    logic           awvalid;
    logic           awready;
    // Write data channel
    logic [DW-1:0]  wdata;
    logic [DW/8-1:0] wstrb;
    logic           wvalid;
    logic           wready;
    // Write response channel
    logic [1:0]     bresp;
    logic           bvalid;
    logic           bready;
    // Read address channel
    logic [AW-1:0]  araddr;
    logic [2:0]     arprot;
    logic           arvalid;
    logic           arready;
    // Read data channel
    logic [DW-1:0]  rdata;
    logic [1:0]     rresp;
    logic           rvalid;
    logic           rready;

    clocking master_cb @(posedge clk);
        default input #1 output #1;
        output awaddr, awprot, awvalid;
        input  awready;
        output wdata, wstrb, wvalid;
        input  wready;
        input  bresp, bvalid;
        output bready;
        output araddr, arprot, arvalid;
        input  arready;
        input  rdata, rresp, rvalid;
        output rready;
    endclocking

    clocking slave_cb @(posedge clk);
        default input #1 output #1;
        input  awaddr, awprot, awvalid;
        output awready;
        input  wdata, wstrb, wvalid;
        output wready;
        output bresp, bvalid;
        input  bready;
        input  araddr, arprot, arvalid;
        output arready;
        output rdata, rresp, rvalid;
        input  rready;
    endclocking

    modport master(clocking master_cb, input clk, rst_n);
    modport slave (clocking slave_cb,  input clk, rst_n);
endinterface
