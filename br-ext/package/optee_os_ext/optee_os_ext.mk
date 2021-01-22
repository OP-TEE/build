OPTEE_OS_EXT_VERSION = 1.0
OPTEE_OS_EXT_SOURCE = local
OPTEE_OS_EXT_SITE = $(BR2_PACKAGE_OPTEE_OS_EXT_SITE)
OPTEE_OS_EXT_SITE_METHOD = local
OPTEE_OS_EXT_SDK = $(BR2_PACKAGE_OPTEE_OS_EXT_SDK)

define OPTEE_OS_EXT_INSTALL_DEVKIT_SHLIBS
	@mkdir -p $(TARGET_DIR)/lib/optee_armtz && \
		for f in $(OPTEE_OS_EXT_SDK)/lib/*.ta; do \
			[ -f "$$f" ] || continue; \
			$(INSTALL) -v -p  --mode=444 \
				--target-directory=$(TARGET_DIR)/lib/optee_armtz $$f; \
		done
endef

define OPTEE_OS_EXT_INSTALL_DEVKIT_TAS
	for f in $(OPTEE_OS_EXT_SDK)/ta/*.ta; do \
		[ -f "$$f" ] || continue; \
		$(INSTALL) -v -p  --mode=444 \
			--target-directory=$(TARGET_DIR)/lib/optee_armtz $$f; \
	done
endef

define OPTEE_OS_EXT_DO_INSTALL
	$(OPTEE_OS_EXT_INSTALL_DEVKIT_SHLIBS)
	$(OPTEE_OS_EXT_INSTALL_DEVKIT_TAS)
endef

OPTEE_OS_EXT_POST_INSTALL_TARGET_HOOKS += OPTEE_OS_EXT_DO_INSTALL

$(eval $(cmake-package))
