################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
COMPILE_NS_USER   ?= 64
override COMPILE_NS_KERNEL := 64
COMPILE_S_USER    ?= 32
COMPILE_S_KERNEL  ?= 64

# Normal/secure world console UARTs: 3 or 0 [default 3]
# NOTE: For Debian build only UART 3 works until we have sorted out how to build
# UEFI correcly.
CFG_NW_CONSOLE_UART ?= 3
CFG_SW_CONSOLE_UART ?= 3

# TODO: Figure out how to handle this in a better way, but we need a version
# number with major and minor for the debian packages.
#   <major version>.<minor version>-<package revision>
OPTEE_PKG_VERSION ?= 2.0-1

# IP-address to the HiKey device
IP ?= 127.0.0.1

# URL to images
SYSTEM_IMG_URL=https://builds.96boards.org/releases/reference-platform/debian/hikey/16.03/hikey-rootfs-debian-jessie-alip-20160301-68.emmc.img.gz
BOOT_IMG_URL=https://builds.96boards.org/releases/reference-platform/debian/hikey/16.03/hikey-boot-linux-20160301-68.uefi.img.gz
NVME_IMG_URL=https://builds.96boards.org/releases/hikey/linaro/binaries/latest/nvme.img

################################################################################
# Includes
################################################################################
-include common.mk

################################################################################
# Mandatory definition to use common.mk
################################################################################
ifeq ($(COMPILE_NS_USER),64)
MULTIARCH			:= aarch64-linux-gnu
else
MULTIARCH			:= arm-linux-gnueabihf
endif

################################################################################
# Paths to git projects and various binaries
################################################################################
ARM_TF_PATH			?= $(ROOT)/arm-trusted-firmware
ifeq ($(DEBUG),1)
ARM_TF_BUILD			?= debug
else
ARM_TF_BUILD			?= release
endif

EDK2_PATH 			?= $(ROOT)/edk2
ifeq ($(DEBUG),1)
EDK2_BIN 			?= $(EDK2_PATH)/Build/HiKey/DEBUG_GCC49/FV/BL33_AP_UEFI.fd
EDK2_BUILD			?= DEBUG
else
EDK2_BIN 			?= $(EDK2_PATH)/Build/HiKey/RELEASE_GCC49/FV/BL33_AP_UEFI.fd
EDK2_BUILD			?= RELEASE
endif

OUT_PATH			?= $(ROOT)/out
MCUIMAGE_BIN			?= $(EDK2_PATH)/HisiPkg/HiKeyPkg/NonFree/mcuimage.bin
BOOT_IMG			?= $(OUT_PATH)/boot-fat.uefi.img
NVME_IMG			?= $(OUT_PATH)/nvme.img
SYSTEM_IMG			?= $(OUT_PATH)/debian_system.img
ROOTFS_PATH			?= $(OUT_PATH)/rootfs
LLOADER_PATH			?= $(ROOT)/l-loader
PATCHES_PATH			?= $(ROOT)/patches_hikey
AESPERF_PATH			?= $(ROOT)/aes-perf
SHAPERF_PATH			?= $(ROOT)/sha-perf
DEBPKG_PATH			?= $(OUT_PATH)/optee_$(OPTEE_PKG_VERSION)
DEBPKG_BIN_PATH			?= $(DEBPKG_PATH)/usr/bin
DEBPKG_LIB_PATH			?= $(DEBPKG_PATH)/usr/lib/$(MULTIARCH)
DEBPKG_TA_PATH			?= $(DEBPKG_PATH)/lib/optee_armtz
DEBPKG_CONTROL_PATH		?= $(DEBPKG_PATH)/DEBIAN

################################################################################
# Targets
################################################################################
all: prepare arm-tf linux boot-img lloader system-img nvme deb

clean: arm-tf-clean edk2-clean linux-clean optee-os-clean optee-client-clean xtest-clean boot-img-clean lloader-clean aes-perf-clean sha-perf-clean

