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

########################################################################################
# If you change this, you MUST run `make arm-tf-clean optee-os-clean` before rebuilding
########################################################################################
XEN_BOOT ?= n
ifeq ($(XEN_BOOT),y)
GICV3 = y
UBOOT = y
# For DomU, guest.cfg and other images can be picked up from mounted folder
QEMU_VIRTFS_AUTOMOUNT = y
endif

include common.mk

DEBUG ?= 1

# Option to use U-Boot in the boot flow instead of EDK2
UBOOT ?= n

# Option to build with GICV3 enabled
GICV3 ?= y

# Option to configure FF-A and SPM:
# n:	disabled
# 3:	SPMC and SPMD at EL3 (in TF-A)
# 2:	not supported, SPMC at S-EL2 (in Hafnium), SPMD at EL3 (in TF-A)
# 1:	SPMC at S-EL1 (in OP-TEE), SPMD at EL3 (in TF-A)
SPMC_AT_EL ?= n
ifneq ($(filter-out n 1 3,$(SPMC_AT_EL)),)
$(error Unsupported SPMC_AT_EL value $(SPMC_AT_EL))
endif

# Option to configure Pointer Authentication for TA's
PAUTH ?= n

# Option to configure Memory Tagging Extension
MEMTAG ?= n

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
MODULE_OUTPUT		?= $(ROOT)/out/kernel_modules
UBOOT_PATH		?= $(ROOT)/u-boot
UBOOT_BIN		?= $(UBOOT_PATH)/u-boot.bin
MKIMAGE_PATH		?= $(UBOOT_PATH)/tools

ROOTFS_GZ		?= $(BINARIES_PATH)/rootfs.cpio.gz
ROOTFS_UGZ		?= $(BINARIES_PATH)/rootfs.cpio.uboot

KERNEL_IMAGE		?= $(LINUX_PATH)/arch/arm64/boot/Image
KERNEL_IMAGEGZ		?= $(LINUX_PATH)/arch/arm64/boot/Image.gz
KERNEL_UIMAGE		?= $(BINARIES_PATH)/uImage

# Load and entry addresses
KERNEL_ENTRY		?= 0x40400000
KERNEL_LOADADDR		?= 0x40400000
ROOTFS_ENTRY		?= 0x44000000
ROOTFS_LOADADDR		?= 0x44000000

ifeq ($(UBOOT),y)
BL33_BIN		?= $(UBOOT_BIN)
BL33_DEPS		?= u-boot
else
BL33_BIN		?= $(EDK2_BIN)
BL33_DEPS		?= edk2
endif

XEN_PATH		?= $(ROOT)/xen
XEN_IMAGE		?= $(ROOT)/out-br/build/xen-4.14.5/xen/xen.efi
XEN_EXT4		?= $(BINARIES_PATH)/xen.ext4
XEN_CFG			?= $(ROOT)/build/qemu_v8/xen/xen.cfg

ifeq ($(GICV3),y)
	TFA_GIC_DRIVER	?= QEMU_GICV3
	QEMU_GIC_VERSION = 3
else
	TFA_GIC_DRIVER	?= QEMU_GICV2
	QEMU_GIC_VERSION = 2
endif

################################################################################
# Targets
################################################################################
TARGET_DEPS := arm-tf buildroot linux optee-os qemu
TARGET_CLEAN := arm-tf-clean buildroot-clean linux-clean optee-os-clean \
	qemu-clean check-clean

TARGET_DEPS 		+= $(BL33_DEPS)

ifeq ($(UBOOT),y)
TARGET_DEPS		+= $(KERNEL_UIMAGE) $(ROOTFS_UGZ)
TARGET_CLEAN		+= u-boot-clean
else
TARGET_CLEAN		+= edk2-clean
endif

ifeq ($(XEN_BOOT),y)
TARGET_DEPS		+= xen-create-image buildroot-domu
TARGET_CLEAN		+= buildroot-domu-clean
endif

all: $(TARGET_DEPS)

clean: $(TARGET_CLEAN)

$(BINARIES_PATH):
	mkdir -p $@

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
TF_A_LOGLVL ?= 40
TF_A_OUT = $(TF_A_PATH)/build/qemu/debug
endif

