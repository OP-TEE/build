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

# eMMC flash size: 8 or 4 GB [default 8]
CFG_FLASH_SIZE ?= 8

# IP-address to the HiKey device
IP ?= 127.0.0.1

# URL to images
SYSTEM_IMG_URL=https://builds.96boards.org/releases/reference-platform/debian/hikey/16.06/hikey-rootfs-debian-jessie-alip-20160629-120.emmc.img.gz
WIFI_FW_URL=http://http.us.debian.org/debian/pool/non-free/f/firmware-nonfree/firmware-ti-connectivity_20161130-3_all.deb

################################################################################
# Disallow use of UART0 for Debian Linux console
################################################################################
ifeq ($(CFG_NW_CONSOLE_UART),0)
$(error The Debian Linux console currently supports UART3 only!)
endif

################################################################################
# Includes
################################################################################
-include common.mk

OPTEE_PKG_VERSION := $(shell cd $(OPTEE_OS_PATH) && git describe)-0

################################################################################
# Paths to git projects and various binaries
################################################################################
ARM_TF_PATH			?= $(ROOT)/arm-trusted-firmware
ATF_FB_PATH			?= $(ROOT)/atf-fastboot
ifeq ($(DEBUG),1)
ARM_TF_BUILD			?= debug
ATF_FB_BUILD			?= debug
else
ARM_TF_BUILD			?= release
ATF_FB_BUILD			?= release
endif

EDK2_PATH 			?= $(ROOT)/edk2
ifeq ($(DEBUG),1)
EDK2_BUILD			?= DEBUG
else
EDK2_BUILD			?= RELEASE
endif
EDK2_BIN			?= $(EDK2_PATH)/Build/HiKey/$(EDK2_BUILD)_$(EDK2_TOOLCHAIN)/FV/BL33_AP_UEFI.fd
OPENPLATPKG_PATH		?= $(ROOT)/OpenPlatformPkg

OUT_PATH			?= $(ROOT)/out
MCUIMAGE_BIN			?= $(OPENPLATPKG_PATH)/Platforms/Hisilicon/HiKey/Binary/mcuimage.bin
BOOT_IMG			?= $(OUT_PATH)/boot-fat.uefi.img
NVME_IMG			?= $(OUT_PATH)/nvme.img
SYSTEM_IMG			?= $(OUT_PATH)/debian_system.img
WIFI_FW				?= $(OUT_PATH)/firmware-ti-connectivity_20161130-3_all.deb
GRUB_PATH			?= $(ROOT)/grub
GRUB_CONFIGFILE			?= $(OUT_PATH)/grub.configfile
LLOADER_PATH			?= $(ROOT)/l-loader
PATCHES_PATH			?= $(ROOT)/patches_hikey
DEBPKG_PATH			?= $(OUT_PATH)/optee_$(OPTEE_PKG_VERSION)
DEBPKG_SRC_PATH			?= $(ROOT)/debian-kernel-packaging
DEBPKG_BIN_PATH			?= $(DEBPKG_PATH)/usr/bin
DEBPKG_LIB_PATH			?= $(DEBPKG_PATH)/usr/lib/$(MULTIARCH)
DEBPKG_TA_PATH			?= $(DEBPKG_PATH)/lib/optee_armtz
DEBPKG_CONTROL_PATH		?= $(DEBPKG_PATH)/DEBIAN

################################################################################
# Targets
################################################################################
.PHONY: all
all: arm-tf linux boot-img lloader system-img nvme deb

.PHONY: clean
clean: arm-tf-clean atf-fb-clean edk2-clean linux-clean optee-os-clean \
		optee-client-clean xtest-clean optee-examples-clean \
		boot-img-clean lloader-clean grub-clean deb-clean

.PHONY: cleaner
cleaner: clean prepare-cleaner linux-cleaner nvme-cleaner \
			system-img-cleaner grub-cleaner

-include toolchain.mk

