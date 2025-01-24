OPTEE_CLIENT_EXT_VERSION = 1.0
OPTEE_CLIENT_EXT_SOURCE = local
OPTEE_CLIENT_EXT_SITE = $(BR2_PACKAGE_OPTEE_CLIENT_EXT_SITE)
OPTEE_CLIENT_EXT_SITE_METHOD = local
OPTEE_CLIENT_EXT_DEPENDENCIES = host-pkgconf util-linux-libs
OPTEE_CLIENT_EXT_INSTALL_STAGING = YES

ifeq ($(BR2_PACKAGE_OPTEE_CLIENT_EXT_RPMB_EMU),y)
OPTEE_CLIENT_EXT_CONF_OPTS += -DRPMB_EMU=ON
else
OPTEE_CLIENT_EXT_CONF_OPTS += -DRPMB_EMU=OFF
endif

# Avoid CMake warnings on these unused variables set by Buildroot
OPTEE_CLIENT_EXT_CONF_OPTS += -DBUILD_DOC=OFF -DBUILD_DOCS=OFF \
			      -DBUILD_EXAMPLE=OFF -DBUILD_EXAMPLES=OFF \
			      -DBUILD_TEST=OFF -DBUILD_TESTING=OFF \
			      -DBUILD_TESTS=OFF

define OPTEE_CLIENT_EXT_INSTALL_SUPPLICANT_SCRIPT
	$(INSTALL) -m 0755 -D $(OPTEE_CLIENT_EXT_PKGDIR)/S30optee \
		$(TARGET_DIR)/etc/init.d/S30optee
endef

define OPTEE_CLIENT_EXT_INSTALL_INIT_SYSV
	$(OPTEE_CLIENT_EXT_INSTALL_SUPPLICANT_SCRIPT)
endef

# User tee is used to run tee-supplicant because access to /dev/teepriv0 is
# restricted to group tee.
# Any user in group teeclnt (such as test) may run client applications.
define OPTEE_CLIENT_EXT_USERS
	tee -1 tee -1 * - /bin/sh - TEE user
	- -1 teeclnt -1 - - - - TEE users group
	test -1 test -1 - - /bin/sh teeclnt Test user, may run TEE client applications
endef

$(eval $(cmake-package))
