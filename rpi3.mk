################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER    := 64
override COMPILE_S_KERNEL  := 64

# Need to set this before including common.mk
BR2_TARGET_GENERIC_GETTY_PORT ?= ttyS0
BR2_ROOTFS_POST_BUILD_SCRIPT ?= "board/raspberrypi3-64/post-build.sh"

# Network support related packages:
BR2_PACKAGE_DHCPCD ?= y
BR2_PACKAGE_ETHTOOL ?= y
BR2_PACKAGE_XINETD ?= y

# SSH Packages :
BR2_PACKAGE_OPENSSH ?= y
BR2_PACKAGE_OPENSSH_SERVER ?= y
BR2_PACKAGE_OPENSSH_KEY_UTILS ?= y

OPTEE_OS_PLATFORM = rpi3

include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
TF_A_PATH		?= $(ROOT)/trusted-firmware-a
TF_A_OUT		?= $(TF_A_PATH)/build/rpi3/debug
TF_A_BOOT		?= $(TF_A_OUT)/armstub8.bin

OPTEE_PATH		?= $(ROOT)/optee_os
U-BOOT_PATH		?= $(ROOT)/u-boot
U-BOOT_BIN		?= $(U-BOOT_PATH)/u-boot.bin

RPI3_FIRMWARE_PATH	?= $(BUILD_PATH)/rpi3/firmware
RPI3_HEAD_BIN		?= $(ROOT)/out/head.bin
RPI3_BOOT_CONFIG	?= $(RPI3_FIRMWARE_PATH)/config.txt
RPI3_UBOOT_ENV		?= $(ROOT)/out/uboot.env
RPI3_UBOOT_ENV_TXT	?= $(RPI3_FIRMWARE_PATH)/uboot.env.txt
RPI3_STOCK_FW_PATH	?= $(ROOT)/firmware
RPI3_STOCK_FW_PATH_BOOT	?= $(RPI3_STOCK_FW_PATH)/boot
OPTEE_BIN		?= $(OPTEE_PATH)/out/arm/core/tee-header_v2.bin
OPTEE_BIN_EXTRA1	?= $(OPTEE_PATH)/out/arm/core/tee-pager_v2.bin
OPTEE_BIN_EXTRA2	?= $(OPTEE_PATH)/out/arm/core/tee-pageable_v2.bin

LINUX_IMAGE		?= $(LINUX_PATH)/arch/arm64/boot/Image
LINUX_DTB_RPI3_B	?= $(LINUX_PATH)/arch/arm64/boot/dts/broadcom/bcm2710-rpi-3-b.dtb
LINUX_DTB_RPI3_BPLUS	?= $(LINUX_PATH)/arch/arm64/boot/dts/broadcom/bcm2710-rpi-3-b-plus.dtb
MODULE_OUTPUT		?= $(ROOT)/module_output

################################################################################
# Targets
################################################################################
all: arm-tf buildroot optee-os u-boot linux update_rootfs
clean: arm-tf-clean buildroot-clean u-boot-clean \
	optee-os-clean

include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
TF_A_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

TF_A_FLAGS ?= \
	NEED_BL32=yes \
	BL32=$(OPTEE_BIN) \
	BL32_EXTRA1=$(OPTEE_BIN_EXTRA1) \
	BL32_EXTRA2=$(OPTEE_BIN_EXTRA2) \
	BL33=$(U-BOOT_BIN) \
	DEBUG=1 \
	V=0 \
	CRASH_REPORTING=1 \
	LOG_LEVEL=40 \
	PLAT=rpi3 \
	RPI3_PRELOADED_DTB_BASE=0x00010000 \
	SPD=opteed

arm-tf: optee-os u-boot-env
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) all fip

arm-tf-clean:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) clean

################################################################################
# Das U-Boot
################################################################################
U-BOOT_EXPORTS ?= CROSS_COMPILE=$(AARCH64_CROSS_COMPILE) ARCH=arm64
U-BOOT_DEFCONFIG_COMMON_FILES := \
		$(U-BOOT_PATH)/configs/rpi_3_defconfig \
		$(CURDIR)/kconfigs/u-boot_rpi3.conf

.PHONY: u-boot
u-boot: u-boot-defconfig
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) all
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) tools

u-boot-clean: u-boot-defconfig-clean
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean

u-boot-env: $(RPI3_UBOOT_ENV_TXT) u-boot
	mkdir -p $(ROOT)/out
	$(U-BOOT_PATH)/tools/mkenvimage -s 0x4000 -o $(RPI3_UBOOT_ENV) \
		$(RPI3_UBOOT_ENV_TXT)

u-boot-env-clean:
	rm -f $(RPI3_UBOOT_ENV)

u-boot-defconfig: $(U-BOOT_DEFCONFIG_COMMON_FILES)
	cd $(U-BOOT_PATH) && \
		ARCH=arm64 \
		scripts/kconfig/merge_config.sh $(U-BOOT_DEFCONFIG_COMMON_FILES)

.PHONY: u-boot-defconfig-clean
u-boot-defconfig-clean:
	rm -f $(U-BOOT_PATH)/.config

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm64/configs/bcmrpi3_defconfig \
		$(CURDIR)/kconfigs/rpi3.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64

