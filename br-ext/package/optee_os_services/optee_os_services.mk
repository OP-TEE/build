# This recipe build the services TAs from optee_os and installs them in the
# root file system at path /lib/optee_armtz/.
#
# BR2_PACKAGE_OPTEE_OS_SERVICES_SITE sets the optee_os source file tree path.
# BR2_PACKAGE_OPTEE_OS_SERVICES_SDK sets TA devkit path.
# BR2_PACKAGE_OPTEE_OS_SERVICES_CROSS_COMPILE sets cross compiler path.

OPTEE_OS_SERVICES_VERSION = 1.0
OPTEE_OS_SERVICES_SOURCE = local
OPTEE_OS_SERVICES_SITE = $(BR2_PACKAGE_OPTEE_OS_SERVICES_SITE)
OPTEE_OS_SERVICES_SITE_METHOD = local
OPTEE_OS_SERVICES_INSTALL_STAGING = YES

OPTEE_OS_SERVICES_LICENSE = BSD-2-Clause
OPTEE_OS_SERVICES_LICENSE_FILES = LICENSE

define OPTEE_OS_SERVICES_BUILD_CMDS
	@$(foreach f,$(wildcard $(@D)/ta/*/Makefile), \
		echo Building $f && \
			$(MAKE) CROSS_COMPILE="$(shell echo $(BR2_PACKAGE_OPTEE_OS_SERVICES_CROSS_COMPILE))" \
			O=out TA_DEV_KIT_DIR=$(call qstrip,$(BR2_PACKAGE_OPTEE_OS_SERVICES_SDK)) \
			$(TARGET_CONFIGURE_OPTS) -C $(dir $f) all &&) true
endef

# May install OP-TEE TA services in $(TARGET_DIR)/lib/optee_armtz
define OPTEE_OS_SERVICES_INSTALL_IMAGES_CMDS
	@test "$(BR2_PACKAGE_OPTEE_OS_SERVICES)" != y || { \
		mkdir -p $(TARGET_DIR)/lib/optee_armtz && \
		$(foreach f,$(wildcard $(@D)/ta/*/out/*.ta), \
			$(INSTALL) -v -p  --mode=444 \
				--target-directory=$(TARGET_DIR)/lib/optee_armtz \
				 $f &&) true; }
endef

OPTEE_OS_SERVICES_INSTALL_STAGING = YES
OPTEE_OS_SERVICES_INSTALL_IMAGES = YES

$(eval $(generic-package))
