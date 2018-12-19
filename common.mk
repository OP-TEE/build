#
# Common definition to all platforms
#

SHELL := bash
BASH ?= bash
ROOT ?= $(shell pwd)/..

BUILD_PATH			?= $(ROOT)/build
LINUX_PATH			?= $(ROOT)/linux
OPTEE_GENDRV_MODULE		?= $(LINUX_PATH)/drivers/tee/optee/optee.ko
GEN_ROOTFS_PATH			?= $(ROOT)/gen_rootfs
GEN_ROOTFS_FILELIST		?= $(GEN_ROOTFS_PATH)/filelist-tee.txt
OPTEE_OS_PATH			?= $(ROOT)/optee_os
OPTEE_CLIENT_PATH		?= $(ROOT)/optee_client
OPTEE_CLIENT_EXPORT		?= $(OPTEE_CLIENT_PATH)/out/export
OPTEE_TEST_PATH			?= $(ROOT)/optee_test
OPTEE_TEST_OUT_PATH		?= $(ROOT)/optee_test/out
OPTEE_EXAMPLES_PATH		?= $(ROOT)/optee_examples
BENCHMARK_APP_PATH		?= $(ROOT)/optee_benchmark
BENCHMARK_APP_OUT		?= $(BENCHMARK_APP_PATH)/out
LIBYAML_LIB_OUT			?= $(BENCHMARK_APP_OUT)/libyaml/out/lib
BUILDROOT_TARGET_ROOT		?= $(ROOT)/out-br/target

# default high verbosity. slow uarts shall specify lower if prefered
CFG_TEE_CORE_LOG_LEVEL		?= 3

# default disable latency benchmarks (over all OP-TEE layers)
CFG_TEE_BENCHMARK		?= n

CCACHE ?= $(shell which ccache) # Don't remove this comment (space is needed)

# Accessing a shared folder on the host from QEMU:
# # Set QEMU_VIRTFS_ENABLE to 'y' and adjust QEMU_VIRTFS_HOST_DIR
# # Then in QEMU, run:
# # $ mount -t 9p -o trans=virtio host <mount_point>
QEMU_VIRTFS_ENABLE		?= n
QEMU_VIRTFS_HOST_DIR	?= $(ROOT)

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

################################################################################
# default target is all
################################################################################
.PHONY: all
all:

################################################################################
# Busybox
################################################################################
BUSYBOX_COMMON_TARGET		?= TOBEDEFINED
BUSYBOX_CLEAN_COMMON_TARGET	?= TOBEDEFINED

.PHONY: busybox-common
busybox-common: linux
	cd $(GEN_ROOTFS_PATH) &&  \
		CROSS_COMPILE=$(CROSS_COMPILE_NS_USER) \
		PATH=${PATH}:$(LINUX_PATH)/usr \
		$(GEN_ROOTFS_PATH)/generate-cpio-rootfs.sh \
			$(BUSYBOX_COMMON_TARGET)

.PHONY: busybox-clean-common
busybox-clean-common:
	cd $(GEN_ROOTFS_PATH) && \
	$(GEN_ROOTFS_PATH)/generate-cpio-rootfs.sh  \
		$(BUSYBOX_CLEAN_COMMON_TARGET)

.PHONY: busybox-cleaner-common
busybox-cleaner-common:
	rm -rf $(GEN_ROOTFS_PATH)/build
	rm -rf $(GEN_ROOTFS_PATH)/filelist-final.txt

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
BUILDROOT_GETTY_PORT ?= \
	$(if $(CFG_NW_CONSOLE_UART),ttyAMA$(CFG_NW_CONSOLE_UART),ttyAMA0)
.PHONY: buildroot
buildroot: optee-os
	@mkdir -p ../out-br
	@rm -f ../out-br/build/optee_*/.stamp_*
	@rm -f ../out-br/extra.conf
	@touch ../out-br/extra.conf
	@echo "BR2_TARGET_GENERIC_GETTY_PORT=\"$(BUILDROOT_GETTY_PORT)\"" >> \
		../out-br/extra.conf
ifneq (,$(BR2_ROOTFS_OVERLAY))
	@echo "BR2_ROOTFS_OVERLAY=\"$(BR2_ROOTFS_OVERLAY)\"" >> ../out-br/extra.conf
endif
ifneq (,$(BR2_ROOTFS_POST_BUILD_SCRIPT))
	@echo "BR2_ROOTFS_POST_BUILD_SCRIPT=\"$(BR2_ROOTFS_POST_BUILD_SCRIPT)\"" >> \
		../out-br/extra.conf
