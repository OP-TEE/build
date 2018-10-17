################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
COMPILE_NS_USER   ?= 64
override COMPILE_NS_KERNEL := 64
COMPILE_S_USER    ?= 32
COMPILE_S_KERNEL  ?= 64

################################################################################
# Includes
################################################################################
include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
ifeq ($(DEBUG),1)
ARM_TF_BUILD		?= debug
else
ARM_TF_BUILD		?= release
endif

OUT_PATH		?= $(ROOT)/out
ROOTFS_BIN		?= $(ROOT)/out-br/images/rootfs.tar
ARM_TF_PATH		?= $(ROOT)/arm-trusted-firmware
LLOADER_PATH		?= $(ROOT)/l-loader
UBOOT_PATH		?= $(ROOT)/u-boot
OPTEE_CLIENT_EXPORT	?= $(OPTEE_CLIENT_PATH)/out/export
OPTEE_PATH		?= $(ROOT)/optee_os
LINUX_PATH		?= $(ROOT)/linux
TOOLS_PATH		?= $(ROOT)/poplar-tools

BL1_BIN			?= $(ARM_TF_PATH)/build/poplar/$(ARM_TF_BUILD)/bl1.bin
FIP_BIN			?= $(ARM_TF_PATH)/build/poplar/$(ARM_TF_BUILD)/fip.bin
LLOADER_BIN		?= $(LLOADER_PATH)/l-loader.bin

LINUX_DTB		?= $(LINUX_PATH)/arch/arm64/boot/dts/hisilicon/hi3798cv200-poplar.dtb

UBOOT_BIN		?= $(UBOOT_PATH)/u-boot.bin
OPTEE_BIN		?= $(OPTEE_PATH)/out/arm/core/tee-header_v2.bin
OPTEE_BIN_EXTRA1	?= $(OPTEE_PATH)/out/arm/core/tee-pager_v2.bin
OPTEE_BIN_EXTRA2	?= $(OPTEE_PATH)/out/arm/core/tee-pageable_v2.bin

################################################################################
# Targets
################################################################################
.PHONY: all
all: u-boot arm-tf buildroot l-loader linux prepare-images | toolchains

.PHONY: clean
clean: u-boot-clean arm-tf-clean l-loader-clean linux-clean optee-os-clean \
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
		CROSS_COMPILE=$(AARCH64_CROSS_COMPILE) poplar_defconfig
endif

.PHONY: u-boot-menuconfig
u-boot-menuconfig: u-boot-config
	$(MAKE) -C $(UBOOT_PATH) \
		CROSS_COMPILE=$(AARCH64_CROSS_COMPILE) menuconfig

.PHONY: u-boot
u-boot: u-boot-config
	$(MAKE) -C $(UBOOT_PATH) \
		CROSS_COMPILE="$(AARCH64_CROSS_COMPILE)"

.PHONY: u-boot-clean
u-boot-clean:
	cd $(UBOOT_PATH) && git clean -xdf

################################################################################
# ARM Trusted Firmware
################################################################################
.PHONY: arm-tf
arm-tf: u-boot optee-os
	$(MAKE) -C $(ARM_TF_PATH) \
		CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
		all fip \
		DEBUG=$(DEBUG) \
		PLAT=poplar \
		SPD=opteed \
		BL32=$(OPTEE_BIN) \
		BL33=$(UBOOT_BIN) \
		BL32_EXTRA1=$(OPTEE_BIN_EXTRA1) \
		BL32_EXTRA2=$(OPTEE_BIN_EXTRA2)

.PHONY: arm-tf-clean
arm-tf-clean:
	cd $(ARM_TF_PATH) && git clean -xdf

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += PLATFORM=poplar CFG_ARM64_core=y CFG_DRAM_SIZE_GB=1
OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=poplar

.PHONY: optee-os
optee-os: optee-os-common

.PHONY: optee-os-clean
optee-os-clean: optee-os-clean-common

################################################################################
# l-loader
################################################################################
l-loader: arm-tf
	cp $(BL1_BIN) $(LLOADER_PATH)/atf
	cp $(FIP_BIN) $(LLOADER_PATH)/atf
	$(MAKE) -C $(LLOADER_PATH) CROSS_COMPILE="$(AARCH32_CROSS_COMPILE)"

