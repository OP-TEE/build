FVP_VIRTFS_ENABLE		?= y
FVP_VIRTFS_AUTOMOUNT		?= y
MEASURED_BOOT			?= y
MEASURED_BOOT_FTPM		?= n
TS_SMM_GATEWAY			?= y
TS_LOGGING_SP			?= y
TS_LOGGING_SP_LOG		?= "trusted-services-logs.txt"
TS_UEFI_TESTS			?= n
TS_FW_UPDATE			?= n
TS_UEFI_AUTH_VAR 		?= y
TS_UEFI_INTERNAL_CRYPTO	?= n
# Supported values: embedded, fip
SP_PACKAGING_METHOD		?= embedded
SPMC_TESTS			?= n
SPMC_AT_EL			?= 1

# Behaves a similar way like BRANCH_PROTECTION in TF-A:
# unset: Default value. mbranch-protection flag is not provided
# 0: Turns off all types of branch protection
# 1: Enables all types of branch protection features
# 2: Return address signing to its standard level
# 3: Extend the signing to include leaf functions
# 4: Turn on branch target identification mechanism
TS_BRANCH_PROTECTION		?= unset
BRANCH_PROTECTION_OPTIONS	:= unset 0 1 2 3 4

ifeq ($(filter $(TS_BRANCH_PROTECTION),$(BRANCH_PROTECTION_OPTIONS)),)
  $(error TS_BRANCH_PROTECTION is not set to a valid option)
endif

ifneq ($(TS_UEFI_AUTH_VAR)-$(TS_SMM_GATEWAY),y-y)
SP_SMM_GATEWAY_EXTRA_FLAGS += -DUEFI_AUTH_VAR=OFF
TS_APP_UEFI_TEST_EXTRA_FLAGS += -DUEFI_AUTH_VAR=OFF
endif

ifeq ($(TS_UEFI_INTERNAL_CRYPTO),y)
SP_SMM_GATEWAY_EXTRA_FLAGS += -DUEFI_INTERNAL_CRYPTO=ON
endif

# Enable the "HArdware Volatile Entropy Gathering and Expansion" daemon to
# overcome low-entropy conditions in the FVP
BR2_PACKAGE_HAVEGED		?= y

# Disable packages not used by this configuration
BR2_PACKAGE_HOST_E2FSPROGS	?= n
BR2_PACKAGE_KEYUTILS		?= n
BR2_PACKAGE_MMC_UTILS		?= n
BR2_PACKAGE_OPENSC		?= n
BR2_PACKAGE_OPTEE_EXAMPLES_EXT	?= n
BR2_PACKAGE_STRACE		?= n

# Building xtest is not necessary if we don't want to run the SPMC tests
ifneq ($(SPMC_TESTS),y)
BR2_PACKAGE_OPTEE_TEST_EXT	?= n
BR2_PACKAGE_LIBOPENSSL		?= n
BR2_PACKAGE_OPENSSL		?= n
endif

# TS SP configurations
DEFAULT_SP_CONFIG		?= default-opteesp
SP_BLOCK_STORAGE_CONFIG	?= $(DEFAULT_SP_CONFIG)
SP_PSA_ITS_CONFIG		?= $(DEFAULT_SP_CONFIG)
SP_PSA_PS_CONFIG		?= $(DEFAULT_SP_CONFIG)
SP_PSA_CRYPTO_CONFIG		?= $(DEFAULT_SP_CONFIG)
SP_PSA_ATTESTATION_CONFIG	?= $(DEFAULT_SP_CONFIG)
SP_SMM_GATEWAY_CONFIG		?= $(DEFAULT_SP_CONFIG)
SP_FWU_CONFIG			?= $(DEFAULT_SP_CONFIG)
SP_LOGGING_CONFIG		?= $(DEFAULT_SP_CONFIG)

LINUX_DEFCONFIG_COMMON_FILES ?= $(CURDIR)/kconfigs/fvp_trusted-services.conf

include fvp.mk
include trusted-services.mk

# The macros used in bl2_sp_list.dts and spmc_manifest.dts has to be passed to
# TF-A because it handles the preprocessing of these files.
define add-dtc-define
DTC_CPPFLAGS+=-D$1=$(subst y,1,$(subst n,0,$($1)))
endef

ifeq ($(SP_PACKAGING_METHOD),fip)
$(eval $(call add-dtc-define,SPMC_TESTS))
$(eval $(call add-dtc-define,TS_SMM_GATEWAY))
$(eval $(call add-dtc-define,TS_FW_UPDATE))
$(eval $(call add-dtc-define,TS_LOGGING_SP))

