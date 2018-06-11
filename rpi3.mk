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
BUILDROOT_GETTY_PORT ?= ttyS0

include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
ARM_TF_PATH		?= $(ROOT)/arm-trusted-firmware
ARM_TF_OUT		?= $(ARM_TF_PATH)/build/rpi3/debug
ARM_TF_BIN		?= $(ARM_TF_OUT)/bl31.bin
ARM_TF_TMP		?= $(ARM_TF_OUT)/bl31.tmp
ARM_TF_HEAD		?= $(ARM_TF_OUT)/bl31.head
ARM_TF_BOOT             ?= $(ARM_TF_OUT)/optee.bin

U-BOOT_PATH		?= $(ROOT)/u-boot
U-BOOT_BIN		?= $(U-BOOT_PATH)/u-boot.bin
U-BOOT_RPI_BIN		?= $(U-BOOT_PATH)/u-boot-rpi.bin

RPI3_FIRMWARE_PATH	?= $(BUILD_PATH)/rpi3/firmware
RPI3_HEAD_BIN		?= $(ROOT)/out/head.bin
RPI3_BOOT_CONFIG	?= $(RPI3_FIRMWARE_PATH)/config.txt
RPI3_UBOOT_ENV		?= $(ROOT)/out/uboot.env
RPI3_UBOOT_ENV_TXT	?= $(RPI3_FIRMWARE_PATH)/uboot.env.txt
RPI3_STOCK_FW_PATH	?= $(ROOT)/firmware
RPI3_STOCK_FW_PATH_BOOT	?= $(RPI3_STOCK_FW_PATH)/boot
OPTEE_OS_PAGER		?= $(OPTEE_OS_PATH)/out/arm/core/tee-pager.bin

LINUX_IMAGE		?= $(LINUX_PATH)/arch/arm64/boot/Image
LINUX_DTB		?= $(LINUX_PATH)/arch/arm64/boot/dts/broadcom/bcm2710-rpi-3-b.dtb
MODULE_OUTPUT		?= $(ROOT)/module_output

################################################################################
# Targets
################################################################################
all: arm-tf buildroot optee-os u-boot u-boot-rpi-bin \
	linux update_rootfs
clean: arm-tf-clean buildroot-clean u-boot-clean u-boot-rpi-bin-clean \
	optee-os-clean head-bin-clean

include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
ARM_TF_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

ARM_TF_FLAGS ?= \
	BL32=$(OPTEE_OS_BIN) \
	DEBUG=1 \
	V=0 \
	CRASH_REPORTING=1 \
	LOG_LEVEL=40 \
	PLAT=rpi3 \
	SPD=opteed

arm-tf: optee-os
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) all
	cd $(ARM_TF_OUT) && \
	  dd if=/dev/zero of=scratch bs=1c count=131072 && \
	  cat $(ARM_TF_BIN) scratch > $(ARM_TF_TMP) && \
	  dd if=$(ARM_TF_TMP) of=$(ARM_TF_HEAD) bs=1c count=131072 && \
	  cat $(ARM_TF_HEAD) $(OPTEE_OS_PAGER) > $(ARM_TF_BOOT) && \
	  rm scratch $(ARM_TF_TMP) $(ARM_TF_HEAD)

arm-tf-clean:
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) clean

################################################################################
# Das U-Boot
################################################################################

U-BOOT_EXPORTS ?= CROSS_COMPILE=$(AARCH64_CROSS_COMPILE) ARCH=arm64

.PHONY: u-boot
u-boot: $(RPI3_HEAD_BIN)
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) rpi_3_defconfig
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) all
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) tools

u-boot-clean:
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean

u-boot-rpi-bin: $(RPI3_UBOOT_ENV) u-boot
	cd $(U-BOOT_PATH) && cat $(RPI3_HEAD_BIN) $(U-BOOT_BIN) > $(U-BOOT_RPI_BIN)

u-boot-rpi-bin-clean:
	rm -f $(U-BOOT_RPI_BIN)

$(RPI3_HEAD_BIN): $(RPI3_FIRMWARE_PATH)/head.S
	mkdir -p $(ROOT)/out/
	$(AARCH64_CROSS_COMPILE)as $< -o $(ROOT)/out/head.o
	$(AARCH64_CROSS_COMPILE)objcopy -O binary $(ROOT)/out/head.o $@

head-bin-clean:
	rm -f $(RPI3_HEAD_BIN) $(ROOT)/out/head.o

$(RPI3_UBOOT_ENV): $(RPI3_UBOOT_ENV_TXT) u-boot
	mkdir -p $(ROOT)/out
	$(U-BOOT_PATH)/tools/mkenvimage -s 0x4000 -o $(ROOT)/out/uboot.env $(RPI3_UBOOT_ENV_TXT)

u-boot-env-clean:
	rm -f $(RPI3_UBOOT_ENV)

################################################################################
# Busybox
################################################################################
BUSYBOX_COMMON_TARGET = rpi3
BUSYBOX_CLEAN_COMMON_TARGET = rpi3 clean

busybox: busybox-common

busybox-clean: busybox-clean-common

busybox-cleaner: busybox-cleaner-common
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
OPTEE_OS_COMMON_FLAGS += PLATFORM=rpi3
optee-os: optee-os-common

OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=rpi3
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
	@install -v -p --mode=755 $(LINUX_DTB) $(BUILDROOT_TARGET_ROOT)/boot/bcm2710-rpi-3-b.dtb
	@install -v -p --mode=755 $(RPI3_BOOT_CONFIG) $(BUILDROOT_TARGET_ROOT)/boot/config.txt
	@install -v -p --mode=755 $(LINUX_IMAGE) $(BUILDROOT_TARGET_ROOT)/boot/Image
	@install -v -p --mode=755 $(ARM_TF_BOOT) $(BUILDROOT_TARGET_ROOT)/boot/optee.bin
	@install -v -p --mode=755 $(RPI3_UBOOT_ENV) $(BUILDROOT_TARGET_ROOT)/boot/uboot.env
	@install -v -p --mode=755 $(U-BOOT_RPI_BIN) $(BUILDROOT_TARGET_ROOT)/boot/u-boot-rpi.bin
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
	@echo "   > +32M          # create a boot partition with 32MB of space"
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
