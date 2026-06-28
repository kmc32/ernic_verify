# ============================================================
# Makefile — ERNIC UVM Verification Environment
# Tools: Vivado 2022.2 (IP gen), VCS 2018.09-SP2 (simulation)
# ============================================================

VIVADO  ?= vivado
VCS     ?= vcs

UVM_HOME    ?= /home/harry/synopsys/vcs-mx/O-2018.09-SP2/etc/uvm-1.2
VCS_HOME    := $(abspath $(UVM_HOME)/../..)
VERDI_HOME  ?= /home/harry/synopsys/verdi/Verdi_O-2018.09-SP2
VERDI_PLI_DIR := $(VERDI_HOME)/share/PLI/VCS/LINUX64

BUILD_DIR   := build
VCS_LIB     := $(BUILD_DIR)/vcs_lib
ERNIC_LIB   := $(BUILD_DIR)/ernic_lib
SIMV        := $(BUILD_DIR)/simv
SYNOPSYS_SETUP := synopsys_sim.setup

TEST        ?= ernic_rdma_write_test
SEED        ?= 1

# ============================================================
# Step 1: Generate ERNIC simulation library via Vivado
# ============================================================
$(ERNIC_LIB)/.done:
	@echo "[GEN_IP] Generating ERNIC simulation library..."
	$(VIVADO) -mode batch -source scripts/gen_ip.tcl -notrace
	@touch $@

gen_ip: $(ERNIC_LIB)/.done

# ============================================================
# Step 2: Compile UVM + ERNIC lib + TB (VCS-MX multi-step flow)
# ============================================================
VLOGAN      ?= vlogan
VHDLAN      ?= vhdlan
VCS_ELAB    ?= vcs

COMPILE_LOG := $(BUILD_DIR)/compile.log
VLOGAN_LOG  := $(BUILD_DIR)/vlogan.log
VHDLAN_LOG  := $(BUILD_DIR)/vhdlan.log
ELAB_LOG    := $(BUILD_DIR)/elaborate.log

# pthread_yield stub (VCS 2018 compat with glibc 2.34+)
PTHREAD_STUB := $(BUILD_DIR)/pthread_yield_stub.so

$(PTHREAD_STUB):
	@echo 'int pthread_yield(void){extern int sched_yield(void);return sched_yield();}' | \
	    gcc -shared -fPIC -xc - -o $@

# UVM DPI shared library (required by UVM 1.2 multi-step flow)
UVM_DPI_SRC  := $(UVM_HOME)/dpi
UVM_DPI_LIB  := $(BUILD_DIR)/libuvm_dpi.so

$(UVM_DPI_LIB):
	g++ -shared -fPIC -DVCS \
	    -I$(UVM_DPI_SRC) \
	    -I$(VCS_HOME)/include \
	    $(UVM_DPI_SRC)/uvm_dpi.cc \
	    -o $@
	@echo "[DPI] UVM DPI shared library built: $@"

# Vivado install root (for VIP/XPM source paths)
VIVADO_ROOT := $(dir $(shell which vivado))..
VIVADO_ROOT := $(abspath $(VIVADO_ROOT))
VIVADO_VIP  := $(VIVADO_ROOT)/data/xilinx_vip
VIVADO_XPM  := $(VIVADO_ROOT)/data/ip/xpm

# IP static / gen directories (relative to project root)
IPSTATIC    := $(BUILD_DIR)/.tmp_proj.ipstatic
IPGEN       := $(BUILD_DIR)/.tmp_proj.gen

# Common vlogan options (for ERNIC IP — no UVM needed)
VLOGAN_OPTS := -full64 -sverilog -timescale=1ns/1ps +define+UVM_NO_DEPRECATED \
               +incdir+$(VIVADO_VIP)/include +incdir+$(VIVADO_VIP)/hdl \
               +incdir+$(IPGEN)/sources_1/ip/ernic_v4_0/hdl/common

# Common vhdlan options
VHDLAN_OPTS := -full64

# VCS library directories to create
VCS_LIBS := xilinx_vip xpm blk_mem_gen_v8_4_5 \
            lib_bmg_v1_0_14 fifo_generator_v13_2_7 \
            lib_fifo_v1_0_16 ernic_v4_0_0 xil_defaultlib work

