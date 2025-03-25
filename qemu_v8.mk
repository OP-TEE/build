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
# For DomU, guest.cfg and other images can be picked up from mounted folder
QEMU_VIRTFS_AUTOMOUNT = y
endif

# Option to enable Rust examples
# Currently supported only on x86_64 hosts
ifeq ($(shell uname -m),x86_64)
RUST_ENABLE ?= y
endif

# Enable fTPM
MEASURED_BOOT_FTPM ?= y

# Enable Arm Firmware Handoff
ARM_FIRMWARE_HANDOFF ?= n

# Option to build with GICV3 enabled
GICV3 ?= y


SEL0_SPS ?= n
ifeq ($(SEL0_SPS),y)
SPMC_AT_EL = 1
ifneq ($(SPMC_AT_EL),1)
$(error Unsupported SPMC_AT_EL value $(SPMC_AT_EL) for SEL0_SPS=y)
endif
# Needed for arm-ffa-user.ko
QEMU_VIRTFS_AUTOMOUNT = y
LINUX_COMMON_TARGETS += modules
endif

# Option to configure FF-A and SPM:
# n:	disabled
# 3:	SPMC and SPMD at EL3 (in TF-A)
# 2:	SPMC at S-EL2 (in Hafnium), SPMD at EL3 (in TF-A)
# 1:	SPMC at S-EL1 (in OP-TEE), SPMD at EL3 (in TF-A)
SPMC_AT_EL ?= n
ifneq ($(filter-out n 1 2 3,$(SPMC_AT_EL)),)
$(error Unsupported SPMC_AT_EL value $(SPMC_AT_EL))
endif

ifeq ($(ARM_FIRMWARE_HANDOFF),y)
ifneq ($(SPMC_AT_EL),n)
$(error ARM_FIRMWARE_HANDOFF not supported with SPMC_AT_EL value $(SPMC_AT_EL))
endif
endif

# Option to configure Pointer Authentication for TA's
PAUTH ?= n

# Option to configure Memory Tagging Extension
MEMTAG ?= n

include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
TF_A_PATH		?= $(ROOT)/trusted-firmware-a
OUT_PATH		?= $(ROOT)/out
BINARIES_PATH		?= $(OUT_PATH)/bin
QEMU_PATH		?= $(ROOT)/qemu
QEMU_BUILD		?= $(QEMU_PATH)/build
MODULE_OUTPUT		?= $(ROOT)/out/kernel_modules
UBOOT_PATH		?= $(ROOT)/u-boot
UBOOT_BIN		?= $(UBOOT_PATH)/u-boot.bin
MKIMAGE_PATH		?= $(UBOOT_PATH)/tools
HAFNIUM_PATH		?= $(ROOT)/hafnium
HAFNIUM_BIN		?= $(HAFNIUM_PATH)/out/reference/secure_qemu_aarch64_clang/hafnium.bin

ROOTFS_GZ		?= $(BINARIES_PATH)/rootfs.cpio.gz
ROOTFS_UGZ		?= $(BINARIES_PATH)/rootfs.cpio.uboot

KERNEL_IMAGE		?= $(LINUX_PATH)/arch/arm64/boot/Image
KERNEL_IMAGEGZ		?= $(LINUX_PATH)/arch/arm64/boot/Image.gz
KERNEL_UIMAGE		?= $(BINARIES_PATH)/uImage

SCMI_DTSO 		?= $(ROOT)/build/qemu_v8/qemu-v8-scmi-overlay.dtso
SCMI_DTBO 		?= $(BINARIES_PATH)/qemu-v8-scmi-overlay.dtbo
SCMI_DTB 		?= $(BINARIES_PATH)/qemu-v8-scmi.dtb

# Load and entry addresses (u-boot only)
# If you change this please also change in kconfigs/u-boot_qemu_v8.conf
KERNEL_ENTRY		?= 0x42200000
KERNEL_LOADADDR		?= 0x42200000
ROOTFS_ENTRY		?= 0x45000000
ROOTFS_LOADADDR		?= 0x45000000

ifeq ($(SPMC_AT_EL),2)
BL32_DEPS		?= hafnium optee-os
else
BL32_DEPS		?= optee-os
endif

BL33_BIN		?= $(UBOOT_BIN)
BL33_DEPS		?= u-boot

