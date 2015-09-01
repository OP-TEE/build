#
# Common definition to all platforms
#

BASH := $(shell which bash)
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
# xtest / optee_test
################################################################################
xtest-common: optee-os optee-client
	@if [ -d "$(OPTEE_TEST_PATH)" ]; then \
		$(MAKE) -C $(OPTEE_TEST_PATH) \
			CROSS_COMPILE_HOST=$(CROSS_COMPILE_NS_USER) \
			CROSS_COMPILE_TA=$(CROSS_COMPILE_S_USER) \
			TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \
			CFG_DEV_PATH=$(ROOT) \
			O=$(OPTEE_TEST_OUT_PATH); \
	fi

xtest-clean-common:
	@if [ -d "$(OPTEE_TEST_PATH)" ]; then \
		$(MAKE) -C $(OPTEE_TEST_PATH) \
			CROSS_COMPILE_HOST=$(CROSS_COMPILE_NS_USER) \
			CROSS_COMPILE_TA=$(CROSS_COMPILE_S_USER) \
			TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \
			CFG_DEV_PATH=$(ROOT) \
			O=$(OPTEE_TEST_OUT_PATH) \
				clean; \
	fi

xtest-patch-common: optee-os optee-client
	@if [ -d "$(OPTEE_TEST_PATH)" ]; then \
		$(MAKE) -C $(OPTEE_TEST_PATH) \
			CROSS_COMPILE_HOST=$(CROSS_COMPILE_NS_USER) \
			CROSS_COMPILE_TA=$(CROSS_COMPILE_S_USER) \
			TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \
			CFG_ARM32=y \
			CFG_DEV_PATH=$(ROOT) \
			CFG_OPTEE_TEST_PATH=$(OPTEE_TEST_PATH) \
			O=$(OPTEE_TEST_OUT_PATH) \
				patch; \
	fi