.PHONY: l-loader-clean
l-loader-clean:
	cd $(LLOADER_PATH) && git clean -xdf

################################################################################
# Linux
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm64/configs/poplar_defconfig \

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64
# Avoid compile errors with GCC 8.x. These flags may be removed when
# https://github.com/96boards-poplar/linux/pull/3 is merged.
LINUX_COMMON_FLAGS += CFLAGS_drv_hifb_proc.o=-Wno-stringop-truncation \
		      CFLAGS_drv_pvr_intf.o=-Wno-sizeof-pointer-memaccess \
		      CFLAGS_drv_display.o=-Wno-array-bounds

linux: linux-common

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

linux-cleaner: linux-cleaner-common

.PHONY: prepare-images
prepare-images: linux l-loader buildroot
	@mkdir -p $(OUT_PATH)
	@cp $(TOOLS_PATH)/poplar_recovery_builder.sh $(OUT_PATH)
	@cp $(LLOADER_BIN) $(OUT_PATH)
	@cp $(LINUX_PATH)/arch/arm64/boot/Image $(OUT_PATH)
	@cp $(LINUX_DTB) $(OUT_PATH)
	@cd $(OUT_PATH) && PATH=$(UBOOT_PATH)/tools:$$PATH \
	       bash ./poplar_recovery_builder.sh all "$(ROOTFS_BIN)"

################################################################################
# Buildroot/RootFS
################################################################################
.PHONY: update_rootfs
update_rootfs: arm-tf u-boot

.PHONY: buildroot
buildroot: update_rootfs

################################################################################
# Flash images
################################################################################
.PHONY: flash-help
flash-help:
	@echo "1. Install and configure TFTP server on your host PC:"
	@echo ""
	@echo "   $$ sudo apt-get install atftpd      # install atftpd server"
	@echo "   $$ sudo vim /etc/default/atftpd     # edit atftpd server config"
	@echo "   $$ sudo service atftpd restart      # restart atftpd server"
	@echo ""
	@echo "2. Proper configuration should look like:"
	@echo ""
	@echo "   $$ cat /etc/default/atftpd"
	@echo "   USE_INETD=false"
	@echo "   OPTIONS=\"--tftpd-timeout 300 --retry-timeout 5 --mcast-port 1758 --mcast-addr 239.239.239.0-255 --mcast-ttl 1 --maxthread 100 --verbose=5 /path/to/rep/out/dir\""
	@echo ""
	@echo "3. Flash proper U-boot build  to USB stick."
	@echo "   It should be flashed to the first FAT32 partition. Then boot"
	@echo "   from it by pressing USB_BOOT switch on the board"
	@echo ""
	@echo "4. Connect to Poplar board over serial console (run on host PC):"
	@echo ""
	@echo "   $$ screen /dev/ttyUSB0 115200"
	@echo ""
	@echo "5. Configure network interface in Poplar U-boot shell. If you can't"
	@echo "get into U-boot console, press and hold Ctrl+C while booting:"
	@echo ""
	@echo "   => setenv ipaddr 192.168.0.2"
	@echo "   => setenv netmask 255.255.255.0"
	@echo "   => setenv serverip 192.168.0.3"
	@echo "   ETH1: PHY(phyaddr=3, rgmii) link UP: DUPLEX=FULL : SPEED=1000M"
	@echo "   MAC:   00-16-8E-62-66-84"
	@echo "   host 192.168.0.3 is alive"
	@echo ""
	@echo "6. Verify connection is working (run in U-boot shell):"
	@echo ""
	@echo "   => ping 192.168.0.3"
	@echo ""
	@echo "7. Run installer (run in U-boot shell):"
	@echo ""
	@echo "   => tftp 0x08000000 recovery_files/install.scr"
	@echo "   => source 0x08000000"
	@echo ""
	@echo "8. After successful flashing reboot your board (U-boot shell):"
	@echo ""
	@echo "   => reset"
	@echo ""
