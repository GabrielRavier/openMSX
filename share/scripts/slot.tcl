#
# get_selected_slot
#
set_help_text get_selected_slot \
{Returns the selected slot for the given memory page.
This proc is typically used as a helper for a larger proc.
 
 @param page The memory page (0-3)
 @result Returns a TCL list with two elements.
         First element is the primary slot (0-3).
         Second element is the secondary slot (0-3) or 'X'
         in case this slot was not expanded
}
proc get_selected_slot { page } {
	set ps_reg [debug read "ioports" 0xA8]
	set ps [expr ($ps_reg >> (2 * $page)) & 0x03]
	if [machine_info "issubslotted" $ps] {
		set ss_reg [debug read "slotted memory" [expr 0x40000 * $ps + 0xFFFF]]
		set ss [expr (($ss_reg ^ 255) >> (2 * $page)) & 0x03]
	} else {
		set ss "X"
	}
	return [list $ps $ss]
}

#
# slotselect
#
set_help_text slotselect \
{Returns a nicely formatted overview of the selected slots.}
proc slotselect { } {
	set result ""
	for { set page 0 } { $page < 4 } { incr page } {
		set tmp [get_selected_slot $page]
		set ps [lindex $tmp 0]
		set ss [lindex $tmp 1]
		append result [format "%04X" [expr 0x4000 * $page]] ": slot " $ps
		if {$ss != "X"} { append result "." $ss }
		append result "\n"
	}
	return $result
}

#
# get_mapper_size
#
set_help_text get_mapper_size \
{Returns the size of the memory mapper in a given slot.
Result is 0 when there is no memory mapper in the slot.}
proc get_mapper_size { ps ss } {
	set result 0
	catch {
		set slots [split [slotmap] \n]
		set slot_name "$ps"
		if [machine_info issubslotted $ps] { append slot_name ".$ss" }
		set index [lsearch $slots "slot $slot_name:"]
		set device [lrange [lindex $slots [expr $index + 2]] 1 end]
		if { [debug desc $device] == "memory mapper" } {
			set result [expr [debug size $device] / 0x4000]
		}
	}
	return $result
}

#
# pc_in_slot
#
set_help_text pc_in_slot \
{Test whether the CPU's program counter is inside a certain slot.
Typically used to set breakpoints in specific slots.}
proc pc_in_slot { ps {ss "X"} {mapper "X"} } {
	set d "CPU regs"
	set pc [expr [debug read $d 20] * 256 + [debug read $d 21]]
	set page [expr $pc >> 14]
	set tmp [get_selected_slot $page]
	set pc_ps [lindex $tmp 0]
	set pc_ss [lindex $tmp 1]
	if { $ps != $pc_ps } { return false }
	if {($ss != "X") && ($pc_ss != "X") && ($pc_ss != $ss)} { return false }
	set mapper_size [get_mapper_size $pc_ps $pc_ss]
	if { ($mapper_size == 0) || ($mapper == "X" ) } { return true }
	set pc_mapper [debug read "MapperIO" $page]
	return [expr $mapper == ($pc_mapper & ($mapper_size - 1))]
}

#
# slotmap
#
set_help_text slotmap \
{Gives an overview of the devices in the different slots.}
proc slotmap-helper { ps ss } {
	set result ""
	for { set page 0 } { $page < 4 } { incr page } {
		set name [machine_info slot $ps $ss $page]
		append result [format "%04X: %s\n" [expr $page * 0x4000] $name]
	}
	return $result
}
proc slotmap { } {
	set result ""
	for { set ps 0 } { $ps < 4 } { incr ps } {
		if [machine_info issubslotted $ps] {
			for { set ss 0 } { $ss < 4 } { incr ss } {
				append result "slot $ps.$ss:\n"
				append result [slotmap-helper $ps $ss]
			}
		} else {
			append result "slot $ps:\n"
			append result [slotmap-helper $ps 0]
		}
	}
	return $result
}

#
# iomap
#
set_help_text iomap \
{Gives an overview of the devices connected to the different IO ports.}
proc iomap-helper { prefix begin end name } {
	if [string equal $name "empty"] return ""
	set result [format "port %02X" $begin]
	if {$begin == ($end - 1)} {
		append result ":   "
	} else {
		append result [format "-%02X:" [expr $end - 1]]
	}
	append result " $prefix $name\n"
}
proc iomap {} {
	set result ""
	set port 0
	while {$port < 256} {
		set in  [machine_info input_port  $port]
		set out [machine_info output_port $port]
		set end [ expr $port + 1]
		while { ($end < 256) &&
		        [string equal $in  [machine_info input_port  $end]] &&
		        [string equal $out [machine_info output_port $end]] } {
			incr end
		}
		if [string equal $in $out] {
			append result [iomap-helper "I/O" $port $end $in ]
		} else {
			append result [iomap-helper "I  " $port $end $in ]
			append result [iomap-helper "  O" $port $end $out]
		}
		set port $end
	}
	return $result
}