XEN_PATH		?= $(ROOT)/xen
XEN_IMAGE		?= $(XEN_PATH)/xen/xen.efi
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
	qemu-clean check-clean hafnium-clean

TARGET_DEPS 		+= $(BL33_DEPS)

TARGET_DEPS		+= $(KERNEL_UIMAGE) $(ROOTFS_UGZ)
TARGET_CLEAN		+= u-boot-clean

ifeq ($(XEN_BOOT),y)
TARGET_DEPS		+= xen-create-image
endif

ifeq ($(WITH_SCMI),y)
TARGET_DEPS		+= $(SCMI_DTB)
endif

all: $(TARGET_DEPS)

clean: $(TARGET_CLEAN)

$(BINARIES_PATH):
	mkdir -p $@

$(OUT_PATH):
	mkdir -p $@

include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
TF_A_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
	CC="$(CCACHE)$(AARCH64_CROSS_COMPILE)gcc" \
	LD="$(CCACHE)$(AARCH64_CROSS_COMPILE)ld"

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
	ENABLE_SVE_FOR_NS=2 \
	ENABLE_SME_FOR_NS=2 \
	ENABLE_SVE_FOR_SWD=1 \
	ENABLE_SME_FOR_SWD=1 \
	ENABLE_FEAT_FGT=2 \
	ENABLE_FEAT_HCX=2 \
	ENABLE_FEAT_ECV=2 \
	BL32_RAM_LOCATION=tdram \
	DEBUG=$(TF_A_DEBUG) \
	LOG_LEVEL=$(TF_A_LOGLVL)

ifeq ($(ARM_FIRMWARE_HANDOFF),y)
TF_A_FLAGS += TRANSFER_LIST=1
endif

TF_A_FLAGS_BL32_OPTEE  = BL32=$(OPTEE_OS_HEADER_V2_BIN)
TF_A_FLAGS_BL32_OPTEE += BL32_EXTRA1=$(OPTEE_OS_PAGER_V2_BIN)
TF_A_FLAGS_BL32_OPTEE += BL32_EXTRA2=$(OPTEE_OS_PAGEABLE_V2_BIN)

TF_A_FLAGS_SPMC_AT_EL_n  = $(TF_A_FLAGS_BL32_OPTEE) SPD=opteed
TF_A_FLAGS_SPMC_AT_EL_1  = $(TF_A_FLAGS_BL32_OPTEE) SPD=spmd
TF_A_FLAGS_SPMC_AT_EL_1 += CTX_INCLUDE_EL2_REGS=0 SPMD_SPM_AT_SEL2=0
TF_A_FLAGS_SPMC_AT_EL_1 += ENABLE_SME_FOR_NS=0 ENABLE_SME_FOR_SWD=0
TF_A_FLAGS_SPMC_AT_EL_1 += QEMU_TOS_FW_CONFIG_DTS=../build/qemu_v8/spmc_el1_manifest.dts
TF_A_FLAGS_SPMC_AT_EL_1 += SPMC_OPTEE=1
TF_A_FLAGS_SPMC_AT_EL_1 += QEMU_TOS_FW_CONFIG_DTS=../build/qemu_v8/spmc_el1_manifest.dts
TF_A_FLAGS_SPMC_AT_EL_2  = SPD=spmd 
TF_A_FLAGS_SPMC_AT_EL_2 += ENABLE_FEAT_SEL2=1
TF_A_FLAGS_SPMC_AT_EL_2 += SP_LAYOUT_FILE=../build/qemu_v8/sp_layout.json
TF_A_FLAGS_SPMC_AT_EL_2 += NEED_FDT=yes
TF_A_FLAGS_SPMC_AT_EL_2 += BL32=$(HAFNIUM_BIN)
TF_A_FLAGS_SPMC_AT_EL_2 += QEMU_TOS_FW_CONFIG_DTS=../build/qemu_v8/spmc_el2_manifest.dts
TF_A_FLAGS_SPMC_AT_EL_2 += QEMU_TB_FW_CONFIG_DTS=../build/qemu_v8/tb_fw_config.dts
ifneq ($(PAUTH),y)
TF_A_FLAGS_SPMC_AT_EL_2 += BRANCH_PROTECTION=1
TF_A_FLAGS_SPMC_AT_EL_2 += ARM_ARCH_MAJOR=8 ARM_ARCH_MINOR=3
endif
ifneq ($(MEMTAG),y)
TF_A_FLAGS_SPMC_AT_EL_2 += ENABLE_FEAT_MTE2=2
endif
TF_A_FLAGS_SPMC_AT_EL_3  = SPD=spmd SPMC_AT_EL3=1
TF_A_FLAGS_SPMC_AT_EL_3 += CTX_INCLUDE_EL2_REGS=0 SPMD_SPM_AT_SEL2=0
TF_A_FLAGS_SPMC_AT_EL_3 += ENABLE_SME_FOR_NS=0 ENABLE_SME_FOR_SWD=0
TF_A_FLAGS_SPMC_AT_EL_3 += BL32=$(OPTEE_OS_PAGER_V2_BIN)
TF_A_FLAGS_SPMC_AT_EL_3 += QEMU_TOS_FW_CONFIG_DTS=../build/qemu_v8/spmc_el3_manifest.dts

