// AXI4 Interface for ERNIC memory master access
interface axi4_if #(
    parameter AW = 64,
    parameter DW = 512,
    parameter IW = 4
)(input logic clk, input logic rst_n);

    // Write address
    logic [IW-1:0]   awid;
    logic [AW-1:0]   awaddr;
    logic [7:0]      awlen;
    logic [2:0]      awsize;
    logic [1:0]      awburst;
    logic            awvalid;
    logic            awready;
    // Write data
    logic [DW-1:0]   wdata;
    logic [DW/8-1:0] wstrb;
    logic            wlast;
    logic            wvalid;
    logic            wready;
    // Write response
    logic [IW-1:0]   bid;
    logic [1:0]      bresp;
    logic            bvalid;
    logic            bready;
    // Read address
    logic [IW-1:0]   arid;
    logic [AW-1:0]   araddr;
    logic [7:0]      arlen;
    logic [2:0]      arsize;
    logic [1:0]      arburst;
    logic            arvalid;
    logic            arready;
    // Read data
    logic [IW-1:0]   rid;
    logic [DW-1:0]   rdata;
    logic [1:0]      rresp;
    logic            rlast;
    logic            rvalid;
    logic            rready;

    clocking master_cb @(posedge clk);
        default input #1 output #1;
        output awid, awaddr, awlen, awsize, awburst, awvalid;
        input  awready;
        output wdata, wstrb, wlast, wvalid;
        input  wready;
        input  bid, bresp, bvalid;
        output bready;
        output arid, araddr, arlen, arsize, arburst, arvalid;
        input  arready;
        input  rid, rdata, rresp, rlast, rvalid;
        output rready;
    endclocking

    clocking slave_cb @(posedge clk);
        default input #1 output #1;
        input  awid, awaddr, awlen, awsize, awburst, awvalid;
        output awready;
        input  wdata, wstrb, wlast, wvalid;
        output wready;
        output bid, bresp, bvalid;
        input  bready;
        input  arid, araddr, arlen, arsize, arburst, arvalid;
        output arready;
        output rid, rdata, rresp, rlast, rvalid;
        input  rready;
    endclocking

    modport master(clocking master_cb, input clk, rst_n);
    modport slave (clocking slave_cb,  input clk, rst_n);
endinterface
