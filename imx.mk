################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER    := 64
override COMPILE_S_KERNEL  := 64

OPTEE_OS_PLATFORM = imx-mx8mqevk
BR2_TARGET_GENERIC_GETTY_PORT = ttymxc0

include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
TF_A_PATH		?= $(ROOT)/trusted-firmware-a

U-BOOT_PATH		?= $(ROOT)/u-boot
U-BOOT_BIN		?= $(U-BOOT_PATH)/u-boot.bin

FIRMWARE_BIN_SHA256_SUM ?= 63ec62f5d229cbed00918c8449173933f1c9d594c59396b8dd217e94f47138b0
FIRMWARE_BIN		?= firmware-imx-8.0.bin
FIRMWARE_BIN		?= firmware-imx-8.0.bin
FIRMWARE_BIN_URL	?= https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/$(FIRMWARE_BIN)
FIRMWARE_VERSION	?= firmware-imx-8.0
FIRMWARE_PATH		?= $(ROOT)/out-firmware/$(FIRMWARE_VERSION)
LPDDR_BIN_PATH		?= $(FIRMWARE_PATH)/firmware/ddr/synopsys

MKIMAGE_PATH		?= $(ROOT)/imx-mkimage
BOOT_IMG		?= $(ROOT)/out/boot.img

################################################################################
# Targets
################################################################################
all: tfa u-boot linux optee-os buildroot flash-image
clean: tfa-clean buildroot-clean u-boot-clean optee-os-clean

include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
TF_A_EXPORTS = CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

#	BL32=$(OPTEE_OS_HEADER_V2_BIN) \
#	BL32_EXTRA1=$(OPTEE_OS_PAGER_V2_BIN) \
#	BL32_EXTRA2=$(OPTEE_OS_PAGEABLE_V2_BIN) \

TF_A_FLAGS  = PLAT=imx8mq SPD=opteed DEBUG_CONSOLE=1 DEBUG=0 V=1
TF_A_FLAGS += BL32=$(ROOT)/optee_os/out/arm/core/tee-raw.bin

tfa: optee-os u-boot
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) all fip

tfa-clean:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) clean

################################################################################
# U-Boot
################################################################################

U-BOOT_EXPORTS = CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

U-BOOT_DEFCONFIG_FILES := $(U-BOOT_PATH)/configs/imx8mq_evk_defconfig \
			  $(BUILD_PATH)/kconfigs/uboot_imx8.conf

$(U-BOOT_PATH)/.config: $(U-BOOT_DEFCONFIG_FILES)
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) imx8mq_evk_defconfig
	(cd $(U-BOOT_PATH) && \
                ARCH=arm64 \
                scripts/kconfig/merge_config.sh $(U-BOOT_DEFCONFIG_FILES))

.PHONY: u-boot-defconfig
u-boot-defconfig: $(U-BOOT_PATH)/.config

.PHONY: u-boot
u-boot: u-boot-defconfig
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH)

.PHONY: u-boot-clean
u-boot-clean:
	cd $(U-BOOT_PATH) && git clean -xdf

.PHONY: u-boot-cscope
u-boot-cscope:
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) cscope


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

$(ROOT)/out-firmware/$(FIRMWARE_BIN):
	mkdir -p $(ROOT)/out-firmware
	(cd $(ROOT)/out-firmware && wget $(FIRMWARE_BIN_URL))

$(FIRMWARE_PATH)/.unpacked: $(ROOT)/out-firmware/$(FIRMWARE_BIN)
	(cd $(ROOT)/out-firmware && \
	 echo $(FIRMWARE_BIN_SHA256_SUM) $(FIRMWARE_BIN) | sha256sum -c)
	(cd $(ROOT)/out-firmware && \
	 chmod 711 $(FIRMWARE_BIN) && ./$(FIRMWARE_BIN) --auto-accept)
	touch $(FIRMWARE_PATH)/.unpacked
	
