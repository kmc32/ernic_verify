// AXI4-Stream Interface for ERNIC network TX/RX
interface axis_if #(
    parameter DW = 512,
    parameter KEEP_W = DW/8,
    parameter USER_W = 1
)(input logic clk, input logic rst_n);

    logic [DW-1:0]     tdata;
    logic [KEEP_W-1:0] tkeep;
    logic              tvalid;
    logic              tready;
    logic              tlast;
    logic [USER_W-1:0] tuser;

    clocking master_cb @(posedge clk);
        default input #1 output #1;
        output tdata, tkeep, tvalid, tlast, tuser;
        input  tready;
    endclocking

    clocking slave_cb @(posedge clk);
        default input #1 output #1;
        input  tdata, tkeep, tvalid, tlast, tuser;
        output tready;
    endclocking

    modport master(clocking master_cb, input clk, rst_n);
    modport slave (clocking slave_cb,  input clk, rst_n);
endinterface
