OPTEE_TEST_VERSION = 1.0
OPTEE_TEST_SOURCE = local
OPTEE_TEST_SITE = $(BR2_PACKAGE_OPTEE_TEST_SITE)
OPTEE_TEST_SITE_METHOD = local
OPTEE_TEST_INSTALL_STAGING = YES
OPTEE_TEST_DEPENDENCIES = optee_client openssl host-python-pycrypto
OPTEE_TEST_SDK = $(BR2_PACKAGE_OPTEE_TEST_SDK)
OPTEE_TEST_CONF_OPTS = -DOPTEE_TEST_SDK=$(OPTEE_TEST_SDK)

define OPTEE_TEST_BUILD_TAS
	@$(foreach f,$(wildcard $(@D)/ta/*/Makefile), \
		echo Building $f && \
			$(MAKE) CROSS_COMPILE="$(shell echo $(BR2_PACKAGE_OPTEE_TEST_CROSS_COMPILE))" \
			O=out TA_DEV_KIT_DIR=$(OPTEE_TEST_SDK) \
			$(TARGET_CONFIGURE_OPTS) -C $(dir $f) all &&) true
endef

define OPTEE_TEST_INSTALL_TAS
	@$(foreach f,$(wildcard $(@D)/ta/*/out/*.ta), \
		mkdir -p $(TARGET_DIR)/lib/optee_armtz && \
		$(INSTALL) -v -p  --mode=444 \
			--target-directory=$(TARGET_DIR)/lib/optee_armtz $f \
			&&) true
endef

OPTEE_TEST_POST_BUILD_HOOKS += OPTEE_TEST_BUILD_TAS
OPTEE_TEST_POST_INSTALL_TARGET_HOOKS += OPTEE_TEST_INSTALL_TAS

$(eval $(cmake-package))
