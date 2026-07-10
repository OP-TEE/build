################################################################################
# RISC-V QEMU64 platform
################################################################################
override ARCH := riscv
override COMPILE_NS_USER := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER := 64
override COMPILE_S_KERNEL := 64

DEBUG ?= 1
PLAT_QEMU ?= virt
ifeq ($(PLAT_QEMU),virt)
QEMU_BOARD_FLAVOR := riscv64-virt-optee
QEMU_LINUX_DTB_BASENAME := qemu_rv64_virt_domain.dtb
OPTEE_OS_PLATFORM = virt
else
$(error Unsupported PLAT_QEMU value $(PLAT_QEMU))
endif
# Keep TLS-specific xtest cases disabled on qemu_riscv64 for now.
# Enabling WITH_TLS_TESTS currently makes os_test.ta carry
# R_RISCV_TLS_DTPMOD64 relocations, and ldelf then fails with:
# "e64_relocate:732 Unknown relocation type 7".
WITH_TLS_TESTS := n

# Keep the rootfs/image layout local to this repo, similar to the ARM QEMU
# platforms which define their QEMU run parameters directly in the makefile.
BR2_ROOTFS_OVERLAY = $(ROOT)/build/br-ext/board/qemu/$(QEMU_BOARD_FLAVOR)/rootfs_overlay
BR2_ROOTFS_POST_IMAGE_SCRIPT = $(ROOT)/buildroot/support/scripts/genimage.sh
BR2_ROOTFS_POST_IMAGE_SCRIPT_ARGS = "-c $(ROOT)/build/br-ext/board/qemu/$(QEMU_BOARD_FLAVOR)/genimage_sdcard.cfg"
BR2_PACKAGE_HOST_GENIMAGE ?= y
BR2_PACKAGE_HOST_QEMU ?= y
BR2_PACKAGE_HOST_QEMU_SYSTEM_MODE ?= y
BR2_PACKAGE_OPTEE_EXAMPLES ?= y
BR2_PACKAGE_OPTEE_TEST ?= y
BR2_SYSTEM_DHCP ?= "eth0"
BR2_TARGET_GENERIC_GETTY_PORT ?= "ttyS0"
BR2_TARGET_ROOTFS_EXT2 ?= y
BR2_TARGET_ROOTFS_EXT2_SIZE ?= "260M"

include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
OUT_PATH		?= $(ROOT)/out
BINARIES_PATH		?= $(OUT_PATH)/bin
OPENSBI_PATH		?= $(ROOT)/opensbi
OPENSBI_OUT		?= $(OPENSBI_PATH)/build/platform/generic/firmware
QEMU_PATH		?= $(ROOT)/qemu
QEMU_BUILD		?= $(QEMU_PATH)/build
UBOOT_PATH		?= $(ROOT)/u-boot

LINUX_IMAGE		?= $(LINUX_PATH)/arch/riscv/boot/Image
LINUX_DTB		?= $(LINUX_PATH)/arch/riscv/boot/dts/qemu/$(QEMU_LINUX_DTB_BASENAME)
OPENSBI_FW_DYNAMIC_BIN	?= $(OPENSBI_OUT)/fw_dynamic.bin
OPENSBI_FW_JUMP_BIN	?= $(OPENSBI_OUT)/fw_jump.bin
UBOOT_ITB		?= $(UBOOT_PATH)/u-boot.itb
UBOOT_SPL		?= $(UBOOT_PATH)/spl/u-boot-spl.bin

SDCARD_IMG		?= $(ROOT)/out-br/images/sdcard.img
ROOTFS_EXT2		?= $(ROOT)/out-br/images/rootfs.ext2

################################################################################
# Targets
################################################################################
TARGET_DEPS := opensbi optee-os u-boot linux buildroot qemu
TARGET_CLEAN := opensbi-clean optee-os-clean u-boot-clean linux-clean \
	buildroot-clean qemu-clean check-clean

all: $(TARGET_DEPS)

clean: $(TARGET_CLEAN)

$(BINARIES_PATH):
	mkdir -p $@

$(OUT_PATH):
	mkdir -p $@

include toolchain.mk