cleaner: clean prepare-cleaner linux-cleaner nvme-cleaner system-img-cleaner

-include toolchain.mk

prepare:
	@mkdir -p $(ROOT)/out

.PHONY: prepare-cleaner
prepare-cleaner:
	rm -rf $(ROOT)/out

################################################################################
# ARM Trusted Firmware
################################################################################
ARM_TF_EXPORTS ?= \
	CFLAGS="-O0 -gdwarf-2" \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

ARM_TF_FLAGS ?= \
	BL32=$(OPTEE_OS_BIN) \
	BL33=$(EDK2_BIN) \
	BL30=$(MCUIMAGE_BIN) \
	DEBUG=$(DEBUG) \
	PLAT=hikey \
	SPD=opteed

ARM_TF_CONSOLE_UART ?= $(CFG_SW_CONSOLE_UART)
ifeq ($(ARM_TF_CONSOLE_UART),0)
	ARM_TF_FLAGS += CONSOLE_BASE=PL011_UART0_BASE \
			CRASH_CONSOLE_BASE=PL011_UART0_BASE
endif

arm-tf: optee-os edk2
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) all fip

.PHONY: arm-tf-clean
arm-tf-clean:
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) clean

################################################################################
# EDK2 / Tianocore
################################################################################
EDK2_VARS ?= EDK2_ARCH=AARCH64 \
		EDK2_DSC=HisiPkg/HiKeyPkg/HiKey.dsc \
		EDK2_TOOLCHAIN=GCC49 \
		EDK2_BUILD=$(EDK2_BUILD)

EDK2_CONSOLE_UART ?= $(CFG_NW_CONSOLE_UART)
ifeq ($(EDK2_CONSOLE_UART),0)
	EDK2_VARS += EDK2_MACROS="-DSERIAL_BASE=0xF8015000"
endif

define edk2-call
	GCC49_AARCH64_PREFIX=$(LEGACY_AARCH64_CROSS_COMPILE) \
	$(MAKE) -j1 -C $(EDK2_PATH) \
		-f HisiPkg/HiKeyPkg/Makefile $(EDK2_VARS)
endef

edk2: edk2-common

.PHONY: edk2-clean
edk2-clean: edk2-clean-common

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH ?= arm64
LINUX_DEFCONFIG_COMMON_FILES ?= $(LINUX_PATH)/arch/arm64/configs/defconfig \
				$(LINUX_PATH)/arch/arm64/configs/distro.config \
				$(CURDIR)/kconfigs/hikey_debian.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64 deb-pkg LOCALVERSION=-optee-rpb
UPSTREAM_KERNEL := $(if $(wildcard $(LINUX_PATH)/arch/arm64/boot/dts/hisilicon/hi6220-hikey.dts),1,0)
ifeq ($(UPSTREAM_KERNEL),0)
LINUX_COMMON_FLAGS += hi6220-hikey.dtb
DTB = $(LINUX_PATH)/arch/arm64/boot/dts/hi6220-hikey.dtb
else
LINUX_COMMON_FLAGS += hisilicon/hi6220-hikey.dtb
DTB = $(LINUX_PATH)/arch/arm64/boot/dts/hisilicon/hi6220-hikey.dtb
endif

linux: linux-common

.PHONY: linux-defconfig-clean
linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

.PHONY: linux-clean
linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

.PHONY: linux-cleaner
linux-cleaner: linux-cleaner-common

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += PLATFORM=hikey CFG_TEE_TA_LOG_LEVEL=3 CFG_CONSOLE_UART=$(CFG_SW_CONSOLE_UART)
OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=hikey

optee-os: optee-os-common

.PHONY: optee-os-clean
optee-os-clean: optee-os-clean-common

optee-client: optee-client-common

.PHONY: optee-client-clean
optee-client-clean: optee-client-clean-common

################################################################################
# xtest / optee_test
################################################################################

xtest: xtest-common

