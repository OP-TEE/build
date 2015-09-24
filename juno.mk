DEBUG ?= 1

-include common.mk

################################################################################
# Mandatory definition to use common.mk
################################################################################
CROSS_COMPILE_NS_USER	?= "$(CCACHE)$(AARCH64_CROSS_COMPILE)"
CROSS_COMPILE_NS_KERNEL	?= "$(CCACHE)$(AARCH64_CROSS_COMPILE)"
CROSS_COMPILE_S_USER	?= "$(CCACHE)$(AARCH32_CROSS_COMPILE)"
CROSS_COMPILE_S_KERNEL	?= "$(CCACHE)$(AARCH32_CROSS_COMPILE)"
OPTEE_OS_BIN		?= $(OPTEE_OS_PATH)/out/arm-plat-vexpress/core/tee.bin
OPTEE_OS_TA_DEV_KIT_DIR	?= $(OPTEE_OS_PATH)/out/arm-plat-vexpress/export-user_ta

################################################################################
# Paths to git projects and various binaries
################################################################################
ARM_TF_PATH		?= $(ROOT)/arm-trusted-firmware

################################################################################
# Targets
################################################################################
all: arm-tf linux optee-os optee-client optee-linuxdriver xtest
all-clean: arm-tf-clean optee-os-clean \
	optee-client-clean optee-linuxdriver-clean xtest-clean

-include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
BL30 ?= $(ROOT)/pre-built-binaries/bl30.bin
BL33 ?= $(ROOT)/pre-built-binaries/bl33.bin

pre-built-binaries:
	@if [ ! -e "$(BL30)" ]; then \
		mkdir -p $(ROOT)/pre-built-binaries && \
		cp $(ROOT)/build/patches/bl30.bin $(BL30) ; \
	fi
	@if [ ! -e "$(BL33)" ]; then \
		mkdir -p $(ROOT)/pre-built-binaries && \
		cp $(ROOT)/build/patches/bl33.bin $(BL33) ; \
	fi

ARM_TF_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_NONE_CROSS_COMPILE)"

ARM_TF_FLAGS ?= \
       DEBUG=1 \
       PLAT_TSP_LOCATION=dram \
       PLAT=juno \
       SPD=opteed \
       BL30=$(BL30) \
       BL32=$(OPTEE_OS_BIN) \
       BL33=$(BL33)

arm-tf: optee-os pre-built-binaries
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) all fip

arm-tf-clean:
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) clean


################################################################################
# Linux kernel
################################################################################

$(LINUX_PATH)/.config:
	$(MAKE) -C $(LINUX_PATH) ARCH=arm64 defconfig
	cd $(LINUX_PATH) && git checkout arch/arm64/boot/dts/juno.dts
	patch -N -b $(LINUX_PATH)/arch/arm64/boot/dts/juno.dts < $(ROOT)/build/patches/juno.dts.linux-linaro-tracking.a226b22057c22b433caafc58eeae6e9b13ac6c8d.patch
	patch -N -b $(LINUX_PATH)/.config < $(ROOT)/build/patches/config.linux-linaro-tracking.a226b22057c22b433caafc58eeae6e9b13ac6c8d.patch

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
OPTEE_OS_COMMON_FLAGS += PLATFORM=vexpress-juno
optee-os: optee-os-common

OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=vexpress-juno
optee-os-clean: optee-os-clean-common

optee-client: optee-client-common

optee-client-clean: optee-client-clean-common

OPTEE_LINUXDRIVER_COMMON_FLAGS += ARCH=arm64
# Required patch as Juno is based on an "old" linux, with the old
# dma_buf interface
optee-linuxdriver-patch:
	sed -i 's/O_RDWR, 0/O_RDWR/g' $(OPTEE_LINUXDRIVER_PATH)/core/tee_shm.c

optee-linuxdriver:| optee-linuxdriver-patch optee-linuxdriver-common

OPTEE_LINUXDRIVER_CLEAN_COMMON_FLAGS += ARCH=arm64
optee-linuxdriver-clean: optee-linuxdriver-clean-common

################################################################################
# xtest / optee_test
################################################################################
xtest: xtest-common

xtest-clean: xtest-clean-common

xtest-patch: xtest-patch-common
