// ERNIC CSR address map — PG332 v4.0, December 2022
`ifndef ERNIC_CSR_SVH
`define ERNIC_CSR_SVH

// =====================================================================
// Global Registers (base 0x10_0000)
// =====================================================================
`define ERNIC_XRNICCONF              32'h10_0000  // [0]=enable, [23:8]=UDP src port
`define ERNIC_XRNICADCONF            32'h10_0004  // [0]=SW override, [19:16]=base cnt
`define ERNIC_MACXADDLSB             32'h10_0010  // Local MAC LSB
`define ERNIC_MACXADDMSB             32'h10_0014  // Local MAC MSB [15:0]
`define ERNIC_IPv4XADD               32'h10_0070  // Local IPv4 address
`define ERNIC_DATBUFBA               32'h10_00A0  // Data Buffer base address
`define ERNIC_DATBUFBAMSB            32'h10_00A4  // Data Buffer base address MSB
`define ERNIC_DATBUFSZ               32'h10_00A8  // [15:0]=#bufs, [31:16]=buf size in bytes
`define ERNIC_ERRBUFBA               32'h10_0060  // Error Buffer base address
`define ERNIC_ERRBUFBAMSB            32'h10_0064  // Error Buffer base address MSB
`define ERNIC_ERRBUFSZ               32'h10_0068  // [15:0]=#bufs, [31:16]=buf size in bytes
`define ERNIC_CON_IO_CONF            32'h10_00AC  // [26:16]=QPID, [31]=ready(RO)
`define ERNIC_OUTIOPKTCNT            32'h10_0108  // Outgoing IO pkt count (RO)

// =====================================================================
// Per-QP Registers (base 0x18_0000 + (i-1)*0x100, i=1..C_NUM_QP)
// QP1 = MAD QP (special), QP2..N = RC QPs
// =====================================================================
`define ERNIC_PER_QP_BASE(i)         (32'h18_0000 + ((i)-1)*32'h100)

// Offsets within per-QP space
`define ERNIC_QP_QPCONF              32'h00  // QP Configuration
`define ERNIC_QP_QPADVCONF           32'h04  // QP Advanced Config (not for QP1)
`define ERNIC_QP_RQBA                32'h08  // RCV Q Buffer base address
`define ERNIC_QP_RQBAMSB             32'hC0  // RCV Q Buffer base address MSB
`define ERNIC_QP_SQBA                32'h10  // SEND Q base address (32B aligned)
`define ERNIC_QP_SQBAMSB             32'hC8  // SEND Q base address MSB
`define ERNIC_QP_CQBA                32'h18  // CQ base address (32B aligned)
`define ERNIC_QP_CQBAMSB             32'hD0  // CQ base address MSB
`define ERNIC_QP_RQWPTRDBADD         32'h20  // RCV Q Write pointer DB address
`define ERNIC_QP_RQWPTRDBADDMSB      32'h24  // RCV Q Write pointer DB address MSB
`define ERNIC_QP_CQDBADD             32'h28  // CQ Doorbell address
`define ERNIC_QP_CQDBADDMSB          32'h2C  // CQ Doorbell address MSB
`define ERNIC_QP_RQCI                32'h34  // RQ Consumer Index [15:0]
`define ERNIC_QP_SQPI                32'h38  // SQ Producer Index [15:0] (doorbell)
`define ERNIC_QP_QDEPTH              32'h3C  // [15:0]=SQ depth, [31:16]=RQ depth
`define ERNIC_QP_SQPSN               32'h40  // SEND Q PSN [23:0]
`define ERNIC_QP_LSTRQREQ            32'h44  // [23:0]=RQ PSN, [31:24]=RQ opcode
`define ERNIC_QP_DESTQPCONF          32'h48  // Destination QP [23:0]
`define ERNIC_QP_TIMEOUTCONF         32'h4C  // Timeout configuration
`define ERNIC_QP_MACDESADDLSB        32'h50  // MAC destination address LSB
`define ERNIC_QP_MACDESADDMSB        32'h54  // MAC destination address MSB [15:0]
`define ERNIC_QP_IPDESADDR1          32'h60  // IP dest (IPv4, or IPv6[31:0])
`define ERNIC_QP_IPDESADDR2          32'h64  // IPv6 dest [63:32]
`define ERNIC_QP_IPDESADDR3          32'h68  // IPv6 dest [95:64]
`define ERNIC_QP_IPDESADDR4          32'h6C  // IPv6 dest [127:96]
`define ERNIC_QP_PDNUM               32'hB0  // Protection Domain number [23:0]
`define ERNIC_QP_STATQP              32'h88  // Status QP (RO)

// QPCONF bit fields
`define QPCONF_QP_EN                 (1 << 0)   // [0]: QP enable
`define QPCONF_RQ_INT_EN             (1 << 2)   // [2]: RQ interrupt enable
`define QPCONF_CQ_INT_EN             (1 << 3)   // [3]: CQ interrupt enable
`define QPCONF_HW_HNDSHK_DIS         (1 << 4)   // [4]: HW handshake disable (0=enabled)
`define QPCONF_CQE_WR_EN             (1 << 5)   // [5]: CQE write enable
`define QPCONF_QP_RECOVERY           (1 << 6)   // [6]: QP under recovery
`define QPCONF_IP_VER                (1 << 7)   // [7]: IPv4=0, IPv6=1

// PMTU values for QPCONF[10:8] — 3-bit field, place directly at bits [10:8]
`define PMTU_256B                    3'b000
`define PMTU_512B                    3'b001
`define PMTU_1024B                   3'b010
`define PMTU_2048B                   3'b011
`define PMTU_4096B                   3'b100

// WQE opcodes (Table 2-1)
`define WQE_OP_RDMA_WRITE            8'h00
`define WQE_OP_RDMA_WRITE_IMM        8'h01
`define WQE_OP_SEND                  8'h02
`define WQE_OP_SEND_WITH_IMM         8'h03
`define WQE_OP_RDMA_READ             8'h04
`define WQE_OP_SEND_INVALIDATE       8'h0C

`endif
