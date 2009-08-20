namespace eval osd_keyboard {

# KNOWN ISSUES/TODO:
# * "-" key doesn't work (needs escaping) shouldn't use the keymatrix command,
#   but the 'type' command for all keys that are not on the same position in the matrix
#   for all machines
# * lots more? :P

#init vars
variable mouse1_pressed false
variable key_pressed -1
variable key_selected -1
variable keys_held
variable row_starts

#init colors
variable key_color 0xffffffc0
variable key_pressed_color 0xff8800ff
variable key_background_color 0x88888880
variable key_hold_color 0x00ff88ff
variable key_select_color 0xffff88ff
variable key_edge_color 0xaaaaaaa0

# Keyboard layout constants.
variable key_height 16
variable key_hspace 2
variable key_vspace 2
variable board_hborder 4
variable board_vborder 4

proc toggle_osd_keyboard {} {

	#If exists destory/reset and exit
	if {![catch {osd info kb -rgba} errmsg]} {
		#destroy virtual keyboard
		osd destroy kb
		#unbind mouse buttons and hotkeys
		unbind_default "mouse button1 down"
		unbind_default "mouse button1 up"
		unbind_default "mouse button3 down"
		unbind_default "keyb UP"
		unbind_default "keyb DOWN"
		unbind_default "keyb LEFT"
		unbind_default "keyb RIGHT"
		unbind_default "keyb SPACE,PRESS"
		unbind_default "keyb SPACE,RELEASE"
		#reset keyboard matrix
		for {set i 0} {$i <= 8} {incr i} {
			keymatrixup $i 255
		}
		return ""
	}

	variable mouse1_pressed false
	variable keys_held [list]
	variable row_starts [list]
	variable key_color
	variable key_background_color
	variable key_edge_color

	#bind stuff
	bind_default "mouse button1 down"  {osd_keyboard::key_handler true}
	bind_default "mouse button1 up"    {osd_keyboard::key_handler false}

	bind_default "mouse button3 down"  {osd_keyboard::key_hold_toggle}

	bind_default "keyb UP"     -repeat { osd_keyboard::selection_row -1  }
	bind_default "keyb DOWN"   -repeat { osd_keyboard::selection_row +1  }
	bind_default "keyb LEFT"   -repeat { osd_keyboard::selection_col -1  }
	bind_default "keyb RIGHT"  -repeat { osd_keyboard::selection_col +1  }
	bind_default "keyb SPACE,PRESS"    { osd_keyboard::selection_press   }
	bind_default "keyb SPACE,RELEASE"  { osd_keyboard::selection_release }

	#Define Keyboard (how do we handle the shift/ctrl/graph command?)
	set key_basewidth 18
	set rows {"F1*26|F2*26|F3*26|F4*26|F5*26|null*8|Select*26|Stop*26|null*8|Home*26|Ins*26|Del*26" \
			 "Esc|1|2|3|4|5|6|7|8|9|0|-|=|\\|BS" \
			 "Tab*28|Q|W|E|R|T|Y|U|I|O|P|\[|]|Return*28" \
			 "Ctrl*32|A|S|D|F|G|H|J|K|L|;|'|`|<--*24" \
			 "Shift*40|Z|X|C|V|B|N|M|,|.|/|Acc|Shift*36" \
			 "null*40|Cap|Grp|Space*158|Cod"}

	# Keyboard layout constants.
	variable key_height
	variable key_hspace
	variable key_vspace
	variable board_hborder
	variable board_vborder

	# Create widgets.
	set board_width \
		[expr 15 * $key_basewidth + 14 * $key_hspace + 2 * $board_hborder]
	set board_height \
		[expr 6 * $key_height + 5 * $key_vspace + 2 * $board_vborder]
	osd create rectangle kb \
		-x [expr (320 - $board_width) / 2 ] \
		-y 4 \
		-w $board_width \
		-h $board_height -scaled true -rgba $key_background_color
	set keycount 0
	for {set y 0} {$y <= [llength $rows]} {incr y} {
		lappend row_starts $keycount
		set x $board_hborder
		foreach {keys} [split [lindex $rows $y]  "|"] {
			set key [split $keys "*"]
			set key_text [lindex $key 0]
			set key_width [lindex $key 1]
			if {$key_width < 1} {set key_width $key_basewidth}

			if {$key_text != "null"} {
				osd create rectangle kb.$keycount \
					-x $x \
					-y [expr $board_vborder + $y * ($key_height + $key_vspace)] \
					-w $key_width \
					-h $key_height \
					-rgba $key_color

			#no edge for return key
			if {$key_text != "Return" && $key_text != "<--"} {
				osd_widgets::box kb.$keycount.box \
					-w $key_width \
					-h $key_height \
					-rgba $key_edge_color
			}

				if {$key_text == "<--"} {
					# Merge bottom part of "return" key with top part.
					osd configure kb.$keycount \
						-y [expr [osd info kb.$keycount -y] - $key_vspace] \
						-h [expr [osd info kb.$keycount -h] + $key_vspace]
				}

				osd create text kb.$keycount.text \
					-x 0.1 \
					-y 0.1 \
					-text $key_text \
					-size 8

				incr keycount
			}

			set x [expr $x + $key_width + $key_hspace]
		}
	}

	variable key_selected
	if {$key_selected == -1} {
		# Select the key in the middle of the keyboard.
		key_select [key_at_coord \
			[expr $board_width / 2] \
			[expr $board_vborder + 3.5 * ($key_height + $key_vspace)] \
			]
	} else {
		update_key_color $key_selected
	}

	return ""
}

proc selection_row {delta} {
	variable row_starts
	variable key_selected

	# Note: Delta as bias makes sure that if a key is exactly in the middle
	#       above/below two other keys, an up/down or down/up sequence will
	#       end on the same key it started on.
	set x [expr \
		[osd info kb.$key_selected -x] + [osd info kb.$key_selected -w] / 2 \
		+ $delta ]
	set num_rows [expr [llength $row_starts] - 1]
	set row [row_for_key $key_selected]
	while {1} {
		# Determine new row.
		incr row $delta
		if {$row < 0} {
			set row [expr $num_rows - 1]
		} elseif {$row >= $num_rows} {
			set row 0
		}

		# Get key at new coordinates.
		set first_key [lindex $row_starts $row]
		set y [expr \
			[osd info kb.$first_key -y] + [osd info kb.$first_key -h] / 2 \
			]
		set new_selection [key_at_coord $x $y]
		if {$new_selection >= 0} {
			break
		}
	}

	key_select $new_selection
}

proc selection_col {delta} {
	variable row_starts
	variable key_selected

	# Figure out first and last key of current row.
	set row [row_for_key $key_selected]
	set row_start [lindex $row_starts $row]
	set row_end [lindex $row_starts [expr $row + 1]]

	# Move left or right.
	set new_selection [expr $key_selected + $delta]
	if {$new_selection < $row_start} {
		set new_selection [expr $row_end - 1]
	} elseif {$new_selection >= $row_end} {
		set new_selection $row_start
	}

	key_select $new_selection
}

proc selection_press {} {
	variable key_selected
	key_press $key_selected
}

proc selection_release {} {
	key_release
}

proc key_press {key_id} {
	variable key_pressed

	set key_pressed $key_id
	key_matrix $key_id down
	update_key_color $key_id
}

proc key_release {} {
	variable key_pressed
	variable keys_held

	set key_id $key_pressed
	set key_pressed -1
	set index [lsearch $keys_held $key_id]
	if {$index != -1} {
		set keys_held [lreplace $keys_held $index $index]
	}
	key_matrix $key_id up
	update_key_color $key_id
}

proc key_select {key_id} {
	variable key_selected

	set old_selected $key_selected
	set key_selected $key_id
	update_key_color $key_selected
	update_key_color $old_selected
}

proc row_for_key {key_id} {
	variable row_starts
	for {set row 0} {$row < [llength $row_starts] - 1} {incr row} {
		set row_start [lindex $row_starts $row]
		set row_end [lindex $row_starts [expr $row + 1]]
		if {$row_start <= $key_id && $key_id < $row_end} {
			return $row
		}
	}
	return -1
}

proc update_key_color {key_id} {
	variable key_selected
	variable key_pressed
	variable keys_held
	variable key_color
	variable key_select_color
	variable key_pressed_color
	variable key_hold_color

	if {$key_id < 0} {
		return
	} elseif {$key_id == $key_pressed} {
		set color $key_pressed_color
	} elseif {$key_id == $key_selected} {
		set color $key_select_color
	} elseif {[lsearch $keys_held $key_id] != -1} {
		set color $key_hold_color
	} else {
		set color $key_color
	}
	osd configure kb.$key_id -rgba $color
}

proc key_at_coord {x y} {
	variable key_hspace
	variable key_height
	variable key_vspace
	variable board_vborder
	variable row_starts
	set row [expr int(floor( \
		($y - $board_vborder + $key_vspace / 2) / ($key_height + $key_vspace) \
		))]
	if {$row >= 0 && $row < [llength $row_starts] - 1} {
		set row_start [lindex $row_starts $row]
		set row_end [lindex $row_starts [expr $row + 1]]
		for {set key_id $row_start} {$key_id < $row_end} {incr key_id} {
			set relx [expr $x - [osd info kb.$key_id -x] + $key_hspace / 2]
			if {$relx >= 0 && $relx < [osd info kb.$key_id -w] + $key_hspace} {
				return $key_id
			}
		}
	}
	return -1
}

proc key_at_mouse {} {
	foreach {x y} [osd info kb -mousecoord] {
		return [key_at_coord \
			[expr $x * [osd info kb -w]] \
			[expr $y * [osd info kb -h]] \
			]
	}
}

proc key_hold_toggle {} {
	variable keys_held
	variable key_color
	variable key_hold_color

	set key_id [key_at_mouse]
	if {$key_id >= 0} {
		set index [lsearch $keys_held $key_id]
		if {$index == -1} {
			key_matrix $key_id down
			lappend keys_held $key_id
		} else {
			key_matrix $key_id up
			set keys_held [lreplace $keys_held $index $index]
		}
		update_key_color $key_id
	}
}

proc key_handler {mouse_state} {
	if {$mouse_state} {
		set key_id [key_at_mouse]
		if {$key_id >= 0} {
			key_press $key_id
			key_select $key_id
		}
	} else {
		key_release
	}
}

proc key_matrix {keynum state} {
	set key [string trim "[osd info kb.$keynum.text -text]"]

	set km keymatrix$state

	#info from http://map.grauw.nl/articles/keymatrix.php (thanks Grauw)

	switch $key {
		"0" 	{$km 0 1}
		"1" 	{$km 0 2}
		"2" 	{$km 0 4}
		"3" 	{$km 0 8}
		"4" 	{$km 0 16}
		"5" 	{$km 0 32}
		"6" 	{$km 0 64}
		"7" 	{$km 0 128}

		"8" 	{$km 1 1}
		"9" 	{$km 1 2}
		"-" 	{$km 1 4}
		"=" 	{$km 1 8}
		"\\" 	{$km 1 16}
		"\[" 	{$km 1 32}
		"\]" 	{$km 1 64}
		";" 	{$km 1 128}

		"'" 	{$km 2 1}
		"`" 	{$km 2 2}
		"," 	{$km 2 4}
		"." 	{$km 2 8}
		"/" 	{$km 2 16}
		"Acc" 	{$km 2 32}
		"A" 	{$km 2 64}
		"B" 	{$km 2 128}

		"C" 	{$km 3 1}
		"D" 	{$km 3 2}
		"E" 	{$km 3 4}
		"F" 	{$km 3 8}
		"G" 	{$km 3 16}
		"H" 	{$km 3 32}
		"I" 	{$km 3 64}
		"J" 	{$km 3 128}

		"K" 	{$km 4 1}
		"L" 	{$km 4 2}
		"M" 	{$km 4 4}
		"N" 	{$km 4 8}
		"O" 	{$km 4 16}
		"P" 	{$km 4 32}
		"Q" 	{$km 4 64}
		"R" 	{$km 4 128}

		"S" 	{$km 5 1}
		"T" 	{$km 5 2}
		"U" 	{$km 5 4}
		"V" 	{$km 5 8}
		"W" 	{$km 5 16}
		"X" 	{$km 5 32}
		"Y" 	{$km 5 64}
		"Z" 	{$km 5 128}

		"Shift" {$km 6 1}
		"Ctrl" 	{$km 6 2}
		"Grp"	{$km 6 4}
		"Cap" 	{$km 6 8}
		"Cod" 	{$km 6 16}
		"F1" 	{$km 6 32}
		"F2" 	{$km 6 64}
		"F3" 	{$km 6 128}

		"F4" 	{$km 7 1}
		"F5" 	{$km 7 2}
		"Esc" 	{$km 7 4}
		"Tab" 	{$km 7 8}
		"Stop" 	{$km 7 16}
		"BS" 	{$km 7 32}
		"Select" {$km 7 64}
		"Return" {$km 7 128}
		"<--"	{$km 7 128}

		"Space" {$km 8 1}
		"Home" 	{$km 8 2}
		"Ins" 	{$km 8 4}
		"Del" 	{$km 8 8}
	}

		#cursor keys etc (not implemented... should we?)
		#numeric keyboard?
}

namespace export toggle_osd_keyboard

};# namespace osd_keyboard

namespace import osd_keyboard::*