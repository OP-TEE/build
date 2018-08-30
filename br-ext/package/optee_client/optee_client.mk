OPTEE_CLIENT_VERSION = 1.0
OPTEE_CLIENT_SOURCE = local
OPTEE_CLIENT_SITE = $(BR2_PACKAGE_OPTEE_CLIENT_SITE)
OPTEE_CLIENT_SITE_METHOD = local
OPTEE_CLIENT_INSTALL_STAGING = YES

ifeq ($(BR2_PACKAGE_OPTEE_BENCHMARK),y)
OPTEE_CLIENT_CONF_OPTS = -DCFG_TEE_BENCHMARK=ON
endif

define OPTEE_CLIENT_INSTALL_SUPPLICANT_SCRIPT
	$(INSTALL) -m 0755 -D $(OPTEE_CLIENT_PKGDIR)/S30optee \
		$(TARGET_DIR)/etc/init.d/S30optee
endef

define OPTEE_CLIENT_INSTALL_INIT_SYSV
	$(OPTEE_CLIENT_INSTALL_SUPPLICANT_SCRIPT)
endef

# User tee is used to run tee-supplicant because access to /dev/teepriv0 is
# restricted to group tee.
# Any user in group teeclnt (such as test) may run client applications.
# Any user in group ion may access /dev/ion
define OPTEE_CLIENT_USERS
	tee -1 tee -1 * - /bin/sh - TEE user
	- -1 teeclnt -1 - - - - TEE users group
	- -1 ion -1 - - - - ION users group
	test -1 test -1 - - /bin/sh teeclnt,ion Test user, may run TEE client applications
endef

define OPTEE_CLIENT_PERMISSIONS
	/data d 755 root root - - - - -
	/data/tee d 770 tee tee - - - - -
endef

$(eval $(cmake-package))
