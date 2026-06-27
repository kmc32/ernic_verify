// ERNIC CSR address map
`ifndef ERNIC_CSR_SVH
`define ERNIC_CSR_SVH

// Global config
`define ERNIC_CONF_SRC_MAC_L    32'h0000
`define ERNIC_CONF_SRC_MAC_H    32'h0004
`define ERNIC_CONF_SRC_IP       32'h0008

// QP context base (stride 0x100 per QP, indexed by qpn)
`define ERNIC_QP_BASE(qpn)      (32'h1000 + (qpn)*32'h100)
// Within a QP context
`define ERNIC_QP_CONF            32'h00   // en, type, state
`define ERNIC_QP_SEND_QA_L       32'h04
`define ERNIC_QP_SEND_QA_H       32'h08
`define ERNIC_QP_RECV_QA_L       32'h0C
`define ERNIC_QP_RECV_QA_H       32'h10
`define ERNIC_QP_CQ_ADDR_L       32'h14
`define ERNIC_QP_CQ_ADDR_H       32'h18
`define ERNIC_QP_RQ_PSN          32'h1C
`define ERNIC_QP_SQ_PSN          32'h20
`define ERNIC_QP_DST_QPN         32'h24
`define ERNIC_QP_DST_IP          32'h28
`define ERNIC_QP_RETRY_CNT       32'h2C
`define ERNIC_QP_TIMEOUT         32'h30
`define ERNIC_QP_DOORBELL        32'h34
`define ERNIC_QP_WQE_CNT         32'h38

// WQE opcodes
`define WQE_OP_SEND              8'h00
`define WQE_OP_SEND_WITH_IMM     8'h01
`define WQE_OP_RDMA_WRITE        8'h02
`define WQE_OP_RDMA_WRITE_IMM    8'h03
`define WQE_OP_RDMA_READ         8'h04

`endif