.PHONY: prepare
prepare:
	mkdir -p $(OUT_PATH)

.PHONY: prepare-cleaner
prepare-cleaner:
	rm -rf $(ROOT)/out

################################################################################
# ARM Trusted Firmware
################################################################################
ARM_TF_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

ARM_TF_FLAGS ?= \
	BL32=$(OPTEE_OS_HEADER_V2_BIN) \
	BL32_EXTRA1=$(OPTEE_OS_PAGER_V2_BIN) \
	BL32_EXTRA2=$(OPTEE_OS_PAGEABLE_V2_BIN) \
	BL33=$(EDK2_BIN) \
	SCP_BL2=$(MCUIMAGE_BIN) \
	DEBUG=$(DEBUG) \
	PLAT=hikey \
	SPD=opteed

ARM_TF_CONSOLE_UART ?= $(CFG_SW_CONSOLE_UART)
ifeq ($(ARM_TF_CONSOLE_UART),0)
	ARM_TF_FLAGS += CONSOLE_BASE=PL011_UART0_BASE \
			CRASH_CONSOLE_BASE=PL011_UART0_BASE
endif

.PHONY: arm-tf
arm-tf: optee-os edk2
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) all fip

.PHONY: arm-tf-clean
arm-tf-clean:
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) clean

################################################################################
# EDK2 / Tianocore
################################################################################
EDK2_ARCH ?= AARCH64
EDK2_DSC ?= OpenPlatformPkg/Platforms/Hisilicon/HiKey/HiKey.dsc
EDK2_TOOLCHAIN ?= GCC49

EDK2_CONSOLE_UART ?= $(CFG_NW_CONSOLE_UART)
ifeq ($(EDK2_CONSOLE_UART),0)
	EDK2_BUILDFLAGS += -DSERIAL_BASE=0xF8015000
endif

define edk2-call
	$(EDK2_TOOLCHAIN)_$(EDK2_ARCH)_PREFIX=$(LEGACY_AARCH64_CROSS_COMPILE) \
	build -n `getconf _NPROCESSORS_ONLN` -a $(EDK2_ARCH) \
		-t $(EDK2_TOOLCHAIN) -p $(EDK2_DSC) \
		-b $(EDK2_BUILD) $(EDK2_BUILDFLAGS)
endef

.PHONY: edk2
edk2:
	cd $(EDK2_PATH) && rm -rf OpenPlatformPkg && \
		ln -s $(OPENPLATPKG_PATH)
	set -e && cd $(EDK2_PATH) && source edksetup.sh && \
		$(MAKE) -j1 -C $(EDK2_PATH)/BaseTools && \
		$(call edk2-call)

.PHONY: edk2-clean
edk2-clean:
	set -e && cd $(EDK2_PATH) && source edksetup.sh && \
		$(call edk2-call) cleanall && \
		$(MAKE) -j1 -C $(EDK2_PATH)/BaseTools clean
	rm -rf $(EDK2_PATH)/Build
	rm -rf $(EDK2_PATH)/Conf/.cache
	rm -f $(EDK2_PATH)/Conf/build_rule.txt
	rm -f $(EDK2_PATH)/Conf/target.txt
	rm -f $(EDK2_PATH)/Conf/tools_def.txt

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH ?= arm64
LINUX_DEFCONFIG_COMMON_FILES ?= $(DEBPKG_SRC_PATH)/debian/config/config \
				$(DEBPKG_SRC_PATH)/debian/config/arm64/config \
				$(CURDIR)/kconfigs/hikey_debian.conf \
				$(PATCHES_PATH)/kernel_config/usb_net_dm9601.conf \
				$(PATCHES_PATH)/kernel_config/ftrace.conf

.PHONY: linux-defconfig
linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64 deb-pkg LOCALVERSION=-optee-rpb

.PHONY: linux
linux: linux-common

.PHONY: linux-defconfig-clean
linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

