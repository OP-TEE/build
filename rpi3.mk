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

# Required tools to create the SD image
BR2_PACKAGE_HOST_GENIMAGE=y

# We need the ext2/4 image to be generated, so we will be able to copy that
# directly into a parition on the image.
BR2_TARGET_ROOTFS_EXT2=y
BR2_TARGET_ROOTFS_EXT2_4=y
BR2_TARGET_ROOTFS_EXT2_SIZE="256M"

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
RPI3_BOOT_CONFIG	?= $(RPI3_FIRMWARE_PATH)/config.txt
RPI3_UBOOT_ENV		?= $(ROOT)/out/uboot.env
RPI3_UBOOT_ENV_TXT	?= $(RPI3_FIRMWARE_PATH)/uboot.env.txt
RPI3_STOCK_FW_PATH	?= $(ROOT)/firmware
RPI3_STOCK_FW_PATH_BOOT	?= $(RPI3_STOCK_FW_PATH)/boot
OPTEE_BIN		?= $(OPTEE_PATH)/out/arm/core/tee-header_v2.bin
OPTEE_BIN_EXTRA1	?= $(OPTEE_PATH)/out/arm/core/tee-pager_v2.bin
OPTEE_BIN_EXTRA2	?= $(OPTEE_PATH)/out/arm/core/tee-pageable_v2.bin
BOOT_PARTITION_FILES	?= $(ROOT)/out/boot
CREATE_IMAGE		?= $(BUILD_PATH)/rpi3/scripts/create-image.sh

LINUX_IMAGE		?= $(LINUX_PATH)/arch/arm64/boot/Image
LINUX_DTB_RPI3_B	?= $(LINUX_PATH)/arch/arm64/boot/dts/broadcom/bcm2710-rpi-3-b.dtb
LINUX_DTB_RPI3_BPLUS	?= $(LINUX_PATH)/arch/arm64/boot/dts/broadcom/bcm2710-rpi-3-b-plus.dtb
MODULE_OUTPUT		?= $(ROOT)/module_output

################################################################################
# Targets
################################################################################
all: tf-a buildroot optee-os u-boot linux update_bootfs update_rootfs \
	sdcard-image

clean: tf-a-clean buildroot-clean u-boot-clean optee-os-clean

include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
TF_A_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

TF_A_FLAGS ?= \
	LDFLAGS="--no-warn-rwx-segments" \
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

tf-a: optee-os u-boot
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) all fip

tf-a-clean:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) clean

.PHONY: tf-a tf-a-clean

################################################################################
# Das U-Boot
################################################################################
U-BOOT_EXPORTS ?= CROSS_COMPILE=$(AARCH64_CROSS_COMPILE) ARCH=arm64
U-BOOT_DEFCONFIG_COMMON_FILES := \
		$(U-BOOT_PATH)/configs/rpi_3_defconfig \
		$(CURDIR)/kconfigs/u-boot_rpi3.conf

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

u-boot-defconfig-clean:
	rm -f $(U-BOOT_PATH)/.config

.PHONY: u-boot u-boot-clean u-boot-defconfig u-boot-defconfig-clean u-boot-env \
	u-boot-env-clean

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

.PHONY: linux linux-defconfig-clean linux-clean linux-cleaner

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
update_rootfs: linux
	@mkdir -p --mode=755 $(BUILDROOT_TARGET_ROOT)/usr/bin
	@cd $(MODULE_OUTPUT) && find . | cpio -pudm $(BUILDROOT_TARGET_ROOT)

update_bootfs: tf-a linux u-boot-env
	@mkdir -p --mode=755 $(BOOT_PARTITION_FILES)
	@install -v -p --mode=755 $(LINUX_DTB_RPI3_B) $(BOOT_PARTITION_FILES)/bcm2710-rpi-3-b.dtb
	@install -v -p --mode=755 $(LINUX_DTB_RPI3_BPLUS) $(BOOT_PARTITION_FILES)/bcm2710-rpi-3-b-plus.dtb
	@install -v -p --mode=755 $(RPI3_BOOT_CONFIG) $(BOOT_PARTITION_FILES)/config.txt
	@install -v -p --mode=755 $(LINUX_IMAGE) $(BOOT_PARTITION_FILES)/kernel8.img
	@install -v -p --mode=755 $(TF_A_BOOT) $(BOOT_PARTITION_FILES)/armstub8.bin
	@install -v -p --mode=755 $(RPI3_UBOOT_ENV) $(BOOT_PARTITION_FILES)/uboot.env
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/bootcode.bin $(BOOT_PARTITION_FILES)/bootcode.bin
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/COPYING.linux $(BOOT_PARTITION_FILES)/COPYING.linux
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/fixup_cd.dat $(BOOT_PARTITION_FILES)/fixup_cd.dat
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/fixup.dat $(BOOT_PARTITION_FILES)/fixup.dat
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/fixup_db.dat $(BOOT_PARTITION_FILES)/fixup_db.dat
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/fixup_x.dat $(BOOT_PARTITION_FILES)/fixup_x.dat
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/LICENCE.broadcom $(BOOT_PARTITION_FILES)/LICENCE.broadcom
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/start_cd.elf $(BOOT_PARTITION_FILES)/start_cd.elf
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/start_db.elf $(BOOT_PARTITION_FILES)/start_db.elf
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/start.elf $(BOOT_PARTITION_FILES)/start.elf
	@install -v -p --mode=755 $(RPI3_STOCK_FW_PATH)/boot/start_x.elf $(BOOT_PARTITION_FILES)/start_x.elf

.PHONY: sdcard-image
sdcard-image: update_bootfs update_rootfs buildroot
	$(CREATE_IMAGE) -w $(ROOT)

# Creating images etc, could wipe out a drive on the system, therefore we don't
# want to automate that in script or make target. Instead we just simply provide
# the steps here.
.PHONY: img-help
img-help:
	@echo "Use 'dmesg' to find your device/SD-card name, then run the following as root:"
	@echo "   $$ sudo dd if=$(ROOT)/out/rpi3-sdcard.img of=/dev/<name-of-my-sd-card> bs=1024k conv=fsync status=progress"
