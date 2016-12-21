arch=arm
atf_load_addr=0x08400000
baudrate=115200
board=rpi
board_name=3 Model B
board_rev=0x8
board_rev_scheme=1
board_revision=0xA02082
boot_a_script=load ${devtype} ${devnum}:${distro_bootpart} ${scriptaddr} ${prefix}${script}; source ${scriptaddr}
boot_efi_binary=load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} efi/boot/bootaa64.efi; bootefi ${kernel_addr_r}
boot_extlinux=sysboot ${devtype} ${devnum}:${distro_bootpart} any ${scriptaddr} ${prefix}extlinux/extlinux.conf
boot_it=booti ${kernel_addr_r} - ${fdt_addr_r}
boot_net_usb_start=usb start
boot_prefixes=/ /boot/
boot_script_dhcp=boot.scr.uimg
boot_scripts=boot.scr.uimg boot.scr
boot_targets=mmc0 usb0 pxe dhcp
bootargs=console=ttyS0,115200 root=/dev/mmcblk0p2 rw rootfs=ext4 ignore_loglevel dma.dmachans=0x7f35 rootwait 8250.nr_uarts=1 elevator=deadline fsck.repair=yes smsc95xx.macaddr=@MAC@ bcm2708_fb.fbwidth=1920 bcm2708_fb.fbheight=1080 vc_mem.mem_base=0x3dc00000 vc_mem.mem_size=0x3f000000
bootcmd=run load_kernel ; run load_dtb; run load_firmware; run set_bootargs; run boot_it
bootcmd_dhcp=run boot_net_usb_start; if dhcp ${scriptaddr} ${boot_script_dhcp}; then source ${scriptaddr}; fi
bootcmd_mmc0=setenv devnum 0; run mmc_boot
bootcmd_pxe=run boot_net_usb_start; dhcp; if pxe get; then pxe boot; fi
bootcmd_usb0=setenv devnum 0; run usb_boot
bootdelay=1
bootfile=192.168.1.236:optee.bin
cpu=armv8
dhcpuboot=usb start; dhcp u-boot.uimg; bootm
distro_bootcmd=for target in ${boot_targets}; do run bootcmd_${target}; done
dnsip=192.168.1.1
efi_dtb_prefixes=/ /dtb/ /dtb/current/
ethact=sms0
ethaddr=@MAC@
fdt_addr_r=0x1700000
fdt_high=ffffffff
fdtfile=bcm2710-rpi-3-b.dtb
fileaddr=8400000
filesize=5a65c
gatewayip=192.168.1.1
initrd_high=ffffffff
ipaddr=192.168.1.158
kernel_addr_r=0x10000000
load_dtb=fatload mmc 0:1 ${fdt_addr_r} ${fdtfile}
load_efi_dtb=load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} ${prefix}${fdtfile}; fdt addr ${fdt_addr_r}
load_firmware=fatload mmc 0:1 $atf_load_addr optee.bin
load_kernel=fatload mmc 0:1 ${kernel_addr_r} Image
loadaddr=0x00200000
mmc_boot=if mmc dev ${devnum}; then setenv devtype mmc; run scan_dev_for_boot_part; fi
netmask=255.255.255.0
optee=usb start; dhcp ${kernel_addr_r} 192.168.1.236:Image; run load_dtb; dhcp ${atf_load_addr} 192.168.1.236:optee.bin;  run boot_it
preboot=usb start
pxefile_addr_r=0x00100000
ramdisk_addr_r=0x02100000
saved_bootcmd=run distro_bootcmd
scan_dev_for_boot=echo Scanning ${devtype} ${devnum}:${distro_bootpart}...; for prefix in ${boot_prefixes}; do run scan_dev_for_extlinux; run scan_dev_for_scripts; done;run scan_dev_for_efi;
scan_dev_for_boot_part=part list ${devtype} ${devnum} -bootable devplist; env exists devplist || setenv devplist 1; for distro_bootpart in ${devplist}; do if fstype ${devtype} ${devnum}:${distro_bootpart} bootfstype; then run scan_dev_for_boot; fi; done
scan_dev_for_efi=for prefix in ${efi_dtb_prefixes}; do if test -e ${devtype} ${devnum}:${distro_bootpart} ${prefix}${fdtfile}; then run load_efi_dtb; fi;done;if test -e ${devtype} ${devnum}:${distro_bootpart} efi/boot/bootaa64.efi; then echo Found EFI removable media binary efi/boot/bootaa64.efi; run boot_efi_binary; echo EFI LOAD FAILED: continuing...; fi;
scan_dev_for_extlinux=if test -e ${devtype} ${devnum}:${distro_bootpart} ${prefix}extlinux/extlinux.conf; then echo Found ${prefix}extlinux/extlinux.conf; run boot_extlinux; echo SCRIPT FAILED: continuing...; fi
scan_dev_for_scripts=for script in ${boot_scripts}; do if test -e ${devtype} ${devnum}:${distro_bootpart} ${prefix}${script}; then echo Found U-Boot script ${prefix}${script}; run boot_a_script; echo SCRIPT FAILED: continuing...; fi; done
scriptaddr=0x02000000
serial#=@SERIAL@
serverip=192.168.1.1
smp=on
soc=bcm283x
stderr=serial,lcd
stdin=serial,usbkbd
stdout=serial,lcd
tee_load_addr=0x08420000
usb_boot=usb start; if usb dev ${devnum}; then setenv devtype usb; run scan_dev_for_boot_part; fi
usbethaddr=@MAC@
vendor=raspberrypi