TF_A_FLAGS += $(TF_A_FLAGS_SPMC_AT_EL_$(SPMC_AT_EL))

ifeq ($(TF_A_TRUSTED_BOARD_BOOT),y)
TF_A_FLAGS += \
	MBEDTLS_DIR=$(ROOT)/mbedtls \
	TRUSTED_BOARD_BOOT=1 \
	GENERATE_COT=1
endif

ifeq ($(PAUTH),y)
TF_A_FLAGS += BRANCH_PROTECTION=1
TF_A_FLAGS += ARM_ARCH_MAJOR=8 ARM_ARCH_MINOR=3
endif
ifeq ($(MEMTAG),y)
TF_A_FLAGS += ENABLE_FEAT_MTE2=2
endif

arm-tf: $(BL32_DEPS) $(BL33_DEPS)
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
	rm -f $(BINARIES_PATH)/bl32.bin
	rm -f $(BINARIES_PATH)/bl32_extra1.bin
	rm -f $(BINARIES_PATH)/bl32_extra2.bin
	rm -f $(BINARIES_PATH)/tos_fw_config.dtb
	rm -f $(BINARIES_PATH)/op-tee.pkg
ifeq ($(SPMC_AT_EL),1)
	ln -sf $(TF_A_OUT)/fdts/spmc_el1_manifest.dtb \
		$(BINARIES_PATH)/tos_fw_config.dtb
	ln -sf $(OPTEE_OS_HEADER_V2_BIN) $(BINARIES_PATH)/bl32.bin
	ln -sf $(OPTEE_OS_PAGER_V2_BIN) $(BINARIES_PATH)/bl32_extra1.bin
	ln -sf $(OPTEE_OS_PAGEABLE_V2_BIN) $(BINARIES_PATH)/bl32_extra2.bin
else ifeq ($(SPMC_AT_EL),2)
	ln -sf $(TF_A_OUT)/fdts/spmc_el2_manifest.dtb \
		$(BINARIES_PATH)/tos_fw_config.dtb
	ln -sf $(TF_A_OUT)/fdts/tb_fw_config.dtb \
		$(BINARIES_PATH)/tb_fw_config.dtb
	ln -sf $(HAFNIUM_BIN) $(BINARIES_PATH)/bl32.bin
	ln -sf $(TF_A_OUT)/op-tee.pkg $(BINARIES_PATH)/op-tee.pkg
else ifeq ($(SPMC_AT_EL),3)
	ln -sf $(TF_A_OUT)/fdts/spmc_el3_manifest.dtb \
		$(BINARIES_PATH)/tos_fw_config.dtb
	ln -sf $(OPTEE_OS_PAGER_V2_BIN) $(BINARIES_PATH)/bl32.bin
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

qemu: $(QEMU_BUILD)/.stamp_qemu

$(QEMU_BUILD)/.stamp_qemu: $(QEMU_BUILD)/config-host.mak
	$(MAKE) -C $(QEMU_PATH)
	touch $@

qemu-clean:
	rm -f $(QEMU_BUILD)/.stamp_qemu
	$(MAKE) -C $(QEMU_PATH) distclean

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

ifeq ($(ARM_FIRMWARE_HANDOFF),y)
UBOOT_DEFCONFIG_FILES += $(ROOT)/build/kconfigs/u-boot_tl.conf
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

