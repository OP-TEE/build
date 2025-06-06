################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER	:= 64
override COMPILE_NS_KERNEL	:= 64
override COMPILE_S_USER		:= 64
override COMPILE_S_KERNEL	:= 64

PLATFORM = AMD Versal Gen 2

# Network support related packages:
BR2_PACKAGE_DHCPCD	?= y
BR2_PACKAGE_ETHTOOL	?= y
BR2_PACKAGE_XINETD	?= y

# SSH Packages :
BR2_PACKAGE_OPENSSH		?= y
BR2_PACKAGE_OPENSSH_SERVER	?= y
BR2_PACKAGE_OPENSSH_KEY_UTILS	?= y

# Openssl binary
BR2_PACKAGE_LIBOPENSSL_BIN	?= y
BR2_PACKAGE_LIBP11	?= y

# Busybox
BR2_PACKAGE_BUSYBOX_WATCHDOG    ?= y

# Target specific
BR2_TARGET_GENERIC_ISSUE	?= "OP-TEE embedded distrib for $(PLATFORM)"
BR2_TARGET_GENERIC_GETTY_PORT   ?= "console"
BR2_TARGET_ROOTFS_EXT2		?= y

# OP-TEE
OPTEE_OS_PLATFORM = versal2
OPTEE_OS_COMMON_EXTRA_FLAGS ?= CFG_PKCS11_TA=y CFG_USER_TA_TARGET_pkcs11=ta_arm64 O=out/arm

################################################################################
# Paths to git projects and various binaries
################################################################################
TF_A_PATH	?= $(ROOT)/arm-trusted-firmware
U-BOOT_PATH	?= $(ROOT)/u-boot-xlnx
LINUX_PATH	?= $(ROOT)/linux-xlnx

include common.mk

BINARIES_PATH	?= $(ROOT)/out/bin
TF_A_ELF	?= $(TF_A_PATH)/build/$(OPTEE_OS_PLATFORM)/release/bl31/bl31.elf
OPTEE_OS_ELF	?= $(OPTEE_OS_PATH)/out/arm/core/tee.elf
U-BOOT_ELF	?= $(U-BOOT_PATH)/u-boot.elf
U-BOOT_DTB	?= $(U-BOOT_PATH)/arch/arm/dts/versal2-*.dtb
MKIMAGE_PATH	?= $(U-BOOT_PATH)/tools
LINUX_IMAGE	?= $(LINUX_PATH)/arch/arm64/boot/Image
ROOTFS_GZ	?= $(ROOT)/out-br/images/rootfs.cpio.gz
ROOTFS_SIGN	?= $(BINARIES_PATH)/rootfs.cpio.gz.u-boot

################################################################################
# Targets
################################################################################

all: tfa optee-os u-boot linux dtbo buildroot buildroot_mkimg
clean: tfa-clean optee-os-clean u-boot-clean linux-clean dtbo-clean buildroot-clean

$(BINARIES_PATH):
	mkdir -p $@

include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################

TF_A_EXPORTS = CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"
TF_A_FLAGS = PLAT=versal2 CONSOLE=pl011 RESET_TO_BL31=1 SPD=opteed DEBUG=0 \
	     MEM_BASE=0x1600000 MEM_SIZE=0x200000 \
	     XILINX_OF_BOARD_DTB_ADDR=0x1000000 \
	     BL32_MEM_BASE=0x1800000 BL32_MEM_SIZE=0x8000000

tfa:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) bl31
	mkdir -p $(BINARIES_PATH)
	cp $(TF_A_ELF) $(BINARIES_PATH)

tfa-clean:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) clean

################################################################################
# OP-TEE
################################################################################

OPTEE_OS_COMMON_FLAGS += CFG_TEE_CORE_LOG_LEVEL=2 CFG_TEE_TA_LOG_LEVEL=2 \
			 CFG_DT=y

optee-os: optee-os-common
	mkdir -p $(BINARIES_PATH)
	cp $(OPTEE_OS_ELF) $(BINARIES_PATH)

optee-os-clean: optee-os-clean-common
	rm -rf ${OPTEE_OS_PATH}/out/

################################################################################
# U-Boot
################################################################################

U-BOOT_EXPORTS = CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"
U-BOOT_DEFCONFIG_COMMON_FILES := $(U-BOOT_PATH)/configs/amd_versal2_virt_defconfig \
			$(BUILD_PATH)/kconfigs/u-boot_versal2.conf

u-boot-defconfig: $(U-BOOT_DEFCONFIG_COMMON_FILES)
	cd $(U-BOOT_PATH) && \
                ARCH=arm64 \
                scripts/kconfig/merge_config.sh $(U-BOOT_DEFCONFIG_COMMON_FILES)

u-boot: u-boot-defconfig
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH)
	mkdir -p $(BINARIES_PATH)
	cp $(U-BOOT_ELF) $(BINARIES_PATH)

u-boot-defconfig-clean:
	rm -f $(U-BOOT_PATH)/.config

u-boot-clean: u-boot-defconfig-clean
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean

###############################################################################
# Device-Tree
###############################################################################
dtbo: linux u-boot
	mkdir -p $(BINARIES_PATH)
	${LINUX_PATH}/scripts/dtc/dtc -@ -I dts \
		-O dtb -o $(BINARIES_PATH)/versal2-memory-reservation.dtbo \
		$(BUILD_PATH)/versal2/versal2-memory-reservation.dtso
	@$(foreach dtb,$(wildcard $(U-BOOT_DTB)), \
		${LINUX_PATH}/scripts/dtc/fdtoverlay -i $(dtb) \
		-o $(dtb) $(BINARIES_PATH)/versal2-memory-reservation.dtbo ; \
		echo "Applied overlay to $(dtb)";)
	cp $(U-BOOT_DTB) $(BINARIES_PATH)

dtbo-clean:
	rm -f $(BINARIES_PATH)/versal2-memory-reservation.dtbo

################################################################################
# Linux kernel
################################################################################

LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm64/configs/xilinx_defconfig \
		$(BUILD_PATH)/kconfigs/versal2.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64

linux: linux-common
	mkdir -p $(BINARIES_PATH)
	cp $(LINUX_IMAGE) $(BINARIES_PATH)

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

linux-cleaner: linux-cleaner-common

################################################################################
# Buildroot
################################################################################

buildroot_mkimg: buildroot
	mkdir -p $(BINARIES_PATH)
	$(MKIMAGE_PATH)/mkimage -A arm \
				-T ramdisk \
				-C gzip \
				-d $(ROOTFS_GZ) $(ROOTFS_SIGN)