TF_A_FLAGS ?= \
	BL33=$(BL33_BIN) \
	PLAT=qemu \
	QEMU_USE_GIC_DRIVER=$(TFA_GIC_DRIVER) \
	ENABLE_SVE_FOR_NS=1 \
	ENABLE_SVE_FOR_SWD=1 \
	ENABLE_SME_FOR_NS=1 \
	ENABLE_SME_FOR_SWD=1 \
	BL32_RAM_LOCATION=tdram \
	DEBUG=$(TF_A_DEBUG) \
	LOG_LEVEL=$(TF_A_LOGLVL)

TF_A_FLAGS_BL32_OPTEE  = BL32=$(OPTEE_OS_HEADER_V2_BIN)
TF_A_FLAGS_BL32_OPTEE += BL32_EXTRA1=$(OPTEE_OS_PAGER_V2_BIN)
TF_A_FLAGS_BL32_OPTEE += BL32_EXTRA2=$(OPTEE_OS_PAGEABLE_V2_BIN)

TF_A_FLAGS_SPMC_AT_EL_n  = $(TF_A_FLAGS_BL32_OPTEE) SPD=opteed
TF_A_FLAGS_SPMC_AT_EL_1  = $(TF_A_FLAGS_BL32_OPTEE) SPD=spmd
TF_A_FLAGS_SPMC_AT_EL_1 += CTX_INCLUDE_EL2_REGS=0 SPMD_SPM_AT_SEL2=0
TF_A_FLAGS_SPMC_AT_EL_1 += SPMC_OPTEE=1
TF_A_FLAGS_SPMC_AT_EL_3  = SPD=spmd SPMC_AT_EL3=1
TF_A_FLAGS_SPMC_AT_EL_3 += CTX_INCLUDE_EL2_REGS=0 SPMD_SPM_AT_SEL2=0
TF_A_FLAGS_SPMC_AT_EL_3 += BL32=$(OPTEE_OS_PAGER_V2_BIN)
TF_A_FLAGS_SPMC_AT_EL_3 += QEMU_SPMC_MANIFEST_DTS=../build/qemu_v8/spmc_el3_manifest.dts

TF_A_FLAGS += $(TF_A_FLAGS_SPMC_AT_EL_$(SPMC_AT_EL))

ifeq ($(TF_A_TRUSTED_BOARD_BOOT),y)
TF_A_FLAGS += \
	MBEDTLS_DIR=$(ROOT)/mbedtls \
	TRUSTED_BOARD_BOOT=1 \
	GENERATE_COT=1
endif

ifeq ($(PAUTH),y)
TF_A_FLAGS += CTX_INCLUDE_PAUTH_REGS=1
endif
ifeq ($(MEMTAG),y)
TF_A_FLAGS += CTX_INCLUDE_MTE_REGS=1
endif

arm-tf: optee-os $(BL33_DEPS)
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
ifeq ($(SPMC_AT_EL),3)
	ln -sf $(TF_A_OUT)/fdts/spmc_el3_manifest.dtb \
		$(BINARIES_PATH)/tos_fw_config.dtb
	ln -sf $(OPTEE_OS_PAGER_V2_BIN) $(BINARIES_PATH)/bl32.bin
	rm -f $(BINARIES_PATH)/bl32_extra1.bin
	rm -f $(BINARIES_PATH)/bl32_extra2.bin
else
	ln -sf $(OPTEE_OS_HEADER_V2_BIN) $(BINARIES_PATH)/bl32.bin
	ln -sf $(OPTEE_OS_PAGER_V2_BIN) $(BINARIES_PATH)/bl32_extra1.bin
	ln -sf $(OPTEE_OS_PAGEABLE_V2_BIN) $(BINARIES_PATH)/bl32_extra2.bin
endif
	ln -sf $(BL33_BIN) $(BINARIES_PATH)/bl33.bin

arm-tf-clean:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) clean

################################################################################
# QEMU
################################################################################
$(QEMU_BUILD)/config-host.mak:
	cd $(QEMU_PATH); ./configure --target-list=aarch64-softmmu --enable-slirp\
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
# U-Boot
################################################################################
ifeq ($(XEN_BOOT),y)
UBOOT_DEFCONFIG_FILES := $(UBOOT_PATH)/configs/qemu_arm64_defconfig		\
			 $(ROOT)/build/kconfigs/u-boot_xen_qemu_v8.conf
