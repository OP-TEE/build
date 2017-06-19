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
SYSTEM_IMG_URL=http://builds.96boards.org/snapshots/reference-platform/debian-iot/latest/hikey/hikey-rootfs-debian-stretch-iot-20170331-56.emmc.img.gz
NVME_IMG_URL=http://builds.96boards.org/snapshots/reference-platform/components/uefi/latest/debug/hikey/nvme.img

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
OPENPLATPKG_PATH		?= $(ROOT)/OpenPlatformPkg

OUT_PATH			?= $(ROOT)/out
MCUIMAGE_BIN			?= $(OPENPLATPKG_PATH)/Platforms/Hisilicon/HiKey/Binary/mcuimage.bin
BOOT_IMG			?= $(OUT_PATH)/boot-fat.uefi.img
NVME_IMG			?= $(OUT_PATH)/nvme.img
SYSTEM_IMG			?= $(OUT_PATH)/debian_system.img
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
all: arm-tf linux boot-img lloader system-img nvme deb

clean: arm-tf-clean edk2-clean linux-clean optee-os-clean optee-client-clean xtest-clean helloworld-clean boot-img-clean lloader-clean grub-clean

cleaner: clean prepare-cleaner linux-cleaner nvme-cleaner system-img-cleaner grub-cleaner

-include toolchain.mk

prepare:
	@mkdir -p $(OUT_PATH)

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
EDK2_ARCH ?= AARCH64
EDK2_DSC ?= OpenPlatformPkg/Platforms/Hisilicon/HiKey/HiKey.dsc
EDK2_TOOLCHAIN ?= GCC49

EDK2_CONSOLE_UART ?= $(CFG_NW_CONSOLE_UART)
ifeq ($(EDK2_CONSOLE_UART),0)
	EDK2_BUILDFLAGS += -DSERIAL_BASE=0xF8015000
endif

define edk2-call
	GCC49_AARCH64_PREFIX=$(LEGACY_AARCH64_CROSS_COMPILE) \
	build -n 1 -a $(EDK2_ARCH) -t $(EDK2_TOOLCHAIN) -p $(EDK2_DSC) \
		-b $(EDK2_BUILD) $(EDK2_BUILDFLAGS)
endef

.PHONY: edk2
edk2:
	cd $(EDK2_PATH) && rm -rf OpenPlatformPkg && \
		ln -s $(OPENPLATPKG_PATH)
	set -e && cd $(EDK2_PATH) && source edksetup.sh BaseTools && \
		$(MAKE) -j1 -C $(EDK2_PATH)/BaseTools && \
		$(call edk2-call)

.PHONY: edk2-clean
edk2-clean:
	set -e && cd $(EDK2_PATH) && source edksetup.sh BaseTools && \
		$(MAKE) -j1 -C $(EDK2_PATH)/BaseTools clean
	rm -rf $(EDK2_PATH)/Build
	rm -f $(EDK2_PATH)/Conf/build_rule.txt
	rm -f $(EDK2_PATH)/Conf/target.txt
	rm -f $(EDK2_PATH)/Conf/tools_def.txt

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH ?= arm64
LINUX_DEFCONFIG_COMMON_FILES ?= $(DEBPKG_SRC_PATH)/debian/config/config \
				$(DEBPKG_SRC_PATH)/debian/config/arm64/config \
				$(CURDIR)/kconfigs/hikey_debian.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64 deb-pkg LOCALVERSION=-optee-rpb

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
OPTEE_OS_COMMON_FLAGS += PLATFORM=hikey \
			 CFG_CONSOLE_UART=$(CFG_SW_CONSOLE_UART) \
			 CFG_SECURE_DATA_PATH=n
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
# hello_world
################################################################################
helloworld: helloworld-common

helloworld-clean: helloworld-clean-common

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
boot-img: grub edk2
	rm -f $(BOOT_IMG)
	/sbin/mkfs.fat -F32 -n "boot" -C $(BOOT_IMG) 65536
	mmd -i $(BOOT_IMG) EFI
	mmd -i $(BOOT_IMG) EFI/BOOT
	mcopy -i $(BOOT_IMG) $(EDK2_PATH)/Build/HiKey/$(EDK2_BUILD)_GCC49/AARCH64/AndroidFastbootApp.efi ::/EFI/BOOT/fastboot.efi
	mcopy -i $(BOOT_IMG) $(OUT_PATH)/grubaa64.efi ::/EFI/BOOT/grubaa64.efi

.PHONY: boot-img-clean
boot-img-clean:
	rm -f $(BOOT_IMG)

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

.PHONY: system-cleaner
system-img-cleaner:
	rm -f $(SYSTEM_IMG)

################################################################################
# l-loader
################################################################################
lloader: arm-tf
	$(MAKE) -C $(LLOADER_PATH) BL1=$(ARM_TF_PATH)/build/hikey/$(ARM_TF_BUILD)/bl1.bin CROSS_COMPILE="$(CCACHE)$(AARCH32_CROSS_COMPILE)" PTABLE_LST=linux-$(CFG_FLASH_SIZE)g

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
 Package contains tee-supplicant, libtee.so, xtest, hello_world and a set of
 Trusted Applications.
 NOTE! This package should only be used for testing and development.
endef

export CONTROL_TEXT

.PHONY: deb
deb: prepare xtest helloworld optee-client
	@mkdir -p $(DEBPKG_BIN_PATH) && cd $(DEBPKG_BIN_PATH) && \
		cp -f $(OPTEE_CLIENT_EXPORT)/bin/tee-supplicant . && \
		cp -f $(OPTEE_TEST_OUT_PATH)/xtest/xtest . && \
		cp -f $(HELLOWORLD_PATH)/host/hello_world .

	@mkdir -p $(DEBPKG_LIB_PATH) && cd $(DEBPKG_LIB_PATH) && \
		cp $(OPTEE_CLIENT_EXPORT)/lib/libtee* .

	@mkdir -p $(DEBPKG_TA_PATH) && cd $(DEBPKG_TA_PATH) && \
		cp $(HELLOWORLD_PATH)/ta/*.ta . && \
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
	@echo
	@echo "Make sure udev permissions are set appropriately:"
	@echo "  # /etc/udev/rules.d/hikey.rules"
	@echo '  SUBSYSTEM=="usb", ATTRS{idVendor}=="18d1", ATTRS{idProduct}=="d00d", MODE="0666"'
	@echo '  SUBSYSTEM=="usb", ATTRS{idVendor}=="12d1", MODE="0666", ENV{ID_MM_DEVICE_IGNORE}="1"'
	@echo
	@echo "Jumper 1-2: Closed (Auto power up = Boot up when power is applied)"
	@echo "       3-4: Closed (Boot Select = Recovery: program eMMC from USB OTG)"
	$(call flash_help)
	python $(ROOT)/burn-boot/hisi-idt.py --img1=$(LLOADER_PATH)/l-loader.bin
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
	@echo "If the board stalls while flashing $(SYSTEM_IMG),"
	@echo "i.e. does not complete after more than 5 minutes,"
	@echo "please try running 'make recovery' instead"
	fastboot flash ptable $(LLOADER_PATH)/ptable-linux-$(CFG_FLASH_SIZE)g.img
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
