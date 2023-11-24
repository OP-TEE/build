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
STM32MP1_DTS_LINUX 	?= $(STM32MP1_DTS_BASENAME)-scmi
STM32MP1_DTS_U_BOOT 	?= $(STM32MP1_DTS_BASENAME)-scmi
WITH_SRAM1_PAGER_POOL	?= y
else ifeq ($(PLATFORM),stm32mp1-157A_DHCOR_AVENGER96)
BREXT_FLAVOR		= STM32MP157A-DHCOR-AVENGER96
STM32MP1_DTS_BASENAME	= stm32mp157a-dhcor-avenger96
STM32MP1_DTS_U_BOOT	= stm32mp15xx-dhcor-avenger96
else ifeq ($(PLATFORM),stm32mp1-157C_DHCOM_PDK2)
BREXT_FLAVOR		= STM32MP157C-DHCOM-PDK2
STM32MP1_DTS_BASENAME	= stm32mp157c-dhcom-pdk2
STM32MP1_DTS_U_BOOT	= stm32mp15xx-dhcom-pdk2
else ifeq ($(PLATFORM),stm32mp1-157C_DK2)
BREXT_FLAVOR		= STM32MP157C-DK2
STM32MP1_DTS_BASENAME	= stm32mp157c-dk2
STM32MP1_DTS_LINUX 	?= $(STM32MP1_DTS_BASENAME)-scmi
STM32MP1_DTS_U_BOOT 	?= $(STM32MP1_DTS_BASENAME)-scmi
WITH_SRAM1_PAGER_POOL	?= y
else ifeq ($(PLATFORM),stm32mp1-157C_EV1)
BREXT_FLAVOR		= STM32MP157C-EV1
STM32MP1_DTS_BASENAME	= stm32mp157c-ev1
STM32MP1_DTS_LINUX 	?= $(STM32MP1_DTS_BASENAME)-scmi
STM32MP1_DTS_U_BOOT 	?= $(STM32MP1_DTS_BASENAME)-scmi
WITH_SRAM1_PAGER_POOL	?= y
CFG_RPMB_FS_DEV_ID	= 1
else ifeq ($(PLATFORM),stm32mp1-157C_ED1)
BREXT_FLAVOR		= STM32MP157C-ED1
STM32MP1_DTS_BASENAME	= stm32mp157c-ed1
STM32MP1_DTS_LINUX 	?= $(STM32MP1_DTS_BASENAME)-scmi
STM32MP1_DTS_U_BOOT 	?= $(STM32MP1_DTS_BASENAME)-scmi
WITH_SRAM1_PAGER_POOL	?= y
else ifeq ($(PLATFORM),stm32mp1-135F_DK)
BREXT_FLAVOR		= STM32MP135F-DK
STM32MP1_DTS_BASENAME	= stm32mp135f-dk
STM32MP1_DEFCONFIG_U_BOOT = stm32mp13_defconfig
else
$(error Unknown PLATFORM $(PLATFORM))
endif

STM32MP1_DTS_LINUX ?= $(STM32MP1_DTS_BASENAME)
STM32MP1_DTS_U_BOOT ?= $(STM32MP1_DTS_BASENAME)
STM32MP1_DEFCONFIG_U_BOOT ?= stm32mp15_defconfig

# When enabled WITH_RPMB_TEST enables RPMB secure storage test configuration.
# The configuraiton enables OP-TEE RPMB test key (CFG_RPMB_TESTKEY=y)
# and CFG_REE_FS_ALLOW_RESET to allow testing with an empty REE_FS secure
# storage content wihtout needing to reset the full RPMB_FS secure storage.
# This configuration switch is intended to platforms with an eMMC device.
WITH_RPMB_TEST ?= n

# When enabled WITH_SRAM1_PAGER_POOL makes OP-TEE pager core to use secure
# SYSRAM and SRAM1. This switch concerns STM32MP15 based platforms only.
WITH_SRAM1_PAGER_POOL ?= n

################################################################################
# Binary images names
################################################################################

TFA_BIN			:= tf-a-$(STM32MP1_DTS_BASENAME).stm32
TFA_FIP_BIN		:= fip.bin
OPTEE_HEADER_BIN	:= tee-header_v2.bin
OPTEE_PAGER_BIN		:= tee-pager_v2.bin
OPTEE_PAGEABLE_BIN  	:= tee-pageable_v2.bin
U_BOOT_BIN		:= u-boot.bin
U_BOOT_DTB		:= u-boot.dtb
LINUX_KERNEL_BIN 	:= uImage

