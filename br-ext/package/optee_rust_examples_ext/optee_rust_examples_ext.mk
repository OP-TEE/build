OPTEE_RUST_EXAMPLES_EXT_VERSION = 1.0
OPTEE_RUST_EXAMPLES_EXT_SOURCE = local
OPTEE_RUST_EXAMPLES_EXT_SITE = $(BR2_PACKAGE_OPTEE_RUST_EXAMPLES_EXT_SITE)
OPTEE_RUST_EXAMPLES_EXT_SITE_METHOD = local
OPTEE_RUST_EXAMPLES_EXT_INSTALL_STAGING = YES
OPTEE_RUST_EXAMPLES_EXT_DEPENDENCIES = optee_client_ext

ifneq (,$(BR2_PACKAGE_OPTEE_RUST_EXAMPLES_TC_PATH_ENV))
OPTEE_RUST_EXAMPLES_TC_PATH_ENV = PATH=$(BR2_PACKAGE_OPTEE_RUST_EXAMPLES_TC_PATH_ENV)
endif

EXAMPLE = $(wildcard examples/*)

HOST_TARGET := aarch64-unknown-linux-gnu
TA_TARGET := aarch64-unknown-optee-trustzone

export RUST_TARGET_PATH = $(@D)
export RUST_COMPILER_RT_ROOT = $(RUST_TARGET_PATH)/rust/rust/src/llvm-project/compiler-rt
export OPTEE_DIR = $(@D)/../../..
export OPTEE_OS_DIR = $(OPTEE_DIR)/optee_os
export OPTEE_CLIENT_DIR = $(OPTEE_DIR)/out-br/build/optee_client_ext-1.0
export OPTEE_CLIENT_INCLUDE = $(OPTEE_CLIENT_DIR)/out/export/usr/include
export VENDOR = qemu_v8.mk
export OPTEE_OS_INCLUDE = $(OPTEE_DIR)/optee_os/out/arm/export-ta_arm64/include
export CC = $(OPTEE_DIR)/toolchains/aarch64/bin/aarch64-linux-gnu-gcc

define OPTEE_RUST_EXAMPLES_EXT_BUILD_CMDS
	@$(foreach f,$(wildcard $(@D)/examples/*/Makefile), \
		echo Building $f && \
		$(OPTEE_RUST_EXAMPLES_TC_PATH_ENV) $(MAKE) -C $(dir $f) &&) true
endef

define OPTEE_RUST_EXAMPLES_EXT_INSTALL_TARGET_CMDS
	@$(foreach f,$(wildcard $(@D)/examples/*/ta/target/$(TA_TARGET)/release/*.ta), \
		mkdir -p $(TARGET_DIR)/lib/optee_armtz && \
		echo Installing $f && \
		$(INSTALL) -v -p --mode=444 \
			--target-directory=$(TARGET_DIR)/lib/optee_armtz $f \
			&&) true
	@$(foreach f,$(wildcard $(@D)/examples/*/host/target/$(HOST_TARGET)/release/*-rs), \
		echo Installing $f && \
		$(INSTALL) -v -p --target-directory=$(TARGET_DIR)/usr/bin $f \
		&&) true
	@$(foreach f,$(wildcard $(@D)/examples/*/plugin/target/$(HOST_TARGET)/release/*.plugin.so), \
		mkdir -p $(TARGET_DIR)/usr/lib/tee-supplicant/plugins && \
		echo Installing $f && \
		$(INSTALL) -v -p --target-directory=$(TARGET_DIR)/usr/lib/tee-supplicant/plugins $f \
		&&) true
endef

$(eval $(generic-package))
