################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 32
override COMPILE_NS_KERNEL := 32
override COMPILE_S_USER    := 32
override COMPILE_S_KERNEL  := 32

BR2_ROOTFS_OVERLAY = $(ROOT)/build/br-ext/board/qemu/overlay
BR2_ROOTFS_POST_BUILD_SCRIPT = $(ROOT)/build/br-ext/board/qemu/post-build.sh
BR2_ROOTFS_POST_SCRIPT_ARGS = "$(QEMU_VIRTFS_AUTOMOUNT) $(QEMU_VIRTFS_MOUNTPOINT) $(QEMU_PSS_AUTOMOUNT)"

OPTEE_OS_PLATFORM = vexpress-qemu_virt

include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
TF_A_PATH			?= $(ROOT)/trusted-firmware-a
BINARIES_PATH			?= $(ROOT)/out/bin
U-BOOT_PATH			?= $(ROOT)/u-boot
QEMU_PATH			?= $(ROOT)/qemu
QEMU_BUILD			?= $(QEMU_PATH)/build

################################################################################
# Targets
################################################################################
all: arm-tf u-boot buildroot linux optee-os qemu
clean: arm-tf-clean u-boot-clean buildroot-clean linux-clean optee-os-clean \
	qemu-clean check-clean

include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
TF_A_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH32_CROSS_COMPILE)" \
	CC="$(CCACHE)$(AARCH32_CROSS_COMPILE)gcc" \
	LD="$(CCACHE)$(AARCH32_CROSS_COMPILE)ld"

TF_A_DEBUG ?= $(DEBUG)
ifeq ($(TF_A_DEBUG),0)
TF_A_LOGLVL ?= 30
TF_A_OUT = $(TF_A_PATH)/build/qemu/release
else
TF_A_LOGLVL ?= 50
TF_A_OUT = $(TF_A_PATH)/build/qemu/debug
endif

TF_A_FLAGS ?= \
	BL32=$(OPTEE_OS_HEADER_V2_BIN) \
	BL32_EXTRA1=$(OPTEE_OS_PAGER_V2_BIN) \
	BL32_EXTRA2=$(OPTEE_OS_PAGEABLE_V2_BIN) \
	BL33=$(ROOT)/u-boot/u-boot.bin \
	ARM_ARCH_MAJOR=7 \
	ARCH=aarch32 \
	PLAT=qemu \
	ARM_TSP_RAM_LOCATION=tdram \
	BL32_RAM_LOCATION=tdram \
	AARCH32_SP=optee \
	DEBUG=$(TF_A_DEBUG) \
	LOG_LEVEL=$(TF_A_LOGLVL) \

arm-tf: optee-os u-boot
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) all fip
	mkdir -p $(BINARIES_PATH)
	ln -sf $(TF_A_OUT)/bl1.bin $(BINARIES_PATH)
	ln -sf $(TF_A_OUT)/bl2.bin $(BINARIES_PATH)
	ln -sf $(OPTEE_OS_HEADER_V2_BIN) $(BINARIES_PATH)/bl32.bin
	ln -sf $(OPTEE_OS_PAGER_V2_BIN) $(BINARIES_PATH)/bl32_extra1.bin
	ln -sf $(OPTEE_OS_PAGEABLE_V2_BIN) $(BINARIES_PATH)/bl32_extra2.bin
	ln -sf $(ROOT)/u-boot/u-boot.bin $(BINARIES_PATH)/bl33.bin

arm-tf-clean:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) clean

################################################################################
# QEMU
################################################################################
$(QEMU_BUILD)/config-host.mak:
	cd $(QEMU_PATH); ./configure --target-list=arm-softmmu\
			$(QEMU_CONFIGURE_PARAMS_COMMON)

qemu: $(QEMU_BUILD)/config-host.mak
	$(MAKE) -C $(QEMU_PATH)

qemu-clean:
	$(MAKE) -C $(QEMU_PATH) distclean

################################################################################
# U-boot
################################################################################
U-BOOT_EXPORTS ?= CROSS_COMPILE="$(CCACHE)$(AARCH32_CROSS_COMPILE)"

U-BOOT_DEFCONFIG_FILES := \
	$(U-BOOT_PATH)/configs/qemu_arm_defconfig \
	$(ROOT)/build/kconfigs/u-boot_qemu_virt_v7.conf

