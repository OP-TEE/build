COMPILE_NS_USER ?= 64
override COMPILE_NS_KERNEL := 64
COMPILE_S_USER ?= 64
COMPILE_S_KERNEL ?= 64

include common.mk

DEBUG ?= 1

# Do not leave a partially downloaded binary in case wget fails midway
.DELETE_ON_ERROR:

################################################################################
# Paths to git projects and various binaries
################################################################################
TF_A_PATH		?= $(ROOT)/trusted-firmware-a
BINARIES_PATH		?= $(ROOT)/out
UBOOT_PATH		?= $(ROOT)/u-boot
UBOOT_BIN		?= $(UBOOT_PATH)/u-boot.bin
ROOT_IMG		?= $(ROOT)/out-br/images/rootfs.ext2
BOOT_IMG		?= $(ROOT)/out/nanopc-t6.img
TPL_BIN			?= $(BINARIES_PATH)/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.18.bin
BOOT_CMD		?= $(ROOT)/build/nanopc-t6/nanopi6.h
BOARD_DTSO		?= $(ROOT)/build/nanopc-t6/rk3588-nanopi6-optee.dtso
FIT_WRAPPER		?= $(ROOT)/build/nanopc-t6/fit_wrapper.sh
LINUX_DTSI		?= $(LINUX_PATH)/arch/arm64/boot/dts/rockchip/rk3588-nanopi6-common.dtsi
UBOOT_HEADER		?= $(UBOOT_PATH)/include/configs/nanopi6.h
UBOOT_FIT		?= $(UBOOT_PATH)/arch/arm/mach-rockchip/fit_wrapper.sh

LINUX_MODULES ?= n

BR2_TARGET_ROOTFS_CPIO = n
BR2_TARGET_ROOTFS_CPIO_GZIP = n
BR2_TARGET_ROOTFS_EXT2 = y
# Use Debug UART (tty1) for system console
# Reference: https://wiki.friendlyelec.com/wiki/index.php/NanoPC-T6#NanoPC-T6
BR2_TARGET_GENERIC_GETTY_PORT = tty1
ifeq ($(LINUX_MODULES),y)
# If modules are installed...
# ...enable automatic device detection and driver loading
BR2_ROOTFS_DEVICE_CREATION_DYNAMIC_EUDEV = y
# ...and configure enP2p33s0 automatically based on ifup helpers
BR2_PACKAGE_IFUPDOWN_SCRIPTS = y
BR2_SYSTEM_DHCP = enP2p33s0
# An image with module takes more space
BR2_TARGET_ROOTFS_EXT2_SIZE = 1536M
# Enable SSH daemon for remote login
BR2_PACKAGE_OPENSSH = y
BR2_PACKAGE_OPENSSH_SERVER = y
BR2_ROOTFS_POST_BUILD_SCRIPT = $(ROOT)/build/br-ext/board/nanopc-t6/post-build.sh
# Enable NTP for current time
BR2_PACKAGE_NTP = y
BR2_PACKAGE_NTP_NTPD = y
else
BR2_TARGET_ROOTFS_EXT2_SIZE = 112M
endif

################################################################################
# Targets
################################################################################

all: boot-img

clean: buildroot-clean

include toolchain.mk

################################################################################
# Arm Trusted Firmware-A
################################################################################
TF_A_EXPORTS ?= CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
		M0_CROSS_COMPILE="$(CCACHE)$(AARCH32_CROSS_COMPILE)" \
		CC="$(CCACHE)$(AARCH64_CROSS_COMPILE)gcc" \
		LD="$(CCACHE)$(AARCH64_CROSS_COMPILE)ld"

TF_A_DEBUG ?= $(DEBUG)
ifeq ($(TF_A_DEBUG),0)
TF_A_LOGLVL ?= 30
TF_A_OUT = $(TF_A_PATH)/build/rk3588/release
else
TF_A_LOGLVL ?= 40
TF_A_OUT = $(TF_A_PATH)/build/rk3588/debug
endif

