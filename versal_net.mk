################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER    := 64
override COMPILE_S_KERNEL  := 64

WITH_CXX_TESTS = n

# Network support related packages:
BR2_PACKAGE_DHCPCD ?= y
BR2_PACKAGE_ETHTOOL ?= y
BR2_PACKAGE_XINETD ?= y

# SSH Packages :
BR2_PACKAGE_OPENSSH ?= y
BR2_PACKAGE_OPENSSH_SERVER ?= y
BR2_PACKAGE_OPENSSH_KEY_UTILS ?= y

# Openssl binary
BR2_PACKAGE_LIBOPENSSL_BIN ?= y

BR2_TARGET_GENERIC_GETTY_PORT ?= ttyAMA1

PLATFORM = versal-net-vnx-b2197-revA
OPTEE_OS_PLATFORM = versal-net
OPTEE_OS_COMMON_EXTRA_FLAGS = CFG_PKCS11_TA=y CFG_USER_TA_TARGET_pkcs11=ta_arm64 O=out/arm

################################################################################
# Paths to git projects and various binaries
################################################################################
TF_A_PATH		?= $(ROOT)/arm-trusted-firmware
U-BOOT_PATH		?= $(ROOT)/u-boot
BOOTGEN_PATH		?= $(ROOT)/bootgen
LINUX_PATH		?= $(ROOT)/linux

include common.mk

################################################################################
# Targets
################################################################################

all: tfa optee-os u-boot linux dtbo buildroot
clean: tfa-clean optee-os-clean u-boot-clean linux-clean dtbo-clean buildroot-clean

include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################

TF_A_EXPORTS = CROSS_COMPILE="$(AARCH64_CROSS_COMPILE)" \
	       CC="$(CCACHE)$(AARCH64_CROSS_COMPILE)gcc" \
	       LD="$(CCACHE)$(AARCH64_CROSS_COMPILE)ld"
TF_A_FLAGS = PLAT=versal_net VERSAL_NET_CONSOLE=pl011 RESET_TO_BL31=1 SPD=opteed DEBUG=1 \
	     VERSAL_NET_ATF_MEM_BASE=0x26200000 VERSAL_NET_ATF_MEM_SIZE=0x100000

tfa:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) bl31

tfa-clean:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) clean

################################################################################
# OP-TEE
#################################################################################

optee-os: optee-os-common

optee-os-clean: optee-os-clean-common

################################################################################
# U-Boot
################################################################################

U-BOOT_EXPORTS = CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"
U-BOOT_DTS = xilinx-versal-net-virt
U-BOOT_DEFCONFIG_COMMON_FILES = \
	$(UBOOT_PATH)/configs/xilinx_versal_net_virt_defconfig \
	$(CURDIR)/kconfigs/versal.conf

$(UBOOT_PATH)/.config: $(U-BOOT_CONFIG_COMMON_FILES)
	cd $(UBOOT_PATH) && \
		$(U-BOOT_EXPORTS) \
		scripts/kconfig/merge_config.sh $(U-BOOT_DEFCONFIG_COMMON_FILES)

u-boot: u-boot-defconfig
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) DEVICE_TREE=$(U-BOOT_DTS) DTC_FLAGS="-@"

u-boot-clean: u-boot-defconfig-clean
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean

u-boot-defconfig: $(UBOOT_PATH)/.config

.PHONY: u-boot-defconfig-clean
u-boot-defconfig-clean:
	rm -f $(UBOOT_PATH)/.config

###############################################################################
# Device-Tree
###############################################################################
dtbo: linux
	${LINUX_PATH}/scripts/dtc/dtc -@ -I dts -O dtb -o versal/versal-optee.dtbo versal/versal-optee.dtso

dtbo-clean:
	rm -f versal/versal-optee.dtbo

################################################################################
# Linux kernel
################################################################################

LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm64/configs/xilinx_versal_net_defconfig \
		$(CURDIR)/kconfigs/versal.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64 -j8

linux: linux-common

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

linux-cleaner: linux-cleaner-common

###############################################################################
# Buildroot
###############################################################################

BR2_TARGET_GENERIC_ISSUE ?= "OP-TEE embedded distrib for $(PLATFORM)"
BR2_TARGET_ROOTFS_EXT2 ?= y
BR2_PACKAGE_BUSYBOX_WATCHDOG ?= y

# TF-A, Linux kernel, U-Boot and OP-TEE OS/Client/... are not built from their
# related Buildroot native package.
BR2_TARGET_ARM_TRUSTED_FIRMWARE ?= n
BR2_LINUX_KERNEL ?= n
BR2_TARGET_OPTEE_OS ?= n
BR2_TARGET_UBOOT ?= n


###############################################################################
# Images
###############################################################################
image: bootimage
image-clean: bootimage-clean

###############################################################################
# Boot Image
###############################################################################

bootimage: bootgen tfa optee-os u-boot linux dtbo fitimage
	$(BOOTGEN_PATH)/bootgen -arch versalnet -image versal/bootImage-${PLATFORM}.bif -w -o versal/BOOT.BIN

bootimage-clean: bootgen-clean tfa-clean optee-os-clean u-boot-clean linux-clean dtbo-clean fitimage-clean
	rm -f versal/BOOT.BIN


###############################################################################
# Bootgen
###############################################################################

bootgen:
	make -C $(BOOTGEN_PATH)

bootgen-clean:
	make -C $(BOOTGEN_PATH) clean


###############################################################################
# FIT Image
###############################################################################

fitimage: buildroot
	${U-BOOT_PATH}/tools/mkimage -f versal/fitImage-${PLATFORM}.its versal/${PLATFORM}.ub

fitimage-clean: buildroot-clean
	rm -f versal/${PLATFORM}.ub

