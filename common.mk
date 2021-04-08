#
# Common definition to all platforms
#

# Set a variable or error out if it was previously set to a different value
# The reason message (3rd parameter) is optional
# Example:
# $(call force,CFG_FOO,foo,required by CFG_BAR)
define force
$(eval $(call _force,$(1),$(2),$(3)))
endef

define _force
ifdef $(1)
ifneq ($($(1)),$(2))
ifneq (,$(3))
_reason := $$(_empty) [$(3)]
endif
$$(error $(1) is set to '$($(1))' (from $(origin $(1))) but its value must be '$(2)'$$(_reason))
endif
endif
$(1) := $(2)
endef

SHELL := bash
BASH ?= bash
ROOT ?= $(shell pwd)/..

BUILD_PATH			?= $(ROOT)/build
LINUX_PATH			?= $(ROOT)/linux
OPTEE_OS_PATH			?= $(ROOT)/optee_os
OPTEE_CLIENT_PATH		?= $(ROOT)/optee_client
OPTEE_TEST_PATH			?= $(ROOT)/optee_test
OPTEE_EXAMPLES_PATH		?= $(ROOT)/optee_examples
BUILDROOT_TARGET_ROOT		?= $(ROOT)/out-br/target

# default high verbosity. slow uarts shall specify lower if prefered
CFG_TEE_CORE_LOG_LEVEL		?= 3

# default disable latency benchmarks (over all OP-TEE layers)
CFG_TEE_BENCHMARK		?= n

# optee_test
WITH_TLS_TESTS			?= y
ifneq ($(COMPILER),clang)
# assuming GCC toolchain from toolchain.mk
WITH_CXX_TESTS			?= y
endif

CCACHE ?= $(shell which ccache) # Don't remove this comment (space is needed)

# QEMU shared folders settings
#
# TL;DR:
# 1) make QEMU_VIRTFS_AUTOMOUNT=y run
#    will mount the project's root on the host as /mnt/host in QEMU.
# 2) mkdir -p /tmp/qemu-data-tee && make QEMU_PSS_AUTOMOUNT=y run
#    will mount the host directory /tmp/qemu-data-tee as /data/tee
#    in QEMU, thus creating persistent secure storage.

ifeq ($(QEMU_VIRTFS_AUTOMOUNT),y)
$(call force,QEMU_VIRTFS_ENABLE,y,required by QEMU_VIRTFS_AUTOMOUNT)
endif

ifeq ($(QEMU_PSS_AUTOMOUNT),y)
$(call force,QEMU_PSS_ENABLE,y,required by QEMU_PSS_AUTOMOUNT)
endif

ifeq ($(QEMU_PSS_ENABLE),y)
$(call force,QEMU_VIRTFS_ENABLE,y,required by QEMU_PSS_ENABLE)
endif

# Accessing a shared folder on the host from QEMU:
# # Set QEMU_VIRTFS_ENABLE to 'y' and adjust QEMU_VIRTFS_HOST_DIR
# # Then in QEMU, run:
# # $ mount -t 9p -o trans=virtio host <mount_point>
# # Or enable QEMU_VIRTFS_AUTOMOUNT
QEMU_VIRTFS_ENABLE	?= n
QEMU_VIRTFS_HOST_DIR	?= $(ROOT)

# Persistent Secure Storage via shared folder
# # Set QEMU_PSS_ENABLE to 'y' and adjust QEMU_PSS_HOST_DIR
# # Then in QEMU, run:
# # $ mount -t 9p -o trans=virtio secure /data/tee
# # Or enable QEMU_PSS_AUTOMOUNT
QEMU_PSS_ENABLE		?= n
QEMU_PSS_HOST_DIR	?= /tmp/qemu-data-tee

