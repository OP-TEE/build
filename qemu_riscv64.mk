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
# Override variables in common.mk
################################################################################
ARCH = riscv

QEMU_VIRTFS_AUTOMOUNT = y

BR2_ROOTFS_OVERLAY = $(ROOT)/build/br-ext/board/qemu/overlay
BR2_ROOTFS_POST_BUILD_SCRIPT = $(ROOT)/build/br-ext/board/qemu/post-build.sh
BR2_ROOTFS_POST_SCRIPT_ARGS = "$(QEMU_VIRTFS_AUTOMOUNT) $(QEMU_VIRTFS_MOUNTPOINT) $(QEMU_PSS_AUTOMOUNT)"
BR2_TARGET_GENERIC_GETTY_PORT = $(if $(CFG_NW_CONSOLE_UART),ttyS$(CFG_NW_CONSOLE_UART),ttyS0)

OPTEE_OS_PLATFORM = virt

# optee_test
WITH_TLS_TESTS			= n
WITH_CXX_TESTS			= n

########################################################################################
# If you change this, you MUST run `optee-os-clean` before rebuilding
########################################################################################
XEN_BOOT ?= n
include common.mk

DEBUG ?= 1

################################################################################
# Paths to git projects and various binaries
################################################################################
OPENSBI_PATH		?= $(ROOT)/opensbi
BINARIES_PATH		?= $(ROOT)/out/bin
QEMU_PATH		?= $(ROOT)/qemu
QEMU_BUILD		?= $(QEMU_PATH)/build
MODULE_OUTPUT		?= $(ROOT)/out/kernel_modules

KERNEL_IMAGE		?= $(LINUX_PATH)/arch/riscv/boot/Image

################################################################################
# Targets
################################################################################
TARGET_DEPS := opensbi linux buildroot optee-os qemu
TARGET_CLEAN := opensbi-clean linux-clean buildroot-clean optee-os-clean \
	qemu-clean

TARGET_DEPS		+= $(KERNEL_IMAGE)

all: $(TARGET_DEPS)

clean: $(TARGET_CLEAN)

$(BINARIES_PATH):
	mkdir -p $@

include toolchain.mk

################################################################################
# openSBI
################################################################################
OPENSBI_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(RISCV64_CROSS_COMPILE)"

OPENSBI_FLAGS ?= PLATFORM=generic

OPENSBI_OUT = $(OPENSBI_PATH)/install/usr/share/opensbi/lp64/generic/firmware/

opensbi:
	$(OPENSBI_EXPORTS) $(MAKE) -C $(OPENSBI_PATH) $(OPENSBI_FLAGS) install
	ln -sf $(OPENSBI_OUT)/fw_jump.bin $(BINARIES_PATH)

opensbi-clean:
	$(OPENSBI_EXPORTS) $(MAKE) -C $(OPENSBI_PATH) $(OPENSBI_FLAGS) clean

################################################################################
# QEMU
################################################################################
$(QEMU_BUILD)/config-host.mak:
	cd $(QEMU_PATH); ./configure --target-list="riscv64-softmmu" --enable-slirp\
			$(QEMU_CONFIGURE_PARAMS_COMMON)

qemu: $(QEMU_BUILD)/config-host.mak
	$(MAKE) -C $(QEMU_PATH)

qemu-clean:
	$(MAKE) -C $(QEMU_PATH) clean

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := riscv
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/riscv/configs/defconfig \
		$(CURDIR)/kconfigs/qemu_riscv.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=riscv

linux: linux-common
	mkdir -p $(BINARIES_PATH)
	ln -sf $(LINUX_PATH)/arch/riscv/boot/Image $(BINARIES_PATH)

linux-modules: linux
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS) modules
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS) INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$(MODULE_OUTPUT) modules_install

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=riscv

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=riscv

linux-cleaner: linux-cleaner-common

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += ARCH=riscv
OPTEE_OS_COMMON_FLAGS += DEBUG=$(DEBUG)
OPTEE_OS_COMMON_FLAGS += CFG_TEE_CORE_NB_CORE=$(QEMU_SMP)
OPTEE_OS_COMMON_FLAGS += CFG_NUM_THREADS=$(QEMU_SMP)
OPTEE_OS_COMMON_FLAGS += CFG_TEE_CORE_LOG_LEVEL=4
OPTEE_OS_COMMON_FLAGS += CFG_TEE_TA_LOG_LEVEL=4
OPTEE_OS_COMMON_FLAGS += CFG_UNWIND=y

OPTEE_OS_LOAD_ADDRESS ?= 0x8e000000

optee-os: optee-os-common
	ln -sf $(OPTEE_OS_BIN) $(BINARIES_PATH)

optee-os-clean: optee-os-clean-common

################################################################################
# Run targets
################################################################################
.PHONY: run
# This target enforces updating root fs etc
run: all
	$(MAKE) run-only

QEMU_SMP 	?= 1
QEMU_MEM 	?= 2048
QEMU_MACHINE	?= virt

.PHONY: run-only
run-only:
	ln -sf $(ROOT)/out-br/images/rootfs.ext2 $(BINARIES_PATH)/
	$(call check-terminal)
	$(call run-help)
	$(call launch-terminal,54320,"Normal World")
	$(call launch-terminal,54321,"Secure World")
	$(call wait-for-ports,54320,54321)
	cd $(BINARIES_PATH) && $(QEMU_BUILD)/qemu-system-riscv64 \
		-nographic \
		-serial tcp:127.0.0.1:54320 -serial tcp:127.0.0.1:54321 \
		-machine $(QEMU_MACHINE) \
		-smp $(QEMU_SMP) \
		-d unimp -semihosting-config enable=on,target=native \
		-m $(QEMU_MEM) \
		-bios fw_jump.bin \
		-kernel Image \
		-append "rootwait root=/dev/vda ro" \
		-drive file=rootfs.ext2,format=raw,id=hd0 \
		-device virtio-blk-device,drive=hd0 \
		-device loader,file=tee.bin,addr=$(OPTEE_OS_LOAD_ADDRESS)
