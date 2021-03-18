################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
COMPILE_NS_USER ?= 64
override COMPILE_NS_KERNEL := 64
COMPILE_S_USER ?= 64
COMPILE_S_KERNEL ?= 64

################################################################################
# If you change this, you MUST run `make arm-tf-clean` first before rebuilding
################################################################################
TF_A_TRUSTED_BOARD_BOOT ?= n

BR2_ROOTFS_OVERLAY = $(ROOT)/build/br-ext/board/qemu/overlay
BR2_ROOTFS_POST_BUILD_SCRIPT = $(ROOT)/build/br-ext/board/qemu/post-build.sh
BR2_ROOTFS_POST_SCRIPT_ARGS = "$(QEMU_VIRTFS_AUTOMOUNT) $(QEMU_VIRTFS_MOUNTPOINT) $(QEMU_PSS_AUTOMOUNT)"

OPTEE_OS_PLATFORM = vexpress-qemu_armv8a

include common.mk

DEBUG ?= 1

################################################################################
# Paths to git projects and various binaries
################################################################################
TF_A_PATH		?= $(ROOT)/trusted-firmware-a
BINARIES_PATH		?= $(ROOT)/out/bin
EDK2_PATH		?= $(ROOT)/edk2
EDK2_TOOLCHAIN		?= GCC5
EDK2_ARCH		?= AARCH64
ifeq ($(DEBUG),1)
EDK2_BUILD		?= DEBUG
else
EDK2_BUILD		?= RELEASE
endif
EDK2_BIN		?= $(EDK2_PATH)/Build/ArmVirtQemuKernel-$(EDK2_ARCH)/$(EDK2_BUILD)_$(EDK2_TOOLCHAIN)/FV/QEMU_EFI.fd
QEMU_PATH		?= $(ROOT)/qemu
QEMU_BUILD		?= $(QEMU_PATH)/build
SOC_TERM_PATH		?= $(ROOT)/soc_term

################################################################################
# Targets
################################################################################
all: arm-tf buildroot edk2 linux optee-os qemu soc-term
clean: arm-tf-clean buildroot-clean edk2-clean linux-clean optee-os-clean \
	qemu-clean soc-term-clean check-clean

include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
TF_A_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

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
	BL33=$(EDK2_BIN) \
	PLAT=qemu \
	ARM_TSP_RAM_LOCATION=tdram \
	BL32_RAM_LOCATION=tdram \
	SPD=opteed \
	DEBUG=$(TF_A_DEBUG) \
	LOG_LEVEL=$(TF_A_LOGLVL)

ifeq ($(TF_A_TRUSTED_BOARD_BOOT),y)
TF_A_FLAGS += \
	MBEDTLS_DIR=$(ROOT)/mbedtls \
	TRUSTED_BOARD_BOOT=1 \
	GENERATE_COT=1
endif

arm-tf: optee-os edk2
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) all fip
	mkdir -p $(BINARIES_PATH)
	ln -sf $(TF_A_OUT)/bl1.bin $(BINARIES_PATH)
	ln -sf $(TF_A_OUT)/bl2.bin $(BINARIES_PATH)
	ln -sf $(TF_A_OUT)/bl31.bin $(BINARIES_PATH)
ifeq ($(TF_A_TRUSTED_BOARD_BOOT),y)
	ln -sf $(TF_A_OUT)/trusted_key.crt $(BINARIES_PATH)
	ln -sf $(TF_A_OUT)/tos_fw_key.crt $(BINARIES_PATH)
	ln -sf $(TF_A_OUT)/tos_fw_content.crt $(BINARIES_PATH)
	ln -sf $(TF_A_OUT)/tb_fw.crt $(BINARIES_PATH)
	ln -sf $(TF_A_OUT)/soc_fw_key.crt $(BINARIES_PATH)
	ln -sf $(TF_A_OUT)/soc_fw_content.crt $(BINARIES_PATH)
	ln -sf $(TF_A_OUT)/nt_fw_key.crt $(BINARIES_PATH)
	ln -sf $(TF_A_OUT)/nt_fw_content.crt $(BINARIES_PATH)