# Multi-step compilation (VCS-MX flow with separate libraries)
# Step 2a: vlogan — compile SV/Verilog to design libraries
# Step 2b: vhdlan — compile VHDL to design libraries
# Step 2c: vcs   — elaborate with UVM
$(SIMV): $(ERNIC_LIB)/.done $(PTHREAD_STUB) $(UVM_DPI_LIB)
	@mkdir -p $(BUILD_DIR)
	@# Create VCS library directories
	@mkdir -p $(addprefix $(VCS_LIB)/,$(VCS_LIBS))
	@# Generate synopsys_sim.setup (library mapping)
	@echo "WORK > DEFAULT" > $(SYNOPSYS_SETUP)
	@echo "work : ./$(VCS_LIB)/work" >> $(SYNOPSYS_SETUP)
	@echo "xilinx_vip : ./$(VCS_LIB)/xilinx_vip" >> $(SYNOPSYS_SETUP)
	@echo "xpm : ./$(VCS_LIB)/xpm" >> $(SYNOPSYS_SETUP)
	@echo "blk_mem_gen_v8_4_5 : ./$(VCS_LIB)/blk_mem_gen_v8_4_5" >> $(SYNOPSYS_SETUP)
	@echo "lib_bmg_v1_0_14 : ./$(VCS_LIB)/lib_bmg_v1_0_14" >> $(SYNOPSYS_SETUP)
	@echo "fifo_generator_v13_2_7 : ./$(VCS_LIB)/fifo_generator_v13_2_7" >> $(SYNOPSYS_SETUP)
	@echo "lib_fifo_v1_0_16 : ./$(VCS_LIB)/lib_fifo_v1_0_16" >> $(SYNOPSYS_SETUP)
	@echo "ernic_v4_0_0 : ./$(VCS_LIB)/ernic_v4_0_0" >> $(SYNOPSYS_SETUP)
	@echo "xil_defaultlib : ./$(VCS_LIB)/xil_defaultlib" >> $(SYNOPSYS_SETUP)
	@echo "[VLOGAN] Compiling Verilog/SV libraries..."
	# --- xilinx_vip ---
	$(VLOGAN) -work xilinx_vip $(VLOGAN_OPTS) \
	    $(VIVADO_VIP)/hdl/axi4stream_vip_axi4streampc.sv \
	    $(VIVADO_VIP)/hdl/axi_vip_axi4pc.sv \
	    $(VIVADO_VIP)/hdl/xil_common_vip_pkg.sv \
	    $(VIVADO_VIP)/hdl/axi4stream_vip_pkg.sv \
	    $(VIVADO_VIP)/hdl/axi_vip_pkg.sv \
	    $(VIVADO_VIP)/hdl/axi4stream_vip_if.sv \
	    $(VIVADO_VIP)/hdl/axi_vip_if.sv \
	    $(VIVADO_VIP)/hdl/clk_vip_if.sv \
	    $(VIVADO_VIP)/hdl/rst_vip_if.sv \
	    -l $(VLOGAN_LOG) 2>&1 | tee -a $(VLOGAN_LOG)
	# --- xpm (SV only) ---
	$(VLOGAN) -work xpm $(VLOGAN_OPTS) \
	    $(VIVADO_XPM)/xpm_cdc/hdl/xpm_cdc.sv \
	    $(VIVADO_XPM)/xpm_fifo/hdl/xpm_fifo.sv \
	    $(VIVADO_XPM)/xpm_memory/hdl/xpm_memory.sv \
	    -l $(VLOGAN_LOG) 2>&1 | tee -a $(VLOGAN_LOG)
	# --- blk_mem_gen ---
	$(VLOGAN) -work blk_mem_gen_v8_4_5 $(VLOGAN_OPTS) +v2k \
	    $(IPSTATIC)/simulation/blk_mem_gen_v8_4.v \
	    -l $(VLOGAN_LOG) 2>&1 | tee -a $(VLOGAN_LOG)
	# --- fifo_generator (Verilog) ---
	$(VLOGAN) -work fifo_generator_v13_2_7 $(VLOGAN_OPTS) +v2k \
	    $(IPSTATIC)/simulation/fifo_generator_vlog_beh.v \
	    $(IPSTATIC)/hdl/fifo_generator_v13_2_rfs.v \
	    -l $(VLOGAN_LOG) 2>&1 | tee -a $(VLOGAN_LOG)
	# --- ernic_v4_0_0 (encrypted RFS) ---
	$(VLOGAN) -work ernic_v4_0_0 $(VLOGAN_OPTS) \
	    $(IPSTATIC)/hdl/ernic_v4_0_rfs.sv \
	    -l $(VLOGAN_LOG) 2>&1 | tee -a $(VLOGAN_LOG)
	# --- xil_defaultlib (ERNIC wrapper + glbl) ---
	$(VLOGAN) -work xil_defaultlib $(VLOGAN_OPTS) \
	    $(IPGEN)/sources_1/ip/ernic_v4_0/sim/ernic_v4_0.sv \
	    -l $(VLOGAN_LOG) 2>&1 | tee -a $(VLOGAN_LOG)
	$(VLOGAN) -work xil_defaultlib +v2k \
	    $(ERNIC_LIB)/vcs/glbl.v \
	    -l $(VLOGAN_LOG) 2>&1 | tee -a $(VLOGAN_LOG)
	@echo "[VHDLAN] Compiling VHDL libraries..."
	# --- xpm VHDL ---
	$(VHDLAN) -work xpm $(VHDLAN_OPTS) \
	    $(VIVADO_XPM)/xpm_VCOMP.vhd \
	    -l $(VHDLAN_LOG) 2>&1 | tee -a $(VHDLAN_LOG)
	# --- lib_bmg ---
	$(VHDLAN) -work lib_bmg_v1_0_14 $(VHDLAN_OPTS) \
	    $(IPSTATIC)/hdl/lib_bmg_v1_0_rfs.vhd \
	    -l $(VHDLAN_LOG) 2>&1 | tee -a $(VHDLAN_LOG)
	# --- fifo_generator VHDL ---
	$(VHDLAN) -work fifo_generator_v13_2_7 $(VHDLAN_OPTS) \
	    $(IPSTATIC)/hdl/fifo_generator_v13_2_rfs.vhd \
	    -l $(VHDLAN_LOG) 2>&1 | tee -a $(VHDLAN_LOG)
	# --- lib_fifo ---
	$(VHDLAN) -work lib_fifo_v1_0_16 $(VHDLAN_OPTS) \
	    $(IPSTATIC)/hdl/lib_fifo_v1_0_rfs.vhd \
	    -l $(VHDLAN_LOG) 2>&1 | tee -a $(VHDLAN_LOG)
	@echo "[VLOGAN] Compiling UVM + tb_top to work library..."
	# Compile UVM package first (required by tb_top)
	$(VLOGAN) -work work -full64 -sverilog \
	    +incdir+$(UVM_HOME)/src +incdir+$(UVM_HOME) \
	    +incdir+build/example_design/ernic_v4_0_ex/imports \
	    +define+UVM_NO_DEPRECATED -timescale=1ns/1ps \
	    tb/responder.v \
		    build/example_design/ernic_v4_0_ex/imports/ernic_v4_0_rnic_exdes_icrc_calc.v \
		    build/example_design/ernic_v4_0_ex/imports/ernic_v4_0_rnic_exdes_crc32_8b.v \
		    build/example_design/ernic_v4_0_ex/imports/ernic_v4_0_rnic_exdes_crc32_zero_extnd.v \
		    build/example_design/ernic_v4_0_ex/imports/ernic_v4_0_rnic_exdes_wqe_proc_crc_wrap.v \
		    build/example_design/ernic_v4_0_ex/imports/ernic_v4_0_RDMA_pkt_filter.v \
	    $(UVM_HOME)/src/uvm_pkg.sv \
	    -l $(VLOGAN_LOG) 2>&1 | tee -a $(VLOGAN_LOG)
	# Compile tb_top with UVM support
	$(VLOGAN) -work work -full64 -sverilog \
	    +incdir+$(UVM_HOME)/src +incdir+$(UVM_HOME) +incdir+. \
	    +incdir+$(VIVADO_VIP)/include +incdir+$(VIVADO_VIP)/hdl \
	    +incdir+$(IPGEN)/sources_1/ip/ernic_v4_0/hdl/common \
	    +incdir+build/example_design/ernic_v4_0_ex/imports \
	    +define+UVM_NO_DEPRECATED -timescale=1ns/1ps \
	    tb/responder.v \
		    build/example_design/ernic_v4_0_ex/imports/ernic_v4_0_rnic_exdes_icrc_calc.v \
		    build/example_design/ernic_v4_0_ex/imports/ernic_v4_0_rnic_exdes_crc32_8b.v \
		    build/example_design/ernic_v4_0_ex/imports/ernic_v4_0_rnic_exdes_crc32_zero_extnd.v \
		    build/example_design/ernic_v4_0_ex/imports/ernic_v4_0_rnic_exdes_wqe_proc_crc_wrap.v \
		    build/example_design/ernic_v4_0_ex/imports/ernic_v4_0_RDMA_pkt_filter.v \
	    tb/tb_top.sv \
	    -l $(VLOGAN_LOG) 2>&1 | tee -a $(VLOGAN_LOG)
	@echo "[VCS] Elaborating all libraries..."
	# Pure elaboration: resolve from pre-compiled libs, link with UVM DPI + Verdi FSDB
	$(VCS_ELAB) -full64 -debug_acc+pp+dmptf \
	    -P $(VERDI_PLI_DIR)/novas.tab \
	    -Mdir=$(BUILD_DIR)/csrc \
	    -LDFLAGS "-Wl,-rpath,$(CURDIR)/$(BUILD_DIR) -Wl,-rpath,$(VERDI_PLI_DIR) -L$(CURDIR)/$(BUILD_DIR) -L$(VERDI_PLI_DIR) -l:pthread_yield_stub.so -l:libuvm_dpi.so" \
	    xil_defaultlib.ernic_v4_0 work.tb_top xil_defaultlib.glbl \
	    -l $(ELAB_LOG) \
	    -o $(SIMV) 2>&1 | tee $(ELAB_LOG)