.PHONY: u-boot
u-boot:
	cd $(U-BOOT_PATH) && \
		scripts/kconfig/merge_config.sh $(U-BOOT_DEFCONFIG_FILES)
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) all

.PHONY: u-boot-clean
u-boot-clean:
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean

.PHONY: u-boot-cscope
u-boot-cscope:
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) cscope

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := arm
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm/configs/vexpress_defconfig \
		$(CURDIR)/kconfigs/qemu.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm
LINUX_COMMON_TARGETS += zImage

linux: linux-common
	mkdir -p $(BINARIES_PATH)
	ln -sf $(LINUX_PATH)/arch/arm/boot/zImage $(BINARIES_PATH)

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm

linux-cleaner: linux-cleaner-common

################################################################################
# OP-TEE
################################################################################
optee-os: optee-os-common
optee-os-clean: optee-os-clean-common

################################################################################
# Run targets
################################################################################
.PHONY: run
# This target enforces updating root fs etc
run: all
	$(MAKE) run-only

QEMU_SMP ?= 2
QEMU_MEM ?= 1057

QEMU_BASE_ARGS = -nographic
QEMU_BASE_ARGS += -smp $(QEMU_SMP)
QEMU_BASE_ARGS += -d unimp -semihosting-config enable=on,target=native
QEMU_BASE_ARGS += -m $(QEMU_MEM)
QEMU_BASE_ARGS += -bios bl1.bin
QEMU_BASE_ARGS += -machine virt,secure=on -cpu cortex-a15
QEMU_BASE_ARGS += $(QEMU_EXTRA_ARGS)

QEMU_RUN_ARGS = $(QEMU_BASE_ARGS)
QEMU_RUN_ARGS += $(QEMU_RUN_ARGS_COMMON)
QEMU_RUN_ARGS += -s -S -serial tcp:127.0.0.1:$(QEMU_NW_PORT) -serial tcp:127.0.0.1:$(QEMU_SW_PORT)

# The arm-softmmu part of the path to qemu-system-arm was removed
# somewhere between 8.1.2 and 9.1.2
QEMU_BIN = $(or $(wildcard $(QEMU_BUILD)/qemu-system-arm),$(wildcard $(QEMU_BUILD)/arm-softmmu/qemu-system-arm),qemu-system-arm-not-found)

.PHONY: run-only
run-only:
	ln -sf $(ROOT)/out-br/images/rootfs.cpio.gz $(BINARIES_PATH)/
	$(call check-terminal)
	$(call run-help)
	$(call launch-terminal,$(QEMU_NW_PORT),"Normal World")
	$(call launch-terminal,$(QEMU_SW_PORT),"Secure World")
	$(call wait-for-ports,$(QEMU_NW_PORT),$(QEMU_SW_PORT))
	cd $(BINARIES_PATH) && $(QEMU_BIN) $(QEMU_RUN_ARGS)

ifneq ($(filter check,$(MAKECMDGOALS)),)
CHECK_DEPS := all
endif

check-args := --bios $(BINARIES_PATH)/bl1.bin
ifneq ($(TIMEOUT),)
check-args += --timeout $(TIMEOUT)
endif
ifneq ($(CHECK_TESTS),)
check-args += --tests $(CHECK_TESTS)
endif
ifneq ($(XTEST_ARGS),)
check-args += --xtest-args "$(XTEST_ARGS)"
endif

QEMU_CHECK_ARGS = $(QEMU_BASE_ARGS)
QEMU_CHECK_ARGS += -monitor none
QEMU_CHECK_ARGS += -serial stdio -serial file:serial1.log

check: $(CHECK_DEPS)
	ln -sf $(ROOT)/out-br/images/rootfs.cpio.gz $(BINARIES_PATH)/
	cd $(BINARIES_PATH) && \
		export QEMU=$(QEMU_BIN) && \
		export QEMU_CHECK_ARGS="$(QEMU_CHECK_ARGS)" && \
		export XEN_BOOT=n && \
		expect $(ROOT)/build/qemu-check.exp -- $(check-args) || \
		(if [ "$(DUMP_LOGS_ON_ERROR)" ]; then \
			echo "== $$PWD/serial0.log:"; \
			cat serial0.log; \
			echo "== end of $$PWD/serial0.log:"; \
			echo "== $$PWD/serial1.log:"; \
			cat serial1.log; \
			echo "== end of $$PWD/serial1.log:"; \
		fi; false)

check-only: check

check-clean:
	rm -f serial0.log serial1.log