endif
	ln -sf $(OPTEE_OS_HEADER_V2_BIN) $(BINARIES_PATH)/bl32.bin
	ln -sf $(OPTEE_OS_PAGER_V2_BIN) $(BINARIES_PATH)/bl32_extra1.bin
	ln -sf $(OPTEE_OS_PAGEABLE_V2_BIN) $(BINARIES_PATH)/bl32_extra2.bin
	ln -sf $(EDK2_BIN) $(BINARIES_PATH)/bl33.bin

arm-tf-clean:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) clean

################################################################################
# QEMU
################################################################################
$(QEMU_BUILD)/config-host.mak:
	cd $(QEMU_PATH); ./configure --target-list=aarch64-softmmu\
			$(QEMU_CONFIGURE_PARAMS_COMMON)

qemu: $(QEMU_BUILD)/config-host.mak
	$(MAKE) -C $(QEMU_PATH)

qemu-clean:
	$(MAKE) -C $(QEMU_PATH) distclean

################################################################################
# EDK2 / Tianocore
################################################################################
define edk2-env
	export WORKSPACE=$(EDK2_PATH) PYTHON3_ENABLE=TRUE
endef

define edk2-call
        $(EDK2_TOOLCHAIN)_$(EDK2_ARCH)_PREFIX=$(AARCH64_CROSS_COMPILE) \
        build -n `getconf _NPROCESSORS_ONLN` -a $(EDK2_ARCH) \
                -t $(EDK2_TOOLCHAIN) -p ArmVirtPkg/ArmVirtQemuKernel.dsc \
		-b $(EDK2_BUILD)
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

LINUX_COMMON_FLAGS += ARCH=arm64 Image

linux: linux-common
	mkdir -p $(BINARIES_PATH)
	ln -sf $(LINUX_PATH)/arch/arm64/boot/Image $(BINARIES_PATH)

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

linux-cleaner: linux-cleaner-common

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += DEBUG=$(DEBUG)
optee-os: optee-os-common

optee-os-clean: optee-os-clean-common

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

QEMU_SMP ?= 2

.PHONY: run-only
run-only:
	ln -sf $(ROOT)/out-br/images/rootfs.cpio.gz $(BINARIES_PATH)/
	$(call check-terminal)
	$(call run-help)
	$(call launch-terminal,54320,"Normal World")
	$(call launch-terminal,54321,"Secure World")
	$(call wait-for-ports,54320,54321)
	cd $(BINARIES_PATH) && $(QEMU_BUILD)/aarch64-softmmu/qemu-system-aarch64 \
		-nographic \
		-serial tcp:localhost:54320 -serial tcp:localhost:54321 \
		-smp $(QEMU_SMP) \
		-s -S -machine virt,secure=on -cpu cortex-a57 \
		-d unimp -semihosting-config enable,target=native \
		-m 1057 \
		-bios bl1.bin \
		-initrd rootfs.cpio.gz \
		-kernel Image -no-acpi \
		-append 'console=ttyAMA0,38400 keep_bootcon root=/dev/vda2' \
		$(QEMU_EXTRA_ARGS)

ifneq ($(filter check,$(MAKECMDGOALS)),)
CHECK_DEPS := all
endif

ifneq ($(TIMEOUT),)
check-args := --timeout $(TIMEOUT)
endif

check: $(CHECK_DEPS)
	ln -sf $(ROOT)/out-br/images/rootfs.cpio.gz $(BINARIES_PATH)/
	cd $(BINARIES_PATH) && \
		export QEMU=$(QEMU_BUILD)/aarch64-softmmu/qemu-system-aarch64 && \
		export QEMU_SMP=$(QEMU_SMP) && \
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
