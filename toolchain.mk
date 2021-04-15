################################################################################
# Toolchains
################################################################################
SHELL				= /bin/bash
ROOT				?= $(CURDIR)/..
TOOLCHAIN_ROOT 			?= $(ROOT)/toolchains

AARCH32_PATH 			?= $(TOOLCHAIN_ROOT)/aarch32
AARCH32_CROSS_COMPILE 		?= $(AARCH32_PATH)/bin/arm-linux-gnueabihf-
AARCH32_GCC_VERSION 		?= gcc-arm-9.2-2019.12-x86_64-arm-none-linux-gnueabihf
SRC_AARCH32_GCC 		?= https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/$(AARCH32_GCC_VERSION).tar.xz

AARCH64_PATH 			?= $(TOOLCHAIN_ROOT)/aarch64
AARCH64_CROSS_COMPILE 		?= $(AARCH64_PATH)/bin/aarch64-linux-gnu-
AARCH64_GCC_VERSION 		?= gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu
SRC_AARCH64_GCC 		?= https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/$(AARCH64_GCC_VERSION).tar.xz

# Download toolchain macro for saving some repetition
# $(1) is $AARCH.._PATH		: i.e., path to the destination
# $(2) is $SRC_AARCH.._GCC	: is the downloaded tar.gz file
# $(3) is $.._GCC_VERSION	: the name of the file to download
define dltc
	@if [ ! -d "$(1)" ]; then \
		mkdir -p $(1); \
		echo "Downloading $(3) ..."; \
		curl -s -L $(2) -o $(TOOLCHAIN_ROOT)/$(3).tar.xz; \
		tar xf $(TOOLCHAIN_ROOT)/$(3).tar.xz -C $(1) --strip-components=1; \
		(cd $(1)/bin && for f in *-none-linux*; do ln -s $$f $${f//-none} ; done;) \
	fi
endef

.PHONY: toolchains
toolchains: aarch32 aarch64

.PHONY: aarch32
aarch32:
	$(call dltc,$(AARCH32_PATH),$(SRC_AARCH32_GCC),$(AARCH32_GCC_VERSION))

.PHONY: aarch64
aarch64:
	$(call dltc,$(AARCH64_PATH),$(SRC_AARCH64_GCC),$(AARCH64_GCC_VERSION))

CLANG_VER			?= 12.0.0
CLANG_PATH			?= $(ROOT)/clang-$(CLANG_VER)

# Download the Clang compiler with LLVM tools and compiler-rt libraries
define dl-clang
	@if [ ! -d "$(2)" ]; then \
		./get_clang.sh $(1) $(2); \
	else \
		echo "$(2) already exists"; \
	fi
endef

.PHONY: clang-toolchains
clang-toolchains:
	$(call dl-clang,$(CLANG_VER),$(CLANG_PATH))
