################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 32
override COMPILE_NS_KERNEL := 32
override COMPILE_S_USER    := 32
override COMPILE_S_KERNEL  := 32

PLATFORM ?= stm32mp1-157C_DK2
OPTEE_OS_PLATFORM := $(PLATFORM)

include common.mk

ifeq ($(PLATFORM),stm32mp1-157A_DK1)
BREXT_FLAVOR		= STM32MP157A-DK1
STM32MP1_DTS_BASENAME	= stm32mp157a-dk1
else ifeq ($(PLATFORM),stm32mp1-157C_DK2)
BREXT_FLAVOR		= STM32MP157C-DK2
STM32MP1_DTS_BASENAME	= stm32mp157c-dk2
else ifeq ($(PLATFORM),stm32mp1-157C_EV1)
BREXT_FLAVOR		= STM32MP157C-EV1
STM32MP1_DTS_BASENAME	= stm32mp157c-ev1
else
$(error Unknown PLATFORM $(PLATFORM))
endif

################################################################################
# Binary images names
################################################################################

TFA_BIN			:= tf-a-$(STM32MP1_DTS_BASENAME).stm32
OPTEE_HEADER_BIN	:= tee-header_v2.stm32
OPTEE_PAGER_BIN		:= tee-pager_v2.stm32
OPTEE_PAGEABLE_BIN  	:= tee-pageable_v2.stm32
U_BOOT_BIN		:= u-boot.stm32
LINUX_KERNEL_BIN 	:= uImage
LINUX_DTB_BIN		:= $(STM32MP1_DTS_BASENAME).dtb

################################################################################
# Paths to git projects and various binaries
################################################################################
BINARIES_PATH		?= $(ROOT)/out/bin
TFA_PATH		?= $(ROOT)/trusted-firmware-a
U_BOOT_PATH		?= $(ROOT)/u-boot

define install_in_binaries
	echo "  INSTALL $(shell basename $1) to $(BINARIES_PATH)" && \
	mkdir -p $(BINARIES_PATH) && \
	ln -sf $1 $(BINARIES_PATH)
endef

################################################################################
# Main targets
################################################################################
all: tfa optee-os u-boot linux buildroot
	@$(call install_in_binaries,$(ROOT)/out-br/images/sdcard.img)
	@echo Build for platform $(PLATFORM) completed

clean: tfa-clean optee-os-clean u-boot-clean linux-clean buildroot-clean

include toolchain.mk

################################################################################
# OP-TEE OS
################################################################################
optee-os: optee-os-common
	@$(call install_in_binaries,$(OPTEE_OS_PATH)/out/arm/core/$(OPTEE_HEADER_BIN))
	@$(call install_in_binaries,$(OPTEE_OS_PATH)/out/arm/core/$(OPTEE_PAGER_BIN))
	@$(call install_in_binaries,$(OPTEE_OS_PATH)/out/arm/core/$(OPTEE_PAGEABLE_BIN))

optee-os-clean: optee-os-clean-common

################################################################################
# TrustedFirmware-A
################################################################################
TFA_EXPORTS ?= CROSS_COMPILE="$(CCACHE)$(AARCH32_CROSS_COMPILE)"

TFA_DEBUG ?= $(DEBUG)
ifeq ($(TFA_DEBUG),0)
TFA_LOGLVL ?= 30
TFA_OUT = $(TFA_PATH)/build/stm32mp1/release
else
TFA_LOGLVL ?= 50
TFA_OUT = $(TFA_PATH)/build/stm32mp1/debug
endif

TFA_FLAGS ?= \
	BL32=$(BINARIES_PATH)/$(OPTEE_HEADER_BIN) \
	BL32_EXTRA1=$(BINARIES_PATH)/$(OPTEE_PAGER_BIN) \
	BL32_EXTRA2=$(BINARIES_PATH)/$(OPTEE_PAGEABLE_BIN) \
	BL33=$(BINARIES_PATH)/$(U_BOOT_BIN) \
	ARM_ARCH_MAJOR=7 \
	ARCH=aarch32 \
	PLAT=stm32mp1 \
	DTB_FILE_NAME=$(STM32MP1_DTS_BASENAME).dtb \
	AARCH32_SP=optee \
	DEBUG=$(TFA_DEBUG) \
	LOG_LEVEL=$(TFA_LOGLVL) \
	STM32MP_EMMC=1 STM32MP_SDMMC=1 \
	STM32MP_RAW_NAND=0 STM32MP_SPI_NAND=0 STM32MP_SPI_NOR=0

tfa: optee-os u-boot
	$(TFA_EXPORTS) $(MAKE) -C $(TFA_PATH) $(TFA_FLAGS) all
	@$(call install_in_binaries,$(TFA_OUT)/$(TFA_BIN))

tfa-clean:
	$(TFA_EXPORTS) $(MAKE) -C $(TFA_PATH) $(TFA_FLAGS) clean

