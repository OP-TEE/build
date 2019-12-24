################################################################################
# Following variables defines how the NS_USER (Non-Secure User - Client
# Application), NS_KERNEL (Non-Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
COMPILE_NS_USER   ?= 64
COMPILE_NS_KERNEL ?= 64
COMPILE_S_USER    ?= 64
COMPILE_S_KERNEL  ?= 64

################################################################################
# Includes
################################################################################
include common.mk
include toolchain.mk

ifeq ($(DEBUG),1)
SCP_BUILD ?= debug
TFA_BUILD ?= debug
EDK2_BUILD ?= DEBUG
else
SCP_BUILD ?= release
TFA_BUILD ?= release
EDK2_BUILD ?= RELEASE
endif

################################################################################
# Paths to git projects and various binaries
################################################################################
BINARIES_PATH ?= $(ROOT)/out/bin
SCP_PATH ?= $(ROOT)/SCP-firmware
SCP_OUT ?= $(SCP_PATH)/build/product/synquacer
SCP_ROM ?= $(SCP_OUT)/scp_romfw/$(SCP_BUILD)/bin/scp_romfw.bin
SCP_RAM ?= $(SCP_OUT)/scp_ramfw/$(SCP_BUILD)/bin/scp_ramfw.bin
SCP_ROMRAM ?= $(SCP_OUT)/scp_romramfw.bin
TFA_PATH ?= $(ROOT)/trusted-firmware-a
TFA_OUT ?= $(TFA_PATH)/build/synquacer/$(TFA_BUILD)
TFA_BL31 ?= $(TFA_OUT)/bl31.bin
TFA_BL32 ?= $(TFA_OUT)/bl32.bin
TFA_FIP ?= $(TFA_OUT)/fip_all_arm_tf.bin
FIPTOOL ?= $(TFA_PATH)/tools/fiptool/fiptool
EDK2_PATH ?= $(ROOT)/edk2
EDK2_PLATFORMS_PATH ?= $(ROOT)/edk2-platforms
EDK2_NON_OSI_PATH ?= $(ROOT)/edk2-non-osi
EDK2_PKGS_PATH := "$(EDK2_PATH):$(EDK2_PLATFORMS_PATH):$(EDK2_NON_OSI_PATH)"
EDK2_FIP ?= $(EDK2_NON_OSI_PATH)/Platform/Socionext/DeveloperBox/fip_all_arm_tf.bin
EDK2_TOOLCHAIN ?= GCC5
EDK2_ARCH ?= AARCH64

################################################################################
# Targets
################################################################################
.PHONY: all
all: edk2 optee-os scp tfa

.PHONY: clean
clean: edk2-clean optee-os-clean scp-clean tfa-clean

################################################################################
# Toolchains
################################################################################
AARCH32_NONE_PATH		?= $(TOOLCHAIN_ROOT)/aarch32-none
AARCH32_NONE_CROSS_COMPILE	?= $(AARCH32_NONE_PATH)/bin/arm-none-eabi-
AARCH32_NONE_GCC_VERSION	?= gcc-arm-none-eabi-9-2019-q4-major-x86_64-linux
SRC_AARCH32_NONE_GCC		?= https://developer.arm.com/-/media/Files/downloads/gnu-rm/9-2019q4/RC2.1/$(AARCH32_NONE_GCC_VERSION).tar.bz2

toolchains: aarch32-none

.PHONY: aarch32-none
aarch32-none:
	$(call dltc,$(AARCH32_NONE_PATH),$(SRC_AARCH32_NONE_GCC),$(AARCH32_NONE_GCC_VERSION))

################################################################################
# SCP
################################################################################
SCP_FLAGS ?= \
	CC=$(AARCH32_NONE_CROSS_COMPILE)gcc \
	PRODUCT=synquacer \
	MODE=$(SCP_BUILD)

.PHONY: scp
scp: aarch32-none
	$(MAKE) -C $(SCP_PATH) $(SCP_FLAGS) all
	tr "\000" "\377" < /dev/zero | dd of=$(SCP_ROMRAM) bs=1 count=196608
	dd of=$(SCP_ROMRAM) if=$(SCP_ROM) bs=1 conv=notrunc seek=0
	dd of=$(SCP_ROMRAM) if=$(SCP_RAM) bs=1 seek=65536
	ln -sf $(SCP_ROMRAM) $(BINARIES_PATH)

.PHONY: scp-clean
scp-clean:
	rm -f $(SCP_ROMRAM)
	$(MAKE) -C $(SCP_PATH) $(SCP_FLAGS) clean

################################################################################
# Trusted Firmware A
################################################################################
TFA_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

TFA_FLAGS ?= \
	BL32=$(TFA_BL32) \
	PRELOADED_BL33_BASE=0x08200000 \
	DEBUG=$(DEBUG) \
	PLAT=synquacer \
	SPD=opteed \
	SQ_USE_SCMI_DRIVER=1

.PHONY: tfa
tfa: $(TFA_FIP)

.PHONY: tfa-clean
tfa-clean:
	$(TFA_EXPORTS) $(MAKE) -C $(TFA_PATH) $(TFA_FLAGS) clean

$(TFA_FIP): $(TFA_BL32)
	$(TFA_EXPORTS) $(MAKE) -C $(TFA_PATH) $(TFA_FLAGS) all fiptool
	$(FIPTOOL) create \
		--tb-fw $(TFA_BL31) \
		--soc-fw $(TFA_BL31) \
		--scp-fw $(TFA_BL31) \
		--tos-fw $< \
		$@

$(TFA_BL32): optee-os
	mkdir -p $(dir $@)
	$(AARCH64_CROSS_COMPILE)objcopy \
		-O binary $(OPTEE_OS_PATH)/out/arm/core/tee.elf $@

################################################################################
# EDK2 / Tianocore
################################################################################
define edk2-env
	export WORKSPACE=$(EDK2_PLATFORMS_PATH)
endef

define edk2-call
	$(EDK2_TOOLCHAIN)_$(EDK2_ARCH)_PREFIX=$(AARCH64_CROSS_COMPILE) \
	build -n `getconf _NPROCESSORS_ONLN` \
		-a $(EDK2_ARCH) -t $(EDK2_TOOLCHAIN) -b $(EDK2_BUILD) \
		-p Platform/Socionext/DeveloperBox/DeveloperBox.dsc
endef

.PHONY: edk2
edk2: $(EDK2_FIP)
	$(call edk2-env) && \
	export PACKAGES_PATH=$(EDK2_PKGS_PATH) && \
	source $(EDK2_PATH)/edksetup.sh && \
	$(MAKE) -j1 -C $(EDK2_PATH)/BaseTools && \
	$(call edk2-call) all

.PHONY: edk2-clean
edk2-clean: edk2-clean-common
	cd $(EDK2_NON_OSI_PATH) && \
		git checkout $(EDK2_FIP)

$(EDK2_FIP): $(TFA_FIP)
	cp $< $@

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += PLATFORM=synquacer
OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=synquacer

.PHONY: optee-os
optee-os: optee-os-common

.PHONY: optee-os-clean
optee-os-clean: optee-os-clean-common