# Warning: when these variables are modified, you must remake the buildroot
# target directory. This can be done without rebuilding everything as follows:
# rm -rf ../out-br/target; find ../out-br/ -name .stamp_target_installed | xargs rm
# make <flags> run
QEMU_VIRTFS_AUTOMOUNT	?= n
QEMU_PSS_AUTOMOUNT	?= n
# Mount point for the shared directory inside QEMU
# Used by the post-build script, this is written to /etc/fstab as the mount
# point of the shared directory
QEMU_VIRTFS_MOUNTPOINT	?= /mnt/host

# End of QEMU shared folder settings

################################################################################
# Mandatory for autotools (for specifying --host)
################################################################################
ifeq ($(COMPILE_NS_USER),64)
MULTIARCH			:= aarch64-linux-gnu
else
MULTIARCH			:= arm-linux-gnueabihf
endif

################################################################################
# Check coherency of compilation mode
################################################################################

ifneq ($(COMPILE_NS_USER),)
ifeq ($(COMPILE_NS_KERNEL),)
$(error COMPILE_NS_KERNEL must be defined as COMPILE_NS_USER=$(COMPILE_NS_USER) is defined)
endif
ifeq (,$(filter $(COMPILE_NS_USER),32 64))
$(error COMPILE_NS_USER=$(COMPILE_NS_USER) - Should be 32 or 64)
endif
endif

ifneq ($(COMPILE_NS_KERNEL),)
ifeq ($(COMPILE_NS_USER),)
$(error COMPILE_NS_USER must be defined as COMPILE_NS_KERNEL=$(COMPILE_NS_KERNEL) is defined)
endif
ifeq (,$(filter $(COMPILE_NS_KERNEL),32 64))
$(error COMPILE_NS_KERNEL=$(COMPILE_NS_KERNEL) - Should be 32 or 64)
endif
endif

ifeq ($(COMPILE_NS_KERNEL),32)
ifneq ($(COMPILE_NS_USER),32)
$(error COMPILE_NS_USER=$(COMPILE_NS_USER) - Should be 32 as COMPILE_NS_KERNEL=$(COMPILE_NS_KERNEL))
endif
endif

ifneq ($(COMPILE_S_USER),)
ifeq ($(COMPILE_S_KERNEL),)
$(error COMPILE_S_KERNEL must be defined as COMPILE_S_USER=$(COMPILE_S_USER) is defined)
endif
ifeq (,$(filter $(COMPILE_S_USER),32 64))
$(error COMPILE_S_USER=$(COMPILE_S_USER) - Should be 32 or 64)
endif
endif

ifneq ($(COMPILE_S_KERNEL),)
OPTEE_OS_COMMON_EXTRA_FLAGS ?= O=out/arm
OPTEE_OS_BIN		    ?= $(OPTEE_OS_PATH)/out/arm/core/tee.bin
OPTEE_OS_HEADER_V2_BIN	    ?= $(OPTEE_OS_PATH)/out/arm/core/tee-header_v2.bin
OPTEE_OS_PAGER_V2_BIN	    ?= $(OPTEE_OS_PATH)/out/arm/core/tee-pager_v2.bin
OPTEE_OS_PAGEABLE_V2_BIN    ?= $(OPTEE_OS_PATH)/out/arm/core/tee-pageable_v2.bin
ifeq ($(COMPILE_S_USER),)
$(error COMPILE_S_USER must be defined as COMPILE_S_KERNEL=$(COMPILE_S_KERNEL) is defined)
endif
ifeq (,$(filter $(COMPILE_S_KERNEL),32 64))
$(error COMPILE_S_KERNEL=$(COMPILE_S_KERNEL) - Should be 32 or 64)
endif
endif

ifeq ($(COMPILE_S_KERNEL),32)
ifneq ($(COMPILE_S_USER),32)
$(error COMPILE_S_USER=$(COMPILE_S_USER) - Should be 32 as COMPILE_S_KERNEL=$(COMPILE_S_KERNEL))
endif
endif


################################################################################
# set the compiler when COMPILE_xxx are defined
################################################################################


