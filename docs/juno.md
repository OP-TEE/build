# OP-TEE on Juno

# Contents
1. [Introduction](#1-introduction)
2. [Regular build](#2-regular-build)
3. [Install files on the device](#3-install-files-on-the-device)

# 1. Introduction
The instructions here will tell how to run OP-TEE on the Juno board.

# 2. Regular build
Start out by following the "Get and build the solution" in the [README.md] file.

# 3. Install files on the device
Enter the firmware console on the juno board and press enter to stop the auto
boot flow
```
ARM V2M_Juno Firmware v1.3.9
Build Date: Nov 11 2015

Time :  12:50:45
Date :  29:03:2016

Press Enter to stop auto boot...

```
Enable ftp at the firmware prompt
```
Cmd> ftp_on
Enabling ftp server...
 MAC address: xxxxxxxxxxxx

 IP address: 192.168.1.158

 Local host name = V2M-JUNO-A2
```

Flash the binary by running (note the IP address from above):
```
make JUNO_IP=192.168.1.158 flash
```

Once the binaries are transferred, reboot the board:
```
Cmd> reboot

```

## 3.1 Update flash and its layout
The flash in the board may need to be updated for the flashing above to
work.  If the flashing fails or if ARM-TF refuses to boot due to wrong
version of the SCP binary the flash needs to be updated. To update the
flash please follow the instructions at [Using Linaro's deliverable on
Juno](https://community.arm.com/docs/DOC-10804) selecting one of the zips
under "4.1 Prebuilt configurations" flashing it as described under "5.
Running the software".

## 3.2 GlobalPlatform testsuite support
**Note!**
Depending on the Juno pre-built configuration, the built ramdisk.img
size with GlobalPlatform testsuite may exceed its pre-defined Juno flash
memory reserved location (image.txt file).
In that case, you will need to extend the Juno flash block size reserved
location for the ramdisk.img in the image.txt file accordingly and
follow the instructions under "5.7.1 Update flash and its layout".

**Example with juno-latest-busybox-uboot.zip:**

The current ramdisk.img size with GlobalPlatform testsuite is 8.6 MBytes.

###### Updated file is /JUNO/SITE1/HBI0262B/images.txt (limited to 8.3 MB)
```
NOR4UPDATE: AUTO                 ;Image Update:NONE/AUTO/FORCE
NOR4ADDRESS: 0x01800000          ;Image Flash Address
NOR4FILE: \SOFTWARE\ramdisk.img  ;Image File Name
NOR4NAME: ramdisk.img
NOR4LOAD: 00000000               ;Image Load Address
NOR4ENTRY: 00000000              ;Image Entry Point
```

###### Extended to 16MB
```
NOR4UPDATE: AUTO                 ;Image Update:NONE/AUTO/FORCE
NOR4ADDRESS: 0x01000000          ;Image Flash Address
NOR4FILE: \SOFTWARE\ramdisk.img  ;Image File Name
NOR4NAME: ramdisk.img
NOR4LOAD: 00000000               ;Image Load Address
NOR4ENTRY: 00000000              ;Image Entry Point
```

## 3.3 GCC5.x support
##### Note :
In case you are using the **Latest version** of the ARM Juno board (this is
`juno.xml` manifest), the built `ramdisk.img` size with GCC5 compiler, at the
moment, exceeds its pre-defined Juno flash memory reserved location (`image.txt`
file).

To solve this problem you will need to extend the Juno flash block size reserved
location for the `ramdisk.img` and decrease the size for other images in the
`image.txt` file accordingly and then follow the instructions under "3.2" above.

##### Example with juno-latest-busybox-uboot.zip:
The current `ramdisk.img` size with GCC5 compiler is 29.15 MBytes we will
extend it to  32 MBytes. The only changes that you need to do are those in
**bold**

###### File to update is /JUNO/SITE1/HBI0262B/images.txt
```
NOR2UPDATE: AUTO                 ;Image Update:NONE/AUTO/FORCE
NOR2ADDRESS: <b>0x00100000</b>          ;Image Flash Address
NOR2FILE: \SOFTWARE\Image        ;Image File Name
NOR2NAME: norkern                ;Rename kernel to norkern
NOR2LOAD: 00000000               ;Image Load Address
NOR2ENTRY: 00000000              ;Image Entry Point

NOR3UPDATE: AUTO                 ;Image Update:NONE/AUTO/FORCE
NOR3ADDRESS: <b>0x02C00000</b>          ;Image Flash Address
NOR3FILE: \SOFTWARE\juno.dtb     ;Image File Name
NOR3NAME: board.dtb              ;Specify target filename to preserve file extension
NOR3LOAD: 00000000               ;Image Load Address
NOR3ENTRY: 00000000              ;Image Entry Point

NOR4UPDATE: AUTO                 ;Image Update:NONE/AUTO/FORCE
NOR4ADDRESS: <b>0x00D00000</b>          ;Image Flash Address
NOR4FILE: \SOFTWARE\ramdisk.img  ;Image File Name
NOR4NAME: ramdisk.img
NOR4LOAD: 00000000               ;Image Load Address
NOR4ENTRY: 00000000              ;Image Entry Point

NOR5UPDATE: AUTO                 ;Image Update:NONE/AUTO/FORCE
NOR5ADDRESS: <b>0x02D00000</b>          ;Image Flash Address
NOR5FILE: \SOFTWARE\hdlcdclk.dat ;Image File Name
NOR5LOAD: 00000000               ;Image Load Address
NOR5ENTRY: 00000000              ;Image Entry Point
```

[README.md]: ../README.md
