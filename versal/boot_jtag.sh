#!/bin/bash

read -p "Enter full path to the Petalinux install [i.e: /opt/petalinux.2022.1]: " path

. "${path}"/settings.sh

xsct ./versal.tcl