################################################################################
# OpenSBI
################################################################################
OPENSBI_PLATFORM ?= generic
OPENSBI_COMMON_FLAGS += PLATFORM=$(OPENSBI_PLATFORM)
OPENSBI_COMMON_FLAGS += CROSS_COMPILE=$(CROSS_COMPILE_NS_KERNEL)
OPENSBI_COMMON_FLAGS += FW_DYNAMIC=y
OPENSBI_COMMON_FLAGS += FW_JUMP=y
OPENSBI_COMMON_FLAGS += APLIC_QEMU_VIRQ_TEST=y

.PHONY: opensbi
opensbi: | $(BINARIES_PATH)
	$(MAKE) -C $(OPENSBI_PATH) $(OPENSBI_COMMON_FLAGS)
	ln -sf $(OPENSBI_FW_DYNAMIC_BIN) $(BINARIES_PATH)/fw_dynamic.bin
	ln -sf $(OPENSBI_FW_JUMP_BIN) $(BINARIES_PATH)/fw_jump.bin

.PHONY: opensbi-clean
opensbi-clean:
	$(MAKE) -C $(OPENSBI_PATH) $(OPENSBI_COMMON_FLAGS) clean

################################################################################
# U-Boot
################################################################################
UBOOT_DEFCONFIG := qemu-riscv64_spl_defconfig
UBOOT_COMMON_FLAGS += CROSS_COMPILE=$(CROSS_COMPILE_NS_KERNEL)
UBOOT_COMMON_FLAGS += OPENSBI=$(OPENSBI_FW_DYNAMIC_BIN)
UBOOT_COMMON_FLAGS += TEE=$(OPTEE_OS_BIN)

$(UBOOT_PATH)/.config:
	$(MAKE) -C $(UBOOT_PATH) $(UBOOT_DEFCONFIG)
	$(MAKE) -C $(UBOOT_PATH) olddefconfig

.PHONY: u-boot-defconfig
u-boot-defconfig: $(UBOOT_PATH)/.config

.PHONY: u-boot
u-boot: optee-os opensbi u-boot-defconfig | $(BINARIES_PATH)
	$(MAKE) -C $(UBOOT_PATH) $(UBOOT_COMMON_FLAGS)
	ln -sf $(UBOOT_ITB) $(BINARIES_PATH)/u-boot.itb
	ln -sf $(UBOOT_SPL) $(BINARIES_PATH)/u-boot-spl.bin

.PHONY: u-boot-clean
u-boot-clean:
	$(MAKE) -C $(UBOOT_PATH) $(UBOOT_COMMON_FLAGS) distclean

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := riscv
LINUX_DEFCONFIG_COMMON_FILES := \
	$(LINUX_PATH)/arch/riscv/configs/defconfig

LINUX_COMMON_FLAGS += ARCH=riscv
LINUX_COMMON_TARGETS += Image dtbs

linux-defconfig: $(LINUX_PATH)/.config

linux: linux-common | $(BINARIES_PATH)
	ln -sf $(LINUX_IMAGE) $(BINARIES_PATH)/Image
	ln -sf $(LINUX_DTB) $(BINARIES_PATH)/$(QEMU_LINUX_DTB_BASENAME)

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=riscv

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=riscv

linux-cleaner: linux-cleaner-common

################################################################################
# Root FS
################################################################################
CFG_TEE_CORE_LOG_LEVEL ?= 4
CFG_TEE_TA_LOG_LEVEL ?= 4
CFG_TEE_CORE_NB_CORE ?= 2
CFG_NUM_THREADS ?= 2

