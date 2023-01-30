################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER    := 64
override COMPILE_S_KERNEL  := 64

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

PLATFORM = versal-vck190
OPTEE_OS_PLATFORM = versal
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

TF_A_EXPORTS = CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"
TF_A_FLAGS = PLAT=versal VERSAL_CONSOLE=pl011 RESET_TO_BL31=1 SPD=opteed DEBUG=1

tfa:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) bl31

tfa-clean:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) clean

################################################################################
# OP-TEE
#################################################################################

optee-os: optee-os-common

optee-os-clean: optee-os-clean-common
	rm -f ${OPTEE_OS_PATH}/out/arm/core/tee_raw.bin

################################################################################
# U-Boot
################################################################################

U-BOOT_EXPORTS = CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"
U-BOOT_CONFIG = xilinx_versal_virt_defconfig
U-BOOT_DTS = versal-vck190-revA

u-boot:
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) $(U-BOOT_CONFIG)
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) DEVICE_TREE=$(U-BOOT_DTS) DTC_FLAGS="-@"

u-boot-clean:
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean

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
		$(LINUX_PATH)/arch/arm64/configs/xilinx_versal_defconfig \
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
# Bouildroot
###############################################################################

BR2_TARGET_GENERIC_ISSUE="OP-TEE embedded distrib for $(PLATFORM)"
BR2_TARGET_ROOTFS_EXT2=y
BR2_PACKAGE_BUSYBOX_WATCHDOG=y

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


###############################################################################
# Images
###############################################################################
image: bootimage fitimage
image-clean: bootimage-clean fitimage-clean

###############################################################################
# Boot Image
###############################################################################

bootimage: bootgen tfa optee-os u-boot
	$(BOOTGEN_PATH)/bootgen -arch versal -image versal/bootImage-${PLATFORM}.bif -w -o versal/BOOT.BIN

bootimage-clean: bootgen-clean tfa-clean optee-os-clean u-boot-clean
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

fitimage: linux dtbo buildroot
	${U-BOOT_PATH}/tools/mkimage -f versal/fitImage-${PLATFORM}.its versal/${PLATFORM}.ub

fitimage-clean: linux-clean dtbo-clean buildroot-clean
	rm -f versal/${PLATFORM}.ub