.PHONY: linux-clean
linux-clean: linux-clean-common
	rm -f $(ROOT)/linux-*optee*.*

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

.PHONY: linux-cleaner
linux-cleaner: linux-cleaner-common

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += PLATFORM=hikey \
			 CFG_CONSOLE_UART=$(CFG_SW_CONSOLE_UART) \
			 CFG_SECURE_DATA_PATH=n
OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=hikey

.PHONY: optee-os
optee-os: optee-os-common

.PHONY: optee-os-clean
optee-os-clean: optee-os-clean-common

.PHONY: optee-client
optee-client: optee-client-common

.PHONY: optee-client-clean
optee-client-clean: optee-client-clean-common

################################################################################
# xtest / optee_test
################################################################################
.PHONY: xtest
xtest: xtest-common

# FIXME:
# "make clean" in xtest: fails if optee_os has been cleaned previously
.PHONY: xtest-clean
xtest-clean: xtest-clean-common
	rm -rf $(OPTEE_TEST_OUT_PATH)

.PHONY: xtest-patch
xtest-patch: xtest-patch-common

################################################################################
# Sample applications / optee_examples
################################################################################
.PHONY: optee-examples
optee-examples: optee-examples-common

.PHONY: optee-examples-clean
optee-examples-clean: optee-examples-clean-common

################################################################################
# grub
################################################################################
grub-flags := CC="$(CCACHE)gcc" \
	TARGET_CC="$(AARCH64_CROSS_COMPILE)gcc" \
	TARGET_OBJCOPY="$(AARCH64_CROSS_COMPILE)objcopy" \
	TARGET_NM="$(AARCH64_CROSS_COMPILE)nm" \
	TARGET_RANLIB="$(AARCH64_CROSS_COMPILE)ranlib" \
	TARGET_STRIP="$(AARCH64_CROSS_COMPILE)strip"

GRUB_MODULES += boot chain configfile echo efinet eval ext2 fat font gettext \
		gfxterm gzio help linux loadenv lsefi normal part_gpt \
		part_msdos read regexp search search_fs_file search_fs_uuid \
		search_label terminal terminfo test tftp time

$(GRUB_CONFIGFILE): prepare
	@echo "search.fs_label rootfs root" > $(GRUB_CONFIGFILE)
	@echo "set prefix=(\$$root)'/boot/grub'" >> $(GRUB_CONFIGFILE)
	@echo "configfile \$$prefix/grub.cfg" >> $(GRUB_CONFIGFILE)

$(GRUB_PATH)/configure: $(GRUB_PATH)/configure.ac
	cd $(GRUB_PATH) && ./autogen.sh

$(GRUB_PATH)/Makefile: $(GRUB_PATH)/configure
	cd $(GRUB_PATH) && ./configure --target=aarch64 --enable-boot-time $(grub-flags)

.PHONY: grub
grub: $(GRUB_CONFIGFILE) $(GRUB_PATH)/Makefile
	$(MAKE) -C $(GRUB_PATH); \
	cd $(GRUB_PATH) && ./grub-mkimage \
		--verbose \
		--output=$(OUT_PATH)/grubaa64.efi \
		--config=$(GRUB_CONFIGFILE) \
		--format=arm64-efi \
		--directory=grub-core \
		--prefix=/boot/grub \
		$(GRUB_MODULES)

.PHONY: grub-clean
grub-clean:
	@if [ -e $(GRUB_PATH)/Makefile ]; then $(MAKE) -C $(GRUB_PATH) clean; fi
	rm -f $(OUT_PATH)/grubaa64.efi
	rm -f $(GRUB_CONFIGFILE)

.PHONY: grub-cleaner
grub-cleaner: grub-clean
	@if [ -e $(GRUB_PATH)/Makefile ]; then $(MAKE) -C $(GRUB_PATH) distclean; fi
	rm -f $(GRUB_PATH)/configure

