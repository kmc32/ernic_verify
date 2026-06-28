# Generate and run example design simulation using Vivado xsim
# Usage: vivado -mode batch -source scripts/gen_exdes_sim.tcl

set EXDES_PROJ [file normalize "[file dirname [info script]]/../build/example_design/ernic_v4_0_ex/ernic_v4_0_ex.xpr"]

puts "INFO: Opening example design project: $EXDES_PROJ"
open_project $EXDES_PROJ

# Set top module
set_property top xrnic_exdes_tb [get_filesets sim_1]

# Set simulation runtime to 200us (long enough for full test)
set_property -name {xsim.simulate.runtime} -value {200us} -objects [get_filesets sim_1]

# Generate simulation scripts only (don't launch GUI)
puts "INFO: Generating simulation scripts..."
launch_simulation -scripts_only -simset sim_1 -mode behavioral

set XSIM_DIR [file normalize "$EXDES_PROJ.ernic_v4_0_ex.sim/sim_1/behav/xsim"]
puts "INFO: Scripts generated in: $XSIM_DIR"

# Run compilation
cd $XSIM_DIR
puts "INFO: Running compilation (xvlog/xvhdl)..."
if {[catch {exec bash -c "cd $XSIM_DIR && xvlog --incr --relax -prj [glob $XSIM_DIR/../*.prj] 2>&1 | tee compile.log"} err]} {
    puts "WARNING: xvlog direct command may have failed, trying elaborate..."
}

# Run elaborate
puts "INFO: Running elaboration..."
set elab_cmd "xelab --incr --debug typical --relax --mt 8 -L xil_defaultlib -L blk_mem_gen_v8_4_5 -L lib_bmg_v1_0_14 -L fifo_generator_v13_2_7 -L lib_fifo_v1_0_16 -L ernic_v4_0_0 -L uvm -L unisims_ver -L unimacro_ver -L secureip -L xpm --snapshot xrnic_exdes_tb_behav xil_defaultlib.xrnic_exdes_tb xil_defaultlib.glbl -log elaborate.log"

if {[catch {exec bash -c "cd $XSIM_DIR && $elab_cmd"} elab_err]} {
    puts "ERROR: Elaboration failed:"
    puts $elab_err
    if {[file exists "$XSIM_DIR/elaborate.log"]} {
        set fh [open "$XSIM_DIR/elaborate.log" r]
        puts [read $fh]
        close $fh
    }
} else {
    puts "INFO: Elaboration passed. Running simulation..."
    # Run simulation with TCL batch
    set tcl_file "$XSIM_DIR/xrnic_exdes_tb.tcl"
    if {[catch {exec bash -c "cd $XSIM_DIR && xsim xrnic_exdes_tb_behav -key {Behavioral:sim_1:Functional:xrnic_exdes_tb} -tclbatch $tcl_file -log simulate.log 2>&1"} sim_err]} {
        puts "SIM RESULT: $sim_err"
    }
    # Show results
    set sim_log "$XSIM_DIR/simulate.log"
    if {[file exists $sim_log]} {
        set fh [open $sim_log r]
        set log_data [read $fh]
        close $fh
        foreach line [split $log_data "\n"] {
            if {[regexp {Test |ERROR|Completed|Number of|Successfully|EXDES_} $line]} {
                puts "RESULT: $line"
            }
        }
    }
}

close_project
puts "INFO: Done"
