set interactive 0
set hw_server_url ""
set hw_server_url_opt 0
foreach arg $argv {
	if {$hw_server_url_opt} {
		set hw_server_url_opt 0
		set hw_server_url $arg
		continue
	}
	if {"$arg" eq "-interactive"} {
		set interactive 1
	} elseif {"$arg" eq "-url"} {
		set hw_server_url_opt 1
	}
}

proc _connect {} {
	global hw_server_url

	if {[string length $hw_server_url] > 0} {
		puts "info: using hw_server URL from command line argument: \"$hw_server_url\""
		connect -url $hw_server_url
	} elseif {[info exists ::env(HW_SERVER_URL)] &&
		  [string length $::env(HW_SERVER_URL)]} {
		puts "info: using hw_server URL from environment variable HW_SERVER_URL: \"$::env(HW_SERVER_URL)\""
		connect -url $::env(HW_SERVER_URL)
	} else {
		puts "info: launching local hw_server instance"
		connect
	}
	after 1000
}

proc _reset {} {
	puts "Selecting target Versal"
	target -set -filter {name =~ "Versal *"}

	# PMC_MULTI_BOOT (PMC_GLOBAL) Register
	#   0x00F1110004
	puts "Clear PMC_MULTI_BOOT register (0x00f1110004 = 0x0)"
	mwr 0x00f1110004 0x0

	# BOOT_MODE_USER (CRP) Register
	#   0x00f1260200[15:12] == 0x0  => JTAG boot mode
	#   0x00f1260200[8]     == 0x1  => use [15:12] as boot mode
	set boot_mode_user_reg 0x0100
	puts "Switch to JTAG boot mode, BOOT_MODE_USER register (0x00f1260200 = [format 0x%04x $boot_mode_user_reg])"
	mwr 0x00f1260200 $boot_mode_user_reg

	puts "Selecting target PMC"
	target -set -filter {name =~ "*PMC*"}

	puts "Reset system"
	rst -type system
}

proc _program {} {
	_reset

	puts "Selecting target Versal"
	target -set -filter {name =~ "Versal *"}

	puts "Loading BOOT.BIN"
	device program "BOOT.BIN"

	puts "PLM memory log after loading BOOT.BIN:"
	plm log
}

_connect
_program

if {$interactive} {
	puts "info: Staying interactive; available custom commands:"
	puts ""
	puts "	_program	(re-)program BOOT.BIN"
	puts "	_reset		switch to JTAG boot mode and reset"
	puts "	_connect	(re-)connect to target"
	puts ""
}
