################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER    := 64
override COMPILE_S_KERNEL  := 64

TFA_PLATFORM      ?= imx8mq
OPTEE_OS_PLATFORM ?= imx-mx8mqevk
U_BOOT_DEFCONFIG  ?= imx8mq_evk_defconfig
U_BOOT_DT         ?= imx8mq-evk.dtb
LINUX_DT          ?= imx8mq-evk.dtb
MKIMAGE_DT        ?= fsl-imx8mq-evk.dtb
MKIMAGE_SOC       ?= iMX8MQ

BR2_TARGET_GENERIC_GETTY_PORT ?= ttymxc0
BR2_TARGET_ROOTFS_EXT2 ?= y
BR2_TARGET_ROOTFS_EXT2_4 ?= y

include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
ifeq ($(DEBUG),1)
TF_A_BUILD		?= debug
else
TF_A_BUILD		?= release
endif

FIRMWARE_PATH		?= $(ROOT)/out-firmware
MKIMAGE_PATH		?= $(ROOT)/imx-mkimage
MKIMAGE_SOC_PATH	?= $(MKIMAGE_PATH)/iMX8M
TF_A_PATH		?= $(ROOT)/trusted-firmware-a

FIRMWARE_VERSION	?= firmware-imx-8.0
FIRMWARE_BIN_SHA256_SUM ?= 63ec62f5d229cbed00918c8449173933f1c9d594c59396b8dd217e94f47138b0
FIRMWARE_BIN		?= $(FIRMWARE_VERSION).bin
FIRMWARE_BIN_URL	?= https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/$(FIRMWARE_BIN)

BOOT_IMG		?= $(ROOT)/out/boot.img

# Set the variable to include the board config snippet
# Default value is empty, will select the imx8mq-evk board.
# Possible values: "imx8mp-evk" or "imx8mp-verdin"
IMX_BOARD ?=
ifneq (,$(IMX_BOARD))
include $(IMX_BOARD).inc.mk
endif

################################################################################
# Targets
################################################################################
all: tfa u-boot linux optee-os buildroot flash-image
clean: ddr-firmware-clean optee-os-clean tfa-clean u-boot-clean buildroot-clean

include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
TF_A_EXPORTS = CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

#	BL32=$(OPTEE_OS_HEADER_V2_BIN) \
#	BL32_EXTRA1=$(OPTEE_OS_PAGER_V2_BIN) \
#	BL32_EXTRA2=$(OPTEE_OS_PAGEABLE_V2_BIN) \

TF_A_FLAGS += PLAT=$(TFA_PLATFORM) SPD=opteed DEBUG_CONSOLE=1 DEBUG=0 V=1
TF_A_FLAGS += BL32=$(OPTEE_OS_PATH)/out/arm/core/tee-raw.bin

tfa: optee-os
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) all fip

tfa-clean:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) clean

################################################################################
# U-Boot
################################################################################

U-BOOT_EXPORTS = CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

U-BOOT_DEFCONFIG_FILES := $(UBOOT_PATH)/configs/$(U_BOOT_DEFCONFIG) \
			  $(BUILD_PATH)/kconfigs/uboot_imx8.conf

$(UBOOT_PATH)/.config: $(U-BOOT_DEFCONFIG_FILES)
	$(U-BOOT_EXPORTS) $(MAKE) -C $(UBOOT_PATH) $(U_BOOT_DEFCONFIG)
	(cd $(UBOOT_PATH) && ARCH=arm64 scripts/kconfig/merge_config.sh \
		$(U-BOOT_DEFCONFIG_FILES))

.PHONY: u-boot-defconfig
u-boot-defconfig: $(UBOOT_PATH)/.config

.PHONY: u-boot
u-boot: u-boot-defconfig tfa ddr-firmware
	# Copy DDR4 firmware
	cp $(FIRMWARE_PATH)/$(FIRMWARE_VERSION)/firmware/ddr/synopsys/lpddr4_pmu_train_*.bin \
		$(UBOOT_PATH)
	# Copy BL31 binary from TF-A
	cp $(TF_A_PATH)/build/$(TFA_PLATFORM)/$(TF_A_BUILD)/bl31.bin $(UBOOT_PATH)
	$(U-BOOT_EXPORTS) $(MAKE) -C $(UBOOT_PATH)

.PHONY: u-boot-clean
u-boot-clean:
	cd $(UBOOT_PATH) && git clean -xdf