LINUX_COMMON_FLAGS += ARCH=arm64
LINUX_COMMON_TARGETS += Image scripts_gdb

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
# Trusted Services
################################################################################
ifeq ($(SEL0_SPS),y)
SP_PACKAGING_METHOD = embedded
SPMC_TESTS=y
include trusted-services.mk

# SPMC test SPs
OPTEE_OS_COMMON_EXTRA_FLAGS     += CFG_SPMC_TESTS=y CFG_SECURE_PARTITION=y
OPTEE_OS_COMMON_EXTRA_FLAGS     += CFG_SP_SKIP_FAILED=y
OPTEE_OS_COMMON_EXTRA_FLAGS     += CFG_DT=y CFG_MAP_EXT_DT_SECURE=y
SP_SPMC_TEST_EXTRA_FLAGS	+= -DCFG_TEST_MEM_REGION_ADDRESS=0x0efff000
$(eval $(call build-sp,spm-test1,opteesp,5c9edbc3-7b3a-4367-9f83-7c191ae86a37,$(SP_SPMC_TEST_EXTRA_FLAGS)))
$(eval $(call build-sp,spm-test2,opteesp,7817164c-c40c-4d1a-867a-9bb2278cf41a,$(SP_SPMC_TEST_EXTRA_FLAGS)))
$(eval $(call build-sp,spm-test3,opteesp,23eb0100-e32a-4497-9052-2f11e584afa6,$(SP_SPMC_TEST_EXTRA_FLAGS)))
$(eval $(call build-sp,spm-test4,opteesp,423762ed-7772-406f-99d8-0c27da0abbf8,$(SP_SPMC_TEST_EXTRA_FLAGS)))
endif

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += DEBUG=$(DEBUG) CFG_ARM_GICV3=$(GICV3)
OPTEE_OS_COMMON_FLAGS_SPMC_AT_EL_1 = CFG_CORE_SEL1_SPMC=y
OPTEE_OS_COMMON_FLAGS_SPMC_AT_EL_2 = CFG_CORE_SEL2_SPMC=y
OPTEE_OS_COMMON_FLAGS_SPMC_AT_EL_2 += CFG_ARM_GICV3=n CFG_CORE_HAFNIUM_INTC=y
# [0e00.0000 0e2f.ffff] is reserved to early boot and SPMC
# [0e30.0000 0e33.ffff] is reserved manifest etc (op-tee.pkg)
OPTEE_OS_COMMON_FLAGS_SPMC_AT_EL_2 += CFG_TZDRAM_START=0x0e304000
OPTEE_OS_COMMON_FLAGS_SPMC_AT_EL_2 += CFG_TZDRAM_SIZE=0x00cfc000
OPTEE_OS_COMMON_FLAGS_SPMC_AT_EL_2 += CFG_CORE_WORKAROUND_NSITR_CACHE_PRIME=n
OPTEE_OS_COMMON_FLAGS_SPMC_AT_EL_3 = CFG_CORE_EL3_SPMC=y
OPTEE_OS_COMMON_FLAGS_SPMC_AT_EL_3 += CFG_DT_ADDR=0x40000000
OPTEE_OS_COMMON_FLAGS_SPMC_AT_EL_3 += CFG_CORE_RESERVED_SHM=n

ifeq ($(XEN_BOOT),y)
OPTEE_OS_COMMON_FLAGS += CFG_NS_VIRTUALIZATION=y
endif

ifeq ($(PAUTH),y)
OPTEE_OS_COMMON_FLAGS += CFG_TA_PAUTH=y
OPTEE_OS_COMMON_FLAGS += CFG_CORE_PAUTH=y
endif
ifeq ($(MEMTAG),y)
OPTEE_OS_COMMON_FLAGS += CFG_MEMTAG=y
endif

ifneq ($(QEMU_SMP),)
CFG_TEE_CORE_NB_CORE ?= $(QEMU_SMP)
OPTEE_OS_COMMON_FLAGS += CFG_TEE_CORE_NB_CORE=$(CFG_TEE_CORE_NB_CORE)
endif

ifeq ($(WITH_SCMI),y)
OPTEE_OS_COMMON_FLAGS += CFG_SCMI_SCPFW=y
OPTEE_OS_COMMON_FLAGS += CFG_SCP_FIRMWARE=$(ROOT)/SCP-firmware
endif

