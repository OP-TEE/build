OUT_PATH		?= $(ROOT)/out

QEMU_VIRTFS_HOST_DIR	?= $(ROOT)
QEMU_VIRTFS_AUTOMOUNT	?= y

QEMU_USE_CUSTOM_DTB		?= y

MEASURED_BOOT			?= y
MEASURED_BOOT_FTPM		?= n
TS_SMM_GATEWAY			?= y
TS_UEFI_TESTS			?= y
# Supported values: embedded (fip is currently not supported on QEMU platform)
SP_PACKAGING_METHOD		?= embedded
SPMC_TESTS			?= n

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
SP_BLOCK_STORAGE_CONFIG		?= $(DEFAULT_SP_CONFIG)
SP_PSA_ITS_CONFIG		?= $(DEFAULT_SP_CONFIG)
SP_PSA_PS_CONFIG		?= $(DEFAULT_SP_CONFIG)
SP_PSA_CRYPTO_CONFIG		?= $(DEFAULT_SP_CONFIG)
SP_PSA_ATTESTATION_CONFIG	?= $(DEFAULT_SP_CONFIG)
SP_SMM_GATEWAY_CONFIG		?= $(DEFAULT_SP_CONFIG)

# SPMC runs at EL1
SPMC_AT_EL ?= 1
# Use GICv2 or GICv3
GICV3 ?= y
# Use TF-A's Trusted Board Boot mechanism?
TF_A_TRUSTED_BOARD_BOOT ?= y

TF_A_FLAGS ?= \
	BL32=$(OPTEE_OS_PAGER_V2_BIN) \
	BL33=$(BL33_BIN) \
	PLAT=qemu \
	SPD=spmd \
	$(TF_A_FIP_SP_FLAGS) \
	QEMU_USE_GIC_DRIVER=$(TFA_GIC_DRIVER) \
	QEMU_TOS_FW_CONFIG_DTS=$(ROOT)/build/qemu_v8/spmc_el1_manifest.dts

QEMU_EXTRA_ARGS ?= \
	-cpu cortex-a57 \
	-semihosting-config enable=on,target=native,userspace=on \
	-d trace:'__*'

include qemu_v8.mk
include trusted-services.mk

# The macros used in bl2_sp_list.dts and spmc_manifest.dts has to be passed to
# TF-A because it handles the preprocessing of these files.
define add-dtc-define
DTC_CPPFLAGS+=-D$1=$(subst y,1,$(subst n,0,$($1)))
endef

ifeq ($(SP_PACKAGING_METHOD),fip)
$(eval $(call add-dtc-define,SPMC_TESTS))
$(eval $(call add-dtc-define,TS_SMM_GATEWAY))

TF_A_EXPORTS += DTC_CPPFLAGS="$(DTC_CPPFLAGS)"
endif

OPTEE_OS_COMMON_EXTRA_FLAGS += \
	CFG_SECURE_PARTITION=y \
	CFG_CORE_HEAP_SIZE=131072 \
	CFG_DT=y \
	CFG_MAP_EXT_DT_SECURE=y

SP_SMM_GATEWAY_EXTRA_FLAGS +=-DMM_COMM_BUFFER_ADDRESS="0x00000000 0x42000000"
TS_APP_COMMON_FLAGS +=-DMM_COMM_BUFFER_ADDRESS="0x42000000"

# The boot order of the SPs is determined by the order of calls here. This is
# due to the SPMC not (yet) supporting the boot order field of the SP manifest.
ifneq ($(SPMC_TESTS),y)
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
else
# SPMC test SPs
OPTEE_OS_COMMON_EXTRA_FLAGS	+= CFG_SPMC_TESTS=y
$(eval $(call build-sp,spm-test1,opteesp,5c9edbc3-7b3a-4367-9f83-7c191ae86a37,$(SP_SPMC_TEST_EXTRA_FLAGS)))
$(eval $(call build-sp,spm-test2,opteesp,7817164c-c40c-4d1a-867a-9bb2278cf41a,$(SP_SPMC_TEST_EXTRA_FLAGS)))
$(eval $(call build-sp,spm-test3,opteesp,23eb0100-e32a-4497-9052-2f11e584afa6,$(SP_SPMC_TEST_EXTRA_FLAGS)))
$(eval $(call build-sp,spm-test4,opteesp,423762ed-7772-406f-99d8-0c27da0abbf8,$(SP_SPMC_TEST_EXTRA_FLAGS)))
endif

# Linux user space applications
ifneq ($(SPMC_TESTS),y)
$(eval $(call build-ts-app,libts))
$(eval $(call build-ts-app,ts-service-test))
$(eval $(call build-ts-app,psa-api-test/internal_trusted_storage))
$(eval $(call build-ts-app,psa-api-test/protected_storage))
$(eval $(call build-ts-app,psa-api-test/crypto))
ifeq ($(MEASURED_BOOT),y)
$(eval $(call build-ts-app,psa-api-test/initial_attestation))
endif
ifeq ($(TS_UEFI_TESTS),y)
$(eval $(call build-ts-app,uefi-test))

# uefi-test uses MM Communicate via the arm-ffa-user driver and the message
# payload is forwarded in a carveout memory area. Adding reserved-memory node to
# the device tree to prevent Linux from using the carveout area for other
# purposes.

CARVEOUT_ENTRY = $(ROOT)/build/qemu_v8/mm_communicate_carveout.dtsi
$(QEMU_DTB_PATH): $(CARVEOUT_ENTRY) dumpdtb | linux
	{ dtc -Idtb -Odts $(QEMU_DTB_PATH); cat $(CARVEOUT_ENTRY); } | dtc -Idts -Odtb -o $(QEMU_DTB_PATH)

boot-img: $(QEMU_DTB_PATH)

.PHONY: qemu-dtb-clean
qemu-dtb-clean:
	rm -f $(QEMU_DTB_PATH)

boot-img-clean: qemu-dtb-clean
endif
endif