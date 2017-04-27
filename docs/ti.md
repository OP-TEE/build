# OP-TEE on Texas Instruments SoCs

# Contents
1. [Introduction](#1-introduction)
2. [Regular build](#2-regular-build)
3. [Booting the device](#3-booting-the-device)

# 1. Introduction
The instructions here will tell how to run OP-TEE on Texas Instruments
devices. Secure TI devices require a boot image that is authenticated by ROM
code to function. Without this, even JTAG remains locked. In order to create
a valid boot image for a secure device from TI, the initial public software
image must be signed and combined with various headers, certificates, and
other binary images.

Information on the details on the complete boot image format can be obtained
from Texas Instruments. The tools used to generate boot images for secure
devices are part of a secure development package (SECDEV) that can be
downloaded from:

	http://www.ti.com/mysecuresoftware (login required)

The secure development package is access controlled due to NDA and export
control restrictions. Access must be requested and granted by TI before the
package is viewable and downloadable. Contact TI, either online or by way
of a local TI representative, to request access.

# 2. Regular build
Start out by following the "Get and build the solution" in the [README.md] file.
Stop before the section on flashing the device, this is currently not supported
automatically.

# 3. Booting the device

## 3.1 SD Card boot

Create two partitions on an SD card, 'boot' of type FAT16 and 'rootfs' of type
EXT4. To prevent accidental data loss we do not attempt this automatically, the
RPI3 instructions use a similar SD card layout, you can refer to that page for
details.

Extract the generated rootfs to the 'rootfs' partition
```
# cd <SD card rootfs partition>
# gunzip -cd <repo directory>/gen_rootfs/filesystem.cpio.gz | sudo cpio -idm
```

Add the bootloader to the 'boot' partition
```
# cd <SD card boot partition>
# cp <repo directory>/u-boot/u-boot-spl_HS_MLO MLO
# cp <repo directory>/u-boot/u-boot_HS.img u-boot.img
```

[README.md]: ../README.md