OPTEE_OS_COMMON_FLAGS += $(OPTEE_OS_COMMON_FLAGS_SPMC_AT_EL_$(SPMC_AT_EL))

ifeq ($(ARM_FIRMWARE_HANDOFF),y)
OPTEE_OS_COMMON_FLAGS += CFG_TRANSFER_LIST=y
endif

optee-os: optee-os-common

optee-os-clean: optee-os-clean-common

################################################################################
# Hafnium
################################################################################

HAFNIUM_EXPORTS = PATH=$(TOOLCHAIN_ROOT)/clang-$(CLANG_BUILD_VER)/bin:$(PATH)

.hafnium_checkout:
	git -C $(HAFNIUM_PATH) submodule update --init
	touch $@

hafnium: $(HAFNIUM_BIN)

$(HAFNIUM_BIN): .hafnium_checkout | $(OUT_PATH)
	$(HAFNIUM_EXPORTS) $(MAKE) -C $(HAFNIUM_PATH) $(HAFNIUM_FLAGS) PLATFORM=secure_qemu_aarch64

hafnium-clean:
	$(HAFNIUM_EXPORTS) $(MAKE) -C $(HAFNIUM_PATH) $(HAFNIUM_FLAGS) clean
	rm -f .hafnium_checkout

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

.PHONY: uImage
uImage: $(KERNEL_UIMAGE)

$(ROOTFS_UGZ): u-boot buildroot | $(BINARIES_PATH)
	ln -sf $(ROOT)/out-br/images/rootfs.cpio.gz $(BINARIES_PATH)
	$(MKIMAGE_PATH)/mkimage -A arm64 \
				-T ramdisk \
				-C gzip \
				-a $(ROOTFS_LOADADDR) \
				-e $(ROOTFS_ENTRY) \
				-n "Root file system" \
				-d $(ROOTFS_GZ) $(ROOTFS_UGZ)

.PHONY: uRootfs
uRootfs: $(ROOTFS_UGZ)

################################################################################
# XEN
################################################################################

XEN_CONFIGS = .config $(ROOT)/build/kconfigs/xen.conf
ifeq ($(XEN_DEBUG),y)
XEN_CONFIGS += $(ROOT)/build/kconfigs/xen_debug.conf
endif

ifneq ($(filter 1 2 3,$(SPMC_AT_EL)),)
XEN_FFA = y
endif

$(XEN_PATH)/xen/.config:
	$(MAKE) -C $(XEN_PATH)/xen XEN_TARGET_ARCH=arm64 defconfig
	cd $(XEN_PATH)/xen && \
	env XEN_TARGET_ARCH=arm64 tools/kconfig/merge_config.sh $(XEN_CONFIGS)

xen-menuconfig:
	$(MAKE) -C $(XEN_PATH)/xen XEN_TARGET_ARCH=arm64 menuconfig

xen: $(XEN_PATH)/xen/.config
	$(MAKE) -C $(XEN_PATH) dist-xen \
	XEN_TARGET_ARCH=arm64 \
	CONFIG_XEN_INSTALL_SUFFIX=.gz	\
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

xen-create-image: xen

XEN_TMP = $(BINARIES_PATH)/xen_files

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
QEMU_VIRT	= true
QEMU_XEN	?= -drive if=none,file=$(XEN_EXT4),format=raw,id=hd1 \
		   -device virtio-blk-device,drive=hd1
else ifeq ($(SPMC_AT_EL),2)
QEMU_VIRT	= true
else
QEMU_VIRT	= false
endif

ifeq ($(QEMU_VIRT),true)
QEMU_MEM 	?= 3072
QEMU_SMP	?= 4
else
QEMU_SMP 	?= 2
QEMU_MEM 	?= 1057
endif

ifeq ($(XEN_BOOT),y)
QEMU_SME	= off
else ifeq ($(SPMC_AT_EL),n)
QEMU_SME	= on
else ifeq ($(SPMC_AT_EL),2)
QEMU_SME	= on
else
QEMU_SME	= off
endif
QEMU_CPU	?= max,sme=$(QEMU_SME),pauth-impdef=on

ifeq ($(MEMTAG),y)
QEMU_MTE	= on
else ifeq ($(SPMC_AT_EL),2)
QEMU_MTE	= on
else
QEMU_MTE	= off
endif

