###############################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
###############################################################################
override COMPILE_NS_USER   := 32
override COMPILE_NS_KERNEL := 32
override COMPILE_S_USER    := 32
override COMPILE_S_KERNEL  := 32

###############################################################################
# Includes
###############################################################################
-include common.mk

###############################################################################
# Paths to git projects and various binaries
###############################################################################
STAGING_AREA    ?= $(ROOT)/out
U-BOOT_PATH     ?= $(ROOT)/u-boot
UBOOT_SPL       ?= $(U-BOOT_PATH)/u-boot-spl_HS_MLO
UBOOT_IMG       ?= $(U-BOOT_PATH)/u-boot_HS.img
UBOOT_ENV       ?= $(BUILD_PATH)/dra7xx/uEnv.txt
LINUX_IMAGE     ?= $(LINUX_PATH)/arch/arm/boot/zImage
LINUX_DTBS      ?= $(wildcard $(LINUX_PATH)/arch/arm/boot/dts/dra7*.dtb)
FIT_SOURCE      ?= $(BUILD_PATH)/dra7xx/fitImage.its
FIT_MAKEFILE    ?= $(BUILD_PATH)/dra7xx/Makefile

###############################################################################
# Targets
###############################################################################
.PHONY: all clean cleaner prepare

all: u-boot linux optee-os optee-client xtest helloworld build-fit update_rootfs
clean: linux-clean busybox-clean u-boot-clean optee-os-clean optee-client-clean build-fit-clean
cleaner: clean prepare-cleaner busybox-cleaner linux-cleaner

-include toolchain.mk

prepare:
	@if [ ! -d $(STAGING_AREA) ]; then mkdir $(STAGING_AREA); fi

.PHONY: prepare-cleaner
prepare-cleaner:
	rm -rf $(STAGING_AREA)

###############################################################################
# Das U-Boot
###############################################################################
.PHONY: u-boot u-boot-clean

U-BOOT_EXPORTS ?= CROSS_COMPILE=$(CROSS_COMPILE_NS_KERNEL) ARCH=arm

u-boot:
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) dra7xx_hs_evm_defconfig
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) all

u-boot-clean:
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean

###############################################################################
# Linux kernel
###############################################################################
.PHONY: linux-defconfig linux linux-defconfig-clean linux-clean linux-cleaner

LINUX_DEFCONFIG_COMMON_ARCH := arm
LINUX_DEFCONFIG_COMMON_FILES := \
	$(LINUX_PATH)/arch/arm/configs/multi_v7_defconfig \
	$(LINUX_PATH)/ti_config_fragments/multi_v7_prune.cfg \
	$(LINUX_PATH)/ti_config_fragments/baseport.cfg \
	$(LINUX_PATH)/ti_config_fragments/ipc.cfg \
	$(LINUX_PATH)/ti_config_fragments/connectivity.cfg \
	$(LINUX_PATH)/ti_config_fragments/audio_display.cfg \
	$(LINUX_PATH)/ti_config_fragments/wlan.cfg \
	$(LINUX_PATH)/ti_config_fragments/omap_soc.cfg \
	$(LINUX_PATH)/ti_config_fragments/lpae.cfg \
	$(LINUX_PATH)/ti_config_fragments/dra7_only.cfg \
	$(LINUX_PATH)/ti_config_fragments/debug_options.cfg

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm
linux: linux-common
linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm
linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm
linux-cleaner: linux-cleaner-common

###############################################################################
# OP-TEE
###############################################################################
.PHONY: optee-os optee-os-clean optee-client optee-client-clean

OPTEE_OS_COMMON_FLAGS += PLATFORM=ti-dra7xx
optee-os: optee-os-common

OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=ti-dra7xx
optee-os-clean: optee-os-clean-common

optee-client: optee-client-common
optee-client-clean: optee-client-clean-common

###############################################################################
# xtest / optee_test
###############################################################################
.PHONY: xtest xtest-clean xtest-patch

xtest: xtest-common
xtest-clean: xtest-clean-common
xtest-patch: xtest-patch-common

###############################################################################
# hello_world
###############################################################################
.PHONY: helloworld helloworld-clean

helloworld: helloworld-common
helloworld-clean: helloworld-clean-common

###############################################################################
# Busybox
###############################################################################
.PHONY: busybox busybox-clean busybox-cleaner

BUSYBOX_COMMON_TARGET = dra7xx
BUSYBOX_CLEAN_COMMON_TARGET = dra7xx clean

busybox: busybox-common
busybox-clean: busybox-clean-common
busybox-cleaner: busybox-cleaner-common

###############################################################################
# Build FIT
###############################################################################
.PHONY: build-fit build-fit-clean

build-fit: prepare linux optee-os
	cp $(LINUX_IMAGE) $(STAGING_AREA)/
	cp $(LINUX_DTBS) $(STAGING_AREA)/
	cp $(OPTEE_OS_BIN) $(STAGING_AREA)/
	cp $(FIT_SOURCE) $(STAGING_AREA)/
	cp $(FIT_MAKEFILE) $(STAGING_AREA)/
	MKIMAGE=$(U-BOOT_PATH)/tools/mkimage $(MAKE) -C $(STAGING_AREA)

build-fit-clean:
	$(RM) $(STAGING_AREA)/Makefile
	$(RM) $(STAGING_AREA)/fitImage.its
	$(RM) $(STAGING_AREA)/tee.bin
	$(RM) $(STAGING_AREA)/*.dtb
	$(RM) $(STAGING_AREA)/zImage

###############################################################################
# Root FS
###############################################################################
.PHONY: filelist-tee update_rootfs

filelist-tee: filelist-tee-common u-boot build-fit
	@echo "dir /boot 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "file /boot/MLO $(UBOOT_SPL) 644 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "file /boot/u-boot.img $(UBOOT_IMG) 644 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "file /boot/uEnv.txt $(UBOOT_ENV) 644 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "file /boot/fitImage.itb $(STAGING_AREA)/fitImage.itb 644 0 0" >> $(GEN_ROOTFS_FILELIST)

update_rootfs: update_rootfs-common