endif
	@echo "BR2_PACKAGE_OPTEE_TEST_CROSS_COMPILE=\"$(CROSS_COMPILE_S_USER)\"" >> \
		../out-br/extra.conf
	@echo "BR2_PACKAGE_OPTEE_EXAMPLES_CROSS_COMPILE=\"$(CROSS_COMPILE_S_USER)\"" >> \
		../out-br/extra.conf
	@echo "BR2_PACKAGE_OPTEE_TEST_SDK=\"$(OPTEE_OS_TA_DEV_KIT_DIR)\"" >> \
		../out-br/extra.conf
	@echo "BR2_PACKAGE_OPTEE_EXAMPLES_SDK=\"$(OPTEE_OS_TA_DEV_KIT_DIR)\"" >> \
		../out-br/extra.conf
	@echo "BR2_PACKAGE_OPTEE_CLIENT_SITE=\"$(OPTEE_CLIENT_PATH)\"" >> \
		../out-br/extra.conf
	@echo "BR2_PACKAGE_OPTEE_TEST_SITE=\"$(OPTEE_TEST_PATH)\"" >> \
		../out-br/extra.conf
	@echo "BR2_PACKAGE_OPTEE_EXAMPLES_SITE=\"$(OPTEE_EXAMPLES_PATH)\"" >> \
		../out-br/extra.conf
	@echo "BR2_PACKAGE_OPTEE_BENCHMARK_SITE=\"$(BENCHMARK_APP_PATH)\"" >> \
		../out-br/extra.conf
	@echo "BR2_PACKAGE_OPTEE_TEST=y" >> ../out-br/extra.conf
	@echo "BR2_PACKAGE_OPTEE_EXAMPLES=y" >> ../out-br/extra.conf
	@echo "BR2_PACKAGE_STRACE=y" >> ../out-br/extra.conf
ifeq ($(CFG_TEE_BENCHMARK),y)
	@echo "BR2_PACKAGE_OPTEE_BENCHMARK=y" >> ../out-br/extra.conf
endif
	@echo "BR2_PACKAGE_OPENSSL=y" >> ../out-br/extra.conf
	@echo "BR2_PACKAGE_LIBOPENSSL=y" >> ../out-br/extra.conf
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
	export PACKAGES_PATH=$(EDK2_PATH):$(ROOT)/edk2-platforms && \
	source $(EDK2_PATH)/edksetup.sh && \
	$(MAKE) -j1 -C $(EDK2_PATH)/BaseTools clean && \
	$(call edk2-call) cleanall

################################################################################
# QEMU / QEMUv8
################################################################################
QEMU_CONFIGURE_PARAMS_COMMON = --cc="$(CCACHE)gcc" --extra-cflags="-Wno-error"

ifeq ($(QEMU_VIRTFS_ENABLE),y)
QEMU_CONFIGURE_PARAMS_COMMON +=  --enable-virtfs
QEMU_EXTRA_ARGS +=\
	-fsdev local,id=fsdev0,path=$(QEMU_VIRTFS_HOST_DIR),security_model=none \
	-device virtio-9p-device,fsdev=fsdev0,mount_tag=host
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
		$(LAUNCH_TERMINAL) $(SOC_TERM_PATH)/soc_term $(1) &
endef
else
gnome-terminal := $(shell command -v gnome-terminal 2>/dev/null)
xterm := $(shell command -v xterm 2>/dev/null)
ifdef gnome-terminal
# Note: the title option (-t) is ignored with gnome-terminal versions
# >= 3.14 and < 3.20
define launch-terminal
	@nc -z  127.0.0.1 $(1) || \
	$(gnome-terminal) -t "$(2)" -x $(SOC_TERM_PATH)/soc_term $(1) &
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
	CROSS_COMPILE=$(CROSS_COMPILE_S_USER) \
	CROSS_COMPILE_core=$(CROSS_COMPILE_S_KERNEL) \
	CROSS_COMPILE_ta_arm64=$(AARCH64_CROSS_COMPILE) \
	CROSS_COMPILE_ta_arm32=$(AARCH32_CROSS_COMPILE) \
	CFG_TEE_CORE_LOG_LEVEL=$(CFG_TEE_CORE_LOG_LEVEL) \
	DEBUG=$(DEBUG) \
	CFG_TEE_BENCHMARK=$(CFG_TEE_BENCHMARK)

.PHONY: optee-os-common
optee-os-common:
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_COMMON_FLAGS)

OPTEE_OS_CLEAN_COMMON_FLAGS ?= $(OPTEE_OS_COMMON_EXTRA_FLAGS)

.PHONY: optee-os-clean-common
ifeq ($(CFG_TEE_BENCHMARK),y)
optee-os-clean-common: benchmark-app-clean-common
endif
optee-os-clean-common: xtest-clean-common optee-examples-clean-common
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_CLEAN_COMMON_FLAGS) clean

