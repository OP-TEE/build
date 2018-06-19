# OP-TEE on Raspberry Pi 3
[Sequitur Labs] did the initial port which besides the actual OP-TEE port also
patched U-boot, ARM Trusted Firmware and Linux kernel. Sequitur Labs also pulled
together patches for OpenOCD to be able to debug the solution using cheap JTAG
debuggers. For more information about the work, please see the [press
release] from June 8 2016.

# Contents
1. [Disclaimer](#1-disclaimer)
2. [Upstream?](#2-upstream)
3. [Build instructions](#3-build-instructions)
4. [Known problems](#4-known-problems)
5. [NFS boot](#5-nfs-boot)
6. [OpenOCD and JTAG](#6-openocd-and-jtag)

# 1. Disclaimer
```
This port of ARM Trusted Firmware and OP-TEE to Raspberry Pi3

                   IS NOT SECURE!

Although the Raspberry Pi3 processor provides ARM TrustZone
exception states, the mechanisms and hardware required to
implement secure boot, memory, peripherals or other secure
functions are not available. Use of OP-TEE or TrustZone capabilities
within this package _does not result_ in a secure implementation.

This package is provided solely for educational purposes.
```

# 2. Upstream?
This is a working setup, but there are quite a few patches that are put on top
of forks and some of the patches has been put together by just pulling files
instead of (correctly) cherry-pick patches from various projects. For some of
the projects it could take some time to get the work accepted upstream. Due to
this, things might not initially be on official git's and in some cases things
will be kept on a separate branch. But as time goes by we will gradually
move it over to the official gits. We are fully aware that this is not the
optimal way to do this, but we also know that there is a strong interest among
developers, students, researches to start work and learn more about TEE's using
a Raspberry Pi. So instead of delaying this, we have decided to make what we
have available right away. Hopefully there will be some enthusiast that will
help out making proper upstream patches sooner or later.

| Project | Base fork | What to do |
|---------|-----------|------------|
| linux | https://github.com/raspberrypi/linux.git commit: e0d2b2b6df54f175dc73eb294976e756fa68d57d | Three things here. 1. The base is a fork itself and should be upstreamed. 2. Apply patch [arm64: dt: RPI3: Add optee node] |

# 3. Build instructions
- First thing to pay attention to the [OP-TEE prerequisites]. If you forget
  that, then you can get all sorts of strange errors.

- Follow the generic build instructions from the [README.md] file in this git.
  Note that the initial build will download a couple of files, like the official
  Raspberry Pi 3 firmware, the overlay root fs etc. However, that is only done
  once, so subsequent builds won't re-download them again (as long as you don't
  delete them).

- The last step is to partition and format the memory card and to put the files
  onto the same. That is something we don't want to automate, since if anything
  goes wrong, in worst case it might wipe one of your regular hard disks. Instead
  what we have done, is that we have created another makefile target that will tell
  you exactly what to do. Run that command and follow the instructions there.
```bash
$ make img-help
```

- Boot up the Pi. With all files on the memory card, put the memory card into
  the Raspberry Pi 3 and boot up the system. On the UART (for wiring, see
  section 6) you will see the system booting up. When you have a shell, then
  it's simply just to follow the [xtest instructions] to load tee-supplicant and
  run xtest.

# 4. Known problems
We encourage anyone interested in getting this into a better shape to help out.
We have identified a couple issues while working with this. Some are harder to
solve than others.

## 4.1 Root file system
Currently we are using a cpio archive with busybox as a base, that works fine
and has a rather small footprint it terms of size. However in some cases it's
convenient to use something that reminds of what is used in distros. For
example having the ability to use a package manager like apt-get, pacman or rpm
(dnf) to make it easy to add new applications and developer tools.

Suggestions to look into regarding creating a better rootfs
- Create a setup where one use [buildroot] instead of manually creating the cpio
  archive.
- Create a 64bit [Raspbian] image. This would be the ultimate goal. Besides just
  the big work with building a 64bit Raspian image, one would also need to
  ensure that Linux kernel gets updated accordingly (i.e., pull 64bit RPi3
  patches and OP-TEE patches into the official Raspbian Linux kernel build).

Having that said, in the section below about NFS boot, we've been successfully
using a Debian based Linaro root-fs.

# 5. NFS Boot
Booting via NFS is quite useful for several reasons, but the obvious
reason when working with Raspberry Pi is that you don't have to move the
SD-card back and forth between the host machine and the RPi itself. Below we
will describe how to setup NFS server, so the rootfs can be mounted via NFS.
Note that this guide doesn't focus on any desktop security, 
so eventually you would need to harden your setup. Another thing is that 
this seems like a lot of steps, and it is, but most of them is something you
do once and never more and it will save tons of time in the long run.

Note also, that this particular guide is written for the ARMv8-A setup using
OP-TEE. But, it should work on plain RPi also if you change U-boot and
filesystem accordingly.

In the description below we will use the following terminology:
```
HOST_IP=192.168.1.100   <--- This is your desktop computer
RPI_IP=192.168.1.200    <--- This is the Raspberry Pi
```

## 5.1 Configure NFS
Start by installing the NFS server
```bash
$ sudo apt-get install nfs-kernel-server
```

Then edit the exports file,
```bash
$ sudo vim /etc/exports
```

In this file you shall tell where your files/folder are and the IP's allowed
to access the files. The way it's written below will make it available to every
machine on the same subnet (again, be careful about security here). Let's add
this line to the file (it's the only line necessary in the file, but if you have
several different filesystems available, then you should of course add them too).
```
/srv/nfs/rpi 192.168.1.0/24(rw,sync,no_root_squash,no_subtree_check)
```

Next create the folder
```bash
$ sudo mkdir /srv/nfs/rpi
```

After this, restart the nfs kernel server
```bash
$ service nfs-kernel-server restart
```

## 5.2 Prepare files to be shared.

We are now going to put the root fs on the location we prepared in the previous
section (5.2). The path to the `rootfs.cpio.gz` will differ on your machine,
so update accordingly.

```bash
$ cd /srv/nfs/rpi
$ sudo gunzip -cd /home/jbech/devel/optee_projects/rpi3/out-br/images/rootfs.cpio.gz | sudo cpio -idmv
$ sudo rm -rf /srv/nfs/rpi/boot/*
```

### 5.4 Update uboot.env
There are two ways to update uboot.env. First, you can edit
`build/rpi3/firmware/uboot.env.txt` file, which is used as simple text source for
generation of uboot.env during build and you can just edit u-boot env via UART
and save new values to uboot.env. By using the second way you can avoid rebuilding
and copying uboot.env to SD card.

#### 5.4.1 Edit uboot.env.txt
All you need to do is to edit network configuration in `build/rpi3/firmware/uboot.env.txt`.
You have to change value of `serverip` to the IP address of your NFS server,
`gatewayip` to your router IP address and `nfspath` to the exported path, where root FS
is stored (`/srv/nfs/rpi`). Then you need to generate new `uboot.env`:
```bash
$ cd /home/jbech/devel/optee_projects/rpi3/boot/
# clean previous uboot.env
$ make u-boot-env-clean
# generate new
$ make u-boot-bin
```
Then you need to copy your newly generated `uboot.env`(it's stored in `../out/uboot.env`)
to the BOOT partition of your SD card.

#### 5.4.2 Edit u-boot.env via UART
Start by inserting the UART cable and open up `/dev/ttyUSB0`
```bash
# sudo apt-get install picocom
$ picocom -b 115200 /dev/ttyUSB0
```

Power up the Raspberry Pi and almost immediately hit any key and you should see
the `U-Boot>` prompt. First edit your NFS server IP address:
```
U-Boot> setenv serverip '192.168.1.100'
```
Perform the same steps for `gateway`(your router IP address) and
`nfspath` (the exported path, where root FS is stored, for example `/srv/nfs/rpi`)

If you want those environment variables to persist between boots, then type.
```
U-Boot> saveenv
```

And don't worry about the `FAT: Misaligned buffer address ...` message, it will
still work.

## 5.5 Network boot the RPi
With all preparations done correctly above, you should now be able to boot up
the device and kernel, secure side OP-TEE and the entire root fs should be
loaded from the network shares. Power up the Raspberry, halt in U-Boot and then
type.
```
U-Boot> run nfsboot
```

Profit!

## 5.6 Tricks
If everything works, you can simply copy paste files like xtest, the trusted
applications etc, directly from your build folder to the `/srv/nfs/rpi` folders
after rebuilding them. By doing so you don't have to reboot the device when
doing development and testing. Note that you cannot make symlinks to those like
we did with `Image`, `bcm2710-rpi-3-b.dtb` and `optee.bin`.

## 5.7 Other root filesystems than initramfs based?
The default root filesystem used for OP-TEE development is a simple CPIO archive
used as initramfs. That is small and is good enough for testing and debugging.
But sometimes you want to use a more traditional Linux filesystem, such as those
that are in distros. With such filesystem you can apt-get (if Debian based)
other useful tools, such as gdb on the device, valgrind etc to mention a few. An
example of such a rootfs is a Debian based [Linaro rootfs]. The procedure to use
that filesystem with NFS is the same as for the CPIO based, you need to extract
the files to a folder which is known by the NFS server (use regular `tar -xvf
...` command).

Then you need to copy `xtest` and `tee-supplicant` to `<NFS>/bin/`, copy
`libtee.so*` to `<NFS>/lib/` and copy all `*.ta` files to
`<NFS>/lib/optee_armtz/`. Easiest here is to write a small shell script or add a
target to the makefile which will do this so the files always are up-to-date
after a rebuild.

When that has been done, you can run OP-TEE tests, TA's etc and if you're only
updating files in normal world (the ones just mentioned), then you don't even
need to reboot the RPi after a rebuild.

# 6. OpenOCD and JTAG
First a word of warning here, even though this seems to be working quite good as
of now, it should be well understood that this is based on incomplete and out of
tree patches. There are major changes in our U-Boot fork that add capability to
load and execute ARM Trusted Firmware binary.

To enable JTAG you need to uncomment the line: `enable_jtag_gpio=1` in
`rpi3/firmware/config.txt`.

The pin configuration and the wiring for the cable looks like this:

|JTAG pin|Signal|GPIO   |Mode |Header pin|
|--------|------|-------|-----|----------|
| 1      |3v3   |N/A    |N/A  | 1        |
| 3      |nTRST |GPIO22 |ALT4 | 15       |
| 5      |TDI   |GPIO26 |ALT4 | 37       |
| 7      |TMS   |GPIO27 |ALT4 | 13       |
| 9      |TCK   |GPIO25 |ALT4 | 22       |
| 11     |RTCK  |GPIO23 |ALT4 | 16       |
| 13     |TDO   |GPIO24 |ALT4 | 18       |
| 18     |GND   |N/A    |N/A  | 14       |
| 20     |GND   |N/A    |N/A  | 20       |

Note that this configuration seems to remain in the Raspberry Pi3 setup we're
using. But someone with root access could change the GPIO configuration at any
point in time and thereby disable JTAG functionality.

## 6.1 Debug cable / UART cable
We have created our own cables, get a standard 20-pin JTAG connector and 22-pin
connector for the RPi3 itself, then using a ribbon cable, connect the cables
according to the table in section 6 (JTAG pin <-> Header pin). In addition to
that we have also connected a USB FTDI to UART cable to a few more pins.

|UART pin    |Signal|GPIO   |Mode |Header pin|
|------------|------|-------|-----|----------|
|Black (GND) |GND   |N/A    |N/A  | 6        |
|White (RXD) |TXD   |GPIO14 |ALT0 | 8        |
|Green (TXD) |RXD   |GPIO15 |ALT0 | 10       |

## 6.2 OpenOCD
### 6.2.1 Build the software
Before building OpenOCD, **libusb-dev** package should be installed in advance:
```bash
$ sudo apt-get install libusb-1.0-0-dev
```

We are using the [Official OpenOCD] release, simply clone that to your
computer and then building is like a lot of other software, i.e.,

```bash
$ git clone http://repo.or.cz/openocd.git && cd openocd
$ ./bootstrap
$ ./configure
$ make
```
If a jtag debugger needs legacy ft2332 support, OpenOCD should be
configured with `--enable-legacy-ft2232_libftdi` flag:
```bash
$ ./configure --enable-legacy-ft2232_libftdi
```

We leave it up to the reader of this guide to decide if he wants to install it
properly (`make install`) or if he will just run it from the tree directly. The
rest of this guide will just run it from the tree.

### 6.2.2 OpenOCD RPi3 configuration file
Unfortunately, the necessary [RPi3 OpenOCD config] isn't upstreamed yet into the
[Official OpenOCD] repository, so you should use the one stored
here `rpi3/debugger/pi3.cfg`. As you can read there, it's prepared
for four targets, but only one is enabled. The reason for that is simply
because it's a lot simpler to get started with JTAG when running on a single
core. When you have a stable setup using a single core, then you can start
playing with enabling additional cores.
```
...
target create $_TARGETNAME_0 aarch64 -chain-position $_CHIPNAME.dap -dbgbase 0x80010000 -ctibase 0x80018000
#target create $_TARGETNAME_1 aarch64 -chain-position $_CHIPNAME.dap -dbgbase 0x80012000 -ctibase 0x80019000
#target create $_TARGETNAME_2 aarch64 -chain-position $_CHIPNAME.dap -dbgbase 0x80014000 -ctibase 0x8001a000
#target create $_TARGETNAME_3 aarch64 -chain-position $_CHIPNAME.dap -dbgbase 0x80016000 -ctibase 0x8001b000
...
```
## 6.3 Running OpenOCD
Depending on the JTAG debugger you are using you'll need to find and use the
interface file for that particular debugger. We've been using [J-Link debuggers]
and [Bus Blaster] successfully. To start an OpenOCD session using a J-Link
device you type:
```bash
$ cd <openocd>
$ ./src/openocd -f ./tcl/interface/jlink.cfg \
-f <rpi3_repo_dir>/build/rpi3/debugger/pi3.cfg
```

For Bus Blaster type:
```bash
$ ./src/openocd -f ./tcl/interface/ftdi/dp_busblaster.cfg \
-f <rpi3_repo_dir>/build/rpi3/debugger/pi3.cfg
```

To be able to write commands to OpenOCD, you simply open up another shell and
type:
```bash
$ nc localhost 4444
```

From there you can set breakpoints, examine memory etc ("`> help`" will give you
a list of available commands).

## 6.4 Use GDB
The pi3.cfg file is configured to listen to GDB connections on port 3333. So all
you have to do in GDB after starting OpenOCD is to connect to the target on that
port, i.e.,
```bash
# Ensure that you have gdb in your $PATH
$ aarch64-linux-gnu-gdb -q
(gdb) target remote localhost:3333
```

To load symbols you just use the `symbol-file <path/to/my.elf` as usual. For
convenience you can create an alias in the `~/.gdbinit` file. For TEE core
debugging this works:
```
define jlink_rpi3
  target remote localhost:3333
  symbol-file /home/jbech/devel/optee_projects/rpi3/optee_os/out/arm/core/tee.elf
end
```

So, when running GDB, you simply type: `(gdb) jlink_rpi3` and it will both
connect and load the symbols for TEE core. For Linux kernel and other binaries
you would do the same.

## 6.5 Wrap it all up in a debug session
If you have everything prepared, i.e. a working setup for Raspberry Pi3 and
OP-TEE. You've setup both OpenOCD and GDB according to the instructions, then
you should be good to go. Start by booting up to U-Boot, but stop there. In
there start by disable [SMP] and then continue the boot sequence.
```
U-Boot> setenv smp off
U-Boot> boot
```

When Linux is up and running, start a new shell where you run OpenOCD:
```bash
$ cd <openocd>
$ ./src/openocd -f ./tcl/interface/jlink.cfg -f ./pi3.cfg
```

Start a third shell, where you run GDB
```
$ aarch64-linux-gnu-gdb -q
(gdb) target remote localhost:3333
(gdb) symbol-file /home/jbech/devel/optee_projects/rpi3/optee_os/out/arm/core/tee.elf
```

Next, try to set a breakpoint, here use **hardware** breakpoints!
```
(gdb) hb tee_ta_invoke_command
Hardware assisted breakpoint 1 at 0x842bf98: file core/kernel/tee_ta_manager.c, line 534.
(gdb) c
Continuing.
```

And if you run tee-supplicant and xtest for example, the breakpoint should
trigger and you will see something like this in the GDB window:
```
Breakpoint 1, tee_ta_invoke_command (err=0x84940d4 <stack_thread+7764>,
    err@entry=0x8494104 <stack_thread+7812>, sess=sess@entry=0x847bf20, clnt_id=clnt_id@entry=0x0,
    cancel_req_to=cancel_req_to@entry=0xffffffff, cmd=0x2,
    param=param@entry=0x84940d8 <stack_thread+7768>) at core/kernel/tee_ta_manager.c:534
534     {
```

From here you can debug using normal GDB commands.

## 6.6 Know issues when running the JTAG setup
As mentioned in the beginning, this is based on forks and etc, so it's a moving
targets. Sometime you will see that you loose the connection between GDB and
OpenOCD. If that happens, simply reconnect to the target. Another thing that you
will notice is that if you're running all on a single core, then Linux kernel
will be a bit upset when continue running after triggering a breakpoint in
secure world (rcu starving messages etc). If you have suggestion and or
improvements, as usual, feel free to contribute.

[buildroot]: https://buildroot.org
[Bus Blaster]: http://dangerousprototypes.com/docs/Bus_Blaster
[J-Link debuggers]: https://www.segger.com/jlink_base.html
[Linaro rootfs]: http://releases.linaro.org/debian/images/installer-arm64/latest/linaro*.tar.gz
[LSK OP-TEE 4.4]: https://git.linaro.org/kernel/linux-linaro-stable.git/log/?h=v4.4/topic/optee
[arm64: dt: RPI3: Add optee node]: https://github.com/linaro-swg/linux/commit/cc225a78910c37d78f8a00c80dcbf59ef7762884
[OpenOCD]: http://openocd.org
[OP-TEE prerequisites]: ../README.md#71-prerequisites
[press release]: http://www.sequiturlabs.com/media_portfolio/sequitur-labs-collaborates-with-linaro-to-lower-barriers-to-iot-security-education-for-raspberry-pi-maker-community
[Raspbian]: https://www.raspbian.org
[README.md]: ../README.md
[RPi3 GPIO pins]: https://pinout.xyz/pinout/jtag
[RPi3 OpenOCD config]: https://github.com/OP-TEE/build/blob/master/rpi3/debugger/pi3.cfg
[Official OpenOCD]: http://openocd.org/
[Sequitur Labs]: http://www.sequiturlabs.com
[SMP]: https://en.wikipedia.org/wiki/Symmetric_multiprocessing
[xtest instructions]: https://github.com/OP-TEE/build#78-load-tee-supplicant
