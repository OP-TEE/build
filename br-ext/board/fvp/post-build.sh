#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2020, Roland Nagy <rnagy@xmimx.tk>
# Copyright (c) 2022, Arm Limited

TARGET_DIR="$1"
VIRTFS_AUTOMOUNT="$2"
VIRTFS_MOUNTPOINT="$3"

if [[ -z $TARGET_DIR ]]; then
	echo "TARGET_DIR missing"
	exit 1
fi

if [[ -z $VIRTFS_AUTOMOUNT ]]; then
	echo "VIRTFS_AUTOMOUNT missing"
	exit 1
fi

if [[ -z $VIRTFS_MOUNTPOINT ]]; then
	echo "VIRTFS_MOUNTPOINT missing"
	exit 1
fi

if [[ $VIRTFS_AUTOMOUNT == "y" ]]; then
	grep FM "$TARGET_DIR"/etc/fstab > /dev/null || \
	echo "FM $VIRTFS_MOUNTPOINT 9p trans=virtio,version=9p2000.L 0 0" >> "$TARGET_DIR"/etc/fstab
fi
