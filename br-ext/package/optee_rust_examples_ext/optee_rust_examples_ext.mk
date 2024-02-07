OPTEE_RUST_EXAMPLES_EXT_VERSION = 1.0
OPTEE_RUST_EXAMPLES_EXT_SOURCE = local
OPTEE_RUST_EXAMPLES_EXT_SITE = $(BR2_PACKAGE_OPTEE_RUST_EXAMPLES_EXT_SITE)
OPTEE_RUST_EXAMPLES_EXT_SITE_METHOD = local
OPTEE_RUST_EXAMPLES_EXT_INSTALL_STAGING = YES
OPTEE_RUST_EXAMPLES_EXT_DEPENDENCIES = optee_client_ext
OPTEE_RUST_EXAMPLES_EXT_SDK = $(BR2_PACKAGE_OPTEE_RUST_EXAMPLES_EXT_SDK)
OPTEE_RUST_EXAMPLES_EXT_TC_PATH = $(subst $\",,$(BR2_PACKAGE_OPTEE_RUST_EXAMPLES_EXT_TC_PATH))

EXAMPLE = $(wildcard examples/*)

define OPTEE_RUST_EXAMPLES_EXT_CONFIGURE_CMDS
	# Ensure the toolchain, components, and targets we've specified in
	# rust-toolchain.toml are ready to go. Since that file sets rustup's
	# default toolchain for the entire directory, all we need to do is run
	# any rustup-wrapped command to trigger installation. We've arbitrarily
	# chosen "cargo --version" since it has no other effect.
	@echo Configuring OP-TEE rust examples && \
	export RUSTUP_HOME=$(OPTEE_RUST_EXAMPLES_EXT_TC_PATH)/.rustup && \
	export CARGO_HOME=$(OPTEE_RUST_EXAMPLES_EXT_TC_PATH)/.cargo && \
	source $(OPTEE_RUST_EXAMPLES_EXT_TC_PATH)/.cargo/env && \
	cd $(@D) && cargo --version >/dev/null
endef

define OPTEE_RUST_EXAMPLES_EXT_BUILD_CMDS
	@echo Building OP-TEE rust examples && \
	export RUSTUP_HOME=$(OPTEE_RUST_EXAMPLES_EXT_TC_PATH)/.rustup && \
	export CARGO_HOME=$(OPTEE_RUST_EXAMPLES_EXT_TC_PATH)/.cargo && \
	source $(OPTEE_RUST_EXAMPLES_EXT_TC_PATH)/.cargo/env && \
	TARGET_HOST=$(BR2_PACKAGE_OPTEE_RUST_EXAMPLES_EXT_TARGET_HOST) \
	TARGET_TA=$(BR2_PACKAGE_OPTEE_RUST_EXAMPLES_EXT_TARGET_TA) \
	CROSS_COMPILE_HOST=$(BR2_PACKAGE_OPTEE_RUST_EXAMPLES_EXT_CROSS_COMPILE_HOST) \
	CROSS_COMPILE_TA=$(BR2_PACKAGE_OPTEE_RUST_EXAMPLES_EXT_CROSS_COMPILE_TA) \
	TA_DEV_KIT_DIR=$(OPTEE_RUST_EXAMPLES_EXT_SDK) \
	OPTEE_CLIENT_EXPORT=$(TARGET_DIR) \
	$(MAKE) -C $(@D) install O=$(TARGET_DIR)
endef

$(eval $(generic-package))