else
UBOOT_DEFCONFIG_FILES := $(UBOOT_PATH)/configs/qemu_arm64_defconfig		\
			 $(ROOT)/build/kconfigs/u-boot_qemu_v8.conf
endif

UBOOT_COMMON_FLAGS ?= CROSS_COMPILE=$(CROSS_COMPILE_NS_KERNEL)

$(UBOOT_PATH)/.config: $(UBOOT_DEFCONFIG_FILES)
	cd $(UBOOT_PATH) && \
                scripts/kconfig/merge_config.sh $(UBOOT_DEFCONFIG_FILES)

.PHONY: u-boot-defconfig
u-boot-defconfig: $(UBOOT_PATH)/.config

.PHONY: u-boot
u-boot: u-boot-defconfig
	$(MAKE) -C $(UBOOT_PATH) $(UBOOT_COMMON_FLAGS)

.PHONY: u-boot-clean
u-boot-clean:
	$(MAKE) -C $(UBOOT_PATH) $(UBOOT_COMMON_FLAGS) distclean

################################################################################

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm64/configs/defconfig \
		$(CURDIR)/kconfigs/qemu.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64 Image scripts_gdb

linux: linux-common
	mkdir -p $(BINARIES_PATH)
	ln -sf $(LINUX_PATH)/arch/arm64/boot/Image $(BINARIES_PATH)

linux-modules: linux
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS) modules
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS) INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$(MODULE_OUTPUT) modules_install

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

linux-cleaner: linux-cleaner-common

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += DEBUG=$(DEBUG) CFG_ARM_GICV3=$(GICV3)
OPTEE_OS_COMMON_FLAGS_SPMC_AT_EL_1 = CFG_CORE_SEL1_SPMC=y
OPTEE_OS_COMMON_FLAGS_SPMC_AT_EL_3 = CFG_CORE_EL3_SPMC=y
OPTEE_OS_COMMON_FLAGS_SPMC_AT_EL_3 += CFG_DT_ADDR=0x40000000
OPTEE_OS_COMMON_FLAGS_SPMC_AT_EL_3 += CFG_CORE_RESERVED_SHM=n

ifeq ($(XEN_BOOT),y)
OPTEE_OS_COMMON_FLAGS += CFG_VIRTUALIZATION=y
endif

ifeq ($(PAUTH),y)
OPTEE_OS_COMMON_FLAGS += CFG_TA_PAUTH=y
OPTEE_OS_COMMON_FLAGS += CFG_CORE_PAUTH=y
endif
ifeq ($(MEMTAG),y)
OPTEE_OS_COMMON_FLAGS += CFG_MEMTAG=y
endif

OPTEE_OS_COMMON_FLAGS += $(OPTEE_OS_COMMON_FLAGS_SPMC_AT_EL_$(SPMC_AT_EL))

optee-os: optee-os-common

optee-os-clean: optee-os-clean-common

################################################################################
# mkimage - create images to be loaded by U-Boot
################################################################################
# Without the objcopy, the uImage will be 10x bigger.
$(KERNEL_UIMAGE): u-boot linux | $(BINARIES_PATH)
	${AARCH64_CROSS_COMPILE}objcopy -O binary \
					-R .note \
					-R .comment \
					-S $(LINUX_PATH)/vmlinux \
					$(BINARIES_PATH)/linux.bin
	$(MKIMAGE_PATH)/mkimage -A arm64 \
				-O linux \
				-T kernel \
				-C none \
				-a $(KERNEL_LOADADDR) \
				-e $(KERNEL_ENTRY) \
				-n "Linux kernel" \
				-d $(BINARIES_PATH)/linux.bin $(KERNEL_UIMAGE)

$(ROOTFS_UGZ): u-boot buildroot | $(BINARIES_PATH)
	ln -sf $(ROOT)/out-br/images/rootfs.cpio.gz $(BINARIES_PATH)
	$(MKIMAGE_PATH)/mkimage -A arm64 \
				-T ramdisk \
				-C gzip \
				-a $(ROOTFS_LOADADDR) \
				-e $(ROOTFS_ENTRY) \
				-n "Root file system" \
				-d $(ROOTFS_GZ) $(ROOTFS_UGZ)

################################################################################
# XEN
################################################################################

XEN_TMP ?= $(BINARIES_PATH)/xen_files

