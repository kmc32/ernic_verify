# gen_ip.tcl — generate VCS-compatible simulation libraries from Xilinx ERNIC v4.0
# Usage: vivado -mode batch -source scripts/gen_ip.tcl
# Requires: Vivado 2022.2, ERNIC IP licence

set PART     "xcvu9p-flga2104-2-i"
set IP_NAME  "ernic_v4_0"
set OUT_DIR  "[file dirname [file normalize [info script]]]/../sim/ernic_lib"

# Create a temporary in-memory project
create_project -in_memory -part $PART

# Customise ERNIC IP
create_ip -name ernic -vendor xilinx.com -library ip -version 4.0 -module_name $IP_NAME

# Apply default configuration — adjust properties per your design requirements
set_property -dict [list \
    CONFIG.C_NUM_QP          {4}   \
    CONFIG.C_DATA_WIDTH      {512} \
    CONFIG.C_AXIL_ADDR_WIDTH {32}  \
] [get_ips $IP_NAME]

generate_target simulation [get_ips $IP_NAME]

# Export simulation files for VCS
export_simulation \
    -simulator vcs \
    -ip_user_files_dir [get_property SIM_REPO_DIR [current_project]]/ip_user_files \
    -ipstatic_source_dir [get_property SIM_REPO_DIR [current_project]]/ipstatic \
    -lib_map_path $OUT_DIR/vcs_lib \
    -directory $OUT_DIR \
    -force

puts "INFO: ERNIC simulation library generated at $OUT_DIR"
