# gen_ip.tcl — generate VCS-compatible simulation libraries from Xilinx ERNIC v4.0
# Usage: vivado -mode batch -source scripts/gen_ip.tcl
# Requires: Vivado 2022.2, ERNIC IP licence

set PART     "xcvu9p-flga2104-2-i"
set IP_NAME  "ernic_v4_0"
set SCRIPT_DIR [file dirname [file normalize [info script]]]
set OUT_DIR  "[file normalize "$SCRIPT_DIR/../build/ernic_lib"]"
set TMP_PROJ "[file normalize "$SCRIPT_DIR/../build/.tmp_proj"]"

# Detect actual Vivado install root (e.g. /home/harry/synopsys/xilinx/Vivado/2022.2)
# Vivado's export_simulation may generate paths relative to /synopsys/...
# instead of the real install location when the temp project is at a
# different filesystem depth than expected.
set vivado_bin [file dirname [info nameofexecutable]]
set vivado_root [file dirname $vivado_bin]

# Clean up previous temp project (Vivado creates .tmp_proj.xpr + .tmp_proj.* dirs)
foreach f [glob -nocomplain "$TMP_PROJ*"] {
    file delete -force $f
}
file delete -force $OUT_DIR
file mkdir $OUT_DIR

# Create a disk-based temporary project
create_project -force -part $PART $TMP_PROJ

# Create and configure ERNIC IP
create_ip -name ernic -vendor xilinx.com -library ip -version 4.0 -module_name $IP_NAME

# C_NUM_QP valid range: 8,16,32,64,128,256,512,1024,2048
set_property -dict [list \
    CONFIG.C_NUM_QP                {8}   \
    CONFIG.C_S_AXI_LITE_ADDR_WIDTH {32}  \
] [get_ips $IP_NAME]

generate_target simulation [get_ips $IP_NAME]

# ==================================================================
# Export simulation to get file list and glbl.v
# ==================================================================
set VCS_DIR "$OUT_DIR/vcs"

# Simple relative-path helper (relative_path not available in Vivado Tcl)
proc relative_path {from to} {
    set from [file normalize [string map {\\ /} $from]]
    set to   [file normalize [string map {\\ /} $to]]
    set from_parts [file split $from]
    set to_parts   [file split $to]

    # Find common prefix
    set i 0
    while {$i < [llength $from_parts] && $i < [llength $to_parts] &&
           [lindex $from_parts $i] eq [lindex $to_parts $i]} {
        incr i
    }

    # Back up from remainder of $from
    set up_count [expr {[llength $from_parts] - $i}]
    set rel_parts {}
    for {set j 0} {$j < $up_count} {incr j} {
        lappend rel_parts ".."
    }

    # Append remainder of $to
    for {set j $i} {$j < [llength $to_parts]} {incr j} {
        lappend rel_parts [lindex $to_parts $j]
    }

    if {[llength $rel_parts] == 0} { return "." }
    return [join $rel_parts "/"]
}
# Set the IP as simulation top to suppress the "top was not set" error
set_property top $IP_NAME [current_fileset -simset]

export_simulation \
    -simulator vcs \
    -ip_user_files_dir "${TMP_PROJ}.ip_user_files" \
    -ipstatic_source_dir "${TMP_PROJ}.ipstatic" \
    -lib_map_path "$OUT_DIR/vcs_lib" \
    -directory $OUT_DIR \
    -force

# ==================================================================
# Generate ernic_v4_0.f from file_info.txt
# ==================================================================
set FILE_INFO "$VCS_DIR/file_info.txt"
set F_FILE    "$OUT_DIR/vcs_lib/ernic_v4_0.f"

file mkdir "$OUT_DIR/vcs_lib"

if {[file exists $FILE_INFO]} {
    set fh_in  [open $FILE_INFO r]
    set fh_out [open $F_FILE w]

    # Resolve all paths to absolute, then make them relative to the
    # project root (where Makefile runs VCS).  VCS resolves paths in -f
    # files relative to CWD, not relative to the .f file location.

    set PROJ_ROOT [file normalize "$SCRIPT_DIR/.."]
    set file_count 0
    set inc_dirs  [list]

    while {[gets $fh_in line] >= 0} {
        set fields [split $line ","]
        if {[llength $fields] < 3} { continue }

        set fpath  [string trim [lindex $fields 3]]
        set incdir [string trim [lindex $fields 4]]

        # Convert Windows backslashes
        set fpath [string map {\\ /} $fpath]

        # Resolve absolute path via VCS_DIR
        set abs_path [file normalize [file join $VCS_DIR $fpath]]

        # Fix: Vivado export_simulation may generate relative paths that
        # resolve to /synopsys/xilinx/... when the real install is elsewhere
        # (e.g. /home/harry/synopsys/xilinx/...).  Remap the prefix.
        if {![file exists $abs_path]} {
            regsub {^/synopsys/xilinx/Vivado/[^/]+} $abs_path $vivado_root corrected
            if {$corrected ne $abs_path && [file exists $corrected]} {
                set abs_path $corrected
            }
        }

        # Skip VHDL files — VCS is invoked with -sverilog only
        if {[string match "*.vhd" $fpath] || [string match "*.vhd" $abs_path]} {
            continue
        }

        set rel_path [string map {\\ /} [relative_path $PROJ_ROOT $abs_path]]

        puts $fh_out $rel_path

        # Collect unique include directories
        if {$incdir ne ""} {
            regsub {^incdir="(.*)"$} $incdir {\1} inc_path
            if {$inc_path ne "" && [lsearch -exact $inc_dirs $inc_path] < 0} {
                lappend inc_dirs $inc_path
            }
        }

        incr file_count
    }

    # Emit include dirs as +incdir+ lines (deduplicated)
    foreach inc_path $inc_dirs {
        set abs_inc [file normalize [file join $VCS_DIR $inc_path]]
        # Same Vivado path correction as for source files
        if {![file exists $abs_inc] && [file isdirectory $abs_inc] == 0} {
            regsub {^/synopsys/xilinx/Vivado/[^/]+} $abs_inc $vivado_root corrected
            if {$corrected ne $abs_inc && [file isdirectory $corrected]} {
                set abs_inc $corrected
            }
        }
        set rel_inc [string map {\\ /} [relative_path $PROJ_ROOT $abs_inc]]
        puts $fh_out "+incdir+$rel_inc"
    }

    # Add Vivado VIP include dirs (export_simulation doesn't emit these)
    set vip_include "$vivado_root/data/xilinx_vip/include"
    set vip_hdl     "$vivado_root/data/xilinx_vip/hdl"
    foreach vip_dir [list $vip_include $vip_hdl] {
        set rel_inc [string map {\\ /} [relative_path $PROJ_ROOT $vip_dir]]
        puts $fh_out "+incdir+$rel_inc"
    }
    close $fh_in
    close $fh_out
    puts "INFO: Generated $F_FILE with $file_count files"
} else {
    puts "ERROR: file_info.txt not found at $FILE_INFO"
    close_project
    exit 1
}

# Copy glbl.v to vcs_lib/ for convenience
if {[file exists "$VCS_DIR/glbl.v"]} {
    file copy -force "$VCS_DIR/glbl.v" "$OUT_DIR/vcs_lib/glbl.v"
}

close_project

puts "INFO: ERNIC simulation library generated at $OUT_DIR"