OPTEE_CLIENT_COMMON_FLAGS ?= CROSS_COMPILE=$(CROSS_COMPILE_NS_USER) \
	CFG_TEE_BENCHMARK=$(CFG_TEE_BENCHMARK) \

.PHONY: optee-client-common
optee-client-common:
	$(MAKE) -C $(OPTEE_CLIENT_PATH) $(OPTEE_CLIENT_COMMON_FLAGS)

# OPTEE_CLIENT_CLEAN_COMMON_FLAGS can be defined in specific makefiles
# (hikey.mk,...) if necessary

.PHONY: optee-client-clean-common
optee-client-clean-common:
	$(MAKE) -C $(OPTEE_CLIENT_PATH) $(OPTEE_CLIENT_CLEAN_COMMON_FLAGS) \
		clean

################################################################################
# xtest / optee_test
################################################################################
XTEST_COMMON_FLAGS ?= CROSS_COMPILE_HOST=$(CROSS_COMPILE_NS_USER)\
	CROSS_COMPILE_TA=$(CROSS_COMPILE_S_USER) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \
	OPTEE_CLIENT_EXPORT=$(OPTEE_CLIENT_EXPORT) \
	COMPILE_NS_USER=$(COMPILE_NS_USER) \
	O=$(OPTEE_TEST_OUT_PATH)

.PHONY: xtest-common
xtest-common: optee-os optee-client
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_COMMON_FLAGS)

XTEST_CLEAN_COMMON_FLAGS ?= O=$(OPTEE_TEST_OUT_PATH) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \

.PHONY: xtest-clean-common
xtest-clean-common:
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_CLEAN_COMMON_FLAGS) clean

XTEST_PATCH_COMMON_FLAGS ?= $(XTEST_COMMON_FLAGS)

.PHONY: xtest-patch-common
xtest-patch-common:
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_PATCH_COMMON_FLAGS) patch

################################################################################
# sample applications / optee_examples
################################################################################
OPTEE_EXAMPLES_COMMON_FLAGS ?= HOST_CROSS_COMPILE=$(CROSS_COMPILE_NS_USER)\
	TA_CROSS_COMPILE=$(CROSS_COMPILE_S_USER) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \
	TEEC_EXPORT=$(OPTEE_CLIENT_EXPORT)

.PHONY: optee-examples-common
optee-examples-common: optee-os optee-client
	$(MAKE) -C $(OPTEE_EXAMPLES_PATH) $(OPTEE_EXAMPLES_COMMON_FLAGS)

OPTEE_EXAMPLES_CLEAN_COMMON_FLAGS ?= TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR)

.PHONY: optee-examples-clean-common
optee-examples-clean-common:
	$(MAKE) -C $(OPTEE_EXAMPLES_PATH) \
			$(OPTEE_EXAMPLES_CLEAN_COMMON_FLAGS) clean

################################################################################
# benchmark_app
################################################################################
BENCHMARK_APP_COMMON_FLAGS ?= CROSS_COMPILE=$(CROSS_COMPILE_NS_USER) \
	TEEC_EXPORT=$(OPTEE_CLIENT_EXPORT) \
	TEEC_INTERNAL_INCLUDES=$(OPTEE_CLIENT_PATH)/libteec \
	MULTIARCH=$(MULTIARCH)

.PHONY: benchmark-app-common
benchmark-app-common: optee-os optee-client
	$(MAKE) -C $(BENCHMARK_APP_PATH) $(BENCHMARK_APP_COMMON_FLAGS)

.PHONY: benchmark-app-clean-common
benchmark-app-clean-common:
	$(MAKE) -C $(BENCHMARK_APP_PATH) clean

################################################################################
# rootfs
################################################################################
.PHONY: update_rootfs-common
update_rootfs-common: busybox filelist-tee
	cat $(GEN_ROOTFS_PATH)/filelist-final.txt > $(GEN_ROOTFS_PATH)/filelist.tmp
	cat $(GEN_ROOTFS_FILELIST) >> $(GEN_ROOTFS_PATH)/filelist.tmp
	cd $(GEN_ROOTFS_PATH) && \
	        $(LINUX_PATH)/usr/gen_init_cpio $(GEN_ROOTFS_PATH)/filelist.tmp | \
			gzip > $(GEN_ROOTFS_PATH)/filesystem.cpio.gz

.PHONY: update_rootfs-clean-common
update_rootfs-clean-common:
	rm -f $(GEN_ROOTFS_PATH)/filesystem.cpio.gz
	rm -f $(GEN_ROOTFS_PATH)/filelist-all.txt
	rm -f $(GEN_ROOTFS_PATH)/filelist-tmp.txt
	rm -f $(GEN_ROOTFS_FILELIST)

