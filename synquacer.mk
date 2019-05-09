################################################################################
# Following variables defines how the NS_USER (Non-Secure User - Client
# Application), NS_KERNEL (Non-Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
COMPILE_NS_USER   ?= 64
COMPILE_NS_KERNEL ?= 64
COMPILE_S_USER    ?= 64
COMPILE_S_KERNEL  ?= 64

DEBUG ?= 0
ifeq ($(DEBUG),1)
TFA_BUILD ?= debug
else
TFA_BUILD ?= release
endif
ifeq ($(DEBUG),1)
EDK2_BUILD ?= DEBUG
else
EDK2_BUILD ?= RELEASE
endif

################################################################################
# Includes
################################################################################
include common.mk
include toolchain.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
TFA_PATH ?= $(ROOT)/arm-trusted-firmware
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

################################################################################
# Targets
################################################################################
.PHONY: all
all: edk2 optee-os tfa

.PHONY: clean
clean: edk2-clean optee-os-clean tfa-clean

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
	SPD=opteed

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
	GCC5_AARCH64_PREFIX=$(AARCH64_CROSS_COMPILE) \
	build -n `getconf _NPROCESSORS_ONLN` \
		-a "AARCH64" -t "GCC5" -b $(EDK2_BUILD) \
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