# FIXME:
# "make clean" in xtest: fails if optee_os has been cleaned previously
.PHONY: xtest-clean
xtest-clean: xtest-clean-common
	rm -rf $(OPTEE_TEST_OUT_PATH)

.PHONY: xtest-patch
xtest-patch: xtest-patch-common

################################################################################
# aes-pef
################################################################################
PERF_FLAGS := CROSS_COMPILE_HOST=$(CROSS_COMPILE_NS_USER) \
	CROSS_COMPILE_TA=$(CROSS_COMPILE_S_USER) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR)

aes-perf: optee-os optee-client
	$(MAKE) -C -j$(NPROC) $(AESPERF_PATH) $(PERF_FLAGS)

.PHONY: aes-perf-clean
aes-perf-clean:
	rm -rf $(AESPERF_PATH)/out

################################################################################
# sha-perf
################################################################################
sha-perf: optee-os optee-client
	$(MAKE) -C -j$(NPROC) $(SHAPERF_PATH) $(PERF_FLAGS)

.PHONY: sha-perf-clean
sha-perf-clean:
	rm -rf $(SHAPERF_PATH)/out

################################################################################
# Boot Image
################################################################################
.PHONY: boot-img
boot-img:
ifeq ("$(wildcard $(BOOT_IMG))","")
	echo "Downloading Debian HiKey boot image ..."
	wget $(BOOT_IMG_URL) -O $(BOOT_IMG).gz
	gunzip $(BOOT_IMG).gz
endif

.PHONY: boot-img-clean
boot-img-clean:
	rm -f $(BOOT_IMG)

################################################################################
# system image
################################################################################
.PHONY: system-img
system-img: prepare
ifeq ("$(wildcard $(SYSTEM_IMG))","")
	@echo "Downloading Debian root fs (730MB) ..."
	wget $(SYSTEM_IMG_URL) -O $(SYSTEM_IMG).gz
	gunzip $(SYSTEM_IMG).gz
endif

.PHONY: system-cleaner
system-img-cleaner:
	rm -f $(SYSTEM_IMG)

################################################################################
# l-loader
################################################################################
lloader: arm-tf
	$(MAKE) -C $(LLOADER_PATH) BL1=$(ARM_TF_PATH)/build/hikey/$(ARM_TF_BUILD)/bl1.bin CROSS_COMPILE="$(CCACHE)$(AARCH32_CROSS_COMPILE)" PTABLE_LST=linux-4g

.PHONY: lloader-clean
lloader-clean:
	$(MAKE) -C $(LLOADER_PATH) clean

################################################################################
# nvme image
################################################################################
.PHONY: nvme
nvme: prepare
ifeq ("$(wildcard $(NVME_IMG))","")
	wget $(NVME_IMG_URL) -O $(NVME_IMG)
endif

.PHONY: nvme-cleaner
nvme-cleaner:
	rm -f $(NVME_IMG)

################################################################################
# Debian package
################################################################################
define CONTROL_TEXT
Package: op-tee
Version: $(OPTEE_PKG_VERSION)
Section: base
Priority: optional
Architecture: arm64
Depends:
Maintainer: Joakim Bech <joakim.bech@linaro.org>
Description: OP-TEE client binaries, test program and Trusted Applications
 Package contains tee-supplicant, libtee.so, xtest and a set of
 Trusted Applications.
 NOTE! This package should only be used for testing and development.
endef

export CONTROL_TEXT