ifeq ($(COMPILE_LEGACY),)
CROSS_COMPILE_NS_USER   ?= "$(CCACHE)$(AARCH$(COMPILE_NS_USER)_CROSS_COMPILE)"
CROSS_COMPILE_NS_KERNEL ?= "$(CCACHE)$(AARCH$(COMPILE_NS_KERNEL)_CROSS_COMPILE)"
CROSS_COMPILE_S_USER    ?= "$(CCACHE)$(AARCH$(COMPILE_S_USER)_CROSS_COMPILE)"
CROSS_COMPILE_S_KERNEL  ?= "$(CCACHE)$(AARCH$(COMPILE_S_KERNEL)_CROSS_COMPILE)"
else
CROSS_COMPILE_NS_USER   ?= "$(CCACHE)$(LEGACY_AARCH$(COMPILE_NS_USER)_CROSS_COMPILE)"
CROSS_COMPILE_NS_KERNEL ?= "$(CCACHE)$(LEGACY_AARCH$(COMPILE_NS_KERNEL)_CROSS_COMPILE)"
CROSS_COMPILE_S_USER    ?= "$(CCACHE)$(LEGACY_AARCH$(COMPILE_S_USER)_CROSS_COMPILE)"
CROSS_COMPILE_S_KERNEL  ?= "$(CCACHE)$(LEGACY_AARCH$(COMPILE_S_KERNEL)_CROSS_COMPILE)"
endif

ifeq ($(COMPILE_S_USER),32)
OPTEE_OS_TA_DEV_KIT_DIR	?= $(OPTEE_OS_PATH)/out/arm/export-ta_arm32
endif
ifeq ($(COMPILE_S_USER),64)
OPTEE_OS_TA_DEV_KIT_DIR	?= $(OPTEE_OS_PATH)/out/arm/export-ta_arm64
endif

ifeq ($(COMPILE_S_KERNEL),64)
OPTEE_OS_COMMON_EXTRA_FLAGS	+= CFG_ARM64_core=y
else
OPTEE_OS_COMMON_EXTRA_FLAGS	+= CFG_ARM64_core=n
endif


################################################################################
# defines, macros, configuration etc
################################################################################
define KERNEL_VERSION
$(shell cd $(LINUX_PATH) && $(MAKE) --no-print-directory kernelversion)
endef

# Read stdin, expand ${VAR} environment variables, output to stdout
# http://superuser.com/a/302847
define expand-env-var
awk '{while(match($$0,"[$$]{[^}]*}")) {var=substr($$0,RSTART+2,RLENGTH -3);gsub("[$$]{"var"}",ENVIRON[var])}}1'
endef

DEBUG ?= 0

# Macro to check if a compiler supports a given option
# For example: $(call cc-option,gcc,-Wno-error=stringop-truncation,)
#   ...will return -Wno-error=stringop-truncation if gcc supports it, empty
#   otherwise.
__cc-option = $(if $(shell $(1) $(2) -c -x c /dev/null -o /dev/null 2>&1 >/dev/null),$(3),$(2))
_cc-opt-cached-var-name = cached-cc-option$(subst =,~,$(strip $(2)))$(subst $(empty) $(empty),,$(1))
define _cc-option
$(eval _cached := $(call _cc-opt-cached-var-name,$1,$2))
$(eval $(_cached) := $(if $(filter $(origin $(_cached)),undefined),$(call __cc-option,$(1),$(2),$(3)),$($(_cached))))
$($(_cached))
endef
cc-option = $(strip $(call _cc-option,$(1),$(2),$(3)))

################################################################################
# default target is all
################################################################################
.PHONY: all
all:

