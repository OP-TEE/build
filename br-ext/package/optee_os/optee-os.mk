# TODO: get from config: $(call qstrip,$(BR2_OPTEE_OS_VERSION))
OPTEE_OS_VERSION = 3.1

OPTEE_OS_LICENSE = BSD-2-Clause
OPTEE_OS_LICENSE_FILES = LICENSE

OPTEE_OS_SOURCE = local
OPTEE_OS_SITE = $(TOPDIR)/../optee_os
OPTEE_OS_SITE_METHOD = local

ifneq ($(BR2_PACKAGE_OPTEE_OS_SDK),)
OPTEE_OS_SDK = $(BR2_PACKAGE_OPTEE_OS_SDK)
else
ifeq ($(BR2_aarch64),y)
OPTEE_OS_SDK = ./out-br/export_ta_arm64
else
OPTEE_OS_SDK = ./out-br/export_ta_arm32
endif
endif

OPTEE_OS_CONF_OPTS = -DOPTEE_TEST_SDK=$(OPTEE_OS_SDK)
OPTEE_OS_MAKE_OPTS += CROSS_COMPILE=$(TARGET_CROSS)
OPTEE_OS_MAKE_OPTS += CROSS_COMPILE_core=$(TARGET_CROSS)
ifeq ($(BR2_aarch64),y)
OPTEE_OS_MAKE_OPTS += CROSS_COMPILE_ta_arm64=$(TARGET_CROSS)
endif
ifeq ($(BR2_arm),y)
OPTEE_OS_MAKE_OPTS += CROSS_COMPILE_ta_arm32=$(TARGET_CROSS)
endif

OPTEE_OS_MAKE_OPTS += PLATFORM=$(call qstrip,$(BR2_PACKAGE_OPTEE_OS_PLATFORM))
OPTEE_OS_MAKE_OPTS += $(call qstrip,$(BR2_PACKAGE_OPTEE_OS_ADDITIONAL_VARIABLES))

define OPTEE_OS_BUILD_CMDS
	@echo Skip step as optee_os is built and installed outside buildroot
	@echo $(@D)
	@if [ "$(BR2_PACKAGE_OPTEE_OS_BUILD)" == y ]; then \
		$(TARGET_CONFIGURE_OPTS) \
			$(MAKE) -C $(@D) O=out-br $(OPTEE_OS_MAKE_OPTS) all; \
	fi
	@if [ "$(BR2_PACKAGE_OPTEE_OS_SERVICES)" == y ]; then \
		$(foreach f,$(wildcard $(@D)/ta_services/*/Makefile), \
		$(TARGET_CONFIGURE_OPTS) \
			$(MAKE) CROSS_COMPILE=$(TARGET_CROSS) \
				O=out-br TA_DEV_KIT_DIR=$(OPTEE_OS_SDK) \
				-C $(dir $f) &&) true; \
	fi
endef

define OPTEE_OS_INSTALL_IMAGES_CMDS
	@if [ "$(BR2_PACKAGE_OPTEE_OS_BUILD)" == y ]; then \
		mkdir -p $(BINARIES_DIR)/out-br-optee; \
		cp -dpf $(@D)/out-br/core/tee-*_v2.bin $(BINARIES_DIR)/out-br-optee; \
	fi
	@if [ "$(BR2_PACKAGE_OPTEE_OS_SERVICES)" == y ]; then \
		mkdir -p $(TARGET_DIR)/lib/optee_armtz; \
		$(foreach f,$(wildcard $(@D)/ta_services/*/out-br/*.ta), \
			$(INSTALL) -v -p  --mode=444 \
				--target-directory=$(TARGET_DIR)/lib/optee_armtz \
				 $f &&) true; \
	fi
endef

OPTEE_OS_INSTALL_STAGING = YES
OPTEE_OS_INSTALL_IMAGES = YES

$(eval $(generic-package))
