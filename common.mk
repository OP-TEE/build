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
GEN_ROOTFS_PATH			?= $(ROOT)/gen_rootfs
GEN_ROOTFS_FILELIST		?= $(GEN_ROOTFS_PATH)/filelist-tee.txt
OPTEE_OS_PATH			?= $(ROOT)/optee_os
OPTEE_CLIENT_PATH		?= $(ROOT)/optee_client
OPTEE_CLIENT_EXPORT		?= $(OPTEE_CLIENT_PATH)/out/export
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
# default target is all
################################################################################
all:

################################################################################
# Busybox
################################################################################
BUSYBOX_COMMON_TARGET		?= TOBEDEFINED
BUSYBOX_CLEAN_COMMON_TARGET	?= TOBEDEFINED
BUSYBOX_COMMON_CCDIR		?= TOBEDEFINED

busybox-common: linux
	cd $(GEN_ROOTFS_PATH) &&  \
		CC_DIR=$(BUSYBOX_COMMON_CCDIR) \
		PATH=${PATH}:$(LINUX_PATH)/usr \
		$(GEN_ROOTFS_PATH)/generate-cpio-rootfs.sh \
			$(BUSYBOX_COMMON_TARGET)

busybox-clean-common:
	cd $(GEN_ROOTFS_PATH) && \
	$(GEN_ROOTFS_PATH)/generate-cpio-rootfs.sh  \
		$(BUSYBOX_CLEAN_COMMON_TARGET)

busybox-cleaner-common:
	rm -rf $(GEN_ROOTFS_PATH)/build
	rm -rf $(GEN_ROOTFS_PATH)/filelist-final.txt

################################################################################
# Linux
################################################################################
LINUX_COMMON_FLAGS ?= LOCALVERSION= CROSS_COMPILE=$(CROSS_COMPILE_NS_KERNEL)

linux-common: linux-defconfig
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS)

$(LINUX_PATH)/.config: $(LINUX_DEFCONFIG_COMMON_FILES)
	cd $(LINUX_PATH) && \
		ARCH=$(LINUX_DEFCONFIG_COMMON_ARCH) \
		scripts/kconfig/merge_config.sh $(LINUX_DEFCONFIG_COMMON_FILES)

linux-defconfig-clean-common:
	rm -f $(LINUX_PATH)/.config

# LINUX_CLEAN_COMMON_FLAGS can be defined in specific makefiles (hikey.mk,...)
# if necessary

linux-clean-common: linux-defconfig-clean
	$(MAKE) -C $(LINUX_PATH) $(LINUX_CLEAN_COMMON_FLAGS) clean

# LINUX_CLEANER_COMMON_FLAGS can be defined in specific makefiles (hikey.mk,...)
# if necessary

linux-cleaner-common: linux-defconfig-clean
	$(MAKE) -C $(LINUX_PATH) $(LINUX_CLEANER_COMMON_FLAGS) distclean

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
	CROSS_COMPILE_ta_arm64=$(AARCH64_CROSS_COMPILE) \
	CROSS_COMPILE_ta_arm32=$(AARCH32_CROSS_COMPILE) \
	CFG_TEE_CORE_LOG_LEVEL=3 \
	DEBUG=$(DEBUG)

optee-os-common:
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_COMMON_FLAGS)

# OPTEE_OS_CLEAN_COMMON_FLAGS can be defined in specific makefiles
# (hikey.mk,...) if necessary

optee-os-clean-common: xtest-clean
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_CLEAN_COMMON_FLAGS) clean

OPTEE_CLIENT_COMMON_FLAGS ?= CROSS_COMPILE=$(CROSS_COMPILE_NS_USER)

optee-client-common:
	$(MAKE) -C $(OPTEE_CLIENT_PATH) $(OPTEE_CLIENT_COMMON_FLAGS)

# OPTEE_CLIENT_CLEAN_COMMON_FLAGS can be defined in specific makefiles
# (hikey.mk,...) if necessary

optee-client-clean-common:
	$(MAKE) -C $(OPTEE_CLIENT_PATH) $(OPTEE_CLIENT_CLEAN_COMMON_FLAGS) \
		clean

################################################################################
# xtest / optee_test
################################################################################
XTEST_COMMON_FLAGS ?= CROSS_COMPILE_HOST=$(CROSS_COMPILE_NS_USER)\
	CROSS_COMPILE_TA=$(CROSS_COMPILE_S_USER) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \
	CFG_DEV_PATH=$(ROOT) \
	O=$(OPTEE_TEST_OUT_PATH)

xtest-common: optee-os optee-client
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_COMMON_FLAGS)

XTEST_CLEAN_COMMON_FLAGS ?= TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR)

xtest-clean-common:
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_CLEAN_COMMON_FLAGS) clean

XTEST_PATCH_COMMON_FLAGS ?= $(XTEST_COMMON_FLAGS)

xtest-patch-common:
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_PATCH_COMMON_FLAGS) patch
