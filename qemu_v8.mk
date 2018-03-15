################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER    := 64
override COMPILE_S_KERNEL  := 64

include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
ARM_TF_PATH		?= $(ROOT)/arm-trusted-firmware

EDK2_PATH		?= $(ROOT)/edk2
EDK2_BIN		?= $(EDK2_PATH)/Build/ArmVirtQemuKernel-AARCH64/DEBUG_GCC49/FV/QEMU_EFI.fd

QEMU_PATH		?= $(ROOT)/qemu

SOC_TERM_PATH		?= $(ROOT)/soc_term
STRACE_PATH		?= $(ROOT)/strace

DEBUG = 1

################################################################################
# Targets
################################################################################
all: arm-tf qemu soc-term linux buildroot
clean: arm-tf-clean edk2-clean linux-clean optee-os-clean qemu-clean \
	soc-term-clean check-clean buildroot-clean

include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
ARM_TF_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

ARM_TF_FLAGS ?= \
	BL32=$(OPTEE_OS_HEADER_V2_BIN) \
	BL32_EXTRA1=$(OPTEE_OS_PAGER_V2_BIN) \
	BL32_EXTRA2=$(OPTEE_OS_PAGEABLE_V2_BIN) \
	BL33=$(EDK2_BIN) \
	ARM_TSP_RAM_LOCATION=tdram \
	PLAT=qemu \
	DEBUG=0 \
	LOG_LEVEL=50 \
	BL32_RAM_LOCATION=tdram \
	SPD=opteed

arm-tf: optee-os edk2
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) all fip
	ln -sf $(OPTEE_OS_HEADER_V2_BIN) \
		$(ARM_TF_PATH)/build/qemu/release/bl32.bin
	ln -sf $(OPTEE_OS_PAGER_V2_BIN) \
		$(ARM_TF_PATH)/build/qemu/release/bl32_extra1.bin
	ln -sf $(OPTEE_OS_PAGEABLE_V2_BIN) \
		$(ARM_TF_PATH)/build/qemu/release/bl32_extra2.bin
	ln -sf $(EDK2_BIN) $(ARM_TF_PATH)/build/qemu/release/bl33.bin

arm-tf-clean:
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) clean

################################################################################
# QEMU
################################################################################
qemu:
	cd $(QEMU_PATH); ./configure --target-list=aarch64-softmmu\
			$(QEMU_CONFIGURE_PARAMS_COMMON)
	$(MAKE) -C $(QEMU_PATH)

qemu-clean:
	$(MAKE) -C $(QEMU_PATH) distclean

################################################################################
# EDK2 / Tianocore
################################################################################
define edk2-env
	export WORKSPACE=$(EDK2_PATH)
endef

define edk2-call
        GCC49_AARCH64_PREFIX=$(LEGACY_AARCH64_CROSS_COMPILE) \
        build -n `getconf _NPROCESSORS_ONLN` -a AARCH64 \
                -t GCC49 -p ArmVirtPkg/ArmVirtQemuKernel.dsc \
		-b DEBUG
endef

edk2: edk2-common

edk2-clean: edk2-clean-common



################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm64/configs/defconfig \
		$(CURDIR)/kconfigs/qemu.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64

linux: linux-common

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

linux-cleaner: linux-cleaner-common

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += PLATFORM=vexpress-qemu_armv8a CFG_ARM64_core=y \
			 DEBUG=0 CFG_PM_DEBUG=0
optee-os: optee-os-common

OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=vexpress-qemu_armv8a
optee-os-clean: optee-os-clean-common

optee-client: optee-client-common

optee-client-clean: optee-client-clean-common

################################################################################
# Soc-term
################################################################################
soc-term:
	$(MAKE) -C $(SOC_TERM_PATH)

soc-term-clean:
	$(MAKE) -C $(SOC_TERM_PATH) clean


################################################################################
# Run targets
################################################################################
.PHONY: run
# This target enforces updating root fs etc
run: all
	$(MAKE) run-only

.PHONY: run-only
run-only:
	$(call check-terminal)
	$(call run-help)
	$(call launch-terminal,54320,"Normal World")
	$(call launch-terminal,54321,"Secure World")
	$(call wait-for-ports,54320,54321)
	cd $(ARM_TF_PATH)/build/qemu/release && \
	$(QEMU_PATH)/aarch64-softmmu/qemu-system-aarch64 \
		-nographic \
		-serial tcp:localhost:54320 -serial tcp:localhost:54321 \
		-machine virt,secure=on -cpu cortex-a57 -m 1057 -bios $(ARM_TF_PATH)/build/qemu/release/bl1.bin \
		-s -S -semihosting-config enable,target=native -d unimp \
		-initrd $(ROOT)/out-br/images/rootfs.cpio.gz \
		-kernel $(LINUX_PATH)/arch/arm64/boot/Image -no-acpi \
		-append 'console=ttyAMA0,38400 keep_bootcon root=/dev/vda2' \
		$(QEMU_EXTRA_ARGS)

ifneq ($(filter check,$(MAKECMDGOALS)),)
CHECK_DEPS := all
endif

ifneq ($(TIMEOUT),)
check-args := --timeout $(TIMEOUT)
endif

check: $(CHECK_DEPS)
	expect qemu-check.exp -- $(check-args) || \
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
