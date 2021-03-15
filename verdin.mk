################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
COMPILE_NS_USER   ?= 64
override COMPILE_NS_KERNEL := 64
COMPILE_S_USER    ?= 64
COMPILE_S_KERNEL  ?= 64

BR2_TARGET_GENERIC_GETTY_PORT = ttymxc0
################################################################################
# Includes
################################################################################
include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
OUT_PATH		?= $(ROOT)/out
ROOTFS_BIN		?= $(ROOT)/out-br/images/rootfs.tar
TF_A_PATH		?= $(ROOT)/trusted-firmware-a
UBOOT_PATH		?= $(ROOT)/u-boot
OPTEE_PATH		?= $(ROOT)/optee_os
LINUX_PATH		?= $(ROOT)/linux

LINUX_DTB		?= $(LINUX_PATH)/arch/arm64/boot/dts/freescale/fsl-imx8mm-verdin-dev.dtb
MODULE_OUTPUT		?= $(ROOT)/module_output

UBOOT_BIN		?= $(UBOOT_PATH)/flash.bin
OPTEE_ELF		?= $(OPTEE_PATH)/out/arm/core/tee.elf

DDR_URL			?= https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/firmware-imx-8.1.1.bin
DDR_PATH		?= $(ROOT)/ddr-firmware

ATF_LOAD_ADDR		?= 0x920000
TEE_LOAD_ADDR		?= 0xbe000000


################################################################################
# Targets
################################################################################
.PHONY: all
all: u-boot arm-tf buildroot linux prepare-images | toolchains

.PHONY: clean
clean: u-boot-clean arm-tf-clean linux-clean optee-os-clean \
	buildroot-clean

################################################################################
# Toolchain
################################################################################
include toolchain.mk

################################################################################
# U-Boot
################################################################################
.PHONY: u-boot-config
u-boot-config:
ifeq ($(wildcard $(UBOOT_PATH)/.config),)
	$(MAKE) -C $(UBOOT_PATH) \
		CROSS_COMPILE=$(AARCH64_CROSS_COMPILE) verdin-imx8mm_defconfig
endif

.PHONY: u-boot-menuconfig
u-boot-menuconfig: u-boot-config
	$(MAKE) -C $(UBOOT_PATH) \
		CROSS_COMPILE=$(AARCH64_CROSS_COMPILE) menuconfig

.PHONY: u-boot
u-boot: u-boot-config arm-tf optee-os ddr-firmware
	# Copy BL31 binary from TF-A
	cp $(TF_A_PATH)/build/imx8mm/release/bl31.bin $(UBOOT_PATH)
	# Prepare proper tee.bin
	$(AARCH64_CROSS_COMPILE)objcopy -O binary \
		$(OPTEE_ELF) $(UBOOT_PATH)/tee.bin
	# Copy DDR4 firmware
	cp $(DDR_PATH)/firmware-imx-8.1.1/firmware/ddr/synopsys/lpddr4*.bin \
		$(UBOOT_PATH)
	# Build U-Boot and final ready-to-flash flash.bin image
	ATF_LOAD_ADDR=$(ATF_LOAD_ADDR) TEE_LOAD_ADDR=$(TEE_LOAD_ADDR) \
	$(MAKE) -C $(UBOOT_PATH) \
		CROSS_COMPILE="$(AARCH64_CROSS_COMPILE)" flash.bin

.PHONY: u-boot-clean
u-boot-clean:
	cd $(UBOOT_PATH) && git clean -xdf

################################################################################
# DDR4 Firmware
################################################################################
.PHONY: ddr-firmware
ddr-firmware:
	# DDR is exported to the $PWD only, so cd to $(DDR_PATH)
	# before unpacking
	if [ ! -d "$(DDR_PATH)" ]; then \
		mkdir -p $(DDR_PATH) && \
		wget $(DDR_URL) -O $(DDR_PATH)/firmware.bin && \
		chmod +x $(DDR_PATH)/firmware.bin && \
		cd $(DDR_PATH) && \
		$(DDR_PATH)/firmware.bin --auto-accept && \
		cd $(ROOT)/build; \
	fi;

.PHONY: ddr-firmware-clean
ddr-firmware-clean:
	rm -rf $(DDR_PATH)

################################################################################
# ARM Trusted Firmware
################################################################################
.PHONY: arm-tf
arm-tf:
	$(MAKE) -C $(TF_A_PATH) \
		PLAT=imx8mm \
		CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
		SPD=opteed \
		bl31

.PHONY: arm-tf-clean
arm-tf-clean:
	cd $(TF_A_PATH) && git clean -xdf

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += PLATFORM=imx PLATFORM_FLAVOR=mx8mmevk CFG_ARM64_core=y CFG_UART_BASE=0x30860000
OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=imx-mx8mmevk

.PHONY: optee-os
optee-os: optee-os-common

.PHONY: optee-os-clean
optee-os-clean: optee-os-clean-common

################################################################################
# Linux
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm64/configs/defconfig \

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64

linux: linux-common
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS) freescale/fsl-imx8mm-verdin-dev.dtb
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS) INSTALL_MOD_STRIP=1 \
		INSTALL_MOD_PATH=$(MODULE_OUTPUT) modules_install

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

linux-cleaner: linux-cleaner-common

.PHONY: prepare-images
prepare-images: linux u-boot buildroot
	@mkdir -p $(OUT_PATH)
	@cp $(UBOOT_BIN) $(OUT_PATH)
	@cp $(LINUX_PATH)/arch/arm64/boot/Image $(OUT_PATH)
	@cp $(LINUX_DTB) $(OUT_PATH)
	@cp $(ROOT)/out-br/images/rootfs.tar $(OUT_PATH)

################################################################################
# Buildroot/RootFS
################################################################################
.PHONY: update_rootfs
update_rootfs: u-boot linux
	@cd $(MODULE_OUTPUT) && find . | cpio -pudm $(BUILDROOT_TARGET_ROOT)
	@cd $(ROOT)/build

.PHONY: buildroot
buildroot: update_rootfs