TF_A_EXPORTS += DTC_CPPFLAGS="$(DTC_CPPFLAGS)"
endif

OPTEE_OS_COMMON_EXTRA_FLAGS += \
	CFG_SECURE_PARTITION=y \
	CFG_CORE_SEL1_SPMC=y \
	CFG_CORE_HEAP_SIZE=131072 \
	CFG_DT=y \
	CFG_MAP_EXT_DT_SECURE=y

# If branch protection is unset, do not pass it
ifeq ($(filter $(TS_BRANCH_PROTECTION),unset),)
TF_A_FLAGS              += BRANCH_PROTECTION=$(TS_BRANCH_PROTECTION)
TS_APP_COMMON_FLAGS	+= -DBRANCH_PROTECTION=$(TS_BRANCH_PROTECTION)
SP_COMMON_FLAGS		+= -DBRANCH_PROTECTION=$(TS_BRANCH_PROTECTION)
endif

# Branch Target Identification enablement
ifneq ($(filter $(TS_BRANCH_PROTECTION),1 4),)
OPTEE_OS_COMMON_EXTRA_FLAGS += CFG_CORE_BTI=y
OPTEE_OS_COMMON_EXTRA_FLAGS += CFG_TA_BTI=y

FVP_EXTRA_ARGS += -C cluster0.has_branch_target_exception=2
FVP_EXTRA_ARGS += -C cluster1.has_branch_target_exception=2
FVP_EXTRA_ARGS += -C cluster0.has_arm_v8-5=1
FVP_EXTRA_ARGS += -C cluster1.has_arm_v8-5=1
endif

# Pointer Authentication enablement
ifneq ($(filter $(TS_BRANCH_PROTECTION),1 2 3),)
OPTEE_OS_COMMON_EXTRA_FLAGS += CFG_CORE_PAUTH=y
OPTEE_OS_COMMON_EXTRA_FLAGS += CFG_TA_PAUTH=y

FVP_EXTRA_ARGS += -C cluster0.has_pointer_authentication=2
FVP_EXTRA_ARGS += -C cluster1.has_pointer_authentication=2
endif

# The boot order of the SPs is determined by the order of calls here. This is
# due to the SPMC not (yet) supporting the boot order field of the SP manifest.
ifeq ($(SPMC_TESTS),n)
# LOGGING SP
ifeq ($(TS_LOGGING_SP),y)
$(eval $(call build-sp,logging,config/$(SP_LOGGING_CONFIG),da9dffbd-d590-40ed-975f-19c65a3d52d3,$(SP_LOGGING_EXTRA_FLAGS)))
endif
# PSA SPs
$(eval $(call build-sp,block-storage,config/$(SP_BLOCK_STORAGE_CONFIG),63646e80-eb52-462f-ac4f-8cdf3987519c,$(SP_BLOCK_STORAGE_EXTRA_FLAGS)))
$(eval $(call build-sp,internal-trusted-storage,config/$(SP_PSA_ITS_CONFIG),dc1eef48-b17a-4ccf-ac8b-dfcff7711b14,$(SP_PSA_ITS_EXTRA_FLAGS)))
$(eval $(call build-sp,protected-storage,config/$(SP_PSA_PS_CONFIG),751bf801-3dde-4768-a514-0f10aeed1790,$(SP_PSA_PS_EXTRA_FLAGS)))
$(eval $(call build-sp,crypto,config/$(SP_PSA_CRYPTO_CONFIG),d9df52d5-16a2-4bb2-9aa4-d26d3b84e8c0,$(SP_PSA_CRYPTO_EXTRA_FLAGS)))
ifeq ($(MEASURED_BOOT),y)
$(eval $(call build-sp,attestation,config/$(SP_PSA_ATTESTATION_CONFIG),a1baf155-8876-4695-8f7c-54955e8db974,$(SP_PSA_ATTESTATION_EXTRA_FLAGS)))
endif
ifeq ($(TS_SMM_GATEWAY),y)
$(eval $(call build-sp,smm-gateway,config/$(SP_SMM_GATEWAY_CONFIG),ed32d533-99e6-4209-9cc0-2d72cdd998a7,$(SP_SMM_GATEWAY_EXTRA_FLAGS)))
endif
ifeq ($(TS_FW_UPDATE),y)
$(eval $(call build-sp,fwu,config/$(SP_FWU_CONFIG),6823a838-1b06-470e-9774-0cce8bfb53fd,$(SP_FWU_EXTRA_FLAGS)))
endif
else
# SPMC test SPs
OPTEE_OS_COMMON_EXTRA_FLAGS	+= CFG_SPMC_TESTS=y
$(eval $(call build-sp,spm-test1,opteesp,5c9edbc3-7b3a-4367-9f83-7c191ae86a37,$(SP_SPMC_TEST_EXTRA_FLAGS)))
$(eval $(call build-sp,spm-test2,opteesp,7817164c-c40c-4d1a-867a-9bb2278cf41a,$(SP_SPMC_TEST_EXTRA_FLAGS)))
$(eval $(call build-sp,spm-test3,opteesp,23eb0100-e32a-4497-9052-2f11e584afa6,$(SP_SPMC_TEST_EXTRA_FLAGS)))
$(eval $(call build-sp,spm-test4,opteesp,423762ed-7772-406f-99d8-0c27da0abbf8,$(SP_SPMC_TEST_EXTRA_FLAGS)))
endif

