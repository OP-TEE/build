#
# Common definition to all platforms
#

BASH ?= bash
ROOT ?= $(shell pwd)/..

#
# Must declare in platform specific makefiles:
# - CROSS_COMPILE_NS_USER / CROSS_COMPILE_NS_KERNEL
# - CROSS_COMPILE_S_USER / CROSS_COMPILE_S_KERNEL
#
# - OPTEE_OS_BIN
# - OPTEE_OS_TA_DEV_KIT_DIR
#

LINUX_PATH			?= $(ROOT)/linux
OPTEE_OS_PATH			?= $(ROOT)/optee_os
OPTEE_CLIENT_PATH		?= $(ROOT)/optee_client
OPTEE_CLIENT_EXPORT		?= $(OPTEE_CLIENT_PATH)/out/export
OPTEE_LINUXDRIVER_PATH		?= $(ROOT)/optee_linuxdriver
OPTEE_TEST_PATH			?= $(ROOT)/optee_test
OPTEE_TEST_OUT_PATH 		?= $(ROOT)/optee_test/out

CCACHE ?= $(shell which ccache) # Don't remove this comment (space is needed)

################################################################################
# defines, macros, configuration etc
################################################################################
define KERNEL_VERSION
$(shell cd $(LINUX_PATH) && $(MAKE) --no-print-directory kernelversion)
endef
DEBUG ?= 0

################################################################################
# EDK2 / Tianocore
################################################################################
# Make sure edksetup.sh only will be called once and that we don't rebuild
# BaseTools again and again.
$(EDK2_PATH)/Conf/target.txt:
	set -e && cd $(EDK2_PATH) && $(BASH) edksetup.sh && \
	$(MAKE) -j1 -C $(EDK2_PATH)/BaseTools

edk2-common: $(EDK2_PATH)/Conf/target.txt
	set -e && cd $(EDK2_PATH) && $(BASH) edksetup.sh && \
	$(call edk2-call)

edk2-clean-common:
	set -e && cd $(EDK2_PATH) && $(BASH) edksetup.sh && \
	$(call edk2-call) clean && \
	$(MAKE) -j1 -C $(EDK2_PATH)/BaseTools clean && \
	rm -f $(EDK2_PATH)/Conf/target.txt

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS ?= CROSS_COMPILE=$(CROSS_COMPILE_S_USER) \
	CROSS_COMPILE_core=$(CROSS_COMPILE_S_KERNEL) \
	CFG_TEE_CORE_LOG_LEVEL=3 \
	DEBUG=$(DEBUG)

optee-os-common:
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_COMMON_FLAGS)

OPTEE_OS_CLEAN_COMMON_FLAGS ?= $(OPTEE_OS_COMMON_FLAGS)

optee-os-clean-common:
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_CLEAN_COMMON_FLAGS) clean

OPTEE_CLIENT_COMMON_FLAGS ?= CROSS_COMPILE=$(CROSS_COMPILE_NS_USER)

optee-client-common:
	$(MAKE) -C $(OPTEE_CLIENT_PATH) $(OPTEE_CLIENT_COMMON_FLAGS)

OPTEE_CLIENT_CLEAN_COMMON_FLAGS ?= $(OPTEE_CLIENT_COMMON_FLAGS)

optee-client-clean-common:
	$(MAKE) -C $(OPTEE_CLIENT_PATH) $(OPTEE_CLIENT_CLEAN_COMMON_FLAGS) \
		clean

OPTEE_LINUXDRIVER_COMMON_FLAGS ?= CROSS_COMPILE=$(CROSS_COMPILE_NS_KERNEL) \
	LOCALVERSION= M=$(OPTEE_LINUXDRIVER_PATH)

optee-linuxdriver-common: linux
	$(MAKE) -C $(LINUX_PATH) $(OPTEE_LINUXDRIVER_COMMON_FLAGS) modules

OPTEE_LINUXDRIVER_CLEAN_COMMON_FLAGS ?= $(OPTEE_LINUXDRIVER_COMMON_FLAGS)

optee-linuxdriver-clean-common:
	$(MAKE) -C $(LINUX_PATH) $(OPTEE_LINUXDRIVER_CLEAN_COMMON_FLAGS) clean

################################################################################
# xtest / optee_test
################################################################################
XTEST_COMMON_FLAGS ?= CROSS_COMPILE_HOST=$(CROSS_COMPILE_NS_USER)\
	CROSS_COMPILE_TA=$(CROSS_COMPILE_S_USER) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \
	CFG_DEV_PATH=$(ROOT) \
	O=$(OPTEE_TEST_OUT_PATH)

xtest-common: optee-os optee-client
	@if [ -d "$(OPTEE_TEST_PATH)" ]; then \
		$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_COMMON_FLAGS); \
	fi

XTEST_CLEAN_COMMON_FLAGS ?= $(XTEST_COMMON_FLAGS)

xtest-clean-common:
	@if [ -d "$(OPTEE_TEST_PATH)" ]; then \
		$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_CLEAN_COMMON_FLAGS) clean; \
	fi

XTEST_PATCH_COMMON_FLAGS ?= $(XTEST_COMMON_FLAGS) \
	CFG_OPTEE_TEST_PATH=$(OPTEE_TEST_PATH)

xtest-patch-common: optee-os optee-client
	@if [ -d "$(OPTEE_TEST_PATH)" ]; then \
		$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_PATCH_COMMON_FLAGS) \
			patch; \
	fi