QEMU_BASE_ARGS = -nographic
QEMU_BASE_ARGS += -smp $(QEMU_SMP)
QEMU_BASE_ARGS += -cpu $(QEMU_CPU)
QEMU_BASE_ARGS += -d unimp -semihosting-config enable=on,target=native
QEMU_BASE_ARGS += -m $(QEMU_MEM)
QEMU_BASE_ARGS += -bios bl1.bin
QEMU_BASE_ARGS += -initrd rootfs.cpio.gz
QEMU_BASE_ARGS += -kernel Image
QEMU_BASE_ARGS += -append 'console=ttyAMA0,38400 keep_bootcon root=/dev/vda2 $(QEMU_KERNEL_BOOTARGS)'
QEMU_BASE_ARGS += $(QEMU_XEN)
QEMU_BASE_ARGS += $(QEMU_EXTRA_ARGS)
QEMU_BASE_ARGS += -machine virt,acpi=off,secure=on,mte=$(QEMU_MTE),gic-version=$(QEMU_GIC_VERSION),virtualization=$(QEMU_VIRT)

# The aarch64-softmmu part of the path to qemu-system-aarch64 was removed
# somewhere between 8.1.2 and 9.1.2
QEMU_BIN = $(or $(wildcard $(QEMU_BUILD)/qemu-system-aarch64),$(wildcard $(QEMU_BUILD)/aarch64-softmmu/qemu-system-aarch64),qemu-system-aarch64-not-found)

ifeq ($(WITH_SCMI),y)
QEMU_SCMI_ARGS 	= -dtb $(SCMI_DTB)

$(SCMI_DTBO): $(SCMI_DTSO)
	mkdir -p $(BINARIES_PATH)
	dtc -I dts -O dtb -o $(SCMI_DTBO) $(SCMI_DTSO)

$(SCMI_DTB): $(SCMI_DTBO) $(QEMU_BUILD)/.stamp_qemu linux arm-tf buildroot
	ln -sf $(ROOT)/out-br/images/rootfs.cpio.gz $(BINARIES_PATH)/
	cd $(BINARIES_PATH) && $(QEMU_BIN) \
		$(QEMU_BASE_ARGS) -machine dumpdtb=qemu_v8.dtb
	cd $(BINARIES_PATH) && fdtoverlay -i qemu_v8.dtb -o $(SCMI_DTB) $(SCMI_DTBO)
endif

QEMU_RUN_ARGS = $(QEMU_BASE_ARGS) $(QEMU_SCMI_ARGS)
QEMU_RUN_ARGS += $(QEMU_RUN_ARGS_COMMON)
QEMU_RUN_ARGS += -s -S -serial tcp:127.0.0.1:$(QEMU_NW_PORT) -serial tcp:127.0.0.1:$(QEMU_SW_PORT) 

.PHONY: run-only
run-only:
	ln -sf $(ROOT)/out-br/images/rootfs.cpio.gz $(BINARIES_PATH)/
	$(call check-terminal)
	$(call run-help)
	$(call launch-terminal,$(QEMU_NW_PORT),"Normal World")
	$(call launch-terminal,$(QEMU_SW_PORT),"Secure World")
	$(call wait-for-ports,$(QEMU_NW_PORT),$(QEMU_SW_PORT))
	cd $(BINARIES_PATH) && $(QEMU_BIN) $(QEMU_RUN_ARGS)

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

QEMU_CHECK_ARGS = $(QEMU_BASE_ARGS) $(QEMU_SCMI_ARGS)
QEMU_CHECK_ARGS += -serial mon:stdio -serial file:serial1.log
ifeq ($(XEN_BOOT),y)
QEMU_CHECK_ARGS += -fsdev local,id=fsdev0,path=../..,security_model=none -device virtio-9p-device,fsdev=fsdev0,mount_tag=host
endif

check: $(CHECK_DEPS)
	ln -sf $(ROOT)/out-br/images/rootfs.cpio.gz $(BINARIES_PATH)/
	cd $(BINARIES_PATH) && \
		export QEMU=$(QEMU_BIN) && \
		export QEMU_CHECK_ARGS="$(QEMU_CHECK_ARGS)" && \
		export XEN_BOOT=$(XEN_BOOT) && \
		export XEN_FFA=$(XEN_FFA) && \
		export RUST_ENABLE=$(RUST_ENABLE) && \
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
