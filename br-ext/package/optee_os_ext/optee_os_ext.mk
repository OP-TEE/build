OPTEE_OS_EXT_VERSION = 1.0
OPTEE_OS_EXT_SOURCE = local
OPTEE_OS_EXT_SITE = $(BR2_PACKAGE_OPTEE_OS_EXT_SITE)
OPTEE_OS_EXT_SITE_METHOD = local
OPTEE_OS_EXT_SDK = $(BR2_PACKAGE_OPTEE_OS_EXT_SDK)
OPTEE_OS_EXT_PKCS11_TA = $(call qstrip,$(BR2_PACKAGE_OPTEE_OS_EXT_PKCS11_TA))

define OPTEE_OS_EXT_INSTALL_OPTEE_OS_SHLIBS
	@mkdir -p $(TARGET_DIR)/lib/optee_armtz && \
		for f in $(OPTEE_OS_EXT_SDK)/lib/*.ta; do \
			[ -f "$$f" ] || continue; \
			$(INSTALL) -v -p  --mode=444 \
				--target-directory=$(TARGET_DIR)/lib/optee_armtz $$f; \
		done
endef

ifneq ($(OPTEE_OS_EXT_PKCS11_TA),)
define OPTEE_OS_EXT_INSTALL_OPTEE_PKCS11_TA
	$(INSTALL) -D -m 444 -t $(TARGET_DIR)/lib/optee_armtz $(OPTEE_OS_EXT_PKCS11_TA)
endef
endif

define OPTEE_OS_EXT_DO_INSTALL
	$(OPTEE_OS_EXT_INSTALL_OPTEE_OS_SHLIBS)
	$(OPTEE_OS_EXT_INSTALL_OPTEE_PKCS11_TA)
endef

OPTEE_OS_EXT_POST_INSTALL_TARGET_HOOKS += OPTEE_OS_EXT_DO_INSTALL

$(eval $(cmake-package))
