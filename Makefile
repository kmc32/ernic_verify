# ============================================================
# Makefile — ERNIC UVM Verification Environment
# Tools: Vivado 2022.2 (IP gen), VCS 2018.09-SP2 (simulation)
# ============================================================

VIVADO  ?= vivado
VCS     ?= vcs
SIMV    ?= ./simv

UVM_HOME    ?= /tools/synopsys/vcs/2018.09-SP2/etc/uvm-1.2
ERNIC_LIB   := sim/ernic_lib
VCS_LIBMAP  := $(ERNIC_LIB)/vcs_lib

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
# Step 2: Compile UVM + ERNIC lib + TB
# ============================================================
COMPILE_LOG := sim/compile.log

$(SIMV): $(ERNIC_LIB)/.done
	@mkdir -p sim
	@echo "[VCS] Compiling..."
	$(VCS) -full64 -sverilog -ntb_opts uvm-1.2 \
	    +incdir+$(UVM_HOME)/src \
	    +incdir+. \
	    -f $(VCS_LIBMAP)/ernic_v4_0.f \
	    tb/tb_top.sv \
	    -timescale=1ns/1ps \
	    +define+UVM_NO_DEPRECATED \
	    +lint=TFIPC-L \
	    -l $(COMPILE_LOG) \
	    -o $(SIMV) 2>&1 | tee $(COMPILE_LOG)

compile: $(SIMV)

# ============================================================
# Step 3: Run simulation
# ============================================================
SIM_LOG := sim/$(TEST)_$(SEED).log

sim: compile
	@echo "[SIM] Running test=$(TEST) seed=$(SEED)..."
	$(SIMV) -full64 \
	    +UVM_TESTNAME=$(TEST) \
	    +ntb_random_seed=$(SEED) \
	    +UVM_VERBOSITY=UVM_MEDIUM \
	    -l $(SIM_LOG) 2>&1 | tee $(SIM_LOG)

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
	rm -rf simv simv.daidir csrc sim/*.log sim/*.vpd ucli.key

distclean: clean
	rm -rf $(ERNIC_LIB) sim

.PHONY: gen_ip compile sim test_csr test_rdma_write test_rdma_read \
        test_send_recv test_reliable all_tests clean distclean