################################################################################
# Build root
################################################################################
BUILDROOT_ARCH=aarch$(COMPILE_NS_USER)
ifeq ($(GDBSERVER),y)
BUILDROOT_TOOLCHAIN=toolchain-br # Use toolchain supplied by buildroot
DEFCONFIG_GDBSERVER=--br-defconfig build/br-ext/configs/gdbserver.conf
else
# Local toolchains (downloaded by "make toolchains")
ifeq ($(COMPILE_LEGACY),)
BUILDROOT_TOOLCHAIN=toolchain-aarch$(COMPILE_NS_USER)
else
BUILDROOT_TOOLCHAIN=toolchain-aarch$(COMPILE_NS_USER)-legacy
endif
endif

BR2_PACKAGE_LIBOPENSSL ?= y
BR2_PACKAGE_MMC_UTILS ?= y
BR2_PACKAGE_OPENSSL ?= y
BR2_PACKAGE_OPTEE_BENCHMARK_EXT ?= $(CFG_TEE_BENCHMARK)
BR2_PACKAGE_OPTEE_BENCHMARK_EXT_SITE ?= $(BENCHMARK_APP_PATH)
BR2_PACKAGE_OPTEE_CLIENT_EXT_SITE ?= $(OPTEE_CLIENT_PATH)
BR2_PACKAGE_OPTEE_EXAMPLES_EXT ?= y
BR2_PACKAGE_OPTEE_EXAMPLES_EXT_CROSS_COMPILE ?= $(CROSS_COMPILE_S_USER)
BR2_PACKAGE_OPTEE_EXAMPLES_EXT_SDK ?= $(OPTEE_OS_TA_DEV_KIT_DIR)
BR2_PACKAGE_OPTEE_EXAMPLES_EXT_SITE ?= $(OPTEE_EXAMPLES_PATH)
# The OPTEE_OS package builds nothing, it just installs files into the
# root FS when applicable (for example: shared libraries)
BR2_PACKAGE_OPTEE_OS_EXT ?= y
BR2_PACKAGE_OPTEE_OS_EXT_SDK ?= $(OPTEE_OS_TA_DEV_KIT_DIR)
BR2_PACKAGE_OPTEE_OS_EXT_SITE ?= $(CURDIR)/br-ext/package/optee_os_ext
BR2_PACKAGE_OPTEE_TEST_EXT ?= y
BR2_PACKAGE_OPTEE_TEST_EXT_CROSS_COMPILE ?= $(CROSS_COMPILE_S_USER)
BR2_PACKAGE_OPTEE_TEST_EXT_SDK ?= $(OPTEE_OS_TA_DEV_KIT_DIR)
BR2_PACKAGE_OPTEE_TEST_EXT_SITE ?= $(OPTEE_TEST_PATH)
BR2_PACKAGE_OPTEE_TEST_EXT_GP_PACKAGE := $(GP_PACKAGE)
BR2_PACKAGE_OPTEE_TEST_EXT_WITH_TLS_TESTS := $(WITH_TLS_TESTS)
BR2_PACKAGE_OPTEE_TEST_EXT_WITH_CXX_TESTS := $(WITH_CXX_TESTS)
BR2_PACKAGE_STRACE ?= y
BR2_TARGET_GENERIC_GETTY_PORT ?= $(if $(CFG_NW_CONSOLE_UART),ttyAMA$(CFG_NW_CONSOLE_UART),ttyAMA0)

# Embed opensc for pkcs11-tool
BR2_PACKAGE_OPENSC ?= y

# All BR2_* variables from the makefile or the environment are appended to
# ../out-br/extra.conf. All values are quoted "..." except y and n.
double-quote = "#" # This really sets the variable to " and avoids upsetting vim's syntax highlighting
streq = $(and $(findstring $(1),$(2)),$(findstring $(2),$(1)))
y-or-n = $(or $(call streq,y,$(1)),$(call streq,n,$(1)))
append-var_ = echo '$(1)=$(3)'$($(1))'$(3)' >>$(2);
append-var = $(call append-var_,$(1),$(2),$(if $(call y-or-n,$($(1))),,$(double-quote)))
append-br2-vars = $(foreach var,$(filter BR2_%,$(.VARIABLES)),$(call append-var,$(var),$(1)))

