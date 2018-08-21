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
$ mount -t 9p -o trans=virtio host <mount_point>
```
# 5. Networking
After booting the QEMU VM, `eth0` will automatically receive an IP address from
QEMU via DHCP thanks to the SLiRP user networking feature. QEMU will act as a
gateway to the host network [SLiRP].

Please note that ICMP won't work in the guest unless additional configuration is
made, so the `ping` utility won't work.

# 6. Remote debugging of Normal World applications
If you need to debug a client application, using GDB in a remote debugging
configuration may be useful. Remote debugging means `gdb` runs on your PC, where
it can access the source code, while the program being debugged runs on the remote
system (in this case, in the QEMU environment in normal world).
Here is how to do that. On your PC, build with `GDBSERVER=y`:
```
$ cd build
$ make -j8 run GDBSERVER=y
[...]
(qemu) c
```
Inside QEMU, run your application with gdbserver (for example `xtest 4002`):
```
# gdbserver :12345 xtest 4002
Process xtest created; pid = 654
Listening on port 12345

```
Back on your PC, in another terminal, start GDB and connect to the target:
```
$ ../out-br/host/bin/arm-buildroot-linux-gnueabihf-gdb
(gdb) set sysroot ../out-br/host/arm-buildroot-linux-gnueabihf/sysroot
(gdb) target remote :12345
```
Now GDB is connected to the remote application. You may use GDB normally.
```
(gdb) b main
(gdb) c
etc.
```

[bios]: https://github.com/linaro-swg/bios_qemu_tz_arm
[README.md]: ../README.md
[SLiRP]: https://wiki.qemu.org/Documentation/Networking#User_Networking_.28SLIRP.29