################################################################################
# Boot Image
################################################################################
.PHONY: boot-img
boot-img: edk2 grub
	rm -f $(BOOT_IMG)
	/sbin/mkfs.fat -F32 -n "boot" -C $(BOOT_IMG) 65536
	mmd -i $(BOOT_IMG) EFI
	mmd -i $(BOOT_IMG) EFI/BOOT
	mcopy -i $(BOOT_IMG) $(OUT_PATH)/grubaa64.efi ::/EFI/BOOT/
	mcopy -i $(BOOT_IMG) $(EDK2_PATH)/Build/HiKey/$(EDK2_BUILD)_$(EDK2_TOOLCHAIN)/$(EDK2_ARCH)/AndroidFastbootApp.efi ::/EFI/BOOT/fastboot.efi

.PHONY: boot-img-clean
boot-img-clean:
	rm -f $(BOOT_IMG)

################################################################################
# atf-fastboot
################################################################################
ATF_FB_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

ATF_FB_FLAGS ?= \
	DEBUG=$(DEBUG) \
	PLAT=hikey

.PHONY: atf-fb
atf-fb:
	$(ATF_FB_EXPORTS) $(MAKE) -C $(ATF_FB_PATH) $(ATF_FB_FLAGS)

.PHONY: atf-fb-clean
atf-fb-clean:
	$(ATF_FB_EXPORTS) $(MAKE) -C $(ATF_FB_PATH) $(ATF_FB_FLAGS) clean

################################################################################
# system image
################################################################################
.PHONY: system-img
system-img: prepare
ifeq ("$(wildcard $(SYSTEM_IMG))","")
	@echo "Downloading Debian root fs ..."
	wget $(SYSTEM_IMG_URL) -O $(SYSTEM_IMG).gz
	gunzip $(SYSTEM_IMG).gz
endif
ifeq ("$(wildcard $(WIFI_FW))","")
	@echo "Downloading Wi-Fi firmware package ..."
	wget $(WIFI_FW_URL) -O $(WIFI_FW)
endif

.PHONY: system-cleaner
system-img-cleaner:
	rm -f $(SYSTEM_IMG)
	rm -f $(WIFI_FW)

################################################################################
# l-loader
################################################################################
.PHONY: lloader
lloader: arm-tf atf-fb
	cd $(LLOADER_PATH) && \
		ln -sf $(ARM_TF_PATH)/build/hikey/$(ARM_TF_BUILD)/bl1.bin && \
		ln -sf $(ATF_FB_PATH)/build/hikey/$(ATF_FB_BUILD)/bl1.bin fastboot.bin && \
		$(MAKE) hikey PTABLE_LST=linux-$(CFG_FLASH_SIZE)g CROSS_COMPILE="$(CCACHE)$(AARCH32_CROSS_COMPILE)"

.PHONY: lloader-clean
lloader-clean:
	$(MAKE) -C $(LLOADER_PATH) hikey-clean

################################################################################
# nvme image
#
# nvme partition is used to store UEFI non-volatile variables,
# but nvme image is currently an empty list
################################################################################
.PHONY: nvme
nvme: prepare
ifeq ("$(wildcard $(NVME_IMG))","")
	dd if=/dev/zero of=$(NVME_IMG) bs=1K count=128
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
 Package contains tee-supplicant, libtee.so, xtest, optee-examples and a set of
 Trusted Applications.
 NOTE! This package should only be used for testing and development.
endef

export CONTROL_TEXT