.PHONY: buildroot
buildroot: optee-os
	@mkdir -p ../out-br
	@rm -f ../out-br/build/optee_*/.stamp_*
	@rm -f ../out-br/extra.conf
	@$(call append-br2-vars,../out-br/extra.conf)
	@(cd .. && python build/br-ext/scripts/make_def_config.py \
		--br buildroot --out out-br --br-ext build/br-ext \
		--top-dir "$(ROOT)" \
		--br-defconfig build/br-ext/configs/optee_$(BUILDROOT_ARCH) \
		--br-defconfig build/br-ext/configs/optee_generic \
		--br-defconfig build/br-ext/configs/$(BUILDROOT_TOOLCHAIN) \
		$(DEFCONFIG_GDBSERVER) \
		--br-defconfig out-br/extra.conf \
		--make-cmd $(MAKE))
	@$(MAKE) -C ../out-br all

.PHONY: buildroot-clean
buildroot-clean:
	@test ! -d $(ROOT)/out-br || $(MAKE) -C $(ROOT)/out-br clean

.PHONY: buildroot-cleaner
buildroot-cleaner:
	@rm -rf $(ROOT)/out-br

################################################################################
# Linux
################################################################################
ifeq ($(CFG_TEE_BENCHMARK),y)
LINUX_DEFCONFIG_BENCH ?= $(CURDIR)/kconfigs/tee_bench.conf
endif

LINUX_COMMON_FLAGS ?= LOCALVERSION= CROSS_COMPILE=$(CROSS_COMPILE_NS_KERNEL)

.PHONY: linux-common
linux-common: linux-defconfig
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS)

$(LINUX_PATH)/.config: $(LINUX_DEFCONFIG_COMMON_FILES)
	cd $(LINUX_PATH) && \
		ARCH=$(LINUX_DEFCONFIG_COMMON_ARCH) \
		scripts/kconfig/merge_config.sh $(LINUX_DEFCONFIG_COMMON_FILES) \
			$(LINUX_DEFCONFIG_BENCH)

.PHONY: linux-defconfig-clean-common
linux-defconfig-clean-common:
	rm -f $(LINUX_PATH)/.config

# LINUX_CLEAN_COMMON_FLAGS should be defined in specific makefiles (hikey.mk,...)
.PHONY: linux-clean-common
linux-clean-common: linux-defconfig-clean
	$(MAKE) -C $(LINUX_PATH) $(LINUX_CLEAN_COMMON_FLAGS) clean

# LINUX_CLEANER_COMMON_FLAGS should be defined in specific makefiles (hikey.mk,...)
.PHONY: linux-cleaner-common
linux-cleaner-common: linux-defconfig-clean
	$(MAKE) -C $(LINUX_PATH) $(LINUX_CLEANER_COMMON_FLAGS) distclean

################################################################################
# EDK2 / Tianocore
################################################################################
.PHONY: edk2-common
edk2-common:
	$(call edk2-env) && \
	export PACKAGES_PATH=$(EDK2_PATH):$(EDK2_PLATFORMS_PATH) && \
	source $(EDK2_PATH)/edksetup.sh && \
	$(MAKE) -j1 -C $(EDK2_PATH)/BaseTools && \
	$(call edk2-call) all

.PHONY: edk2-clean-common
edk2-clean-common:
	$(call edk2-env) && \
	export PACKAGES_PATH=$(EDK2_PATH):$(EDK2_PLATFORMS_PATH) && \
	source $(EDK2_PATH)/edksetup.sh && \
	$(MAKE) -j1 -C $(EDK2_PATH)/BaseTools clean && \
	$(call edk2-call) cleanall

