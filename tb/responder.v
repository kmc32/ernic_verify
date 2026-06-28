
`timescale 1ns/1ns
module exdes_send_rdresp_ack_pkt_gen
# (
  parameter C_AXIS_DATA_WIDTH = 512
  )
(
  input  wire                             core_clk,
  input  wire                             core_aresetn,
  input  wire                             tx_m_axis_tready_send_tst,
  output reg [C_AXIS_DATA_WIDTH-1 : 0]    tx_m_axis_tdata_send_test,
  output reg [C_AXIS_DATA_WIDTH/8-1:0]    tx_m_axis_tkeep_send_test,
  output reg                              tx_m_axis_tvalid_send_test,
  output reg                              tx_m_axis_tlast_send_test,
  input  wire [31:0]                      MAC_SRC_ADDR_LSB,
  input  wire [31:0]                      MAC_SRC_ADDR_MSB,
  input  wire [31:0]                      QP3_MAC_DEST_ADDR_LSB,
  input  wire [31:0]                      QP3_MAC_DEST_ADDR_MSB,
  input  wire [31:0]                      IP4H_QP3_DEST_ADDR_1,
  input  wire [31:0]                      IP4H_QP3_SRC_ADDR_1,
  input  wire [31:0]                      QP3_PSN,
  input  wire [31:0]                      QP2_MAC_DEST_ADDR_LSB,
  input  wire [31:0]                      QP2_MAC_DEST_ADDR_MSB,
  input  wire [31:0]                      IP4H_QP2_DEST_ADDR_1,
  input  wire [31:0]                      IP4H_QP2_SRC_ADDR_1,
  input  wire [31:0]                      QP2_PSN,
  input  wire [31:0]                      QP4_MAC_DEST_ADDR_LSB,
  input  wire [31:0]                      QP4_MAC_DEST_ADDR_MSB,
  input  wire [31:0]                      IP4H_QP4_DEST_ADDR_1,
  input  wire [31:0]                      QP4_PSN,

  input  wire [31:0]                      QP5_MAC_DEST_ADDR_LSB,
  input  wire [31:0]                      QP5_MAC_DEST_ADDR_MSB,
  input  wire [31:0]                      IP4H_QP5_DEST_ADDR_1,
  input  wire [31:0]                      QP5_PSN,

  input  wire [31:0]                      QP6_MAC_DEST_ADDR_LSB,
  input  wire [31:0]                      QP6_MAC_DEST_ADDR_MSB,
  input  wire [31:0]                      IP4H_QP6_DEST_ADDR_1,
  input  wire [31:0]                      QP6_PSN,

  input  wire [31:0]                      QP7_MAC_DEST_ADDR_LSB,
  input  wire [31:0]                      QP7_MAC_DEST_ADDR_MSB,
  input  wire [31:0]                      IP4H_QP7_DEST_ADDR_1,
  input  wire [31:0]                      QP7_PSN,

  input  wire                             conf_of_reg_done,
  output wire                             RDMA_SND_TST_DONE,
  input  wire [C_AXIS_DATA_WIDTH-1 : 0]   wqe_proc_top_m_axis_tdata,
  input  wire                             wqe_proc_top_m_axis_tvalid,
  input  wire                             wqe_proc_top_m_axis_tlast,
  output reg  [23:0]                      write_pkt_psn,
  output reg                              rdma_write_test_done_i,
  output reg                              rdma_rdrq_test_done_i,
  output reg                              post_rdma_rd_wqe,
  output reg                              post_rdma_wr_wqe,
  output wire                             rdma_write_path_done,
  output wire                             rdma_read_path_done
 
);

reg [3:0]    axis_gen_st;
reg          rdma_send_test_done_i;
reg          rdma_send_with_inv_test_done_i;
reg          rdma_read_path_done_i;
localparam TX_AXIS_PKT_GEN_ST0 = 4'h0;
localparam TX_AXIS_PKT_GEN_ST1 = 4'h1;
localparam TX_AXIS_PKT_GEN_ST2 = 4'h2;
localparam TX_AXIS_PKT_GEN_ST3 = 4'h3;
localparam TX_AXIS_PKT_GEN_ST4 = 4'h4;
localparam TX_AXIS_PKT_GEN_ST5 = 4'h5;                                        
localparam TX_AXIS_PKT_GEN_ST6 = 4'h6;
localparam TX_AXIS_PKT_GEN_ST7 = 4'h7;
localparam TX_AXIS_PKT_GEN_ST8 = 4'h8;
localparam TX_AXIS_PKT_GEN_ST9 = 4'h9;
localparam TX_AXIS_PKT_GEN_ST10 = 4'hA;
localparam TX_AXIS_PKT_GEN_ST11 = 4'hB;
localparam TX_AXIS_PKT_GEN_ST12 = 4'hC;
localparam TX_AXIS_PKT_GEN_ST13 = 4'hD;
localparam TX_AXIS_PKT_GEN_ST14 = 4'hE;

reg [7:0] pkt_sent_cnt;
reg [7:0] pkt_sent_QP3;
reg [7:0] pkt_sent_QP4;
reg [7:0] pkt_sent_QP5;
reg [7:0] pkt_sent_QP6;
reg [7:0] pkt_sent_QP7;
reg [2:0] cnt;
reg [8:0] remaining_len_to_tx;
reg [15:0] wait_cnt;
reg [15:0] wait_cnt_rr;
reg [23:0] rd_resp_req_psn;
localparam NUM_SEND_PKT    = 2;
localparam NUM_SEND_WITH_INV_PKT    = 8;
localparam NUM_RDMA_RD_PKT = 8;
localparam NUM_RDMA_WR_PKT = 8;

// Signals to drive the CRC module
reg [64*8*5-1:0] pkt_to_tx;
reg [24:0] chekcsum_i;


function [64*8-1 : 0] hdr_byte_reorder;
  input [64*8-1 :0] in_hdr;
  integer i;
  for(i=0;i<64;i=i+1) begin
    hdr_byte_reorder[((64-i)*8)-1 -: 8] = in_hdr[((i+1)*8)-1 -: 8];
  end
endfunction

function [58*8-1 : 0] hdr_byte_reorder_rd_rsp;
  input [58*8-1 :0] in_hdr;
  integer i;
  for(i=0;i<58;i=i+1) begin
    hdr_byte_reorder_rd_rsp[((58-i)*8)-1 -: 8] = in_hdr[((i+1)*8)-1 -: 8];
  end
endfunction

function [2*8-1 : 0] chk_sum_calc;
  input [18*8-1 :0] in_ipv4_hdr;
begin

  chekcsum_i = in_ipv4_hdr[18*8-1 -: 16] + in_ipv4_hdr[16*8-1 -: 16] +  in_ipv4_hdr[14*8-1 -: 16] + in_ipv4_hdr[12*8-1 -: 16] + in_ipv4_hdr[10*8-1 -: 16] + in_ipv4_hdr[8*8-1 -: 16] + 
                  in_ipv4_hdr[6*8-1 -: 16] + in_ipv4_hdr[4*8-1 -: 16] + in_ipv4_hdr[2*8-1 -: 16];
  if(|chekcsum_i[19:16]) begin
    chekcsum_i = chekcsum_i[15:0] + chekcsum_i[19:16];
  end
  chk_sum_calc = {~chekcsum_i[15:8],~chekcsum_i[7:0]};
end

endfunction


// Header fields

localparam IPV4_CHKSUM = 16'h245c;
localparam pkt_len_rd_resp = 314;
localparam Total_Len_rd_resp = 16'h0130;

localparam Protocol_ID = 16'h0800;
//initiator changes
localparam Total_Len = 16'h003c;
localparam UDP_Protocol_ID = 8'h11;
localparam IPV4_CHKSUM_QP3 = 16'h76f8; // QP3
localparam IPV4_CHKSUM_QP2 = 16'h2510; //QP2
localparam UDP_Len = Total_Len - 8'h14;
localparam UDP_Len_rd_resp = Total_Len_rd_resp - 8'h14;

reg [54*8-1:0] in_hdr;
reg [58*8-1:0] in_hdr_inv;
reg [64*8-1:0] in_hdr_in;
reg [58*8-1:0] in_hdr_rd_rsp;
reg [58*8-1:0] hdr_byte_reorder1;
// packet length
localparam send_pkt_len = 70;// in bytes -- including header (header : 70 bytes)

reg [511:0] mem_ack [7:0];
localparam ack_pkt_len = 58;
reg rdma_write_path_done_i;

`include "XRNIC_Reg_Config.vh"