.PHONY: filelist-tee-common
ifeq ($(CFG_TEE_BENCHMARK),y)
filelist-tee-common: benchmark-app
endif
filelist-tee-common: fl:=$(GEN_ROOTFS_FILELIST)
filelist-tee-common: optee-client xtest optee-examples
	@echo "# filelist-tee-common /start" 				> $(fl)
	@echo "dir /lib/optee_armtz 755 0 0" 				>> $(fl)
	@if [ -e $(OPTEE_EXAMPLES_PATH)/out/ca ]; then \
		for file in $(OPTEE_EXAMPLES_PATH)/out/ca/*; do \
			echo "file /usr/bin/$$(basename $$file)" \
			"$$file 755 0 0"				>> $(fl); \
		done; \
	fi
	@if [ -e $(OPTEE_EXAMPLES_PATH)/out/ta ]; then \
		for file in $(OPTEE_EXAMPLES_PATH)/out/ta/*; do \
			echo "file /lib/optee_armtz/$$(basename $$file)" \
			"$$file 755 0 0"				>> $(fl); \
		done; \
	fi
	@echo "# xtest / optee_test" 					>> $(fl)
	@find $(OPTEE_TEST_OUT_PATH) -type f -name "xtest" | \
		sed 's/\(.*\)/file \/bin\/xtest \1 755 0 0/g' 		>> $(fl)
	@find $(OPTEE_TEST_OUT_PATH) -name "*.ta" | \
		sed 's/\(.*\)\/\(.*\)/file \/lib\/optee_armtz\/\2 \1\/\2 444 0 0/g' \
									>> $(fl)
	@if [ -e $(BENCHMARK_APP_OUT)/benchmark ]; then \
		echo "file /bin/benchmark" \
			"$(BENCHMARK_APP_OUT)/benchmark 755 0 0"	>> $(fl); \
		echo "slink /lib/libyaml-0.so.2 libyaml-0.so.2.0.5 755 0 0" \
									>> $(fl); \
		echo "file /lib/libyaml-0.so.2.0.5 $(LIBYAML_LIB_OUT)/libyaml-0.so.2.0.5 755 0 0" \
									>> $(fl); \
	fi
	@echo "slink /etc/rc.d/S02_udhcp_networking /etc/init.d/udhcpc 755 0 0" \
									>> $(fl);
	@echo "# Secure storage dir" 					>> $(fl)
	@echo "dir /data 755 0 0" 					>> $(fl)
	@echo "dir /data/tee 755 0 0" 					>> $(fl)
	@if [ -e $(OPTEE_GENDRV_MODULE) ]; then \
		echo "# OP-TEE device" 					>> $(fl); \
		echo "dir /lib/modules 755 0 0" 			>> $(fl); \
		echo "dir /lib/modules/$(call KERNEL_VERSION) 755 0 0" \
									>> $(fl); \
		echo "file /lib/modules/$(call KERNEL_VERSION)/optee.ko" \
			"$(OPTEE_GENDRV_MODULE) 755 0 0" \
									>> $(fl); \
	fi
	@echo "# OP-TEE Client" 					>> $(fl)
	@echo "file /bin/tee-supplicant $(OPTEE_CLIENT_EXPORT)/bin/tee-supplicant 755 0 0" \
									>> $(fl)
	@echo "file /lib/libteec.so.1.0 $(OPTEE_CLIENT_EXPORT)/lib/libteec.so.1.0 755 0 0" \
									>> $(fl)
	@echo "slink /lib/libteec.so.1 libteec.so.1.0 755 0 0"			>> $(fl)
	@echo "slink /lib/libteec.so libteec.so.1 755 0 0" 			>> $(fl)
	@if [ -e $(OPTEE_CLIENT_EXPORT)/lib/libsqlfs.so.1.0 ]; then \
		echo "file /lib/libsqlfs.so.1.0" \
			"$(OPTEE_CLIENT_EXPORT)/lib/libsqlfs.so.1.0 755 0 0" \
									>> $(fl); \
		echo "slink /lib/libsqlfs.so.1 libsqlfs.so.1.0 755 0 0" >> $(fl); \
		echo "slink /lib/libsqlfs.so libsqlfs.so.1 755 0 0" 	>> $(fl); \
	fi
	@echo "file /etc/init.d/optee $(BUILD_PATH)/init.d.optee 755 0 0"	>> $(fl)
	@echo "slink /etc/rc.d/S09_optee /etc/init.d/optee 755 0 0"	>> $(fl)
	@echo "# filelist-tee-common /end"				>> $(fl)
