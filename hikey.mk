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
CFG_NW_CONSOLE_UART ?= 3
CFG_SW_CONSOLE_UART ?= 3

# eMMC flash size: 8 or 4 GB [default 8]
CFG_FLASH_SIZE ?= 8

################################################################################
# Includes
################################################################################
include common.mk

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
EDK2_BIN 			?= $(EDK2_PATH)/Build/HiKey/$(EDK2_BUILD)_$(EDK2_TOOLCHAIN)/FV/BL33_AP_UEFI.fd
OPENPLATPKG_PATH		?= $(ROOT)/OpenPlatformPkg

OUT_PATH			?=$(ROOT)/out
MCUIMAGE_BIN			?= $(OPENPLATPKG_PATH)/Platforms/Hisilicon/HiKey/Binary/mcuimage.bin
BOOT_IMG			?=$(ROOT)/out/boot-fat.uefi.img
NVME_IMG			?=$(ROOT)/out/nvme.img
GRUB_PATH			?=$(ROOT)/grub
LLOADER_PATH			?=$(ROOT)/l-loader
PATCHES_PATH			?=$(ROOT)/patches_hikey
STRACE_PATH			?=$(ROOT)/strace

################################################################################
# Targets
################################################################################
.PHONY: all
all: prepare arm-tf boot-img lloader nvme

.PHONY: clean
clean: arm-tf-clean atf-fb-clean buildroot-clean edk2-clean linux-clean \
		optee-os-clean boot-img-clean lloader-clean grub-clean

.PHONY: cleaner
cleaner: clean prepare-cleaner buildroot-cleaner linux-cleaner \
		nvme-cleaner grub-cleaner

include toolchain.mk

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
	$(EDK2_TOOLCHAIN)_$(EDK2_ARCH)_PREFIX=$(AARCH64_CROSS_COMPILE) \
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
LINUX_DEFCONFIG_COMMON_FILES ?= $(LINUX_PATH)/arch/arm64/configs/defconfig \
				$(CURDIR)/kconfigs/hikey.conf \
				$(PATCHES_PATH)/kernel_config/usb_net_dm9601.conf \
				$(PATCHES_PATH)/kernel_config/ftrace.conf

.PHONY: linux-defconfig
linux-defconfig: $(LINUX_PATH)/.config

.PHONY: linux-gen_init_cpio
linux-gen_init_cpio: linux-defconfig
	$(MAKE) -C $(LINUX_PATH)/usr \
		CROSS_COMPILE=$(CROSS_COMPILE_NS_KERNEL) \
		ARCH=arm64 \
		LOCALVERSION= \
		gen_init_cpio

LINUX_COMMON_FLAGS += ARCH=arm64 Image modules hisilicon/hi6220-hikey.dtb

.PHONY: linux
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
			CFG_CONSOLE_UART=$(CFG_SW_CONSOLE_UART)
OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=hikey

.PHONY: optee-os
optee-os: optee-os-common

.PHONY: optee-os-clean
optee-os-clean: optee-os-clean-common

################################################################################
# grub
################################################################################
grub-flags := CC="$(CCACHE)gcc" \
	TARGET_CC="$(AARCH64_CROSS_COMPILE)gcc" \
	TARGET_OBJCOPY="$(AARCH64_CROSS_COMPILE)objcopy" \
	TARGET_NM="$(AARCH64_CROSS_COMPILE)nm" \
	TARGET_RANLIB="$(AARCH64_CROSS_COMPILE)ranlib" \
	TARGET_STRIP="$(AARCH64_CROSS_COMPILE)strip" \
	--disable-werror

GRUB_MODULES += boot chain configfile efinet ext2 fat gettext \
                help linux loadenv lsefi normal part_gpt \
                part_msdos read search search_fs_file search_fs_uuid \
                search_label terminal terminfo tftp time

$(GRUB_PATH)/configure: $(GRUB_PATH)/configure.ac
	cd $(GRUB_PATH) && ./autogen.sh

$(GRUB_PATH)/Makefile: $(GRUB_PATH)/configure
	cd $(GRUB_PATH) && ./configure --target=aarch64 --enable-boot-time $(grub-flags)

.PHONY: grub
grub: prepare $(GRUB_PATH)/Makefile
	$(MAKE) -C $(GRUB_PATH); \
	cd $(GRUB_PATH) && ./grub-mkimage \
		--verbose \
		--output=$(OUT_PATH)/grubaa64.efi \
		--config=$(PATCHES_PATH)/grub/grub.configfile \
		--format=arm64-efi \
		--directory=grub-core \
		--prefix=/boot/grub \
		$(GRUB_MODULES)

.PHONY: grub-clean
grub-clean:
	if [ -e $(GRUB_PATH)/Makefile ]; then $(MAKE) -C $(GRUB_PATH) clean; fi
	rm -f $(OUT_PATH)/grubaa64.efi

.PHONY: grub-cleaner
grub-cleaner: grub-clean
	if [ -e $(GRUB_PATH)/Makefile ]; then $(MAKE) -C $(GRUB_PATH) distclean; fi
	rm -f $(GRUB_PATH)/configure

################################################################################
# Boot Image
################################################################################
ifeq ($(CFG_NW_CONSOLE_UART),3)
GRUBCFG = $(PATCHES_PATH)/grub/grub_uart3.cfg
else
GRUBCFG = $(PATCHES_PATH)/grub/grub_uart0.cfg
endif

.PHONY: boot-img
boot-img: linux buildroot edk2 grub
	rm -f $(BOOT_IMG)
	mformat -i $(BOOT_IMG) -n 64 -h 255 -T 131072 -v "BOOT IMG" -C ::
	mcopy -i $(BOOT_IMG) $(LINUX_PATH)/arch/arm64/boot/Image ::
	mcopy -i $(BOOT_IMG) $(LINUX_PATH)/arch/arm64/boot/dts/hisilicon/hi6220-hikey.dtb ::
	mmd -i $(BOOT_IMG) ::/EFI
	mmd -i $(BOOT_IMG) ::/EFI/BOOT
	mcopy -i $(BOOT_IMG) $(OUT_PATH)/grubaa64.efi ::/EFI/BOOT/
	mcopy -i $(BOOT_IMG) $(GRUBCFG) ::/EFI/BOOT/grub.cfg
	mcopy -i $(BOOT_IMG) $(ROOT)/out-br/images/rootfs.cpio.gz ::/initrd.img
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
# l-loader
################################################################################
.PHONY: lloader
lloader: arm-tf atf-fb
	cd $(LLOADER_PATH) && \
		ln -sf $(ARM_TF_PATH)/build/hikey/$(ARM_TF_BUILD)/bl1.bin && \
		ln -sf $(ARM_TF_PATH)/build/hikey/$(ARM_TF_BUILD)/bl2.bin && \
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
	python $(ROOT)/burn-boot/hisi-idt.py --img1=$(LLOADER_PATH)/recovery.bin
	fastboot flash loader $(LLOADER_PATH)/l-loader.bin
	@echo
	@echo "3. Wait until you see the (UART) message"
	@echo "    \"Enter fastboot mode...\""
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
	fastboot flash ptable $(LLOADER_PATH)/prm_ptable.img
	fastboot flash fastboot $(ARM_TF_PATH)/build/hikey/$(ARM_TF_BUILD)/fip.bin
	fastboot flash nvme $(NVME_IMG)
	fastboot flash boot $(BOOT_IMG)