# Linux user space applications
ifeq ($(SPMC_TESTS),n)
$(eval $(call build-ts-app,libts,$(TS_APP_LIBTS_EXTRA_FLAGS)))
$(eval $(call build-ts-app,libpsats,$(TS_APP_LIBPSATS_EXTRA_FLAGS)))
$(eval $(call build-ts-app,ts-service-test,$(TS_APP_TS_SERVICE_TEST_EXTRA_FLAGS)))
$(eval $(call build-ts-app,psa-api-test/internal_trusted_storage,$(TS_APP_PSA_ITS_EXTRA_FLAGS)))
$(eval $(call build-ts-app,psa-api-test/protected_storage,$(TS_APP_PSA_PS_EXTRA_FLAGS)))
$(eval $(call build-ts-app,psa-api-test/crypto,$(TS_APP_PSA_CRYPTO_EXTRA_FLAGS)))
ifeq ($(MEASURED_BOOT),y)
$(eval $(call build-ts-app,psa-api-test/initial_attestation,$(TS_APP_PSA_IAT_EXTRA_FLAGS)))
endif
ifeq ($(TS_UEFI_TESTS),y)
$(eval $(call build-ts-app,uefi-test,$(TS_APP_UEFI_TEST_EXTRA_FLAGS)))

# uefi-test uses MM Communicate via the arm-ffa-user driver and the message
# payload is forwarded in a carveout memory area. Adding reserved-memory node to
# the device tree to prevent Linux from using the carveout area for other
# purposes.

ORIGINAL_DTB := $(FVP_LINUX_DTB)
CARVEOUT_ENTRY = $(ROOT)/build/fvp/mm_communicate_carveout.dtsi
FVP_LINUX_DTB = $(ROOT)/out/fvp_with_mm_carveout.dtb

$(FVP_LINUX_DTB): $(CARVEOUT_ENTRY) | linux
	{ dtc -Idtb -Odts $(ORIGINAL_DTB); cat $(CARVEOUT_ENTRY); } | dtc -Idts -Odtb -o $(FVP_LINUX_DTB)

boot-img: $(FVP_LINUX_DTB)

.PHONY: carveout-dtb-clean
carveout-dtb-clean:
	rm -f $(FVP_LINUX_DTB)

boot-img-clean: carveout-dtb-clean
endif

ifeq ($(TS_FW_UPDATE),y)

# TODO: the fwu-tool is currently not needed.
$(eval $(call build-ts-host-app,fwu-tool,$(TS_HOST_UEFI_TEST_EXTRA_FLAGS)))

ffa-fwu-sp: ts-host-fwu-tool

# Copy the disk image used by FWU to the build directory to allow the FVP binary to find it.
$(BINARIES_PATH)/secure-flash.img:
	mkdir -p $(BINARIES_PATH)
	cp $(ROOT)/trusted-services/components/media/disk/disk_images/multi_location_fw.img $(BINARIES_PATH)/secure-flash.img

# Add a shortcut to help manually doing the copy.
ffa-fwu-fash-img: $(BINARIES_PATH)/secure-flash.img

ffa-fwu-sp: $(BINARIES_PATH)/secure-flash.img

endif

ffa-fwu-fash-img-clean:
	rm -f $(BINARIES_PATH)/secure-flash.img

clean: ffa-fwu-fash-img-clean

clean: ts-host-all-clean ffa-test-all-clean ffa-sp-all-clean linux-arm-ffa-user-clean

endif
