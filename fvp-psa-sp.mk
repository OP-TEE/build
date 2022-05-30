FVP_USE_BASE_PLAT		?= y
FVP_VIRTFS_ENABLE		?= y
FVP_VIRTFS_AUTOMOUNT		?= y
MEASURED_BOOT			?= y
MEASURED_BOOT_FTPM		?= n
TS_SMM_GATEWAY			?= y
TS_UEFI_TESTS			?= y

TF_A_FLAGS ?= \
	BL32=$(OPTEE_OS_PAGER_V2_BIN) \
	BL33=$(EDK2_BIN) \
	PLAT=fvp \
	SPD=spmd \
	SPMD_SPM_AT_SEL2=0 \
	ARM_SPMC_MANIFEST_DTS=$(ROOT)/build/fvp/spmc_manifest.dts

include fvp.mk
include trusted-services.mk

OPTEE_OS_COMMON_EXTRA_FLAGS += \
	CFG_SECURE_PARTITION=y \
	CFG_CORE_SEL1_SPMC=y \
	CFG_CORE_HEAP_SIZE=131072 \
	CFG_DT=y \
	CFG_MAP_EXT_DT_SECURE=y

# The boot order of the SPs is determined by the order of calls here. This is
# due to the SPMC not (yet) supporting the boot order field of the SP manifest.
$(eval $(call build-sp,internal-trusted-storage,dc1eef48-b17a-4ccf-ac8b-dfcff7711b14,$(SP_PSA_ITS_EXTRA_FLAGS)))
$(eval $(call build-sp,protected-storage,751bf801-3dde-4768-a514-0f10aeed1790,$(SP_PSA_PS_EXTRA_FLAGS)))
$(eval $(call build-sp,crypto,d9df52d5-16a2-4bb2-9aa4-d26d3b84e8c0,$(SP_PSA_CRYPTO_EXTRA_FLAGS)))
ifeq ($(MEASURED_BOOT),y)
$(eval $(call build-sp,attestation,a1baf155-8876-4695-8f7c-54955e8db974,$(SP_PSA_ATTESTATION_EXTRA_FLAGS)))
endif
ifeq ($(TS_SMM_GATEWAY),y)
$(eval $(call build-sp,smm-gateway,ed32d533-99e6-4209-9cc0-2d72cdd998a7,$(SP_SMM_GATEWAY_EXTRA_FLAGS)))
endif
