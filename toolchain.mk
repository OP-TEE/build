################################################################################
# Toolchains
################################################################################
ROOT					?= $(CURDIR)/..
TOOLCHAIN_ROOT 			?= $(ROOT)/toolchains

AARCH32_PATH 			?= $(TOOLCHAIN_ROOT)/aarch32
AARCH32_CROSS_COMPILE 		?= $(AARCH32_PATH)/bin/arm-linux-gnueabihf-
AARCH32_GCC_VERSION 		?= gcc-linaro-5.3.1-2016.05-x86_64_arm-linux-gnueabihf
SRC_AARCH32_GCC 		?= http://releases.linaro.org/components/toolchain/binaries/5.3-2016.05/arm-linux-gnueabihf/${AARCH32_GCC_VERSION}.tar.xz

AARCH64_PATH 			?= $(TOOLCHAIN_ROOT)/aarch64
AARCH64_CROSS_COMPILE 		?= $(AARCH64_PATH)/bin/aarch64-linux-gnu-
AARCH64_GCC_VERSION 		?= gcc-linaro-5.3.1-2016.05-x86_64_aarch64-linux-gnu
SRC_AARCH64_GCC 		?= http://releases.linaro.org/components/toolchain/binaries/5.3-2016.05/aarch64-linux-gnu/${AARCH64_GCC_VERSION}.tar.xz

# Due to relocation error on the 96board edk forest, let's keep the old
# toolchain for a while.
LEGACY_AARCH64_PATH             ?= $(TOOLCHAIN_ROOT)/aarch64-legacy
LEGACY_AARCH64_CROSS_COMPILE    ?= $(LEGACY_AARCH64_PATH)/bin/aarch64-linux-gnu-
LEGACY_AARCH64_GCC_VERSION      ?= gcc-linaro-aarch64-linux-gnu-4.9-2014.08_linux
LEGACY_SRC_AARCH64_GCC          ?= http://releases.linaro.org/archive/14.08/components/toolchain/binaries/${LEGACY_AARCH64_GCC_VERSION}.tar.xz

toolchains: aarch32 aarch64 aarch64-legacy

aarch32:
	if [ ! -d "$(AARCH32_PATH)" ]; then \
		mkdir -p $(AARCH32_PATH); \
		curl -L $(SRC_AARCH32_GCC) -o $(TOOLCHAIN_ROOT)/$(AARCH32_GCC_VERSION).tar.xz; \
		tar xf $(TOOLCHAIN_ROOT)/$(AARCH32_GCC_VERSION).tar.xz -C $(AARCH32_PATH) --strip-components=1; \
	fi

aarch64:
	if [ ! -d "$(AARCH64_PATH)" ]; then \
		mkdir -p $(AARCH64_PATH); \
		curl -L $(SRC_AARCH64_GCC) -o $(TOOLCHAIN_ROOT)/$(AARCH64_GCC_VERSION).tar.xz; \
		tar xf $(TOOLCHAIN_ROOT)/$(AARCH64_GCC_VERSION).tar.xz -C $(AARCH64_PATH) --strip-components=1; \
	fi

aarch64-legacy:
	if [ ! -d "$(LEGACY_AARCH64_PATH)" ]; then \
		mkdir -p $(LEGACY_AARCH64_PATH); \
		curl -L $(LEGACY_SRC_AARCH64_GCC) -o $(TOOLCHAIN_ROOT)/$(LEGACY_AARCH64_GCC_VERSION).tar.xz; \
		tar xf $(TOOLCHAIN_ROOT)/$(LEGACY_AARCH64_GCC_VERSION).tar.xz -C $(LEGACY_AARCH64_PATH) --strip-components=1; \
	fi

