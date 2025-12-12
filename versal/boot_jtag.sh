#!/bin/bash

# autodetect xsdb availability
detect_petalinux_xsdb()
{
	if [ -n $PETALINUX_VER ]; then
		# if Petalinux > v2023.2
		if [ -e $PETALINUX/components/xsct/bin/xsdb ]; then
			XSDB=$PETALINUX/components/xsct/bin/xsdb

		# if Petalinux > v2019.1
		else
			XSDB=$PETALINUX/tools/xsct/bin/xsdb
		fi
	fi
}

if [ -z "$XSDB" ]; then
	# if within Vitis environment, xsdb is in PATH
	if which xsdb >/dev/null; then
		XSDB=xsdb

	# if within Petalinux environment, xsdb is NOT in PATH
	else
		detect_petalinux_xsdb
	fi
fi

# fallback to querying user for Petalinux installation unless xsdb has been
# found
if [ -z "$XSDB" ]; then
	read -p "Enter full path to the Petalinux install [i.e: /opt/petalinux.2022.1]: " path
	. "${path}"/settings.sh

	# if within Petalinux environment, xsdb is NOT in PATH
	detect_petalinux_xsdb
fi

opts=
tclargs=
while [ $# -gt 0 ]; do
	case $1 in
	-i|-interactive)
		opts="$opts -interactive"
		tclargs="$tclargs -interactive"
		;;
	-u|-url)
		tclargs="$tclargs -url $2"
		shift 1
		;;
	-h|-help|--help)
		echo "usage: $0 [-i|-interactive] [-u|-url <hw_server-url>]"
		echo ""
		echo "options:"
		echo "	-i		enter xsdb interactive mode after initial loading of BOOT.BIN"
		echo "	-u <url>	hw_server URL to use when executing xsdb command \"connect\""
		exit 0
		;;
	esac
	shift 1
done

env -C $(dirname $0) $XSDB $opts versal.tcl $tclargs