TF_A_FLAGS ?= ARCH=aarch64 PLAT=rk3588 SPD=opteed DEBUG=$(TF_A_DEBUG) \
	      LOG_LEVEL=$(TF_A_LOGLVL)

.PHONY: tfa
tfa:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) bl31

.PHONY: tfa-clean
tfa-clean:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) clean

clean: tfa-clean

################################################################################
# U-Boot
################################################################################
UBOOT_DEFCONFIG_FILES := $(UBOOT_PATH)/configs/nanopi6_defconfig \
			 $(ROOT)/build/kconfigs/u-boot_nanopc-t6.conf

UBOOT_FLAGS ?= CROSS_COMPILE=$(CROSS_COMPILE_NS_KERNEL) \
	       CC=$(CROSS_COMPILE_NS_KERNEL)gcc \
	       HOSTCC="$(CCACHE) gcc"

$(TPL_BIN):
	mkdir -p $(BINARIES_PATH)
	wget -O $(TPL_BIN) https://github.com/rockchip-linux/rkbin/raw/master/bin/rk35/$(notdir $(TPL_BIN))

UBOOT_EXPORTS ?= BL31=$(TF_A_OUT)/bl31/bl31.elf \
                 TEE=$(OPTEE_OS_BIN) \
                 ROCKCHIP_TPL=$(TPL_BIN)

u-boot-defconfig: $(UBOOT_PATH)/.config

$(UBOOT_PATH)/.config: $(UBOOT_DEFCONFIG_FILES)
	cd $(UBOOT_PATH) && \
                scripts/kconfig/merge_config.sh $(UBOOT_DEFCONFIG_FILES)

.PHONY: u-boot-defconfig

.PHONY: u-boot-config
u-boot-config: $(UBOOT_PATH)/.config optee-os tfa
	cp $(TF_A_OUT)/bl31/bl31.elf $(UBOOT_PATH)/
	cp $(ROOT)/optee_os/out/arm/core/tee-raw.bin $(UBOOT_PATH)/tee.bin

.PHONY: u-boot-proper
u-boot-proper: $(TPL_BIN) $(UBOOT_PATH)/.config u-boot-config
	$(UBOOT_EXPORTS) $(MAKE) -C $(UBOOT_PATH) $(UBOOT_FLAGS)

.PHONY: u-boot-apply-bootcmd
u-boot-apply-bootcmd:
	cp $(BOOT_CMD) $(UBOOT_HEADER)

$(UBOOT_FIT): $(FIT_WRAPPER)
	cp $< $@

.PHONY: u-boot-loader
u-boot-loader: u-boot-proper
	$(UBOOT_PATH)/tools/mkimage -n rk3588 -T rksd -d $(UBOOT_PATH)/tpl/u-boot-tpl.bin:$(UBOOT_PATH)/spl/u-boot-spl.bin $(UBOOT_PATH)/idbloader.img

.PHONY: u-boot
u-boot: u-boot-apply-bootcmd $(UBOOT_FIT) $(TPL_BIN) $(UBOOT_PATH)/.config u-boot-loader
	$(UBOOT_EXPORTS) $(MAKE) -C $(UBOOT_PATH) $(UBOOT_FLAGS) u-boot.itb

.PHONY: u-boot-clean
u-boot-clean:
	$(UBOOT_EXPORTS) $(MAKE) -C $(UBOOT_PATH) $(UBOOT_FLAGS) distclean

clean: u-boot-clean

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH ?= arm64
LINUX_DEFCONFIG_COMMON_FILES ?= $(LINUX_PATH)/arch/arm64/configs/nanopi6_linux_defconfig \
				$(CURDIR)/kconfigs/nanopc-t6.conf

.PHONY: linux-defconfig
linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64 CFLAGS_KERNEL="-Wno-error"
LINUX_COMMON_TARGETS += Image rockchip/rk3588-nanopi6-rev01.dtb \
			$(if $(filter y,$(LINUX_MODULES)),modules)

