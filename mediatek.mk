################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER    := 32
override COMPILE_S_KERNEL  := 64

-include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
MTK_TOOLS_PATH 			?= $(ROOT)/mtk_tools
ARM_TF_PATH			?= $(ROOT)/arm-trusted-firmware
OPTEE_OS_PAGER_BIN		?= $(OPTEE_OS_PATH)/out/arm/core/tee-pager.bin
ARM_TF_BIN			?= $(ARM_TF_PATH)/build/mt8173/debug/bl31.bin

################################################################################
# Targets
################################################################################
all: arm-tf linux optee-os optee-client xtest optee-examples
clean: arm-tf-clean linux-clean busybox-clean optee-os-clean \
	optee-client-clean optee-examples-clean

-include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
ARM_TF_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

ARM_TF_FLAGS ?= \
	DEBUG=1 \
	PLAT=mt8173 \
	SPD=opteed

arm-tf: optee-os
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) all

arm-tf-clean:
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) clean

################################################################################
# Busybox
################################################################################
BUSYBOX_COMMON_TARGET = mt8173-evb
BUSYBOX_CLEAN_COMMON_TARGET = mt8173-evb clean

busybox: busybox-common

busybox-clean: busybox-clean-common

busybox-cleaner: busybox-cleaner-common

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
                $(LINUX_PATH)/arch/arm64/configs/defconfig \
                $(CURDIR)/kconfigs/mediatek.conf

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
OPTEE_OS_COMMON_FLAGS += PLATFORM=mediatek-mt8173
optee-os: optee-os-common

OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=mediatek-mt8173
optee-os-clean: optee-os-clean-common

optee-client: optee-client-common

optee-client-clean: optee-client-clean-common


################################################################################
# xtest / optee_test
################################################################################
xtest: xtest-common
xtest-clean: xtest-clean-common
xtest-patch: xtest-patch-common

################################################################################
# Sample applications / optee_examples
################################################################################
optee-examples: optee-examples-common

optee-examples-clean: optee-examples-clean-common

################################################################################
# Root FS
################################################################################
filelist-tee: filelist-tee-common

update_rootfs: update_rootfs-common

################################################################################
# Image Tools
################################################################################
.PHONY: build_image flash_image run
build-image: update_rootfs optee-os
	cd $(MTK_TOOLS_PATH); \
	./build_trustzone.sh $(OPTEE_OS_PAGER_BIN) $(ARM_TF_BIN); \
	./build_bootimg.sh $(LINUX_PATH) $(GEN_ROOTFS_PATH)/filesystem.cpio.gz

flash-image: build-image
	@echo "Please press reset button ..."
	@cd $(MTK_TOOLS_PATH); \
	./fastboot flash boot ./boot.img; \
	./fastboot flash TEE1 ./trustzone.bin
	@echo "Please press reset button again..."

flash: flash-image