OPTEE_OS_COMMON_FLAGS += CFG_TEE_CORE_NB_CORE=$(CFG_TEE_CORE_NB_CORE)
OPTEE_OS_COMMON_FLAGS += CFG_NUM_THREADS=$(CFG_NUM_THREADS)
OPTEE_OS_COMMON_FLAGS += CFG_TEE_TA_LOG_LEVEL=$(CFG_TEE_TA_LOG_LEVEL)
OPTEE_OS_COMMON_FLAGS += ARCH=riscv
OPTEE_OS_COMMON_FLAGS += CFG_UNWIND=y
OPTEE_OS_COMMON_FLAGS += CFG_SEMIHOSTING_CONSOLE=y
OPTEE_OS_COMMON_FLAGS += CFG_SEMIHOSTING_CONSOLE_FILE=NULL
OPTEE_OS_COMMON_FLAGS += CFG_TEE_CORE_DEBUG=y
OPTEE_OS_COMMON_FLAGS += CFG_16550_UART=n
OPTEE_OS_COMMON_FLAGS += CFG_RISCV_PLIC=n
OPTEE_OS_COMMON_FLAGS += CFG_TDDRAM_START=0xF1000000
OPTEE_OS_COMMON_FLAGS += CFG_TDDRAM_SIZE=0x01000000

optee-os: optee-os-common | $(BINARIES_PATH)
	ln -sf $(OPTEE_OS_BIN) $(BINARIES_PATH)/tee.bin

optee-os-clean: optee-os-clean-common

.PHONY: update_rootfs
buildroot: update_rootfs
update_rootfs: linux
	@mkdir -p --mode=755 $(BUILDROOT_TARGET_ROOT)/boot
	@install -v -p --mode=644 $(LINUX_IMAGE) $(BUILDROOT_TARGET_ROOT)/boot/Image
	@install -v -p --mode=644 $(LINUX_DTB) $(BUILDROOT_TARGET_ROOT)/boot/$(QEMU_LINUX_DTB_BASENAME)

################################################################################
# QEMU
################################################################################
$(QEMU_BUILD)/config-host.mak:
	cd $(QEMU_PATH); ./configure --target-list=riscv64-softmmu \
			$(QEMU_CONFIGURE_PARAMS_COMMON)

qemu: $(QEMU_BUILD)/.stamp_qemu

$(QEMU_BUILD)/.stamp_qemu: $(QEMU_BUILD)/config-host.mak
	$(MAKE) -C $(QEMU_PATH)
	touch $@

qemu-clean:
	rm -f $(QEMU_BUILD)/.stamp_qemu
	$(MAKE) -C $(QEMU_PATH) distclean

################################################################################
# Run targets
################################################################################
.PHONY: run
run: all
	$(MAKE) run-only

QEMU_SMP ?= 2
QEMU_MEM ?= 4096
QEMU_CPU ?= rv64,zkr=on
QEMU_LOADER_ADDR ?= 0x80200000
QEMU_EXTRA_ARGS := -device virtio-net-pci,netdev=net0 \
		   -netdev user,id=net0,hostfwd=tcp::2200-:22

# The riscv64-softmmu part of the path to qemu-system-riscv64 was removed
# somewhere between 8.1.2 and 9.1.2.
QEMU_BIN = $(or $(wildcard $(QEMU_BUILD)/qemu-system-riscv64),$(wildcard $(QEMU_BUILD)/riscv64-softmmu/qemu-system-riscv64),qemu-system-riscv64-not-found)

QEMU_BASE_ARGS = -nographic
QEMU_BASE_ARGS += -machine $(PLAT_QEMU)
QEMU_BASE_ARGS += -cpu $(QEMU_CPU)
QEMU_BASE_ARGS += -m $(QEMU_MEM)
QEMU_BASE_ARGS += -smp $(QEMU_SMP)
QEMU_BASE_ARGS += -dtb $(QEMU_LINUX_DTB_BASENAME)
QEMU_BASE_ARGS += -semihosting-config enable=on,target=native
QEMU_BASE_ARGS += -bios u-boot-spl.bin
QEMU_BASE_ARGS += -device loader,file=u-boot.itb,addr=$(QEMU_LOADER_ADDR)
QEMU_BASE_ARGS += -device virtio-blk-device,drive=hd0
QEMU_BASE_ARGS += -drive format=raw,file=sdcard.img,id=hd0,if=none
QEMU_BASE_ARGS += $(QEMU_EXTRA_ARGS)

QEMU_RUN_ARGS = $(QEMU_BASE_ARGS)

.PHONY: run-only
run-only:
	ln -sf $(SDCARD_IMG) $(BINARIES_PATH)/sdcard.img
	cd $(BINARIES_PATH) && $(QEMU_BIN) $(QEMU_RUN_ARGS)