linux: linux-common
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS) INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$(MODULE_OUTPUT) modules_install

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

linux-cleaner: linux-cleaner-common

################################################################################
# OP-TEE
################################################################################
optee-os: optee-os-common
optee-os-clean: optee-os-clean-common

################################################################################
# Root FS
################################################################################
.PHONY: update_rootfs
# Make sure this is built before the buildroot target which will create the
# root file system based on what's in $(BUILDROOT_TARGET_ROOT)
buildroot: update_rootfs
update_rootfs: arm-tf linux u-boot
	@mkdir -p --mode=755 $(BUILDROOT_TARGET_ROOT)/boot
	@mkdir -p --mode=755 $(BUILDROOT_TARGET_ROOT)/usr/bin
	@install -v -p --mode=755 $(LINUX_DTB_RPI3_B) $(BUILDROOT_TARGET_ROOT)/boot/bcm2710-rpi-3-b.dtb
	@install -v -p --mode=755 $(LINUX_DTB_RPI3_BPLUS) $(BUILDROOT_TARGET_ROOT)/boot/bcm2710-rpi-3-b-plus.dtb
	@install -v -p --mode=755 $(RPI3_BOOT_CONFIG) $(BUILDROOT_TARGET_ROOT)/boot/config.txt
	@install -v -p --mode=755 $(LINUX_IMAGE) $(BUILDROOT_TARGET_ROOT)/boot/kernel8.img
	@install -v -p --mode=755 $(TF_A_BOOT) $(BUILDROOT_TARGET_ROOT)/boot/armstub8.bin
	@install -v -p --mode=755 $(RPI3_UBOOT_ENV) $(BUILDROOT_TARGET_ROOT)/boot/uboot.env
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/bootcode.bin $(BUILDROOT_TARGET_ROOT)/boot/bootcode.bin
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/COPYING.linux $(BUILDROOT_TARGET_ROOT)/boot/COPYING.linux
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/fixup_cd.dat $(BUILDROOT_TARGET_ROOT)/boot/fixup_cd.dat
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/fixup.dat $(BUILDROOT_TARGET_ROOT)/boot/fixup.dat
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/fixup_db.dat $(BUILDROOT_TARGET_ROOT)/boot/fixup_db.dat
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/fixup_x.dat $(BUILDROOT_TARGET_ROOT)/boot/fixup_x.dat
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/LICENCE.broadcom $(BUILDROOT_TARGET_ROOT)/boot/LICENCE.broadcom
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/start_cd.elf $(BUILDROOT_TARGET_ROOT)/boot/start_cd.elf
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/start_db.elf $(BUILDROOT_TARGET_ROOT)/boot/start_db.elf
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/start.elf $(BUILDROOT_TARGET_ROOT)/boot/start.elf
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/start_x.elf $(BUILDROOT_TARGET_ROOT)/boot/start_x.elf
	@cd $(MODULE_OUTPUT) && find . | cpio -pudm $(BUILDROOT_TARGET_ROOT)

# Creating images etc, could wipe out a drive on the system, therefore we don't
# want to automate that in script or make target. Instead we just simply provide
# the steps here.
.PHONY: img-help
img-help:
	@echo "$$ fdisk /dev/sdx   # where sdx is the name of your sd-card"
	@echo "   > p             # prints partition table"
	@echo "   > d             # repeat until all partitions are deleted"
	@echo "   > n             # create a new partition"
	@echo "   > p             # create primary"
	@echo "   > 1             # make it the first partition"
	@echo "   > <enter>       # use the default sector"
	@echo "   > +64M          # create a boot partition with 64MB of space"
	@echo "   > n             # create rootfs partition"
	@echo "   > p"
	@echo "   > 2"
	@echo "   > <enter>"
	@echo "   > <enter>       # fill the remaining disk, adjust size to fit your needs"
	@echo "   > t             # change partition type"
	@echo "   > 1             # select first partition"
	@echo "   > e             # use type 'e' (FAT16)"
	@echo "   > a             # make partition bootable"
	@echo "   > 1             # select first partition"
	@echo "   > p             # double check everything looks right"
	@echo "   > w             # write partition table to disk."
	@echo ""
	@echo "run the following as root"
	@echo "   $$ mkfs.vfat -F16 -n BOOT /dev/sdx1"
	@echo "   $$ mkdir -p /media/boot"
	@echo "   $$ mount /dev/sdx1 /media/boot"
	@echo "   $$ cd /media"
	@echo "   $$ gunzip -cd $(ROOT)/out-br/images/rootfs.cpio.gz | sudo cpio -idmv \"boot/*\""
	@echo "   $$ umount boot"
	@echo ""
	@echo "run the following as root"
	@echo "   $$ mkfs.ext4 -L rootfs /dev/sdx2"
	@echo "   $$ mkdir -p /media/rootfs"
	@echo "   $$ mount /dev/sdx2 /media/rootfs"
	@echo "   $$ cd rootfs"
	@echo "   $$ gunzip -cd $(ROOT)/out-br/images/rootfs.cpio.gz | sudo cpio -idmv"
	@echo "   $$ rm -rf /media/rootfs/boot/*"
	@echo "   $$ cd .. && umount rootfs"