################################################################################
# Paths to git projects and various binaries
################################################################################
BINARIES_PATH		?= $(ROOT)/out/bin
TFA_PATH		?= $(ROOT)/trusted-firmware-a
U_BOOT_PATH		?= $(ROOT)/u-boot
SCPFW_PATH		?= $(ROOT)/scp-firmware

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
ifeq ($(WITH_RPMB_TEST),y)
CFG_RPMB_FS_DEV_ID ?= 1
OPTEE_OS_COMMON_FLAGS += \
		CFG_RPMB_FS_DEV_ID=$(CFG_RPMB_FS_DEV_ID) \
		CFG_RPMB_FS=y \
		CFG_RPMB_TESTKEY=y \
		CFG_REE_FS_ALLOW_RESET=y
endif # WITH_RPMB_TEST

ifeq ($(WITH_SRAM1_PAGER_POOL),y)
OPTEE_OS_COMMON_FLAGS += CFG_TZSRAM_SIZE=0x60000
endif # WITH_SRAM1_PAGER_POOL

# Provide scp-firmware source tree path in case CFG_SCMI_SERVER is enabled
OPTEE_OS_COMMON_FLAGS += CFG_SCP_FIRMWARE=$(SCPFW_PATH)

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
	BL33_CFG=$(BINARIES_PATH)/$(U_BOOT_DTB) \
	ARM_ARCH_MAJOR=7 \
	ARCH=aarch32 \
	PLAT=stm32mp1 \
	DTB_FILE_NAME=$(STM32MP1_DTS_BASENAME).dtb \
	AARCH32_SP=optee \
	DEBUG=$(TFA_DEBUG) \
	LOG_LEVEL=$(TFA_LOGLVL) \
	STM32MP15_OPTEE_RSV_SHM=0 \
	STM32MP_EMMC=1 STM32MP_SDMMC=1 \
	STM32MP_RAW_NAND=0 STM32MP_SPI_NAND=0 STM32MP_SPI_NOR=0

tfa: optee-os u-boot
	$(TFA_EXPORTS) $(MAKE) -C $(TFA_PATH) $(TFA_FLAGS) all fip
	@$(call install_in_binaries,$(TFA_OUT)/$(TFA_BIN))
	@$(call install_in_binaries,$(TFA_OUT)/$(TFA_FIP_BIN))

tfa-clean:
	$(TFA_EXPORTS) $(MAKE) -C $(TFA_PATH) $(TFA_FLAGS) clean

################################################################################
# U-Boot
################################################################################
U_BOOT_EXPORTS ?= CROSS_COMPILE="$(CCACHE)$(AARCH32_CROSS_COMPILE)"

u-boot:
	$(U_BOOT_EXPORTS) $(MAKE) -C $(U_BOOT_PATH) $(STM32MP1_DEFCONFIG_U_BOOT)
	$(U_BOOT_EXPORTS) $(MAKE) -C $(U_BOOT_PATH) DEVICE_TREE=$(STM32MP1_DTS_U_BOOT) all
	@$(call install_in_binaries,$(U_BOOT_PATH)/$(U_BOOT_BIN))
	@$(call install_in_binaries,$(U_BOOT_PATH)/$(U_BOOT_DTB))

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
		      st/$(STM32MP1_DTS_LINUX).dtb \
		      PATH=$$PATH:$(U_BOOT_PATH)/tools

linux: linux-common
	@$(call install_in_binaries,$(LINUX_PATH)/arch/arm/boot/$(LINUX_KERNEL_BIN))
	@$(call install_in_binaries,$(LINUX_PATH)/arch/arm/boot/dts/st/$(STM32MP1_DTS_LINUX).dtb)

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

ifeq ($(WITH_RPMB_TEST),y)
# Use S30optee init.d script that runs tee-supplicant as root
BR2_ROOTFS_OVERLAY=$(BREXT_BOARD_PATH)/overlay-$(BREXT_FLAVOR)-rpmb
# Disable RPMB emulation in tee-supplicant
BR2_PACKAGE_OPTEE_CLIENT_EXT_RPMB_EMU=n
endif # WITH_RPMB_TEST

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
	$(call install_in_br_images,$(TFA_FIP_BIN))
	$(call install_in_br_images,$(U_BOOT_BIN))
	$(call install_in_br_images,$(U_BOOT_DTB))
	$(call install_in_br_images,$(LINUX_KERNEL_BIN))
	$(call install_in_br_images,$(STM32MP1_DTS_LINUX).dtb)
	$(call install_in_br_images,$(OPTEE_HEADER_BIN))
	$(call install_in_br_images,$(OPTEE_PAGER_BIN))
	$(call install_in_br_images,$(OPTEE_PAGEABLE_BIN))
