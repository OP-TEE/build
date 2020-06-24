#! /bin/bash
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2020, Roland Nagy <rnagy@xmimx.tk>

TARGETDIR="$1"
VIRTFS_AUTOMOUNT="$2"
VIRTFS_MOUNTPOINT="$3"
PSS_AUTOMOUNT="$4"

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

if [[ -z $PSS_AUTOMOUNT ]]; then
    echo "PSS_AUTOMOUNT missing"
    exit 1
fi


if [[ $VIRTFS_AUTOMOUNT == "y" ]]; then
    grep host "$TARGETDIR"/etc/fstab > /dev/null || \
    echo "host $VIRTFS_MOUNTPOINT 9p trans=virtio,version=9p2000.L,rw 0 0" >> "$TARGETDIR"/etc/fstab
    echo "[+] shared directory mount added to fstab"
fi

if [[ $PSS_AUTOMOUNT == "y" ]]; then
    mkdir -p "$TARGETDIR"/data/tee
    grep secure "$TARGETDIR"/etc/fstab > /dev/null || \
    echo "secure /data/tee 9p trans=virtio,version=9p2000.L,rw 0 0" >> "$TARGET_DIR"/etc/fstab
    echo "[+] persistent secure storage mount added to fstab"
fi
