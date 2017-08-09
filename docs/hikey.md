# OP-TEE on HiKey

# Contents
1. [Introduction](#1-introduction)
2. [Multiple sources for HiKey and OP-TEE instructions?](#2-multiple-sources-for-hikey-and-op-tee-instructions)
3. [Supported HiKey boards?](#3-supported-hikey-boards)
4. [Regular build](#4-regular-build)
5. [Debian based build](#5-debian-based-build)
6. [Recovery](#6-recovery)

# 1. Introduction
The instructions here will tell how to run OP-TEE on HiKey. We have two variants
that we support. One is the regular build as described in the [README.md] file.
The other is a Debian based build.

# 2. Multiple sources for HiKey and OP-TEE instructions?
First you must understand that HiKey project as such is led by the 96Boards
project. So, if you **aren't** interested in running OP-TEE on the device, then
you should stop reading here and instead have a look at the [official HiKey
documentation].

For OP-TEE using HiKey you will still find information in more than one place.
There are a couple of reasons for that.
* **96Boards**: The official 96Boards project used to host some OP-TEE
  instructions and they include OP-TEE in their official releases.
* **Google**: has an [AOSP HiKey branch], where OP-TEE is supported to some extent.
* **Linaro-SWG**: The OP-TEE team has done some work related to AOSP
    ([OP-TEE Android Manifest]) and there HiKey has been the device in use.

If you have questions regarding the configurations above, please reach out to
the people on the right forum (96Boards, Google and Linaro-SWG).

This particular guide is maintained by the OP-TEE team and this is what we use
when we are doing are stable releases. I.e, for OP-TEE this should be considered
as a well maintained guide with a fully working setup.

# 3. Supported HiKey boards?
There are four different versions of the HiKey board.

| Name | Manufacturer | Memory | Flash | Comment |
|------|--------------|--------|-------|---------|
| HiKey | CircuitCo | 1GB | 4GB | Green solder mask |
| HiKey | LeMaker | 1GB | 8GB | Black solder mask |
| HiKey | LeMaker | 2GB | 8GB | Black solder mask |

All of them works, but where differences apply we have default configurations
that works for the LeMaker 8GB eMMC versions.

## 3.1 UART adapter board
Everything is configured to use the [96Boards UART Adapter Board]. The UART is
by default configured to UART3. If you don't have any UART adapter board and
instead would like to use UART0, then you need to change that before building.
See `CFG_NW_CONSOLE_UART` and `CFG_NW_CONSOLE_UART` in [hikey.mk].

# 4. Regular build
Just follow the "Get and build the solution" in the [README.md] file. The `make
flash` step will tell you how you should set the jumpers on the board.

# 5. Debian based build
The intention here was to do almost the same kind of build as the regular where
the big difference is the kernel in use and the rootfs. The kernel currently
comes from the 96Boards team, but that might change soon again. The rootfs is
Debian based.

In the rootfs OP-TEE binaries can be installed via `apt`. After building the
solution one must replace those, since they can be a bit dated (see below about
how to dpkg force install a couple of OP-TEE Debian packages).

## 5.1 Building the OP-TEE Debian based setup
Do the same as the regular build (of course you should use the Debian based
manifest file).

Next, the `make flash` step will tell you how you should set the jumpers on the
board and how to flash the device.

**NOTE**: There have been reports of some boards stalling or getting stuck in
`make flash` when flashing `SYSTEM_IMG`, i.e. the command does not complete
after more than 5 minutes. If that happens, please try running `make recovery`
instead.

Now you can boot up the device, note that the **up-to-date** OP-TEE normal world
binaries still hasn't been put on the device at this stage. So by now you're
basically booting up an RPB build. When you have a prompt, the next step is to
connect the device to the network. WiFi is preferable, since HiKey has no
Ethernet jack. Easiest is to edit `/etc/network/interfaces`. To find out what to
add, run:
```
$ make help
```

When that's been added, reboot and when you have a prompt again, you're ready to
push the OP-TEE client binaries and the kernel with OP-TEE support. First find
out the IP for your device (`ifconfig`). Then send the files to HiKey by
running:
```bash
$ IP=111.222.333.444 make send

Credentials for the image are:
username: linaro
password: linaro
```

When the files has been transfered, please follow the commands from the `make
send` command which will install the debian packages on the device. Typically it
tells you to run something like this on the device itself:
```bash
$ dpkg --force-all -i /tmp/out/*.deb
$ dpkg --force-all -i /tmp/linux-image-*.deb
```
## 5.2 Good to know
Just want to update secure side? Put the device in fastboot mode and
```bash
$ make arm-tf
$ make flash-fip

```

Just want to update OP-TEE client software? Put the device in fastboot mode and
```bash
$ make optee-client
$ make xtest
```

Boot up the device and follow the instructions from make send
```bash
$ IP=111.222.333.444 make send
```

# 6. Recovery
If you manage to corrupt the device, so that fastboot doesn't load automatically
on boot, then you will need to run the recovery procedure. Basically what you
will need to do is use another make target and change some jumpers. All that is
described when you run the target:
```bash
$ make recovery
```

[AOSP HiKey branch]: https://source.android.com/source/devices.html
[official HiKey documentation]: http://www.96boards.org/documentation/ConsumerEdition/HiKey/README.md
[OP-TEE Android Manifest]: https://github.com/linaro-swg/optee_android_manifest
[README.md]: ../README.md
[hikey.mk]: https://github.com/OP-TEE/build/blob/master/hikey.mk
[96Boards UART Adapter Board]: http://www.96boards.org/product/uarts
