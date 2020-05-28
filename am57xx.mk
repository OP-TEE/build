###############################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
###############################################################################
override COMPILE_NS_USER   := 32
override COMPILE_NS_KERNEL := 32
override COMPILE_S_USER    := 32
override COMPILE_S_KERNEL  := 32

# Need to set this before including common.mk
BR2_TARGET_GENERIC_GETTY_PORT ?= ttyS2

###############################################################################
# Includes
###############################################################################
include common.mk

###############################################################################
# Paths to git projects and various binaries
###############################################################################
STAGING_AREA    ?= $(ROOT)/out
U-BOOT_PATH     ?= $(ROOT)/u-boot
UBOOT_SPL       ?= $(U-BOOT_PATH)/u-boot-spl_HS_MLO
UBOOT_IMG       ?= $(U-BOOT_PATH)/u-boot_HS.img
UBOOT_ENV       ?= $(BUILD_PATH)/ti/uEnv.txt
LINUX_IMAGE     ?= $(LINUX_PATH)/arch/arm/boot/zImage
LINUX_DTBS      ?= $(wildcard $(LINUX_PATH)/arch/arm/boot/dts/am57*.dtb)
FIT_SOURCE      ?= $(BUILD_PATH)/ti/fitImage-am57xx.its
FIT_MAKEFILE    ?= $(BUILD_PATH)/ti/Makefile
OPTEE_OS_PLATFORM ?= ti-am57xx
U-BOOT_CONFIG   ?= am57xx_hs_evm_defconfig
# using the same configs as for DRA7xx
CONFIG_TYPE     ?= ti_sdk_dra7x_debug

###############################################################################
# Include common to TI builds
###############################################################################
include ti/ti-common.mk