################################################################################
# U-Boot
################################################################################
U_BOOT_EXPORTS ?= CROSS_COMPILE="$(CCACHE)$(AARCH32_CROSS_COMPILE)"

# Use stm32mp15_optee_defconfig up to U-Boot v2020.07-rc2.
# Use stm32mp15_trusted_defconfig from v2020.07-rc3 onward.
u-boot:
ifneq ($(wildcard $(U_BOOT_PATH)/configs/stm32mp15_optee_defconfig),)
	$(U_BOOT_EXPORTS) $(MAKE) -C $(U_BOOT_PATH) stm32mp15_optee_defconfig
else
	$(U_BOOT_EXPORTS) $(MAKE) -C $(U_BOOT_PATH) stm32mp15_trusted_defconfig
endif
	$(U_BOOT_EXPORTS) $(MAKE) -C $(U_BOOT_PATH) DEVICE_TREE=$(STM32MP1_DTS_BASENAME) all
	@$(call install_in_binaries,$(U_BOOT_PATH)/$(U_BOOT_BIN))

u-boot-clean:
	$(U_BOOT_EXPORTS) $(MAKE) -C $(U_BOOT_PATH) clean

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := arm
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm/configs/multi_v7_defconfig \
		$(CURDIR)/kconfigs/stm32mp1.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm uImage LOADADDR=0xc2000000 \
		      CROSS_COMPILE=$(CROSS_COMPILE_NS_KERNEL) \
		      $(STM32MP1_DTS_BASENAME).dtb \
		      PATH=$$PATH:$(U_BOOT_PATH)/tools

linux: linux-common
	@$(call install_in_binaries,$(LINUX_PATH)/arch/arm/boot/$(LINUX_KERNEL_BIN))
	@$(call install_in_binaries,$(LINUX_PATH)/arch/arm/boot/dts/$(LINUX_DTB_BIN))

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm

linux-cleaner: linux-cleaner-common

################################################################################
# Buildroot
################################################################################

BR2_TARGET_GENERIC_ISSUE="OP-TEE embedded distrib for $(PLATFORM)"
BR2_TARGET_GENERIC_GETTY_PORT=ttySTM0
BR2_TARGET_ROOTFS_EXT2=y
BR2_PACKAGE_BUSYBOX_WATCHDOG=y

BREXT_BOARD_PATH=$(ROOT)/build/br-ext/board/stmicroelectronics/stm32mp1-tz
BREXT_GENIMAGE_CONFIG=$(BREXT_BOARD_PATH)/genimage-$(BREXT_FLAVOR).cfg
BREXT_BOOTFS_OVERLAY=$(BREXT_BOARD_PATH)/overlay-$(BREXT_FLAVOR)

BR2_PACKAGE_HOST_GENIMAGE=y
BR2_ROOTFS_POST_SCRIPT_ARGS="$(BREXT_GENIMAGE_CONFIG) $(BINARIES_PATH) $(BREXT_BOOTFS_OVERLAY)"
BR2_ROOTFS_POST_IMAGE_SCRIPT=$(BREXT_BOARD_PATH)/post-image.sh

# TF-A, Linux kernel, U-Boot and OP-TEE OS/Client/... are not built from their
# related Buildroot native package.
BR2_TARGET_ARM_TRUSTED_FIRMWARE=n
BR2_LINUX_KERNEL=n
BR2_TARGET_OPTEE_OS=n
BR2_TARGET_UBOOT=n
BR2_PACKAGE_OPTEE_CLIENT=n
BR2_PACKAGE_OPTEE_TEST=n
BR2_PACKAGE_OPTEE_EXAMPLES=n
BR2_PACKAGE_OPTEE_BENCHMARK=n

################################################################################
# We build the SD card image from Builroot but TF-A, OP-TEE OS, U-Boot and
# Linux kernel are build outside Buildroot. The get a clear picture of built
# images, images built outside Buildroot are installed (ln -s) in BINARIES_PATH
# and copied (cp -f) to Buildroot output images/ directory before make taget
# buildroot is processed.
################################################################################
define install_in_br_images
	cp -f $(BINARIES_PATH)/$1 $(ROOT)/out-br/images
endef

.PHONY: optee-os optee-os-clean
.PHONY: u-boot u-boot-clean
.PHONY: copy_images_to_br

buildroot: copy_images_to_br
copy_images_to_br: tfa optee-os u-boot linux
	@mkdir -p $(ROOT)/out-br/images
	$(call install_in_br_images,$(TFA_BIN))
	$(call install_in_br_images,$(U_BOOT_BIN))
	$(call install_in_br_images,$(LINUX_KERNEL_BIN))
	$(call install_in_br_images,$(LINUX_DTB_BIN))
	$(call install_in_br_images,$(OPTEE_HEADER_BIN))
	$(call install_in_br_images,$(OPTEE_PAGER_BIN))
	$(call install_in_br_images,$(OPTEE_PAGEABLE_BIN))
