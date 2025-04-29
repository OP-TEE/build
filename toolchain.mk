################################################################################
# Toolchains
################################################################################
SHELL				= /bin/bash
ROOT				?= $(CURDIR)/..
TOOLCHAIN_ROOT 			?= $(ROOT)/toolchains
RUST_TOOLCHAIN_PATH 		?= $(TOOLCHAIN_ROOT)/rust
UNAME_M				:= $(shell uname -m)
ARCH				?= arm

# Download toolchain macro for saving some repetition
# $(1) is $AARCH.._PATH		: i.e., path to the destination
# $(2) is $SRC_AARCH.._GCC	: is the downloaded tar.gz file
# $(3) is $.._GCC_VERSION	: the name of the file to download
define dltc
	@if [ ! -d "$(1)" ]; then \
		echo "Downloading $(3) ..."; \
		mkdir -p $(1); \
		curl --retry 5 -k -s -S -L $(2) -o $(TOOLCHAIN_ROOT)/$(3).tar.xz || \
			{ rm -f $(TOOLCHAIN_ROOT)/$(3).tar.xz; cd $(TOOLCHAIN_ROOT) && rmdir $(1); echo Download failed; exit 1; }; \
		tar xf $(TOOLCHAIN_ROOT)/$(3).tar.xz -C $(1) --strip-components=1 || \
			{ rm $(TOOLCHAIN_ROOT)/$(3).tar.xz; echo Downloaded file is damaged; \
			cd $(TOOLCHAIN_ROOT) && rm -rf $(1); exit 1; }; \
		(cd $(1)/bin && shopt -s nullglob && for f in *-none-linux*; do ln -s $$f $${f//-none} ; done;) \
	fi
endef

# Build buildroot toolchain macro for saving some repetition
# $(1) is $ARCH			: target architecture
# $(2) is $AARCH.._PATH		: i.e., path to the destination
# $(3) & $(4)			: parts of toolchain target triplet
define build_toolchain
	@echo Building $1 toolchain
	@mkdir -p ../out-$1-sdk $2
	@(cd .. && $(PYTHON3) build/br-ext/scripts/make_def_config.py \
		--br buildroot --out out-$1-sdk --br-ext build/br-ext \
		--top-dir "$(ROOT)" \
		--br-defconfig build/br-ext/configs/sdk-$1 \
		--br-defconfig build/br-ext/configs/sdk-common \
		--make-cmd $(MAKE))
	+@$(MAKE) -C ../out-$1-sdk clean
	+@$(MAKE) -C ../out-$1-sdk sdk
	@tar xf ../out-$1-sdk/images/$3-buildroot-linux-$4_sdk-buildroot.tar.gz \
		-C $2 --strip-components=1
	@touch $2/.done
endef

# Download the Rust toolchain
define dl-rust-toolchain
	@if [ ! -d "$(1)" ]; then \
		mkdir -p $(1) && \
		export RUSTUP_HOME=$(1)/.rustup && \
		export CARGO_HOME=$(1)/.cargo && \
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path; \
	fi
endef

ifeq ($(UNAME_M),x86_64)
ifeq ($(ARCH),arm)
# Please keep in sync with br-ext/configs/toolchain-aarch32
# and below for aarch64 host
AARCH32_PATH 			?= $(TOOLCHAIN_ROOT)/aarch32
AARCH32_CROSS_COMPILE 		?= $(AARCH32_PATH)/bin/arm-linux-gnueabihf-
AARCH32_GCC_VERSION 		?= arm-gnu-toolchain-11.3.rel1-x86_64-arm-none-linux-gnueabihf
SRC_AARCH32_GCC 		?= https://developer.arm.com/-/media/Files/downloads/gnu/11.3.rel1/binrel/$(AARCH32_GCC_VERSION).tar.xz

# Please keep in sync with br-ext/configs/toolchain-aarch64
AARCH64_PATH 			?= $(TOOLCHAIN_ROOT)/aarch64
AARCH64_CROSS_COMPILE 		?= $(AARCH64_PATH)/bin/aarch64-linux-gnu-
AARCH64_GCC_VERSION 		?= arm-gnu-toolchain-11.3.rel1-x86_64-aarch64-none-linux-gnu
SRC_AARCH64_GCC 		?= https://developer.arm.com/-/media/Files/downloads/gnu/11.3.rel1/binrel/$(AARCH64_GCC_VERSION).tar.xz

.PHONY: toolchains
toolchains: aarch32-toolchain aarch64-toolchain rust-toolchain

.PHONY: aarch32-toolchain
aarch32-toolchain:
	$(call dltc,$(AARCH32_PATH),$(SRC_AARCH32_GCC),$(AARCH32_GCC_VERSION))

.PHONY: aarch64-toolchain
aarch64-toolchain:
	$(call dltc,$(AARCH64_PATH),$(SRC_AARCH64_GCC),$(AARCH64_GCC_VERSION))

.PHONY: rust-toolchain
rust-toolchain:
	$(call dl-rust-toolchain,$(RUST_TOOLCHAIN_PATH))

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

else ifeq ($(ARCH),riscv)
RISCV64_PATH 			?= $(TOOLCHAIN_ROOT)/riscv64
RISCV64_CROSS_COMPILE 		?= $(RISCV64_PATH)/bin/riscv64-unknown-linux-gnu-
RISCV64_GCC_RELEASE_DATE	?= 2023.07.07
RISCV64_GCC_VERSION		?= riscv64-glibc-ubuntu-22.04-gcc-nightly-$(RISCV64_GCC_RELEASE_DATE)-nightly
SRC_RISCV64_GCC			?= https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/$(RISCV64_GCC_RELEASE_DATE)/$(RISCV64_GCC_VERSION).tar.gz

.PHONY: toolchains
toolchains: riscv64-toolchain

.PHONY: riscv64-toolchain
riscv64-toolchain:
	$(call dltc,$(RISCV64_PATH),$(SRC_RISCV64_GCC),$(RISCV64_GCC_VERSION))

endif

else ifeq ($(UNAME_M),aarch64)

# Please keep in sync with br-ext/configs/toolchain-aarch32
# and above for x86_64 host
AARCH32_PATH 			?= $(TOOLCHAIN_ROOT)/aarch32
AARCH32_CROSS_COMPILE 		?= $(AARCH32_PATH)/bin/arm-linux-gnueabihf-
AARCH32_GCC_VERSION 		?= arm-gnu-toolchain-11.3.rel1-aarch64-arm-none-linux-gnueabihf
SRC_AARCH32_GCC 		?= https://developer.arm.com/-/media/Files/downloads/gnu/11.3.rel1/binrel/$(AARCH32_GCC_VERSION).tar.xz

# There isn't any native aarch64 toolchain released from Arm and buildroot
# doesn't support distribution toolchain [1]. So we are left with no choice
# but to build buildroot toolchain from source and use it.
#
# [1] https://buildroot.org/downloads/manual/manual.html#_cross_compilation_toolchain
AARCH64_PATH 			?= $(TOOLCHAIN_ROOT)/aarch64
AARCH64_CROSS_COMPILE 		?= $(AARCH64_PATH)/bin/aarch64-linux-

.PHONY: toolchains
toolchains: aarch32-toolchain $(AARCH64_PATH)/.done rust-toolchain

.PHONY: aarch32-toolchain
aarch32-toolchain:
	$(call dltc,$(AARCH32_PATH),$(SRC_AARCH32_GCC),$(AARCH32_GCC_VERSION))

$(AARCH64_PATH)/.done:
	$(call build_toolchain,aarch64,$(AARCH64_PATH),aarch64,gnu)

.PHONY: rust-toolchain
rust-toolchain:
	$(call dl-rust-toolchain,$(RUST_TOOLCHAIN_PATH))

else # $(UNAME_M) != x86_64 or $(UNAME_M) != aarch64
AARCH32_PATH 			:= $(TOOLCHAIN_ROOT)/aarch32
AARCH32_CROSS_COMPILE 		:= $(AARCH32_PATH)/bin/arm-linux-
AARCH64_PATH 			:= $(TOOLCHAIN_ROOT)/aarch64
AARCH64_CROSS_COMPILE 		:= $(AARCH64_PATH)/bin/aarch64-linux-

.PHONY: toolchains
toolchains: $(AARCH64_PATH)/.done $(AARCH32_PATH)/.done

$(AARCH64_PATH)/.done:
	$(call build_toolchain,aarch64,$(AARCH64_PATH),aarch64,gnu)

$(AARCH32_PATH)/.done:
	$(call build_toolchain,aarch32,$(AARCH32_PATH),arm,gnueabihf)
endif
