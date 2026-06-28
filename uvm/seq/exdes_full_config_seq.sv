// Replay the full 194-register configuration from Xilinx example design.
// Address mapping: example uses QP offset n*0x100, ours uses (n-1)*0x100.
`include "uvm/seq/ernic_csr.svh"

class exdes_full_config_seq extends ernic_base_seq;
    `uvm_object_utils(exdes_full_config_seq)

    int unsigned NUM_CFG = 194;
    bit [31:0] cfg_addr[];
    bit [31:0] cfg_data[];

    function new(string name = "exdes_full_config_seq");
        super.new(name);
        cfg_addr = new[NUM_CFG];
        cfg_data = new[NUM_CFG];
        init_config();
    endfunction

    function void init_config();
        int i = 0;
        cfg_addr[i] = 32'h001000b8; cfg_data[i] = 32'h00000100; i++;
        cfg_addr[i] = 32'h001000b4; cfg_data[i] = 32'h00000000; i++;
        cfg_addr[i] = 32'h001000b0; cfg_data[i] = 32'h02000000; i++;
        cfg_addr[i] = 32'h0018024c; cfg_data[i] = 32'h00020b18; i++;
        cfg_addr[i] = 32'h0000001c; cfg_data[i] = 32'h00000002; i++;
        cfg_addr[i] = 32'h0000000c; cfg_data[i] = 32'h40000000; i++;
        cfg_addr[i] = 32'h00000018; cfg_data[i] = 32'h00100000; i++;
        cfg_addr[i] = 32'h00000014; cfg_data[i] = 32'h00000098; i++;
        cfg_addr[i] = 32'h00000004; cfg_data[i] = 32'hcad53074; i++;
        cfg_addr[i] = 32'h0018034c; cfg_data[i] = 32'h00051b1f; i++;
        cfg_addr[i] = 32'h0000011c; cfg_data[i] = 32'h00000002; i++;
        cfg_addr[i] = 32'h0000010c; cfg_data[i] = 32'h40040000; i++;
        cfg_addr[i] = 32'h00000118; cfg_data[i] = 32'h00100000; i++;
        cfg_addr[i] = 32'h00000114; cfg_data[i] = 32'h00000081; i++;
        cfg_addr[i] = 32'h00000104; cfg_data[i] = 32'hcad93074; i++;
        cfg_addr[i] = 32'h00000100; cfg_data[i] = 32'h00000001; i++;
        cfg_addr[i] = 32'h0018044c; cfg_data[i] = 32'h00143b1d; i++;
        cfg_addr[i] = 32'h0000021c; cfg_data[i] = 32'h00000002; i++;
        cfg_addr[i] = 32'h0000020c; cfg_data[i] = 32'h40080000; i++;
        cfg_addr[i] = 32'h00000218; cfg_data[i] = 32'h00100000; i++;
        cfg_addr[i] = 32'h00000214; cfg_data[i] = 32'h00000018; i++;
        cfg_addr[i] = 32'h00000204; cfg_data[i] = 32'hcadd3074; i++;
        cfg_addr[i] = 32'h00000200; cfg_data[i] = 32'h00000002; i++;
        cfg_addr[i] = 32'h0018054c; cfg_data[i] = 32'h0009231c; i++;
        cfg_addr[i] = 32'h0000031c; cfg_data[i] = 32'h00000002; i++;
        cfg_addr[i] = 32'h0000030c; cfg_data[i] = 32'h400c0000; i++;
        cfg_addr[i] = 32'h00000318; cfg_data[i] = 32'h00100000; i++;
        cfg_addr[i] = 32'h00000314; cfg_data[i] = 32'h000000eb; i++;
        cfg_addr[i] = 32'h00000304; cfg_data[i] = 32'hcae13074; i++;
        cfg_addr[i] = 32'h00000300; cfg_data[i] = 32'h00000003; i++;
        cfg_addr[i] = 32'h0018064c; cfg_data[i] = 32'h001b1300; i++;
        cfg_addr[i] = 32'h0000041c; cfg_data[i] = 32'h00000002; i++;
        cfg_addr[i] = 32'h0000040c; cfg_data[i] = 32'h40100000; i++;
        cfg_addr[i] = 32'h00000418; cfg_data[i] = 32'h00100000; i++;
        cfg_addr[i] = 32'h00000414; cfg_data[i] = 32'h000000d4; i++;
        cfg_addr[i] = 32'h00000404; cfg_data[i] = 32'hcae53074; i++;
        cfg_addr[i] = 32'h00000400; cfg_data[i] = 32'h00000004; i++;
        cfg_addr[i] = 32'h0018074c; cfg_data[i] = 32'h00062b00; i++;
        cfg_addr[i] = 32'h0000051c; cfg_data[i] = 32'h00000002; i++;
        cfg_addr[i] = 32'h0000050c; cfg_data[i] = 32'h40140000; i++;
        cfg_addr[i] = 32'h00000518; cfg_data[i] = 32'h00100000; i++;
        cfg_addr[i] = 32'h00000514; cfg_data[i] = 32'h00000012; i++;
        cfg_addr[i] = 32'h00000504; cfg_data[i] = 32'hcae93074; i++;
        cfg_addr[i] = 32'h00000500; cfg_data[i] = 32'h00000005; i++;
        cfg_addr[i] = 32'h001803b0; cfg_data[i] = 32'h00000000; i++;
        cfg_addr[i] = 32'h001804b0; cfg_data[i] = 32'h00000001; i++;
        cfg_addr[i] = 32'h001805b0; cfg_data[i] = 32'h00000002; i++;
        cfg_addr[i] = 32'h001806b0; cfg_data[i] = 32'h00000003; i++;
        cfg_addr[i] = 32'h001807b0; cfg_data[i] = 32'h00000004; i++;
        cfg_addr[i] = 32'h00180740; cfg_data[i] = 32'h004c0387; i++;
        cfg_addr[i] = 32'h00180744; cfg_data[i] = 32'h04ffffb5; i++;
        cfg_addr[i] = 32'h00100044; cfg_data[i] = 32'h00000007; i++;
        cfg_addr[i] = 32'h00180704; cfg_data[i] = 32'hcea61326; i++;
        cfg_addr[i] = 32'h00180710; cfg_data[i] = 32'h00608000; i++;
        cfg_addr[i] = 32'h0018073c; cfg_data[i] = 32'h00400100; i++;
        cfg_addr[i] = 32'h00180748; cfg_data[i] = 32'h00000007; i++;
        cfg_addr[i] = 32'h00180718; cfg_data[i] = 32'h00140800; i++;
        cfg_addr[i] = 32'h00100044; cfg_data[i] = 32'h00000007; i++;
        cfg_addr[i] = 32'h00180720; cfg_data[i] = 32'h0fff001c; i++;
        cfg_addr[i] = 32'h00180700; cfg_data[i] = 32'h045c0407; i++;
        cfg_addr[i] = 32'h00180728; cfg_data[i] = 32'h0fff101c; i++;
        cfg_addr[i] = 32'h00180708; cfg_data[i] = 32'h02040000; i++;
        cfg_addr[i] = 32'h00180750; cfg_data[i] = 32'he2f8a222; i++;
        cfg_addr[i] = 32'h00180754; cfg_data[i] = 32'h0000e2de; i++;
        cfg_addr[i] = 32'h00180760; cfg_data[i] = 32'h7481e444; i++;
        cfg_addr[i] = 32'h0018076c; cfg_data[i] = 32'h3e52e18c; i++;
        cfg_addr[i] = 32'h00180764; cfg_data[i] = 32'h780e5bcb; i++;
        cfg_addr[i] = 32'h00180768; cfg_data[i] = 32'h5a95ddd8; i++;
        cfg_addr[i] = 32'h00180640; cfg_data[i] = 32'h00f9a408; i++;
        cfg_addr[i] = 32'h00180644; cfg_data[i] = 32'h04ffff84; i++;
        cfg_addr[i] = 32'h00100044; cfg_data[i] = 32'h00000007; i++;
        cfg_addr[i] = 32'h00180604; cfg_data[i] = 32'h167b4025; i++;
        cfg_addr[i] = 32'h00180610; cfg_data[i] = 32'h00607000; i++;
        cfg_addr[i] = 32'h0018063c; cfg_data[i] = 32'h00800040; i++;
        cfg_addr[i] = 32'h00180648; cfg_data[i] = 32'h00000006; i++;
        cfg_addr[i] = 32'h00180618; cfg_data[i] = 32'h00140700; i++;
        cfg_addr[i] = 32'h00100044; cfg_data[i] = 32'h00000007; i++;
        cfg_addr[i] = 32'h00180620; cfg_data[i] = 32'h0fff0018; i++;
        cfg_addr[i] = 32'h00180600; cfg_data[i] = 32'h012b0427; i++;
        cfg_addr[i] = 32'h00180628; cfg_data[i] = 32'h0fff1018; i++;
        cfg_addr[i] = 32'h00180608; cfg_data[i] = 32'h02038000; i++;
        cfg_addr[i] = 32'h00180650; cfg_data[i] = 32'had424e4e; i++;
        cfg_addr[i] = 32'h00180654; cfg_data[i] = 32'h000002dd; i++;
        cfg_addr[i] = 32'h00180660; cfg_data[i] = 32'h4abea0cf; i++;
        cfg_addr[i] = 32'h0018066c; cfg_data[i] = 32'h00897117; i++;
        cfg_addr[i] = 32'h00180664; cfg_data[i] = 32'h6bb328b7; i++;
        cfg_addr[i] = 32'h00180668; cfg_data[i] = 32'hd52a10d0; i++;
        cfg_addr[i] = 32'h00180540; cfg_data[i] = 32'h0000000a; i++;
        cfg_addr[i] = 32'h00180544; cfg_data[i] = 32'h04000001; i++;
        cfg_addr[i] = 32'h00100044; cfg_data[i] = 32'h00000007; i++;
        cfg_addr[i] = 32'h00180504; cfg_data[i] = 32'h50e92b2a; i++;
        cfg_addr[i] = 32'h00180510; cfg_data[i] = 32'h00606000; i++;
        cfg_addr[i] = 32'h0018053c; cfg_data[i] = 32'h00400040; i++;
        cfg_addr[i] = 32'h00180548; cfg_data[i] = 32'h00000005; i++;
        cfg_addr[i] = 32'h00180518; cfg_data[i] = 32'h00140600; i++;
        cfg_addr[i] = 32'h00100044; cfg_data[i] = 32'h00000007; i++;
        cfg_addr[i] = 32'h00180520; cfg_data[i] = 32'h0fff0014; i++;
        cfg_addr[i] = 32'h00180500; cfg_data[i] = 32'h02940407; i++;
        cfg_addr[i] = 32'h00180528; cfg_data[i] = 32'h0fff1014; i++;
        cfg_addr[i] = 32'h00180508; cfg_data[i] = 32'h02030000; i++;
        cfg_addr[i] = 32'h00180550; cfg_data[i] = 32'h27fbffe6; i++;
        cfg_addr[i] = 32'h00180554; cfg_data[i] = 32'h00008b09; i++;
        cfg_addr[i] = 32'h00180560; cfg_data[i] = 32'h98b129af; i++;
        cfg_addr[i] = 32'h0018056c; cfg_data[i] = 32'h8aa47e41; i++;
        cfg_addr[i] = 32'h00180564; cfg_data[i] = 32'h2ee66645; i++;
        cfg_addr[i] = 32'h00180568; cfg_data[i] = 32'h02c1bf38; i++;
        cfg_addr[i] = 32'h00180440; cfg_data[i] = 32'h00974470; i++;
        cfg_addr[i] = 32'h00180444; cfg_data[i] = 32'h04c02aa9; i++;
        cfg_addr[i] = 32'h00100044; cfg_data[i] = 32'h00000007; i++;
        cfg_addr[i] = 32'h00180404; cfg_data[i] = 32'h9ff2b002; i++;
        cfg_addr[i] = 32'h00180410; cfg_data[i] = 32'h00800000; i++;
        cfg_addr[i] = 32'h0018043c; cfg_data[i] = 32'h00500200; i++;
        cfg_addr[i] = 32'h00180448; cfg_data[i] = 32'h00000004; i++;
        cfg_addr[i] = 32'h00180418; cfg_data[i] = 32'h00360000; i++;
        cfg_addr[i] = 32'h00100044; cfg_data[i] = 32'h00000007; i++;
        cfg_addr[i] = 32'h00180420; cfg_data[i] = 32'h1ffff010; i++;
        cfg_addr[i] = 32'h00180400; cfg_data[i] = 32'h06f80407; i++;
        cfg_addr[i] = 32'h00180428; cfg_data[i] = 32'h2fff1010; i++;
        cfg_addr[i] = 32'h00180408; cfg_data[i] = 32'h04000000; i++;
        cfg_addr[i] = 32'h00180450; cfg_data[i] = 32'h60660f2e; i++;
        cfg_addr[i] = 32'h00180454; cfg_data[i] = 32'h000016e4; i++;
        cfg_addr[i] = 32'h00180460; cfg_data[i] = 32'h622c6007; i++;
        cfg_addr[i] = 32'h0018046c; cfg_data[i] = 32'hcebceaf4; i++;
        cfg_addr[i] = 32'h00180454; cfg_data[i] = 32'h9840f9eb; i++;
        cfg_addr[i] = 32'h00180468; cfg_data[i] = 32'h460a5e88; i++;
        cfg_addr[i] = 32'h00180240; cfg_data[i] = 32'h00774470; i++;
        cfg_addr[i] = 32'h00180244; cfg_data[i] = 32'h04a02aa9; i++;
        cfg_addr[i] = 32'h001000a0; cfg_data[i] = 32'h0c000000; i++;
        cfg_addr[i] = 32'h00100010; cfg_data[i] = 32'h17dc5e9a; i++;
        cfg_addr[i] = 32'h00100070; cfg_data[i] = 32'hf38590ba; i++;
        cfg_addr[i] = 32'h00100014; cfg_data[i] = 32'h00002f76; i++;
        cfg_addr[i] = 32'h00100024; cfg_data[i] = 32'hac92135d; i++;
        cfg_addr[i] = 32'h00100028; cfg_data[i] = 32'h013248eb; i++;
        cfg_addr[i] = 32'h001000a8; cfg_data[i] = 32'h10000080; i++;
        cfg_addr[i] = 32'h00100020; cfg_data[i] = 32'hf38590ba; i++;
        cfg_addr[i] = 32'h0010002c; cfg_data[i] = 32'hafb1f367; i++;
        cfg_addr[i] = 32'h00100068; cfg_data[i] = 32'h01000040; i++;
        cfg_addr[i] = 32'h00100060; cfg_data[i] = 32'h00110000; i++;
        cfg_addr[i] = 32'h00180110; cfg_data[i] = 32'h0b000000; i++;
        cfg_addr[i] = 32'h0018013c; cfg_data[i] = 32'h00800040; i++;
        cfg_addr[i] = 32'h00180148; cfg_data[i] = 32'h00000001; i++;
        cfg_addr[i] = 32'h00180118; cfg_data[i] = 32'h0b800000; i++;
        cfg_addr[i] = 32'h00180120; cfg_data[i] = 32'h0fff0000; i++;
        cfg_addr[i] = 32'h00180100; cfg_data[i] = 32'h024f0435; i++;
        cfg_addr[i] = 32'h00180150; cfg_data[i] = 32'hd1677ed7; i++;
        cfg_addr[i] = 32'h00180154; cfg_data[i] = 32'h0000c918; i++;
        cfg_addr[i] = 32'h00180128; cfg_data[i] = 32'h0fff1000; i++;
        cfg_addr[i] = 32'h00180108; cfg_data[i] = 32'h08000000; i++;
        cfg_addr[i] = 32'h00180160; cfg_data[i] = 32'ha3c9ba8b; i++;
        cfg_addr[i] = 32'h0018016c; cfg_data[i] = 32'h6f2a46fe; i++;
        cfg_addr[i] = 32'h00180164; cfg_data[i] = 32'h823b88db; i++;
        cfg_addr[i] = 32'h00180168; cfg_data[i] = 32'h1798f443; i++;
        cfg_addr[i] = 32'h00100044; cfg_data[i] = 32'h00000007; i++;
        cfg_addr[i] = 32'h00180204; cfg_data[i] = 32'h9bf1b002; i++;
        cfg_addr[i] = 32'h00180210; cfg_data[i] = 32'h00600000; i++;
        cfg_addr[i] = 32'h0018023c; cfg_data[i] = 32'h00400100; i++;
        cfg_addr[i] = 32'h00180248; cfg_data[i] = 32'h00000002; i++;
        cfg_addr[i] = 32'h00180218; cfg_data[i] = 32'h00140000; i++;
        cfg_addr[i] = 32'h00100044; cfg_data[i] = 32'h00000007; i++;
        cfg_addr[i] = 32'h00180220; cfg_data[i] = 32'h0fff0004; i++;
        cfg_addr[i] = 32'h00180200; cfg_data[i] = 32'h04f80407; i++;
        cfg_addr[i] = 32'h00180228; cfg_data[i] = 32'h0fff1004; i++;
        cfg_addr[i] = 32'h00180208; cfg_data[i] = 32'h02000000; i++;
        cfg_addr[i] = 32'h00100044; cfg_data[i] = 32'h00000007; i++;
        cfg_addr[i] = 32'h00100044; cfg_data[i] = 32'h00000007; i++;
        cfg_addr[i] = 32'h00180340; cfg_data[i] = 32'h00e21df7; i++;
        cfg_addr[i] = 32'h00180344; cfg_data[i] = 32'h040b77ce; i++;
        cfg_addr[i] = 32'h00180250; cfg_data[i] = 32'h50560f2e; i++;
        cfg_addr[i] = 32'h00180254; cfg_data[i] = 32'h000016c4; i++;
        cfg_addr[i] = 32'h00180260; cfg_data[i] = 32'h610c6007; i++;
        cfg_addr[i] = 32'h0018026c; cfg_data[i] = 32'hccbceaf4; i++;
        cfg_addr[i] = 32'h00180264; cfg_data[i] = 32'h9640f9eb; i++;
        cfg_addr[i] = 32'h00180268; cfg_data[i] = 32'h440a5e88; i++;
        cfg_addr[i] = 32'h00180304; cfg_data[i] = 32'hd836ba10; i++;
        cfg_addr[i] = 32'h00180310; cfg_data[i] = 32'h00604000; i++;
        cfg_addr[i] = 32'h0018033c; cfg_data[i] = 32'h00400100; i++;
        cfg_addr[i] = 32'h00180348; cfg_data[i] = 32'h00000003; i++;
        cfg_addr[i] = 32'h00180318; cfg_data[i] = 32'h00140400; i++;
        cfg_addr[i] = 32'h00180320; cfg_data[i] = 32'h0fff0008; i++;
        cfg_addr[i] = 32'h00180300; cfg_data[i] = 32'h01dd0407; i++;
        cfg_addr[i] = 32'h00180328; cfg_data[i] = 32'h0fff1008; i++;
        cfg_addr[i] = 32'h00180308; cfg_data[i] = 32'h02010000; i++;
        cfg_addr[i] = 32'h00100044; cfg_data[i] = 32'h00000007; i++;
        cfg_addr[i] = 32'h00100180; cfg_data[i] = 32'h00000070; i++;
        cfg_addr[i] = 32'h00180350; cfg_data[i] = 32'h1c69b8ed; i++;
        cfg_addr[i] = 32'h00180354; cfg_data[i] = 32'h0000ea1e; i++;
        cfg_addr[i] = 32'h00180360; cfg_data[i] = 32'hd7ac977e; i++;
        cfg_addr[i] = 32'h0018036c; cfg_data[i] = 32'he9a855a0; i++;
        cfg_addr[i] = 32'h00180364; cfg_data[i] = 32'h92e8a89f; i++;
        cfg_addr[i] = 32'h00180368; cfg_data[i] = 32'h28640e94; i++;
        cfg_addr[i] = 32'h00100000; cfg_data[i] = 32'h00e3488b; i++; // XRNICCONF (exact example value)
    endfunction

    // Remap: example QP config uses QP index * 0x100 offset, our ERNIC
    // uses (index-1) * 0x100. MR addresses use the SAME n*0x100 scheme
    // in both designs, so no MR remap needed.
    function bit [31:0] remap_addr(bit [31:0] exdes_addr);
        bit [23:0] base = exdes_addr[31:8];
        // QP config region 0x18_xx: example QP1@0x180100→our QP1@0x180000
        // For QPn (n>=1), shift by -0x100
        if (base >= 24'h1800 && base < 24'h1900 && exdes_addr[11:8] >= 4'h1)
            return exdes_addr - 32'h100;
        // MR region: NO remap — both use same QPn * 0x100 scheme
        return exdes_addr;
    endfunction

    task body();
        `uvm_info("EXDES_CFG", $sformatf("Writing %0d registers (example design full config)", NUM_CFG), UVM_MEDIUM)
        for (int j = 0; j < NUM_CFG; j++) begin
            csr_write(remap_addr(cfg_addr[j]), cfg_data[j]);
        end
        `uvm_info("EXDES_CFG", "Full example design configuration done", UVM_MEDIUM)
    endtask
endclass
