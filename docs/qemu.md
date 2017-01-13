# OP-TEE on QEMU

# Contents
1. [Introduction](#1-introduction)
2. [Regular build](#2-regular-build)
3. [Install files on the device](#3-qemu-console)
4. [Host-Guest folder sharing](#4-host-guest-folder-sharing)
5. [SLiRP user networking](#5-slirp-user-networking)

# 1. Introduction
The instructions here will tell how to run OP-TEE using QEMU. We have two
working configurations one for ARMv7-A and one for ARMv8-A. The major difference
between the two is the boot procedure. In the ARMv7-A case it's using a bios,
but on ARMv8-A it uses ARM-TF etc instead.

# 2. Regular build
As long as you pick either the v7 (default.xml) or the v8 (qemu_v8.xml) the "Get
and build the solution" in the [README.md] file tells all you need to know to
build and boot up QEMU.

# 3. QEMU console
After running `make run` you will end up in the QEMU console and it will also
spawn two xterm windows. One console containing the UART for secure world and
one console containing the UART for normal world.

## 3.1 ARMv7-A
It will stop on the QEMU console, to continue, simply
```
(qemu) c
```

## 3.2 ARMv8-A
It won't stop, it will just boot up QEMU and OP-TEE.

# 4. Host-Guest folder sharing

To avoid changing rootfs CPIO archive each time you need to add additional files
to it, you can also use VirtFS QEMU feature to share a folder between the guest
and host operating systems. To use this feature enable VirtFS QEMU build in
build/common.mk (set `QEMU_VIRTFS_ENABLE ?= y`), adjust `QEMU_VIRTFS_HOST_DIR` and
rebuild QEMU.

To mount host folder in QEMU, simply run:

```bash
$ mount_shared <mount_point>
```
# 5. SLiRP user networking
To enable SLiRP user networking just set `QEMU_USERNET_ENABLE ?= y` in `common.mk`.
After booting QEMU VM, eth0 will automatically receive IP address via DHCP

*Important* Take into account that ICMP doesn't work in SLiRP mode,
so `ping` utility won't work.

[bios]: https://github.com/linaro-swg/bios_qemu_tz_arm
[README.md]: ../README.md