.PHONY: linux-apply-dtso
linux-apply-dtso: linux-common
	$(LINUX_PATH)/scripts/dtc/dtc -I dts -O dtb -@ \
		-o $(LINUX_PATH)/arch/arm64/boot/dts/rockchip/rk3588-nanopi6-optee.dtbo \
		$(BOARD_DTSO)

.PHONY: linux
linux: linux-common linux-apply-dtso
ifeq ($(LINUX_MODULES),y)
	$(MAKE) -C $(LINUX_PATH) ARCH=arm64 modules_install \
		INSTALL_MOD_PATH=$(BINARIES_PATH)/modules
endif

$(LINUX_PATH)/arch/arm64/boot/Image.gz: linux
	gzip -c $(LINUX_PATH)/arch/arm64/boot/Image >$@

.PHONY: linux-defconfig-clean
linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

.PHONY: linux-clean
linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

.PHONY: linux-cleaner
linux-cleaner: linux-cleaner-common

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_PLATFORM = rockchip-rk3588
OPTEE_OS_COMMON_FLAGS += CFG_ENABLE_EMBEDDED_TESTS=y

.PHONY: optee-os
optee-os: optee-os-common

.PHONY: optee-os-clean
optee-os-clean: optee-os-clean-common

clean: optee-os-clean

################################################################################
# Boot image, shall be copied to SD card
################################################################################

# U-Boot offset comes from CONFIG_SYS_MMCSD_RAW_MODE_U_BOOT_SECTOR=0x4000
# Partition no. 5 ends at 12288 + BR2_TARGET_ROOTFS_EXT2_SIZE (in kiB)
# File size needs to be slightly bigger to accomodate for whatever meta-data
rootfs-size-kib := $(shell echo $(BR2_TARGET_ROOTFS_EXT2_SIZE) | sed 's/M/*1024/')
p5-end-kib := $(shell echo $$((12288 + $(rootfs-size-kib))))
img-size-kib := $(shell echo $$(($(p5-end-kib) + 1024)))

.PHONY: boot-img
boot-img: u-boot buildroot $(LINUX_PATH)/arch/arm64/boot/Image.gz
	mkdir -p $(BINARIES_PATH)
	rm -f $(BOOT_IMG)
	truncate -s $(img-size-kib)KiB $(BOOT_IMG)
	parted -s $(BOOT_IMG) \
		unit kiB \
		mklabel gpt \
		mkpart idbloader 32 4032 \
		mkpart primary fat32 4032 4096 \
		mkpart primary fat32 4096 8192 \
		mkpart uboot 8192 12288 \
		mkpart root fat32 12288 $(p5-end-kib)
	sgdisk -u 5:17d61bff-8fdc-4089-b675-9be21b9f6ac7 $(BOOT_IMG)
	dd if=$(UBOOT_PATH)/idbloader.img of=$(BOOT_IMG) bs=1kiB seek=32 conv=notrunc
	dd if=$(UBOOT_PATH)/u-boot.itb of=$(BOOT_IMG) bs=1kiB seek=8192 conv=notrunc
	e2mkdir $(ROOT_IMG):/boot
	e2cp $(LINUX_PATH)/arch/arm64/boot/Image.gz $(ROOT_IMG):/boot
	e2cp $(LINUX_PATH)/arch/arm64/boot/dts/rockchip/rk3588-nanopi6-rev01.dtb $(ROOT_IMG):/boot
	e2cp $(LINUX_PATH)/arch/arm64/boot/dts/rockchip/rk3588-nanopi6-optee.dtbo $(ROOT_IMG):/boot
ifeq ($(LINUX_MODULES),y)
	find $(BINARIES_PATH)/modules -type f | while read f; do e2cp -a $$f $(ROOT_IMG):$$(echo $$f | sed s@$(BINARIES_PATH)/modules@@); done
endif
	dd if=$(ROOT_IMG) of=$(BOOT_IMG) bs=1kiB seek=12288 conv=notrunc

.PHONY: boot-img-clean
boot-img-clean:
	rm -f $(BOOT_IMG)

clean: boot-img-clean
