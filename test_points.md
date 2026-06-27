  1. RoCEv2 协议处理
      - 基于 Ethernet + IPv4/UDP + RoCEv2。
      - 解析和生成 RoCEv2 报文头，例如 BTH、RETH、AETH 等。
      - 通常用于 Reliable Connection 语义的 RDMA 通信。

  2. RDMA 数据操作
      - 支持 RDMA 数据搬运，例如：
          - RDMA Write
          - RDMA Read
          - Send/Receive
          - 可能支持 Write with Immediate 等变体，具体取决于 ERNIC 版本和配置。

      - 不应假设它支持完整 verbs 集合，比如 atomic、UD、完整 CM 等通常不是 ERNIC 的重点。

  3. Queue Pair / Work Queue 管理
      - 维护 QP 上下文。
      - 处理 Send Queue、Receive Queue、Completion Queue。
      - 通过 doorbell/描述符方式启动 RDMA 操作。
      - 产生 completion 和中断/状态。

  4. 可靠传输机制
      - PSN 序号检查。
      - ACK/NAK 处理。
      - 重传、超时、retry、RNR 等可靠连接相关逻辑。
      - 报文顺序、重复包、错误包检测。

  5. 内存访问与保护
      - 根据本地/远端 key、地址、长度检查访问权限。
      - 通过 AXI master 读写主机内存、DDR、HBM 或 FPGA 内部存储。
      - 实现 RDMA 的“远端直接读写内存”数据面。

  6. 以太网/UDP/IP 数据接口
      - 对上连接用户逻辑或 DMA/内存系统。
      - 对下连接 UDP/IP、CMAC、100G/10G Ethernet MAC 等网络模块。
      - ERNIC 本身不是完整 TCP/IP NIC，通常还需要外部 IP/UDP、MAC、ARP、控制面软件等配合。

  7. 控制与状态寄存器
      - 通过 AXI-Lite 配置 IP 地址、QP、内存区域、队列地址、retry 参数等。
      - 提供错误状态、统计计数、completion 状态。