.PHONY: ddr-firmware
ddr-firmware: $(FIRMWARE_PATH)/.unpacked

ddr-firmware-clean:
	rm -rf $(ROOT)/out-firmware

################################################################################
# imx-mkimage
################################################################################
mkimage: u-boot tfa ddr-firmware
	ln -sf $(ROOT)/optee_os/out/arm/core/tee-raw.bin \
		$(MKIMAGE_PATH)/iMX8M/tee.bin
	ln -sf $(ROOT)/trusted-firmware-a/build/imx8mq/release/bl31.bin \
		$(MKIMAGE_PATH)/iMX8M/
	ln -sf $(LPDDR_BIN_PATH)/lpddr4_pmu_train_*.bin $(MKIMAGE_PATH)/iMX8M/
	ln -sf $(U-BOOT_PATH)/u-boot-nodtb.bin $(MKIMAGE_PATH)/iMX8M/
	ln -sf $(U-BOOT_PATH)/spl/u-boot-spl.bin $(MKIMAGE_PATH)/iMX8M/
	ln -sf $(U-BOOT_PATH)/arch/arm/dts/imx8mq-evk.dtb \
		$(MKIMAGE_PATH)/iMX8M/fsl-imx8mq-evk.dtb
	ln -sf $(U-BOOT_PATH)/tools/mkimage $(MKIMAGE_PATH)/iMX8M/mkimage_uboot
	$(MAKE) -C $(MKIMAGE_PATH) SOC=iMX8M flash_spl_uboot
#> +If you want to run with HDMI, copy signed_hdmi_imx8m.bin to imx-mkimage/iMX8M
#> +make SOC=iMX8M flash_spl_uboot or make SOC=iMX8M flash_hdmi_spl_uboot to
#> +generate flash.bin.
mkimage-clean:
	cd $(MKIMAGE_PATH) && git clean -xdf
	rm -f $(ROOT)/build/mkimage_imx8

$(ROOT)/out-br/images/ramdisk.img: $(ROOT)/out-br/images/rootfs.cpio.gz
	$(U-BOOT_PATH)/tools/mkimage -A arm64 -O linux -T ramdisk -C gzip \
		-d $< $@

$(ROOT)/out:
	mkdir -p $@

$(ROOT)/out/boot.scr: $(ROOT)/build/imx/u-boot_boot_script | $(ROOT)/out
	$(U-BOOT_PATH)/tools/mkimage -T script -C none -n 'Boot script' \
		-d $< $@

.PHONY: flash-image
flash-image: buildroot mkimage
	$(MAKE) flash-image-only

.PHONY: flash-image-only
flash-image-only: $(ROOT)/out-br/images/ramdisk.img $(ROOT)/out/boot.scr
	rm -f $(BOOT_IMG)
	truncate -s 128M ${BOOT_IMG}
	echo -ne "16384 64M 7\n147456 + 83\n" | sfdisk ${BOOT_IMG}
	mformat -i ${BOOT_IMG}.fat -n 64 -h 255 -T 131072 -v "BOOT IMG" -C ::
	mcopy -i ${BOOT_IMG}.fat $(LINUX_PATH)/arch/arm64/boot/Image ::
	mcopy -i ${BOOT_IMG}.fat \
		$(LINUX_PATH)/arch/arm64/boot/dts/freescale/imx8mq-evk.dtb ::
	mcopy -i ${BOOT_IMG}.fat $(ROOT)/out-br/images/ramdisk.img ::
	mcopy -i ${BOOT_IMG}.fat $(ROOT)/out/boot.scr ::
	dd if=${BOOT_IMG}.fat of=${BOOT_IMG} bs=512 seek=16384 \
		conv=fsync,notrunc
	dd if=${ROOT}/imx-mkimage/iMX8M/flash.bin of=${BOOT_IMG} bs=1k seek=33 \
		conv=fsync,notrunc