.PHONY: u-boot-cscope
u-boot-cscope:
	$(U-BOOT_EXPORTS) $(MAKE) -C $(UBOOT_PATH) cscope


################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm64/configs/defconfig \
		$(CURDIR)/kconfigs/imx.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64

linux: linux-common

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
# DDR firmware
################################################################################
# This is prebuilt binaries by NXP, download them and use them. Update path if
# it changes in the future.

$(FIRMWARE_PATH)/$(FIRMWARE_BIN):
	mkdir -p $(FIRMWARE_PATH)
	(cd $(FIRMWARE_PATH) && wget $(FIRMWARE_BIN_URL))

$(FIRMWARE_PATH)/.unpacked: $(FIRMWARE_PATH)/$(FIRMWARE_BIN)
	(cd $(FIRMWARE_PATH) && \
	 echo $(FIRMWARE_BIN_SHA256_SUM) $(FIRMWARE_BIN) | sha256sum -c)
	(cd $(FIRMWARE_PATH) && \
	 chmod 711 $(FIRMWARE_BIN) && ./$(FIRMWARE_BIN) --auto-accept)
	touch $(FIRMWARE_PATH)/.unpacked

.PHONY: ddr-firmware
ddr-firmware: $(FIRMWARE_PATH)/.unpacked

ddr-firmware-clean:
	rm -rf $(FIRMWARE_PATH)

################################################################################
# imx-mkimage
################################################################################
mkimage: u-boot
	ln -sf $(OPTEE_OS_PATH)/out/arm/core/tee-raw.bin \
		$(MKIMAGE_SOC_PATH)/tee.bin
	ln -sf $(TF_A_PATH)/build/$(TFA_PLATFORM)/$(TF_A_BUILD)/bl31.bin \
		$(MKIMAGE_SOC_PATH)/
	ln -sf $(FIRMWARE_PATH)/$(FIRMWARE_VERSION)/firmware/ddr/synopsys/lpddr4_pmu_train_*.bin \
		$(MKIMAGE_SOC_PATH)/
	ln -sf $(UBOOT_PATH)/u-boot-nodtb.bin $(MKIMAGE_SOC_PATH)/
	ln -sf $(UBOOT_PATH)/spl/u-boot-spl.bin $(MKIMAGE_SOC_PATH)/
	ln -sf $(UBOOT_PATH)/arch/arm/dts/$(U_BOOT_DT) \
		$(MKIMAGE_SOC_PATH)/$(MKIMAGE_DT)
	ln -sf $(UBOOT_PATH)/tools/mkimage $(MKIMAGE_SOC_PATH)/mkimage_uboot
	# imx8mp: allow to override TEE_LOAD_ADDR
	# https://github.com/nxp-imx/imx-mkimage/pull/3
	sed -i 's/TEE_LOAD_ADDR =  /TEE_LOAD_ADDR ?= /' $(MKIMAGE_SOC_PATH)/soc.mak
	$(MAKE) -C $(MKIMAGE_PATH) SOC=$(MKIMAGE_SOC) flash_spl_uboot
#> +If you want to run with HDMI, copy signed_hdmi_imx8m.bin to imx-mkimage/iMX8M
#> +make SOC=iMX8M flash_spl_uboot or make SOC=iMX8M flash_hdmi_spl_uboot to
#> +generate flash.bin.
mkimage-clean:
	cd $(MKIMAGE_PATH) && git clean -xdf
	rm -f $(BUILD_PATH)/mkimage_imx8

$(ROOT)/out-br/images/ramdisk.img: $(ROOT)/out-br/images/rootfs.cpio.gz
	$(UBOOT_PATH)/tools/mkimage -A arm64 -O linux -T ramdisk -C gzip \
		-d $< $@

$(ROOT)/out:
	mkdir -p $@

$(ROOT)/out/boot.scr: $(BUILD_PATH)/imx/u-boot_boot_script | $(ROOT)/out
	$(UBOOT_PATH)/tools/mkimage -T script -C none -n 'Boot script' \
		-d $< $@

################################################################################
# Flash images
################################################################################
USE_PERSISTENT_ROOTFS ?= 0

# Configuration of the BOOT partition
FLASH_PARTITIONS_BLOCK_SIZE = 512
FLASH_PARTITION_BOOT_START_BLOCK = 16384
FLASH_PARTITION_BOOT_SIZE_IN_BYTES = \
	$(shell echo $$(( 64 * 1024 * 1024 )))