################################################################################
# QEMU / QEMUv8
################################################################################
QEMU_CONFIGURE_PARAMS_COMMON = --cc="$(CCACHE)gcc" --extra-cflags="-Wno-error" \
			       --disable-docs
QEMU_EXTRA_ARGS +=\
	-object rng-random,filename=/dev/urandom,id=rng0 \
	-device virtio-rng-pci,rng=rng0,max-bytes=1024,period=1000

ifeq ($(QEMU_VIRTFS_ENABLE),y)
QEMU_CONFIGURE_PARAMS_COMMON +=  --enable-virtfs
QEMU_EXTRA_ARGS +=\
	-fsdev local,id=fsdev0,path=$(QEMU_VIRTFS_HOST_DIR),security_model=none \
	-device virtio-9p-device,fsdev=fsdev0,mount_tag=host
ifeq ($(QEMU_PSS_ENABLE),y)
QEMU_EXTRA_ARGS +=\
	  -fsdev local,id=fsdev1,path=$(QEMU_PSS_HOST_DIR),security_model=none \
	  -device virtio-9p-device,fsdev=fsdev1,mount_tag=secure
endif
endif

ifeq ($(GDBSERVER),y)
HOSTFWD := ,hostfwd=tcp::12345-:12345
endif
# Enable QEMU SLiRP user networking
QEMU_EXTRA_ARGS +=\
	-netdev user,id=vmnic$(HOSTFWD) -device virtio-net-device,netdev=vmnic

define run-help
	@echo
	@echo \* QEMU is now waiting to start the execution
	@echo \* Start execution with either a \'c\' followed by \<enter\> in the QEMU console or
	@echo \* attach a debugger and continue from there.
	@echo \*
	@echo \* To run OP-TEE tests, use the xtest command in the \'Normal World\' terminal
	@echo \* Enter \'xtest -h\' for help.
	@echo
endef

ifneq (, $(LAUNCH_TERMINAL))
define launch-terminal
	@nc -z  127.0.0.1 $(1) || \
		$(LAUNCH_TERMINAL) "$(SOC_TERM_PATH)/soc_term $(1)" &
endef
else
gnome-terminal := $(shell command -v gnome-terminal 2>/dev/null)
xterm := $(shell command -v xterm 2>/dev/null)
ifdef gnome-terminal
define launch-terminal
	@nc -z  127.0.0.1 $(1) || \
	$(gnome-terminal) -x $(SOC_TERM_PATH)/soc_term $(1) &
endef
else
ifdef xterm
define launch-terminal
	@nc -z  127.0.0.1 $(1) || \
	$(xterm) -title $(2) -e $(BASH) -c "$(SOC_TERM_PATH)/soc_term $(1)" &
endef
else
check-terminal := @echo "Error: could not find gnome-terminal nor xterm" ; false
endif
endif
endif

define wait-for-ports
	@while ! nc -z 127.0.0.1 $(1) || ! nc -z 127.0.0.1 $(2); do sleep 1; done
endef

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS ?= \
	$(OPTEE_OS_COMMON_EXTRA_FLAGS) \
	PLATFORM=$(OPTEE_OS_PLATFORM) \
	CROSS_COMPILE=$(CROSS_COMPILE_S_USER) \
	CROSS_COMPILE_core=$(CROSS_COMPILE_S_KERNEL) \
	CROSS_COMPILE_ta_arm64="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
	CROSS_COMPILE_ta_arm32="$(CCACHE)$(AARCH32_CROSS_COMPILE)" \
	CFG_TEE_CORE_LOG_LEVEL=$(CFG_TEE_CORE_LOG_LEVEL) \
	DEBUG=$(DEBUG) \
	CFG_TEE_BENCHMARK=$(CFG_TEE_BENCHMARK)

.PHONY: optee-os-common
optee-os-common:
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_COMMON_FLAGS)

.PHONY: optee-os-clean-common
optee-os-clean-common:
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_COMMON_FLAGS) clean
