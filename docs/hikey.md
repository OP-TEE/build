# OP-TEE on HiKey

# Contents
1. [Introduction](#1-introduction)
2. [Multiple sources for HiKey and OP-TEE instructions?](#2-multiple-sources-for-hikey-and-op-tee-instructions)
3. [Supported HiKey boards?](#3-supported-hikey-boards)
4. [Regular build](#4-regular-build)
5. [Recovery](#5-recovery)

# 1. Introduction
The instructions here will tell how to run OP-TEE on [HiKey 6220].

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

# 5. Recovery
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
[HiKey 6220]: https://www.96boards.org/product/hikey/