// Below block shall drive the CRC module to calculate the CRC
//initiator 

reg [1:0] cnt_psn;
localparam write_pkt_len = 134; // in bytes -- including header (header : 70 bytes + 64 bytes payload)
localparam Total_len_write = 16'h007c;
localparam UDP_Len_write = Total_len_write - 8'h14;
//reg          rdma_rdrq_test_done_i;
//reg          rdma_write_test_done_i;
reg [511:0] temp_val;
always @(posedge core_clk or negedge core_aresetn) begin
    if(~core_aresetn) begin
      tx_m_axis_tdata_send_test  <= 'b0;
      tx_m_axis_tkeep_send_test  <= 'b0;
      tx_m_axis_tvalid_send_test <= 1'b0;
      tx_m_axis_tlast_send_test  <= 1'b0;
      remaining_len_to_tx        <= 'b0;
      pkt_sent_cnt               <= 'b0;
      cnt                        <= 0;
      wait_cnt                   <= 16'h0000;
      wait_cnt_rr                <= 16'h0000;
      in_hdr_in                     <= 'b0;
      rdma_rdrq_test_done_i      <= 1'b0;
      rdma_write_test_done_i      <= 1'b0;
      write_pkt_psn              <= 'b0;
      temp_val                   <= 'b0;
      pkt_sent_QP3               <= 'b0;
      pkt_sent_QP4               <= 'b0;
      pkt_sent_QP5               <= 'b0;
      pkt_sent_QP6               <= 'b0;
      pkt_sent_QP7               <= 'b0;
      cnt_psn                    <= 'b0;
      axis_gen_st                <= TX_AXIS_PKT_GEN_ST0;
      end
      else begin
        case(axis_gen_st)
            TX_AXIS_PKT_GEN_ST0: begin
                                //if (rdma_rdrq_test_done_i == 1'b1 && conf_of_reg_done == 1'b1) begin
                              //  if ( conf_of_reg_done == 1'b1) begin
                                   // EXACT example design format — target QP3 with original params
                                   if (conf_of_reg_done == 1'b1 && pkt_sent_cnt < 4'h8) begin
                                   in_hdr_in <= {MAC_SRC_ADDR_MSB[15:0],MAC_SRC_ADDR_LSB, QP3_MAC_DEST_ADDR_MSB[15:0],QP3_MAC_DEST_ADDR_LSB, Protocol_ID,8'h45,8'hb8,Total_len_write,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,chk_sum_calc({8'h45,8'hb8,Total_len_write,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,IP4H_QP3_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1}),IP4H_QP3_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1,16'h6851,16'h12b7,UDP_Len_write,16'h0000,8'h0a,8'h30,16'h666f,24'h050000,16'h0300,QP3_PSN[23:8],(QP3_PSN[7:0]+pkt_sent_cnt + 1'b1), 32'h00000000, 32'hcad53074, 16'h0000 };
                                   pkt_sent_QP3 <= pkt_sent_QP3 + 1'b1;
                             //   end
                                  end 
                                  else if (pkt_sent_cnt == 4'h4) begin
                                         in_hdr_in <= {MAC_SRC_ADDR_MSB[15:0],MAC_SRC_ADDR_LSB,QP4_MAC_DEST_ADDR_MSB[15:0],QP4_MAC_DEST_ADDR_LSB,Protocol_ID,8'h45,8'hb8,Total_len_write,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,chk_sum_calc({8'h45,8'hb8,Total_len_write,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,IP4H_QP4_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1}),IP4H_QP4_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1,16'h6851,16'h12b7,UDP_Len_write,16'h0000,8'h0a,8'h30,16'h666f,24'h050000,16'h0400,QP4_PSN[23:8],(QP4_PSN[7:0]+1'b1), 32'h00000000, 32'hcad93074, 16'h0000};
                                                               pkt_sent_QP4 <= pkt_sent_QP4 + 1'b1;
                                                               end else if(pkt_sent_cnt == 4'h5) begin
                                                                 in_hdr_in <= {MAC_SRC_ADDR_MSB[15:0],MAC_SRC_ADDR_LSB,QP5_MAC_DEST_ADDR_MSB[15:0],QP5_MAC_DEST_ADDR_LSB,Protocol_ID,8'h45,8'hb8,Total_len_write,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,chk_sum_calc({8'h45,8'hb8,Total_len_write,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,IP4H_QP5_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1}),IP4H_QP5_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1,16'h6851,16'h12b7,UDP_Len_write,16'h0000,8'h0a,8'h30,16'h666f,24'h050000,16'h0500,QP5_PSN[23:8],(QP5_PSN[7:0]+1'b1), 32'h00000000, 32'hcadd3074, 16'h0000};
                                                                 pkt_sent_QP5 <= pkt_sent_QP5 + 1'b1;
                                                                 end else if(pkt_sent_cnt == 4'h6) begin
                                                                    in_hdr_in <= {MAC_SRC_ADDR_MSB[15:0],MAC_SRC_ADDR_LSB,QP6_MAC_DEST_ADDR_MSB[15:0],QP6_MAC_DEST_ADDR_LSB,Protocol_ID,8'h45,8'hb8,Total_len_write,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,chk_sum_calc({8'h45,8'hb8,Total_len_write,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,IP4H_QP6_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1}),IP4H_QP6_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1,16'h6851,16'h12b7,UDP_Len_write,16'h0000,8'h0a,8'h30,16'h666f,24'h050000,16'h0600,QP6_PSN[23:8],(QP6_PSN[7:0]+1'b1), 32'h00000000, 32'hcae13074, 16'h0000};
                                                                    pkt_sent_QP6 <= pkt_sent_QP6 + 1'b1;
                                                                    end else if(pkt_sent_cnt == 4'h7) begin
                                                                        in_hdr_in <= {MAC_SRC_ADDR_MSB[15:0],MAC_SRC_ADDR_LSB,QP7_MAC_DEST_ADDR_MSB[15:0],QP7_MAC_DEST_ADDR_LSB,Protocol_ID,8'h45,8'hb8,Total_len_write,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,chk_sum_calc({8'h45,8'hb8,Total_len_write,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,IP4H_QP7_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1}),IP4H_QP7_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1,16'h6851,16'h12b7,UDP_Len_write,16'h0000,8'h0a,8'h30,16'h666f,24'h050000,16'h0700,QP7_PSN[23:8],(QP7_PSN[7:0]+(pkt_sent_cnt-4'h6)), 32'h00000000, 32'hcae53074, 16'h0000};
                                                                        pkt_sent_QP7 <= pkt_sent_QP7 + 1'b1;
                                                                        end 
                                             if (pkt_sent_cnt < 4'h8) begin
                                             remaining_len_to_tx <= write_pkt_len - 64;
                                             cnt                  <= 'b0;
                                             if(EN_INITIATOR_WR) begin
                                               if(conf_of_reg_done == 1'b1) begin
                                                  axis_gen_st <= TX_AXIS_PKT_GEN_ST1;
                                               end else 
                                                  axis_gen_st <= TX_AXIS_PKT_GEN_ST0;
                                             end else 
                                                  axis_gen_st <= TX_AXIS_PKT_GEN_ST4;
                                             //end
                                             end
                                         end
            TX_AXIS_PKT_GEN_ST1: begin
                         tx_m_axis_tdata_send_test <= hdr_byte_reorder(in_hdr_in);
                         tx_m_axis_tkeep_send_test <= {64{1'b1}};
                         tx_m_axis_tvalid_send_test <= 1'b1;
                         tx_m_axis_tlast_send_test  <= 1'b0;
                         temp_val <= hdr_byte_reorder(in_hdr_in);
                         axis_gen_st <= TX_AXIS_PKT_GEN_ST2;
                    end
             TX_AXIS_PKT_GEN_ST2: begin
                            if(remaining_len_to_tx > 64) begin
                            write_pkt_psn <= temp_val[431 -: 24];
                        //    tx_m_axis_tdata_send_test <= hdr_byte_reorder({ 16'h2ba7, 32'h00001000, {464{1'b1}}});
                               // MODIFIED: use consistent payload for QP2
                               tx_m_axis_tdata_send_test <= hdr_byte_reorder({ 16'h0098, 32'h00001000, {464{1'b1}}});
                            tx_m_axis_tkeep_send_test  <= {64{1'b1}};
                            tx_m_axis_tvalid_send_test <= 1'b1;
                            tx_m_axis_tlast_send_test  <= 1'b0;          
                            remaining_len_to_tx     <= remaining_len_to_tx-64;
                            end
                            else begin
                            tx_m_axis_tdata_send_test <= {48{1'b1}};
                            tx_m_axis_tkeep_send_test  <= {6{1'b1}};
                            tx_m_axis_tvalid_send_test <= 1'b1;
                            tx_m_axis_tlast_send_test  <= 1'b1;
                            axis_gen_st <= TX_AXIS_PKT_GEN_ST3;
                            end
                    end     
              TX_AXIS_PKT_GEN_ST3: begin
                            if(wait_cnt == 16'h00FF && pkt_sent_cnt < 4'h2) begin
                                                   wait_cnt     <= 16'h0000;
                                                   if (pkt_sent_cnt >= 4'h1) begin  // MODIFIED: exit after 2 packets (cnt 0,1)
                                                           rdma_write_test_done_i <= 1'b1;
                                                           pkt_sent_cnt <= pkt_sent_cnt + 1'b1; // prevent re-entry
                                                   end else begin
                                                   axis_gen_st <= TX_AXIS_PKT_GEN_ST0;
                                                   pkt_sent_cnt <= pkt_sent_cnt + 1;
                                                  end
                                              end else if (pkt_sent_cnt >= 4'h2) begin
                                                   // MODIFIED: idle after WRITE phase complete
                                                   tx_m_axis_tvalid_send_test <= 1'b0;
                                                   tx_m_axis_tlast_send_test  <= 1'b0;
                                              end else begin
                                                   wait_cnt     <= wait_cnt + 1'b1;
                                                   tx_m_axis_tvalid_send_test <= 1'b0;
                                                   tx_m_axis_tlast_send_test  <= 1'b0;
                                                   axis_gen_st <= TX_AXIS_PKT_GEN_ST3;
                                              end

                  end 
  //RDMA READ REQUEST
             TX_AXIS_PKT_GEN_ST4: begin
                           if(EN_INITIATOR_RD && EN_INITIATOR_WR) begin
                              if(rdma_write_test_done_i) begin
                                 if (pkt_sent_cnt < 4'h4) begin
                                 in_hdr_in <= {MAC_SRC_ADDR_MSB[15:0],MAC_SRC_ADDR_LSB,QP3_MAC_DEST_ADDR_MSB[15:0],QP3_MAC_DEST_ADDR_LSB,Protocol_ID,8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,chk_sum_calc({8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,IP4H_QP3_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1}),IP4H_QP3_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1,16'h6851,16'h12b7,UDP_Len,16'h0000,8'h0c,8'h30,16'h666f,24'h050000,16'h0300,QP3_PSN[23:8],(QP3_PSN[7:0]+pkt_sent_QP3 + 1'b1), 32'h00000000, 32'hcad53074, 16'h0000 };
                            //     cnt_psn <= cnt_psn + 1'b1;                            
                                 end  else if (pkt_sent_cnt == 4'h4) begin
                                                               in_hdr_in <= {MAC_SRC_ADDR_MSB[15:0],MAC_SRC_ADDR_LSB,QP4_MAC_DEST_ADDR_MSB[15:0],QP4_MAC_DEST_ADDR_LSB,Protocol_ID,8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,chk_sum_calc({8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,IP4H_QP4_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1}),IP4H_QP4_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1,16'h6851,16'h12b7,UDP_Len,16'h0000,8'h0c,8'h30,16'h666f,24'h050000,16'h0400,QP4_PSN[23:8],(QP4_PSN[7:0]+pkt_sent_QP4+1'b1), 32'h00000000, 32'hcad93074, 16'h0000};
                                                                end else if(pkt_sent_cnt == 4'h5) begin
                                                                  in_hdr_in <= {MAC_SRC_ADDR_MSB[15:0],MAC_SRC_ADDR_LSB,QP5_MAC_DEST_ADDR_MSB[15:0],QP5_MAC_DEST_ADDR_LSB,Protocol_ID,8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,chk_sum_calc({8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,IP4H_QP5_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1}),IP4H_QP5_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1,16'h6851,16'h12b7,UDP_Len,16'h0000,8'h0c,8'h30,16'h666f,24'h050000,16'h0500,QP5_PSN[23:8],(QP5_PSN[7:0]+pkt_sent_QP5+1'b1), 32'h00000000, 32'hcadd3074, 16'h0000};
                                                                end else if(pkt_sent_cnt == 4'h6) begin
                                                                  in_hdr_in <= {MAC_SRC_ADDR_MSB[15:0],MAC_SRC_ADDR_LSB,QP6_MAC_DEST_ADDR_MSB[15:0],QP6_MAC_DEST_ADDR_LSB,Protocol_ID,8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,chk_sum_calc({8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,IP4H_QP6_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1}),IP4H_QP6_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1,16'h6851,16'h12b7,UDP_Len,16'h0000,8'h0c,8'h30,16'h666f,24'h050000,16'h0600,QP6_PSN[23:8],(QP6_PSN[7:0]+pkt_sent_QP6+1'b1), 32'h00000000, 32'hcae13074, 16'h0000};
                                                                end else if (pkt_sent_cnt == 4'h7) begin
                                                                  in_hdr_in <= {MAC_SRC_ADDR_MSB[15:0],MAC_SRC_ADDR_LSB,QP7_MAC_DEST_ADDR_MSB[15:0],QP7_MAC_DEST_ADDR_LSB,Protocol_ID,8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,chk_sum_calc({8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,IP4H_QP7_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1}),IP4H_QP7_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1,16'h6851,16'h12b7,UDP_Len,16'h0000,8'h0c,8'h30,16'h666f,24'h050000,16'h0700,QP7_PSN[23:8],(QP7_PSN[7:0]+(pkt_sent_cnt + pkt_sent_QP7-4'h6)), 32'h00000000, 32'hcae53074, 16'h0000};
                                                               end
                                 if (pkt_sent_cnt < 4'h8) begin
                                 remaining_len_to_tx <= send_pkt_len - 64;                                      
                                 axis_gen_st <= TX_AXIS_PKT_GEN_ST5;
                                 end   
                              end          
                             end else begin
                                      if(EN_INITIATOR_RD && ~EN_INITIATOR_WR) begin
                                                           if(conf_of_reg_done) begin
                                                              if (pkt_sent_cnt < 4'h4) begin
                                                              in_hdr_in <= {MAC_SRC_ADDR_MSB[15:0],MAC_SRC_ADDR_LSB,QP3_MAC_DEST_ADDR_MSB[15:0],QP3_MAC_DEST_ADDR_LSB,Protocol_ID,8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,chk_sum_calc({8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,IP4H_QP3_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1}),IP4H_QP3_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1,16'h6851,16'h12b7,UDP_Len,16'h0000,8'h0c,8'h30,16'h666f,24'h050000,16'h0300,QP3_PSN[23:8],(QP3_PSN[7:0]+pkt_sent_QP3 + 1'b1), 32'h00000000, 32'hcad53074, 16'h0000 };
                                                         //     cnt_psn <= cnt_psn + 1'b1;                            
                                                              end  else if (pkt_sent_cnt == 4'h4) begin
                                                                                            in_hdr_in <= {MAC_SRC_ADDR_MSB[15:0],MAC_SRC_ADDR_LSB,QP4_MAC_DEST_ADDR_MSB[15:0],QP4_MAC_DEST_ADDR_LSB,Protocol_ID,8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,chk_sum_calc({8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,IP4H_QP4_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1}),IP4H_QP4_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1,16'h6851,16'h12b7,UDP_Len,16'h0000,8'h0c,8'h30,16'h666f,24'h050000,16'h0400,QP4_PSN[23:8],(QP4_PSN[7:0]+pkt_sent_QP4+1'b1), 32'h00000000, 32'hcad93074, 16'h0000};
                                                                                             end else if(pkt_sent_cnt == 4'h5) begin
                                                                                               in_hdr_in <= {MAC_SRC_ADDR_MSB[15:0],MAC_SRC_ADDR_LSB,QP5_MAC_DEST_ADDR_MSB[15:0],QP5_MAC_DEST_ADDR_LSB,Protocol_ID,8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,chk_sum_calc({8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,IP4H_QP5_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1}),IP4H_QP5_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1,16'h6851,16'h12b7,UDP_Len,16'h0000,8'h0c,8'h30,16'h666f,24'h050000,16'h0500,QP5_PSN[23:8],(QP5_PSN[7:0]+pkt_sent_QP5+1'b1), 32'h00000000, 32'hcadd3074, 16'h0000};
                                                                                             end else if(pkt_sent_cnt == 4'h6) begin
                                                                                               in_hdr_in <= {MAC_SRC_ADDR_MSB[15:0],MAC_SRC_ADDR_LSB,QP6_MAC_DEST_ADDR_MSB[15:0],QP6_MAC_DEST_ADDR_LSB,Protocol_ID,8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,chk_sum_calc({8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,IP4H_QP6_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1}),IP4H_QP6_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1,16'h6851,16'h12b7,UDP_Len,16'h0000,8'h0c,8'h30,16'h666f,24'h050000,16'h0600,QP6_PSN[23:8],(QP6_PSN[7:0]+pkt_sent_QP6+1'b1), 32'h00000000, 32'hcae13074, 16'h0000};
                                                                                             end else if (pkt_sent_cnt == 4'h7) begin
                                                                                               in_hdr_in <= {MAC_SRC_ADDR_MSB[15:0],MAC_SRC_ADDR_LSB,QP7_MAC_DEST_ADDR_MSB[15:0],QP7_MAC_DEST_ADDR_LSB,Protocol_ID,8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,chk_sum_calc({8'h45,8'hb8,Total_Len,16'h5555,16'h4000,8'hba,UDP_Protocol_ID,IP4H_QP7_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1}),IP4H_QP7_DEST_ADDR_1,IP4H_QP3_SRC_ADDR_1,16'h6851,16'h12b7,UDP_Len,16'h0000,8'h0c,8'h30,16'h666f,24'h050000,16'h0700,QP7_PSN[23:8],(QP7_PSN[7:0]+(pkt_sent_cnt + pkt_sent_QP7-4'h6)), 32'h00000000, 32'hcae53074, 16'h0000};
                                                                                            end
                                                              if (pkt_sent_cnt < 4'h8) begin
                                                              remaining_len_to_tx <= send_pkt_len - 64;                                      
                                                              axis_gen_st <= TX_AXIS_PKT_GEN_ST5;
                                                              end   
                                                          end          
                                     end
                                 end
                            end 
               TX_AXIS_PKT_GEN_ST5: begin
                                   tx_m_axis_tdata_send_test <= hdr_byte_reorder(in_hdr_in);
                                   tx_m_axis_tkeep_send_test <= {64{1'b1}};
                                   temp_val <= hdr_byte_reorder(in_hdr_in);
                                   tx_m_axis_tvalid_send_test <= 1'b1;
                                   tx_m_axis_tlast_send_test  <= 1'b0;
                                   axis_gen_st <= TX_AXIS_PKT_GEN_ST6;
                                   end                      
              TX_AXIS_PKT_GEN_ST6 : begin
                               if(remaining_len_to_tx > 0) begin 
                               write_pkt_psn <= temp_val[431 -: 24];
                                  if (pkt_sent_cnt < 4'h4) begin
                                  tx_m_axis_tdata_send_test <= hdr_byte_reorder({ 16'h0098, 32'h00001000, {464{1'b0}}});
                                  end else if (pkt_sent_cnt == 4'h4) begin
                                                               tx_m_axis_tdata_send_test <= hdr_byte_reorder({ 16'h0181, 32'h00001000, {464{1'b0}}});
                                                             end else if (pkt_sent_cnt == 4'h5) begin
                                                                                            tx_m_axis_tdata_send_test <= hdr_byte_reorder({ 16'h0218, 32'h00001000, {464{1'b0}}});
                                                                                          end else if (pkt_sent_cnt == 4'h6) begin
                                                                                                                         tx_m_axis_tdata_send_test <= hdr_byte_reorder({ 16'h03eb, 32'h00001000, {464{1'b0}}});
                                                                                                                       end else if (pkt_sent_cnt == 4'h7) begin
                                                                                                                                                      tx_m_axis_tdata_send_test <= hdr_byte_reorder({ 16'h04d4, 32'h00001000, {464{1'b0}}});
                                                                                                                                                    end
                                 tx_m_axis_tkeep_send_test <= {6{1'b1}};
                                 tx_m_axis_tvalid_send_test <= 1'b1;
                                 tx_m_axis_tlast_send_test  <= 1'b1;
                                 axis_gen_st <= TX_AXIS_PKT_GEN_ST7;
                              end 
                 end
                 TX_AXIS_PKT_GEN_ST7: begin
                                   if(wait_cnt_rr == 16'h0FFF) begin
                                        wait_cnt_rr     <= 16'h0000;
                                        if (pkt_sent_cnt == 4'h7) begin
                                                rdma_rdrq_test_done_i <= 1'b1;
                                               // axis_gen_st <= TX_AXIS_PKT_GEN_ST4;
                                               // pkt_sent_cnt <= 'b0;
                                        end else begin
                                        axis_gen_st <= TX_AXIS_PKT_GEN_ST4;
                                        pkt_sent_cnt <= pkt_sent_cnt + 1;
                                        pkt_sent_QP3 <= pkt_sent_QP3 + 1;
                                        
                                        end
                                   end else begin
                                        wait_cnt_rr     <= wait_cnt_rr + 1'b1;
                                        tx_m_axis_tvalid_send_test <= 1'b0;
                                        tx_m_axis_tlast_send_test  <= 1'b0;
                                        axis_gen_st <= TX_AXIS_PKT_GEN_ST7;                   
                                   end               
                             end   
          default : begin
                      tx_m_axis_tdata_send_test  <= 'b0;
                      tx_m_axis_tkeep_send_test  <= 'b0;
                      tx_m_axis_tvalid_send_test <= 1'b0;
                      tx_m_axis_tlast_send_test  <= 1'b0;
                      remaining_len_to_tx     <= 1'b0;
                      pkt_sent_cnt            <= 0;
                      cnt                     <= 0;
                      axis_gen_st            <= TX_AXIS_PKT_GEN_ST0;
                      wait_cnt         <= 16'h0000;
                      wait_cnt_rr         <= 16'h0000;
                    end

endcase
end
end

endmodule
