################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER    := 64
override COMPILE_S_KERNEL  := 64

DEBUG ?= 0

-include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
ARM_TF_PATH		?= $(ROOT)/arm-trusted-firmware

U-BOOT_PATH		?= $(ROOT)/u-boot
U-BOOT_BIN		?= $(U-BOOT_PATH)/u-boot.bin

################################################################################
# Targets
################################################################################
all: arm-tf u-boot linux optee-os optee-client xtest helloworld update_rootfs
clean: arm-tf-clean busybox-clean u-boot-clean optee-os-clean \
	optee-client-clean


-include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
ARM_TF_EXPORTS ?= \
	CFLAGS="-O0 -gdwarf-2" \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

ARM_TF_FLAGS ?= \
	SCP_BL2=$(ROOT)/vexpress-firmware/SOFTWARE/bl30.bin \
	BL32=$(OPTEE_OS_BIN) \
	BL33=$(U-BOOT_BIN) \
	DEBUG=0 \
	ARM_TSP_RAM_LOCATION=dram \
	PLAT=juno \
	SPD=opteed

arm-tf: optee-os u-boot
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) all fip

arm-tf-clean:
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) clean

################################################################################
# Busybox
################################################################################
BUSYBOX_COMMON_TARGET = fvp
BUSYBOX_CLEAN_COMMON_TARGET = fvp clean

busybox: busybox-common

busybox-clean: busybox-clean-common

busybox-cleaner: busybox-cleaner-common

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
OPTEE_OS_COMMON_FLAGS += PLATFORM=vexpress-juno
optee-os: optee-os-common

OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=vexpress-juno
optee-os-clean: optee-os-clean-common

optee-client: optee-client-common

optee-client-clean: optee-client-clean-common
################################################################################
# xtest / optee_test
################################################################################
xtest: xtest-common

xtest-clean: xtest-clean-common

xtest-patch: xtest-patch-common

################################################################################
# hello_world
################################################################################
helloworld: helloworld-common

helloworld-clean: helloworld-clean-common

################################################################################
# Root FS
################################################################################
filelist-tee: filelist-tee-common

.PHONY: update_rootfs
update_rootfs: u-boot
update_rootfs: update_rootfs-common
	$(U-BOOT_PATH)/tools/mkimage -A arm64 -O linux -T ramdisk -C gzip \
		-d $(GEN_ROOTFS_PATH)/filesystem.cpio.gz \
		$(GEN_ROOTFS_PATH)/ramdisk.img

FTP-UPLOAD = ftp-upload -v --host $(JUNO_IP) --dir SOFTWARE

.PHONY: flash
flash:
	@test -n "$(JUNO_IP)" || \
		(echo "JUNO_IP not set" ; exit 1)
	$(FTP-UPLOAD) $(ROOT)/vexpress-firmware/SOFTWARE/bl0.bin
	$(FTP-UPLOAD) $(ARM_TF_PATH)/build/juno/release/bl1.bin
	$(FTP-UPLOAD) $(ARM_TF_PATH)/build/juno/release/fip.bin
	$(FTP-UPLOAD) $(ROOT)/linux/arch/arm64/boot/Image
	$(FTP-UPLOAD) $(ROOT)/linux/arch/arm64/boot/dts/arm/juno.dtb
	$(FTP-UPLOAD) $(ROOT)/gen_rootfs/ramdisk.img
