OPTEE_TEST_EXT_VERSION = 1.0
OPTEE_TEST_EXT_SOURCE = local
OPTEE_TEST_EXT_SITE = $(BR2_PACKAGE_OPTEE_TEST_EXT_SITE)
OPTEE_TEST_EXT_SITE_METHOD = local
OPTEE_TEST_EXT_INSTALL_STAGING = YES
OPTEE_TEST_EXT_DEPENDENCIES = optee_client_ext openssl host-python3-pycryptodomex
OPTEE_TEST_EXT_SDK = $(BR2_PACKAGE_OPTEE_TEST_EXT_SDK)
OPTEE_TEST_EXT_CONF_OPTS = -DOPTEE_TEST_SDK=$(OPTEE_TEST_EXT_SDK)
# os_test has dependencies, this enforces a valid build order
OPTEE_TEST_EXT_TAS = os_test_lib os_test_lib_dl os_test *
uniq = $(if $1,$(firstword $1) $(call uniq,$(filter-out $(firstword $1),$1)))

ifneq ($(BR2_PACKAGE_OPTEE_TEST_EXT_GP_PACKAGE),"")
OPTEE_TEST_EXT_CONF_OPTS += -DWITH_GP_TESTS=1
OPTEE_TEST_EXT_PRE_CONFIGURE_HOOKS += OPTEE_TEST_EXT_PREPARE_GP_SUITE
endif

ifneq ($(BR2_PACKAGE_OPTEE_TEST_EXT_WITH_TLS_TESTS),)
TARGET_CONFIGURE_OPTS += WITH_TLS_TESTS=$(BR2_PACKAGE_OPTEE_TEST_EXT_WITH_TLS_TESTS)
endif

ifneq ($(BR2_PACKAGE_OPTEE_TEST_EXT_WITH_CXX_TESTS),)
TARGET_CONFIGURE_OPTS += WITH_CXX_TESTS=$(BR2_PACKAGE_OPTEE_TEST_EXT_WITH_CXX_TESTS)
endif

define OPTEE_TEST_EXT_PREPARE_GP_SUITE
	sh $(@D)/host/xtest/gp/prepare_suite.sh $(@D) \
		$(BR2_PACKAGE_OPTEE_TEST_EXT_GP_PACKAGE)
endef

define OPTEE_TEST_EXT_BUILD_TAS
	@$(foreach f,$(call uniq,$(foreach t,$(OPTEE_TEST_EXT_TAS),$(wildcard $(@D)/ta/$(t)/Makefile))), \
		echo Building $f && \
			$(MAKE) CROSS_COMPILE="$(shell echo $(BR2_PACKAGE_OPTEE_TEST_EXT_CROSS_COMPILE))" \
			O=out TA_DEV_KIT_DIR=$(OPTEE_TEST_EXT_SDK) \
			PYTHON3=$(HOST_DIR)/bin/python3 \
			$(TARGET_CONFIGURE_OPTS) -C $(dir $f) all &&) true
endef

define OPTEE_TEST_EXT_INSTALL_TAS
	@$(foreach f,$(wildcard $(@D)/ta/*/out/*.ta), \
		mkdir -p $(TARGET_DIR)/lib/optee_armtz && \
		$(INSTALL) -v -p  --mode=444 \
			--target-directory=$(TARGET_DIR)/lib/optee_armtz $f \
			&&) true
endef


define OPTEE_TEST_EXT_BUILD_GP_TAS
	@$(foreach f,$(wildcard $(shell echo $(@D)/host/xtest/gp-suite/TTAs_Internal_API_1_1_1/*/*/{*/,}code_files/Makefile)), \
		echo Building $f && \
			$(MAKE) CROSS_COMPILE="$(shell echo $(BR2_PACKAGE_OPTEE_TEST_EXT_CROSS_COMPILE))" \
			O=out TA_DEV_KIT_DIR=$(OPTEE_TEST_EXT_SDK) \
			$(TARGET_CONFIGURE_OPTS) -C $(dir $f) all &&) true

endef

define OPTEE_TEST_EXT_INSTALL_GP_TAS
	@$(foreach f,$(wildcard $(shell echo $(@D)/host/xtest/gp-suite/TTAs_Internal_API_1_1_1/*/*/{*/,}code_files/out/*.ta)), \
		mkdir -p $(TARGET_DIR)/lib/optee_armtz && \
		$(INSTALL) -v -p  --mode=444 \
			--target-directory=$(TARGET_DIR)/lib/optee_armtz $f \
			&&) true
endef

OPTEE_TEST_EXT_POST_BUILD_HOOKS += OPTEE_TEST_EXT_BUILD_TAS
OPTEE_TEST_EXT_POST_BUILD_HOOKS += OPTEE_TEST_EXT_BUILD_GP_TAS
OPTEE_TEST_EXT_POST_INSTALL_TARGET_HOOKS += OPTEE_TEST_EXT_INSTALL_TAS
OPTEE_TEST_EXT_POST_INSTALL_TARGET_HOOKS += OPTEE_TEST_EXT_INSTALL_GP_TAS

$(eval $(cmake-package))
