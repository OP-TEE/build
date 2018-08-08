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

ARM_TF_PATH		?= $(ROOT)/arm-trusted-firmware
LLOADER_PATH		?= $(ROOT)/l-loader
UBOOT_PATH		?= $(ROOT)/u-boot
OPTEE_PATH		?= $(ROOT)/optee_os
OPTEE_CLIENT_PATH	?= $(ROOT)/optee_client
OPTEE_CLIENT_EXPORT	?= $(OPTEE_CLIENT_PATH)/out/export
OPTEE_TEST_PATH		?= $(ROOT)/optee_test
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

ROOTFS_BIN		?= linaro-stretch-developer-*.tar.gz
ROOTFS_URL		?= https://releases.linaro.org/debian/images/developer-arm64/latest/$(ROOTFS_BIN)

PKG_OPTEE_VERSION	?= $(shell cd $(OPTEE_OS_PATH) && git describe)-0
PKG_PATH		?= $(OUT_PATH)/debpkg/optee_$(PKG_OPTEE_VERSION)
PKG_USR_BIN		?= $(PKG_PATH)/usr/bin
PKG_CONTROL		?= $(PKG_PATH)/DEBIAN/control

################################################################################
# Targets
################################################################################
.PHONY: all
all: u-boot arm-tf l-loader linux rootfs prepare-images deb-package | toolchains

.PHONY: clean
clean: u-boot-clean arm-tf-clean l-loader-clean linux-clean optee-os-clean

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
# OP-TEE client
################################################################################
.PHONY: optee-client
optee-client: optee-client-common

.PHONY: optee-client-clean
optee-client-clean: optee-client-common-clean

################################################################################
# OP-TEE xtest
################################################################################
.PHONY: xtest
xtest: xtest-common

.PHONY: xtest-clean
xtest-clean: xtest-clean-common

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
OPTEE_OS_COMMON_FLAGS += PLATFORM=poplar CFG_ARM64_core=y CFG_DRAM_SIZE_GB=2
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
# rootfs
################################################################################
.PHONY: rootfs
rootfs:
	@wget -nc -P $(OUT_PATH) $(ROOTFS_URL)

.PHONY: rootfs-clean
rootfs-clean:
	rm -f $(ROOTFS_BIN)

################################################################################
# Linux
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm64/configs/poplar_defconfig \
		$(CURDIR)/kconfigs/hikey.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64

linux: linux-common

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

linux-cleaner: linux-cleaner-common

################################################################################
# Build package
################################################################################
.PHONY: deb-package
deb-package: xtest optee-client
	mkdir -p $(PKG_PATH)/usr/lib/aarch64-linux-gnu
	mkdir -p $(PKG_USR_BIN)
	mkdir -p $(PKG_PATH)/lib/optee_armtz
	mkdir -p $(PKG_PATH)/DEBIAN
	cp -f $(OPTEE_CLIENT_EXPORT)/bin/tee-supplicant $(PKG_USR_BIN)
	cp -f $(OPTEE_TEST_PATH)/out/xtest/xtest $(PKG_USR_BIN)
	cp -f $(OPTEE_CLIENT_EXPORT)/lib/libtee* $(PKG_PATH)/usr/lib/aarch64-linux-gnu
	find $(OPTEE_TEST_PATH)/out/ta -name "*.ta" -exec cp {} $(PKG_PATH)/lib/optee_armtz \;
	echo "Package: op-tee" > $(PKG_CONTROL)
	echo "Version: $(PKG_OPTEE_VERSION)" >> $(PKG_CONTROL)
	echo "Section: base" >> $(PKG_CONTROL)
	echo "Priority: optional" >> $(PKG_CONTROL)
	echo "Architecture: arm64" >> $(PKG_CONTROL)
	echo "Depends:" >> $(PKG_CONTROL)
	echo "Maintainer: OP-TEE <op-tee@linaro.org>" >> $(PKG_CONTROL)
	echo "Description: OP-TEE client binaries, test program and Trusted Applications" >> $(PKG_CONTROL)
	echo " Package contains tee-supplicant, libtee.so, xtest and a set of" >> $(PKG_CONTROL)
	echo " Trusted Applications." >> $(PKG_CONTROL)
	echo " NOTE! This package should only be used for testing and development." >> $(PKG_CONTROL)
	echo ""
	dpkg-deb --build $(PKG_PATH)

################################################################################
# Prepare images
################################################################################
.PHONY: prepare-images
prepare-images: linux l-loader rootfs
	@cp $(TOOLS_PATH)/poplar_recovery_builder.sh $(OUT_PATH)
	@cp $(LLOADER_BIN) $(OUT_PATH)
	@cp $(LINUX_PATH)/arch/arm64/boot/Image $(OUT_PATH)
	@cp $(LINUX_DTB) $(OUT_PATH)
	@cd $(OUT_PATH) && \
		PATH=$(UBOOT_PATH)/tools:$$PATH \
	bash ./poplar_recovery_builder.sh all "$(ROOTFS_BIN)"

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
	@echo "9. Upload deb package using SCP (run on your host PC):"
	@echo ""
	@echo "   $$ scp optee_${PKG_OPTEE_VERSION}.deb linaro@192.168.0.2:/tmp"
	@echo ""
	@echo "10. Install package (run on Poplar board in bash shell):"
	@echo ""
	@echo "   $$ cd /tmp && dpkg --force-all -i optee*.deb"
	@echo ""