$(XEN_TMP):
	mkdir -p $@

xen-create-image: linux buildroot | $(XEN_TMP)
	cp $(KERNEL_IMAGE) $(XEN_TMP)
	cp $(XEN_IMAGE) $(XEN_TMP)
	cp $(XEN_CFG) $(XEN_TMP)
	cp $(ROOT)/out-br/images/rootfs.cpio.gz $(XEN_TMP)
	rm -f $(XEN_EXT4)
	mke2fs -t ext4 -d $(XEN_TMP) $(XEN_EXT4) 100M


################################################################################
# Run targets
################################################################################
.PHONY: run
# This target enforces updating root fs etc
run: all
	$(MAKE) run-only


ifeq ($(XEN_BOOT),y)
QEMU_CPU	?= cortex-a57
QEMU_MEM 	?= 2048
QEMU_SMP	?= 4
QEMU_VIRT	= true
QEMU_XEN	?= -drive if=none,file=$(XEN_EXT4),format=raw,id=hd1 \
		   -device virtio-blk-device,drive=hd1
else
QEMU_CPU	?= max,pauth-impdef=on
QEMU_SMP 	?= 2
QEMU_MEM 	?= 1057
QEMU_VIRT	= false
endif

ifeq ($(MEMTAG),y)
QEMU_MTE	= on
else
QEMU_MTE	= off
endif

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
		-s -S -machine virt,secure=on,mte=$(QEMU_MTE),gic-version=$(QEMU_GIC_VERSION),virtualization=$(QEMU_VIRT) \
		-cpu $(QEMU_CPU) \
		-d unimp -semihosting-config enable=on,target=native \
		-m $(QEMU_MEM) \
		-bios bl1.bin		\
		-initrd rootfs.cpio.gz \
		-kernel Image -no-acpi \
		-append 'console=ttyAMA0,38400 keep_bootcon root=/dev/vda2 $(QEMU_KERNEL_BOOTARGS)' \
		$(QEMU_XEN) \
		$(QEMU_EXTRA_ARGS)

ifneq ($(filter check check-rust,$(MAKECMDGOALS)),)
CHECK_DEPS := all
endif

ifneq ($(TIMEOUT),)
check-args := --timeout $(TIMEOUT)
endif
ifneq ($(CHECK_TESTS),)
check-args += --tests $(CHECK_TESTS)
endif
ifneq ($(XTEST_ARGS),)
check-args += --xtest-args "$(XTEST_ARGS)"
endif

check: $(CHECK_DEPS)
	ln -sf $(ROOT)/out-br/images/rootfs.cpio.gz $(BINARIES_PATH)/
	cd $(BINARIES_PATH) && \
		export QEMU=$(QEMU_BUILD)/aarch64-softmmu/qemu-system-aarch64 && \
		export QEMU_SMP=$(QEMU_SMP) && \
		export QEMU_MTE=$(QEMU_MTE) && \
		export QEMU_GIC=$(QEMU_GIC_VERSION) && \
		export QEMU_MEM=$(QEMU_MEM) && \
		export QEMU_CPU=$(QEMU_CPU) && \
		export XEN_BOOT=$(XEN_BOOT) && \
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

check-rust: $(CHECK_DEPS)
	ln -sf $(ROOT)/out-br/images/rootfs.cpio.gz $(BINARIES_PATH)/
	cd $(BINARIES_PATH) && \
		export QEMU=$(QEMU_BUILD)/aarch64-softmmu/qemu-system-aarch64 && \
		export QEMU_SMP=$(QEMU_SMP) && \
		export QEMU_MTE=$(QEMU_MTE) && \
		export QEMU_GIC=$(QEMU_GIC_VERSION) && \
		export QEMU_MEM=$(QEMU_MEM) && \
		expect $(ROOT)/optee_rust/ci/qemu-check.exp -- $(check-args) || \
		(if [ "$(DUMP_LOGS_ON_ERROR)" ]; then \
			echo "== $$PWD/serial0.log:"; \
			cat serial0.log; \
			echo "== end of $$PWD/serial0.log:"; \
			echo "== $$PWD/serial1.log:"; \
			cat serial1.log; \
			echo "== end of $$PWD/serial1.log:"; \
		fi; false)

check-only-rust: check-rust

check-clean:
	rm -f serial0.log serial1.log