.PHONY: deb
deb: xtest optee-client
	@mkdir -p $(DEBPKG_BIN_PATH) && cd $(DEBPKG_BIN_PATH) && \
		cp -f $(OPTEE_CLIENT_EXPORT)/bin/tee-supplicant . && \
		cp -f $(OPTEE_TEST_OUT_PATH)/xtest/xtest .

	@mkdir -p $(DEBPKG_LIB_PATH) && cd $(DEBPKG_LIB_PATH) && \
		cp $(OPTEE_CLIENT_EXPORT)/lib/libtee* .

	@mkdir -p $(DEBPKG_TA_PATH) && cd $(DEBPKG_TA_PATH) && \
		find $(OPTEE_TEST_OUT_PATH)/ta -name "*.ta" -exec cp {} . \;

	@mkdir -p $(DEBPKG_CONTROL_PATH)
	@echo "$$CONTROL_TEXT" > $(DEBPKG_CONTROL_PATH)/control
	@cd $(OUT_PATH) && dpkg-deb --build optee_$(OPTEE_PKG_VERSION)

################################################################################
# Send built files to the host, note this require that the IP corresponds to
# the device. One can run:
#   IP=111.222.333.444 make send
# If you don't want to edit the makefile itself.
################################################################################
.PHONY: send
send:
	@tar czf - $(shell cd $(OUT_PATH) && echo $(OUT_PATH)/*.deb && echo $(ROOT)/linux-image-*.deb) | ssh linaro@$(IP) "cd /tmp; tar xvzf -"
	@echo "Files has been sent to $$IP/tmp/ and $$IP/tmp/out"
	@echo "On the device, run:"
	@echo " dpkg --force-all -i /tmp/out/optee_$(OPTEE_PKG_VERSION).deb"
	@echo " dpkg --force-all -i /tmp/linux-image-*.deb"

################################################################################
# Flash
################################################################################
define flash_help
	@read -r -p "1. Connect USB OTG cable, the micro USB cable (press any key)" dummy
	@read -r -p "2. Connect HiKey to power up (press any key)" dummy
endef

.PHONY: recovery
recovery:
	@echo "Enter recovery mode to flash a new bootloader"
	@echo "Jumper 1-2: Closed (Auto power up = Boot up when power is applied)"
	@echo "       3-4: Closed (Boot Select = Recovery: program eMMC from USB OTG)"
	$(call flash_help)
	sudo python $(ROOT)/burn-boot/hisi-idt.py --img1=$(LLOADER_PATH)/l-loader.bin
	@$(MAKE) --no-print flash FROM_RECOVERY=1

.PHONY: flash
flash:
ifneq ($(FROM_RECOVERY),1)
	@echo "Flash binaries using fastboot"
	@echo "Jumper 1-2: Closed (Auto power up = Boot up when power is applied)"
	@echo "       3-4: Open   (Boot Select = Boot from eMMC)"
	@echo "       5-6: Closed (GPIO3-1 = Low: UEFI runs Fastboot app)"
	$(call flash_help)
	@echo "3. Wait until you see the (UART) message"
	@echo "    \"Android Fastboot mode - version x.x Press any key to quit.\""
	@read -r -p "   Then press any key to continue flashing" dummy
endif
	fastboot flash ptable $(LLOADER_PATH)/ptable-linux-4g.img
	fastboot flash fastboot $(ARM_TF_PATH)/build/hikey/$(ARM_TF_BUILD)/fip.bin
	fastboot flash nvme $(NVME_IMG)
	fastboot flash boot $(BOOT_IMG)
	fastboot flash system $(SYSTEM_IMG)

.PHONY: flash-fip
flash-fip:
	fastboot flash fastboot $(ARM_TF_PATH)/build/hikey/$(ARM_TF_BUILD)/fip.bin

.PHONY: flash-boot-img
flash-boot-img: boot-img
	fastboot flash boot $(BOOT_IMG)

.PHONY: flash-system-img
flash-system-img: system-img
	fastboot flash system $(SYSTEM_IMG)

.PHONY: help
help:
	@echo " 1. WiFi on HiKey debian"
	@echo " ======================="
	@echo " Open /etc/network/interfaces and add:"
	@echo "  allow-hotplug wlan0"
	@echo "  	iface wlan0 inet dhcp"
	@echo " 	wpa-ssid \"my-ssid\""
	@echo " 	wpa-psk \"my-wifi-password\""
	@echo " Reboot and you should have WiFi access"
