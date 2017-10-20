DEBUG ?= 1

################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
COMPILE_NS_USER   ?= 64
override COMPILE_NS_KERNEL := 64
COMPILE_S_USER    ?= 64
COMPILE_S_KERNEL  ?= 64

-include common.mk


################################################################################
# Paths to git projects and various binaries
################################################################################
ARM_TF_PATH		?= $(ROOT)/arm-trusted-firmware
EDK2_PATH		?= $(ROOT)/edk2
EDK2_BIN		?= $(EDK2_PATH)/Build/ArmVExpress-FVP-AArch64/RELEASE_GCC49/FV/FVP_AARCH64_EFI.fd
FOUNDATION_PATH		?= $(ROOT)/Foundation_Platformpkg
ifeq ($(wildcard $(FOUNDATION_PATH)),)
$(error $(FOUNDATION_PATH) does not exist)
endif

################################################################################
# Targets
################################################################################
all: arm-tf edk2 linux optee-os optee-client xtest optee-examples
clean: arm-tf-clean busybox-clean edk2-clean optee-os-clean \
	optee-client-clean optee-examples-clean


-include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
ARM_TF_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

ARM_TF_FLAGS ?= \
	BL32=$(OPTEE_OS_HEADER_V2_BIN) \
	BL32_EXTRA1=$(OPTEE_OS_PAGER_V2_BIN) \
	BL32_EXTRA2=$(OPTEE_OS_PAGEABLE_V2_BIN) \
	BL33=$(EDK2_BIN) \
	DEBUG=0 \
	ARM_TSP_RAM_LOCATION=tdram \
	FVP_USE_GIC_DRIVER=FVP_GICV3_LEGACY \
	PLAT=fvp \
	SPD=opteed

arm-tf: optee-os edk2
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) all fip

arm-tf-clean:
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) clean

################################################################################
# Busybox
################################################################################
BUSYBOX_COMMON_TARGET = fvp
BUSYBOX_CLEAN_COMMON_TARGET = fvp clean

busybox: busybox-common

busybox-clean: busybox-clean-common

busybox-cleaner: busybox-cleaner-common

################################################################################
# EDK2 / Tianocore
################################################################################
define edk2-call
	GCC49_AARCH64_PREFIX=$(LEGACY_AARCH64_CROSS_COMPILE) \
	     $(MAKE) -j1 -C $(EDK2_PATH) \
	     -f ArmPlatformPkg/Scripts/Makefile EDK2_ARCH=AARCH64 \
	     EDK2_DSC=ArmPlatformPkg/ArmVExpressPkg/ArmVExpress-FVP-AArch64.dsc \
	     EDK2_TOOLCHAIN=GCC49 EDK2_BUILD=RELEASE \
	     EDK2_MACROS="-n 6 -D ARM_FOUNDATION_FVP=1 -D ARM_FVP_BOOT_ANDROID_FROM_SEMIHOSTING=1"
endef

edk2: edk2-common

edk2-clean: edk2-clean-common

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm64/configs/defconfig \
		$(CURDIR)/kconfigs/fvp.conf

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
OPTEE_OS_COMMON_FLAGS += PLATFORM=vexpress-fvp
optee-os: optee-os-common

OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=vexpress-fvp
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
# Run targets
################################################################################
# This target enforces updating root fs etc
run: all
	$(MAKE) update_rootfs
	$(MAKE) run-only

run-only:
	@ln -sf $(LINUX_PATH)/arch/arm64/boot/Image $(FOUNDATION_PATH)/kernel
	@ln -sf $(GEN_ROOTFS_PATH)/filesystem.cpio.gz $(FOUNDATION_PATH)/ramdisk.img
	@ln -sf $(LINUX_PATH)/arch/arm64/boot/Image $(FOUNDATION_PATH)/Image
	@ln -sf $(GEN_ROOTFS_PATH)/filesystem.cpio.gz $(FOUNDATION_PATH)/filesystem.cpio.gz
	@ln -sf $(LINUX_PATH)/arch/arm64/boot/dts/arm/foundation-v8.dtb $(FOUNDATION_PATH)/fdt.dtb
	@cd $(FOUNDATION_PATH); \
	$(FOUNDATION_PATH)/models/Linux64_GCC-4.9/Foundation_Platform \
	--arm-v8.0 \
	--cores=4 \
	--secure-memory \
	--visualization \
	--gicv3 \
	--data="$(ARM_TF_PATH)/build/fvp/release/bl1.bin"@0x0 \
	--data="$(ARM_TF_PATH)/build/fvp/release/fip.bin"@0x8000000

