OPTEE_TEST_EXT_VERSION = 1.0
OPTEE_TEST_EXT_SOURCE = local
OPTEE_TEST_EXT_SITE = $(BR2_PACKAGE_OPTEE_TEST_EXT_SITE)
OPTEE_TEST_EXT_SITE_METHOD = local
OPTEE_TEST_EXT_INSTALL_STAGING = YES
OPTEE_TEST_EXT_DEPENDENCIES = optee_client_ext openssl host-python-cryptography
OPTEE_TEST_EXT_SDK = $(BR2_PACKAGE_OPTEE_TEST_EXT_SDK)
OPTEE_TEST_EXT_CONF_OPTS = -DOPTEE_TEST_SDK=$(OPTEE_TEST_EXT_SDK)
# os_test has dependencies, this enforces a valid build order
OPTEE_TEST_EXT_TAS = os_test_lib os_test_lib_dl os_test *
uniq = $(if $1,$(firstword $1) $(call uniq,$(filter-out $(firstword $1),$1)))


ifneq ($(BR2_PACKAGE_OPTEE_TEST_EXT_GP_PACKAGE),"")
OPTEE_TEST_EXT_CONF_OPTS += -DWITH_GP_TESTS=1
OPTEE_TEST_EXT_PRE_CONFIGURE_HOOKS += OPTEE_TEST_EXT_PREPARE_GP_SUITE
endif

# Avoid CMake warnings on these unused variables set by Buildroot
OPTEE_TEST_EXT_CONF_OPTS += -DBUILD_DOC=OFF -DBUILD_DOCS=OFF \
			    -DBUILD_EXAMPLE=OFF -DBUILD_EXAMPLES=OFF \
			    -DBUILD_TEST=OFF -DBUILD_TESTING=OFF \
			    -DBUILD_TESTS=OFF

ifneq ($(BR2_PACKAGE_OPTEE_TEST_EXT_WITH_TLS_TESTS),)
TARGET_CONFIGURE_OPTS += WITH_TLS_TESTS=$(BR2_PACKAGE_OPTEE_TEST_EXT_WITH_TLS_TESTS)
endif

ifneq ($(BR2_PACKAGE_OPTEE_TEST_EXT_WITH_CXX_TESTS),)
TARGET_CONFIGURE_OPTS += WITH_CXX_TESTS=$(BR2_PACKAGE_OPTEE_TEST_EXT_WITH_CXX_TESTS)
endif

define OPTEE_TEST_EXT_INSTALL_INIT_SYSV
	$(INSTALL) -m 0755 -D $(OPTEE_TEST_EXT_PKGDIR)/S30test-arm-ffa-user \
		$(TARGET_DIR)/etc/init.d/S30test-arm-ffa-user
endef

define OPTEE_TEST_EXT_PREPARE_GP_SUITE
	sh $(@D)/host/xtest/gp/prepare_suite.sh $(@D) \
		$(BR2_PACKAGE_OPTEE_TEST_EXT_GP_PACKAGE)
endef

define OPTEE_TEST_EXT_BUILD_TAS
	$(MAKE) -j$$(nproc) CROSS_COMPILE="$(shell echo $(BR2_PACKAGE_OPTEE_TEST_EXT_CROSS_COMPILE))" \
		O=out TA_DEV_KIT_DIR=$(OPTEE_TEST_EXT_SDK) \
		PYTHON3=$(HOST_DIR)/bin/python3 \
		$(TARGET_CONFIGURE_OPTS) -C $(BUILD_DIR)/optee_test_ext-$(OPTEE_TEST_EXT_VERSION)/ta -f $(@D)/ta/Makefile.gmake all
endef

define OPTEE_TEST_EXT_INSTALL_TAS
	@$(foreach f,$(wildcard $(@D)/ta/*/out/ta/*/*.ta), \
		mkdir -p $(TARGET_DIR)/lib/optee_armtz && \
		$(INSTALL) -v -p  --mode=444 \
			--target-directory=$(TARGET_DIR)/lib/optee_armtz $f \
			&&) true
endef

define OPTEE_TEST_EXT_INSTALL_GP_TAS
	@$(foreach f,$(wildcard $(shell echo $(@D)/host/xtest/gp-suite/TTAs_Internal_API_1_1_1/*/*/{*/,}code_files/out/*.ta)), \
		mkdir -p $(TARGET_DIR)/lib/optee_armtz && \
		$(INSTALL) -v -p  --mode=444 \
			--target-directory=$(TARGET_DIR)/lib/optee_armtz $f \
			&&) true
endef

OPTEE_TEST_EXT_POST_BUILD_HOOKS += OPTEE_TEST_EXT_BUILD_TAS
OPTEE_TEST_EXT_POST_INSTALL_TARGET_HOOKS += OPTEE_TEST_EXT_INSTALL_TAS
OPTEE_TEST_EXT_POST_INSTALL_TARGET_HOOKS += OPTEE_TEST_EXT_INSTALL_GP_TAS

$(eval $(cmake-package))