.PHONY: deb
deb: prepare xtest optee-examples optee-client
	@mkdir -p $(DEBPKG_BIN_PATH) && cd $(DEBPKG_BIN_PATH) && \
		cp -f $(OPTEE_CLIENT_EXPORT)/bin/tee-supplicant . && \
		cp -f $(OPTEE_TEST_OUT_PATH)/xtest/xtest .
	@if [ -e $(OPTEE_EXAMPLES_PATH)/out/ca ]; then \
		for example in $(OPTEE_EXAMPLES_PATH)/out/ca/*; do \
			cp -f $$example $(DEBPKG_BIN_PATH)/; \
		done; \
	fi
	@mkdir -p $(DEBPKG_LIB_PATH) && cd $(DEBPKG_LIB_PATH) && \
		cp $(OPTEE_CLIENT_EXPORT)/lib/libtee* .
	@mkdir -p $(DEBPKG_TA_PATH) && cd $(DEBPKG_TA_PATH) && \
		cp $(OPTEE_EXAMPLES_PATH)/out/ta/*.ta . && \
		find $(OPTEE_TEST_OUT_PATH)/ta -name "*.ta" -exec cp {} . \;
	@mkdir -p $(DEBPKG_CONTROL_PATH)
	@echo "$$CONTROL_TEXT" > $(DEBPKG_CONTROL_PATH)/control
	@cd $(OUT_PATH) && dpkg-deb --build optee_$(OPTEE_PKG_VERSION)

.PHONY: deb-clean
deb-clean:
	rm -rf $(OUT_PATH)/optee_*

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
	@echo " dpkg --force-all -i /tmp/out/*.deb"
	@echo " dpkg --force-all -i /tmp/linux-image-*.deb"

################################################################################
# Flash
################################################################################
define flash_help
	@read -r -p "1. Connect USB OTG cable, the micro USB cable (press enter)" dummy
	@read -r -p "2. Connect HiKey to power up (press enter)" dummy
endef

.PHONY: recovery
recovery:
	@echo "Enter recovery mode to flash a new bootloader"
	@echo
	@echo "Make sure udev permissions are set appropriately:"
	@echo "  # /etc/udev/rules.d/hikey.rules"
	@echo '  SUBSYSTEM=="usb", ATTRS{idVendor}=="18d1", ATTRS{idProduct}=="d00d", MODE="0666"'
	@echo '  SUBSYSTEM=="usb", ATTRS{idVendor}=="12d1", MODE="0666", ENV{ID_MM_DEVICE_IGNORE}="1"'
	@echo
	@echo "Set jumpers as follows:"
	@echo "Jumper 1-2: Closed (Auto power up = Boot up when power is applied)"
	@echo "       3-4: Closed (Boot Select = Recovery: program eMMC from USB OTG)"
	@echo "       5-6: Open (GPIO3-1 = High: UEFI runs normally)"
	@read -r -p "Press enter to continue" dummy
	@echo
	$(call flash_help)
	@echo
	python $(ROOT)/burn-boot/hisi-idt.py --img1=$(LLOADER_PATH)/l-loader.bin
	@echo
	@echo "3. Wait until you see the (UART) message"
	@echo "    \"Enter downloading mode. Please run fastboot command on Host.\""
	@echo "    \"usb: online (highspeed)\""
	@$(MAKE) --no-print flash FROM_RECOVERY=1

.PHONY: flash
flash:
ifneq ($(FROM_RECOVERY),1)
	@echo "Flash binaries using fastboot"
	@echo
	@echo "Set jumpers as follows:"
	@echo "Jumper 1-2: Closed (Auto power up = Boot up when power is applied)"
	@echo "       3-4: Open (Boot Select = Boot from eMMC)"
	@echo "       5-6: Closed (GPIO3-1 = Low: UEFI runs Fastboot app)"
	@read -r -p "Press enter to continue" dummy
	@echo
	$(call flash_help)
	@echo "3. Wait until you see the (UART) message"
	@echo "    \"Android Fastboot mode - version x.x Press any key to quit.\""
endif
	@read -r -p "Then press enter to continue flashing" dummy
	@echo
	@echo "If the board stalls while flashing $(SYSTEM_IMG),"
	@echo "i.e. does not complete after more than 5 minutes,"
	@echo "please try running 'make recovery' instead"
	@read -r -p "Press enter to continue" dummy
	@echo
	fastboot flash ptable $(LLOADER_PATH)/prm_ptable.img
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
