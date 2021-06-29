################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER    := 64
override COMPILE_S_KERNEL  := 64

OPTEE_OS_PLATFORM = vexpress-juno

include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
TF_A_PATH		?= $(ROOT)/trusted-firmware-a

U-BOOT_PATH		?= $(ROOT)/u-boot
U-BOOT_BIN		?= $(U-BOOT_PATH)/u-boot.bin

SCP_BLX_URL		?= https://downloads.trustedfirmware.org/tf-a/css_scp_2.8.0/juno

################################################################################
# Targets
################################################################################
all: scp-blx arm-tf u-boot linux optee-os buildroot
clean: scp-blx-clean arm-tf-clean buildroot-clean u-boot-clean optee-os-clean

include toolchain.mk

################################################################################
# SCP BL1 and BL2
################################################################################
.PHONY: scp-blx
scp-blx: $(ROOT)/out-firmware/scp_bl1.bin $(ROOT)/out-firmware/scp_bl2.bin

.PHONY: scp-blx
scp-blx-clean:
	@rm -f $(ROOT)/out-firmware/scp_bl1.bin
	@rm -f $(ROOT)/out-firmware/scp_bl2.bin
	@rm -f $(ROOT)/out-firmware/tmp/scp_bl1.bin
	@rm -f $(ROOT)/out-firmware/tmp/scp_bl2.bin

define dlscp
	@mkdir -p $(ROOT)/out-firmware/tmp
	@rm -f $(ROOT)/out-firmware/tmp/$1
	@rm -f $(ROOT)/out-firmware/$1
	@(cd $(ROOT)/out-firmware/tmp/ && wget $(SCP_BLX_URL)/$1)
	@(echo $2 $(ROOT)/out-firmware/tmp/$1 | sha256sum -c)
	@(mv $(ROOT)/out-firmware/tmp/$1 $(ROOT)/out-firmware/$1)
endef

$(ROOT)/out-firmware/scp_bl1.bin:
	$(call dlscp,scp_bl1.bin,1c690a7d93c82d39d18b720920ced7a712fdcfc744224b4f067e56013522fece)

$(ROOT)/out-firmware/scp_bl2.bin:
	$(call dlscp,scp_bl2.bin,533eb4a3f9d91e759b98288edf4c1441abe6f7fbc5da87825a8f1bb1b7942aa5)

################################################################################
# ARM Trusted Firmware
################################################################################
TF_A_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

TF_A_FLAGS ?= \
	SCP_BL2=$(ROOT)/out-firmware/scp_bl2.bin \
	BL32=$(OPTEE_OS_HEADER_V2_BIN) \
	BL32_EXTRA1=$(OPTEE_OS_PAGER_V2_BIN) \
	BL32_EXTRA2=$(OPTEE_OS_PAGEABLE_V2_BIN) \
	BL33=$(U-BOOT_BIN) \
	DEBUG=0 \
	ARM_TSP_RAM_LOCATION=dram \
	PLAT=juno \
	SPD=opteed

arm-tf: scp-blx optee-os u-boot
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) all fip

arm-tf-clean:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) clean

################################################################################
# Das U-Boot
################################################################################

U-BOOT_EXPORTS ?= CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

U-BOOT_DEFCONFIG_FILES := \
	$(U-BOOT_PATH)/configs/vexpress_aemv8a_juno_defconfig \
	$(ROOT)/build/kconfigs/u-boot_juno.conf

.PHONY: u-boot
u-boot:
	cd $(U-BOOT_PATH) && \
		scripts/kconfig/merge_config.sh $(U-BOOT_DEFCONFIG_FILES)
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) all

u-boot-clean:
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm64/configs/defconfig \
		$(CURDIR)/kconfigs/juno.conf

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
optee-os: optee-os-common
optee-os-clean: optee-os-clean-common


$(ROOT)/out-br/images/ramdisk.img: $(ROOT)/out-br/images/rootfs.cpio.gz
	$(U-BOOT_PATH)/tools/mkimage -A arm64 -O linux -T ramdisk -C gzip \
		-d $< $@

FTP-UPLOAD = ftp-upload -v --host $(JUNO_IP) --dir SOFTWARE

.PHONY: flash
flash: $(ROOT)/out-br/images/ramdisk.img
	@test -n "$(JUNO_IP)" || \
		(echo "JUNO_IP not set" ; exit 1)
	$(FTP-UPLOAD) $(ROOT)/out-firmware/scp_bl1.bin
	$(FTP-UPLOAD) $(TF_A_PATH)/build/juno/release/bl1.bin
	$(FTP-UPLOAD) $(TF_A_PATH)/build/juno/release/fip.bin
	$(FTP-UPLOAD) $(ROOT)/linux/arch/arm64/boot/Image
	$(FTP-UPLOAD) $(ROOT)/linux/arch/arm64/boot/dts/arm/juno.dtb
	$(FTP-UPLOAD) $(ROOT)/linux/arch/arm64/boot/dts/arm/juno-r1.dtb
	$(FTP-UPLOAD) $(ROOT)/linux/arch/arm64/boot/dts/arm/juno-r2.dtb
	$(FTP-UPLOAD) $(ROOT)/out-br/images/ramdisk.img