FLASH_PARTITION_BOOT_SIZE_IN_BLOCKS = \
	$(shell echo $$(( $(FLASH_PARTITION_BOOT_SIZE_IN_BYTES) / $(FLASH_PARTITIONS_BLOCK_SIZE) )))
FLASH_PARTITIONS_TABLE = "\
	start=$(FLASH_PARTITION_BOOT_START_BLOCK) \
	size=$(FLASH_PARTITION_BOOT_SIZE_IN_BLOCKS) \
	type=7\n"
FLASH_IMAGE_SIZE = \
	$(shell echo $$(( $(FLASH_PARTITION_BOOT_START_BLOCK) * $(FLASH_PARTITIONS_BLOCK_SIZE) \
	+ $(FLASH_PARTITION_BOOT_SIZE_IN_BYTES) )))

# Configuration of the ROOTFS partition if enabled
ifeq ($(USE_PERSISTENT_ROOTFS),1)
FLASH_PARTITION_ROOTFS_IMAGE_PATH = $(ROOT)/out-br/images/rootfs.ext4
FLASH_PARTITION_ROOTFS_START_BLOCK = \
	$(shell echo $$(( $(FLASH_PARTITION_BOOT_START_BLOCK) + $(FLASH_PARTITION_BOOT_SIZE_IN_BLOCKS) )))
FLASH_PARTITION_ROOTFS_SIZE_IN_BYTES = \
	$(shell stat -L --printf="%s" $(FLASH_PARTITION_ROOTFS_IMAGE_PATH))
FLASH_PARTITION_ROOTFS_SIZE_IN_BLOCKS = \
	$(shell echo $$(( $(FLASH_PARTITION_ROOTFS_SIZE_IN_BYTES) / $(FLASH_PARTITIONS_BLOCK_SIZE) )))
FLASH_PARTITIONS_TABLE += "\
	start=$(FLASH_PARTITION_ROOTFS_START_BLOCK) \
	size=$(FLASH_PARTITION_ROOTFS_SIZE_IN_BLOCKS) \
	type=83\n"
FLASH_IMAGE_SIZE := $(shell echo $$(( $(FLASH_IMAGE_SIZE) + $(FLASH_PARTITION_ROOTFS_SIZE_IN_BYTES) )))
endif

.PHONY: flash-image
flash-image: buildroot mkimage linux
	$(MAKE) flash-image-only

.PHONY: flash-image-only
flash-image-only: $(ROOT)/out-br/images/ramdisk.img $(ROOT)/out/boot.scr
	rm -f $(BOOT_IMG)
	truncate -s $(FLASH_IMAGE_SIZE) $(BOOT_IMG)
	echo -ne $(FLASH_PARTITIONS_TABLE) | sfdisk $(BOOT_IMG)
	mformat -i $(BOOT_IMG).fat -n 64 -h 255 -T 131072 -v "BOOT IMG" -C ::
	mcopy -i $(BOOT_IMG).fat $(LINUX_PATH)/arch/arm64/boot/Image ::
	mcopy -i $(BOOT_IMG).fat \
		$(LINUX_PATH)/arch/arm64/boot/dts/freescale/$(LINUX_DT) ::
	mcopy -i $(BOOT_IMG).fat $(ROOT)/out/boot.scr ::

ifeq ($(USE_PERSISTENT_ROOTFS),1)
	dd if=$(FLASH_PARTITION_ROOTFS_IMAGE_PATH) of=$(BOOT_IMG) bs=$(FLASH_PARTITIONS_BLOCK_SIZE) \
		seek=$(FLASH_PARTITION_ROOTFS_START_BLOCK) conv=fsync,notrunc
else
	mcopy -i $(BOOT_IMG).fat $(ROOT)/out-br/images/ramdisk.img ::
endif

	dd if=$(BOOT_IMG).fat of=$(BOOT_IMG) bs=$(FLASH_PARTITIONS_BLOCK_SIZE) \
		seek=$(FLASH_PARTITION_BOOT_START_BLOCK) conv=fsync,notrunc
	dd if=$(MKIMAGE_SOC_PATH)/flash.bin of=$(BOOT_IMG) bs=1k seek=33 \
		conv=fsync,notrunc
