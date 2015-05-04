################################################################################
# Toolchains
################################################################################
ROOT				?= ${HOME}/devel/optee
TOOLCHAIN_ROOT 			?= $(ROOT)/toolchains

AARCH32_PATH 			?= $(TOOLCHAIN_ROOT)/aarch32
AARCH32_CROSS_COMPILE 		?= $(AARCH32_PATH)/bin/arm-linux-gnueabihf-
AARCH32_GCC_VERSION 		?= gcc-linaro-arm-linux-gnueabihf-4.9-2014.08_linux
SRC_AARCH32_GCC 		?= http://releases.linaro.org/14.08/components/toolchain/binaries/${AARCH32_GCC_VERSION}.tar.xz

AARCH64_PATH 			?= $(TOOLCHAIN_ROOT)/aarch64
AARCH64_CROSS_COMPILE 		?= $(AARCH64_PATH)/bin/aarch64-linux-gnu-
AARCH64_GCC_VERSION 		?= gcc-linaro-aarch64-linux-gnu-4.9-2014.08_linux
SRC_AARCH64_GCC 		?= http://releases.linaro.org/14.08/components/toolchain/binaries/${AARCH64_GCC_VERSION}.tar.xz

AARCH64_NONE_PATH 		?= $(TOOLCHAIN_ROOT)/aarch64-none-elf
AARCH64_NONE_CROSS_COMPILE 	?= $(AARCH64_NONE_PATH)/bin/aarch64-none-elf-
AARCH64_NONE_GCC_VERSION 	?= gcc-linaro-aarch64-none-elf-4.9-2014.07_linux
SRC_AARCH64_NONE_GCC 		?= http://releases.linaro.org/14.07/components/toolchain/binaries/${AARCH64_NONE_GCC_VERSION}.tar.xz

toolchains:
	mkdir -p $(AARCH32_PATH)
	curl $(SRC_AARCH32_GCC) -o $(TOOLCHAIN_ROOT)/$(AARCH32_GCC_VERSION).tar.xz
	tar xf $(TOOLCHAIN_ROOT)/$(AARCH32_GCC_VERSION).tar.xz -C $(AARCH32_PATH) --strip-components=1

	mkdir -p $(AARCH64_PATH)
	curl $(SRC_AARCH64_GCC) -o $(TOOLCHAIN_ROOT)/$(AARCH64_GCC_VERSION).tar.xz
	tar xf $(TOOLCHAIN_ROOT)/$(AARCH64_GCC_VERSION).tar.xz -C $(AARCH64_PATH) --strip-components=1

	mkdir -p $(AARCH64_NONE_PATH)
	curl $(SRC_AARCH64_NONE_GCC) -o $(TOOLCHAIN_ROOT)/$(AARCH64_NONE_GCC_VERSION).tar.xz
	tar xf $(TOOLCHAIN_ROOT)/$(AARCH64_NONE_GCC_VERSION).tar.xz -C $(AARCH64_NONE_PATH) --strip-components=1