compile: $(SIMV)

# ============================================================
# Step 3: Run simulation
# ============================================================
SIM_LOG := $(BUILD_DIR)/$(TEST)_$(SEED).log
SIM_LOG_RAW := $(BUILD_DIR)/$(TEST)_$(SEED).raw.log

sim: compile
	@echo "[SIM] Running test=$(TEST) seed=$(SEED)..."
	$(SIMV) -full64 \
	    +UVM_TESTNAME=$(TEST) \
	    +ntb_random_seed=$(SEED) \
	    +UVM_VERBOSITY=UVM_MEDIUM \
	    -l $(SIM_LOG_RAW) 2>&1 | grep --line-buffered -v "XPM_MEMORY 20-[12]" | tee $(SIM_LOG)

# ============================================================
# Convenience targets per test point
# ============================================================
test_csr:
	$(MAKE) sim TEST=ernic_csr_test

test_rdma_write:
	$(MAKE) sim TEST=ernic_rdma_write_test

test_rdma_read:
	$(MAKE) sim TEST=ernic_rdma_read_test

test_send_recv:
	$(MAKE) sim TEST=ernic_send_recv_test

test_reliable:
	$(MAKE) sim TEST=ernic_reliable_transport_test

all_tests:
	$(MAKE) test_csr
	$(MAKE) test_rdma_write
	$(MAKE) test_rdma_read
	$(MAKE) test_send_recv
	$(MAKE) test_reliable

# ============================================================
# Clean
# ============================================================
clean:
	rm -rf $(SIMV) $(SIMV).daidir $(BUILD_DIR)/csrc \
	    $(BUILD_DIR)/*.log $(BUILD_DIR)/*.vpd ucli.key \
	    $(VCS_LIB) $(PTHREAD_STUB) $(UVM_DPI_LIB) $(SYNOPSYS_SETUP)

distclean: clean
	rm -rf $(BUILD_DIR)

.PHONY: gen_ip compile sim test_csr test_rdma_write test_rdma_read \
        test_send_recv test_reliable all_tests clean distclean
