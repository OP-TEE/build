################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
COMPILE_NS_USER   ?= 64
override COMPILE_NS_KERNEL := 64
COMPILE_S_USER    ?= 32
COMPILE_S_KERNEL  ?= 64

# Normal and secure world console UART: 6 (v2 or newer board) or 5 (v1 board)
CFG_CONSOLE_UART ?= 6
# Needed by buildroot
CFG_NW_CONSOLE_UART ?= $(CFG_CONSOLE_UART)

################################################################################
# Includes
################################################################################
include common.mk

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
EDK2_BUILD			?= DEBUG
else
EDK2_BUILD			?= RELEASE
endif
EDK2_BIN			?= $(EDK2_PATH)/Build/HiKey960/$(EDK2_BUILD)_$(EDK2_TOOLCHAIN)/FV/BL33_AP_UEFI.fd
OPENPLATPKG_PATH		?= $(ROOT)/OpenPlatformPkg

OUT_PATH			?=$(ROOT)/out
MCUIMAGE_BIN			?= $(OPENPLATPKG_PATH)/Platforms/Hisilicon/HiKey960/Binary/lpm3.img
BOOT_IMG			?=$(ROOT)/out/boot-fat.uefi.img
GRUB_PATH			?=$(ROOT)/grub
LLOADER_PATH			?=$(ROOT)/l-loader
IMAGE_TOOLS_PATH		?=$(ROOT)/tools-images-hikey960
IMAGE_TOOLS_CONFIG		?=$(OUT_PATH)/config
PATCHES_PATH			?=$(ROOT)/patches_hikey
STRACE_PATH			?=$(ROOT)/strace

################################################################################
# Targets
################################################################################
.PHONY: all
all: arm-tf boot-img lloader

.PHONY: clean
clean: arm-tf-clean buildroot-clean edk2-clean linux-clean optee-os-clean \
		boot-img-clean lloader-clean grub-clean

.PHONY: cleaner
cleaner: clean prepare-cleaner buildroot-cleaner linux-cleaner grub-cleaner

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
	PLAT=hikey960 \
	SPD=opteed

ifeq ($(CFG_CONSOLE_UART),5)
	ARM_TF_FLAGS += CRASH_CONSOLE_BASE=PL011_UART5_BASE
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
EDK2_DSC ?= OpenPlatformPkg/Platforms/Hisilicon/HiKey960/HiKey960.dsc
EDK2_TOOLCHAIN ?= GCC49

ifeq ($(CFG_CONSOLE_UART),5)
	EDK2_BUILDFLAGS += -DSERIAL_BASE=0xFDF05000
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
				$(CURDIR)/kconfigs/hikey960.conf \
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

LINUX_COMMON_FLAGS += ARCH=arm64 Image modules hisilicon/hi3660-hikey960.dtb

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
OPTEE_OS_COMMON_FLAGS += PLATFORM=hikey-hikey960 \
			CFG_CONSOLE_UART=$(CFG_CONSOLE_UART) \
			CFG_SECURE_DATA_PATH=n
OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=hikey-hikey960

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

GRUB_MODULES += boot chain configfile echo efinet eval ext2 fat font gettext \
                gfxterm gzio help linux loadenv lsefi normal part_gpt \
                part_msdos read regexp search search_fs_file search_fs_uuid \
                search_label terminal terminfo test tftp time

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
ifeq ($(CFG_CONSOLE_UART),6)
GRUBCFG = $(PATCHES_PATH)/grub/grub_uart6.cfg
else
GRUBCFG = $(PATCHES_PATH)/grub/grub_uart5.cfg
endif

.PHONY: boot-img
boot-img: linux buildroot edk2 grub
	rm -f $(BOOT_IMG)
	mformat -i $(BOOT_IMG) -n 64 -h 255 -T 131072 -v "BOOT IMG" -C ::
	mcopy -i $(BOOT_IMG) $(LINUX_PATH)/arch/arm64/boot/Image ::
	mcopy -i $(BOOT_IMG) $(LINUX_PATH)/arch/arm64/boot/dts/hisilicon/hi3660-hikey960.dtb ::
	mmd -i $(BOOT_IMG) ::/EFI
	mmd -i $(BOOT_IMG) ::/EFI/BOOT
	mcopy -i $(BOOT_IMG) $(OUT_PATH)/grubaa64.efi ::/EFI/BOOT/
	mcopy -i $(BOOT_IMG) $(GRUBCFG) ::/EFI/BOOT/grub.cfg
	mcopy -i $(BOOT_IMG) $(ROOT)/out-br/images/rootfs.cpio.gz ::/initrd.img
	mcopy -i $(BOOT_IMG) $(EDK2_PATH)/Build/HiKey960/$(EDK2_BUILD)_$(EDK2_TOOLCHAIN)/$(EDK2_ARCH)/AndroidFastbootApp.efi ::/EFI/BOOT/fastboot.efi

.PHONY: boot-img-clean
boot-img-clean:
	rm -f $(BOOT_IMG)

################################################################################
# l-loader
################################################################################
.PHONY: lloader
lloader: arm-tf edk2
	cd $(LLOADER_PATH) && \
		ln -sf $(ARM_TF_PATH)/build/hikey960/$(ARM_TF_BUILD)/bl1.bin && \
		ln -sf $(ARM_TF_PATH)/build/hikey960/$(ARM_TF_BUILD)/bl2.bin && \
		ln -sf $(EDK2_BIN) && \
		$(MAKE) hikey960 PTABLE_LST=linux-32g

.PHONY: lloader-clean
lloader-clean:
	$(MAKE) -C $(LLOADER_PATH) hikey960-clean

################################################################################
# Flash
################################################################################
define flash_help
	@read -r -p "Connect HiKey960 to power up (press enter)" dummy
	@read -r -p "Connect USB OTG cable, the micro USB cable (press enter)" dummy
endef

.PHONY: recov_cfg
recov_cfg:
	@echo "./hisi-sec_usb_xloader.img 0x00020000" > $(IMAGE_TOOLS_CONFIG)
	@echo "./hisi-sec_uce_boot.img 0x6A908000" >> $(IMAGE_TOOLS_CONFIG)
	@echo "./recovery.bin 0x1AC00000" >> $(IMAGE_TOOLS_CONFIG)

.PHONY: recovery
recovery: recov_cfg
	@echo "Enter recovery mode to flash a new bootloader"
	@echo
	@echo "Make sure udev permissions are set appropriately:"
	@echo "  # /etc/udev/rules.d/hikey960.rules"
	@echo '  SUBSYSTEM=="usb", ATTRS{idVendor}=="18d1", ATTRS{idProduct}=="d00d", MODE="0666"'
	@echo '  SUBSYSTEM=="usb", ATTRS{idVendor}=="12d1", MODE="0666", ENV{ID_MM_DEVICE_IGNORE}="1"'
	@echo
	@echo "Set jumpers or switches as follows:"
	@echo "Jumper 1-2: Closed	or	Switch	1: On"
	@echo "       3-4: Closed	or		2: On"
	@echo "       5-6: Open	or		3: Off"
	@read -r -p "Press enter to continue" dummy
	@echo
	$(call flash_help)
	@echo
	@echo "Check the device node (/dev/ttyUSBx) of the micro USB connection"
	@echo "Note the value x of the device node. Default is 1"
	@read -r -p "Enter the device node. Press enter for /dev/ttyUSB1: " DEV && \
		DEV=$${DEV:-/dev/ttyUSB1} && \
		cd $(IMAGE_TOOLS_PATH) && \
		ln -sf $(LLOADER_PATH)/recovery.bin && \
		sudo ./hikey_idt -c $(IMAGE_TOOLS_CONFIG) -p $$DEV && \
		rm -f $(IMAGE_TOOLS_CONFIG)
	@echo
	@echo "If you see dots starting to appear on the console,"
	@echo "press f ON THE CONSOLE (NOT HERE!) to run fastboot."
	@echo "You have 10 seconds! Go!"
	@echo "If not, fastboot should load automatically."
	@read -r -p "Press enter (HERE) to continue flashing" dummy
	@$(MAKE) --no-print flash FROM_RECOVERY=1

.PHONY: flash
flash:
ifneq ($(FROM_RECOVERY),1)
	@echo "Flash binaries using fastboot"
	@echo
	@echo "Set jumpers or switches as follows:"
	@echo "Jumper 1-2: Closed	or	Switch	1: On"
	@echo "       3-4: Open	or		2: Off"
	@echo "       5-6: Closed	or		3: On"
	@read -r -p "Press enter to continue" dummy
	@echo
	$(call flash_help)
endif
	@echo "Wait until you see the (UART) message"
	@echo "    \"Android Fastboot mode - version x.x.\""
	@echo "     Press RETURN or SPACE key to quit.\""
	@echo "It can take a while for the fastboot device to come up,"
	@echo "so please wait ~10 seconds."
	@read -r -p "Then press enter to continue flashing" dummy
	@echo
	fastboot flash ptable $(LLOADER_PATH)/prm_ptable.img
	fastboot flash xloader $(IMAGE_TOOLS_PATH)/hisi-sec_xloader.img
	fastboot flash fastboot $(LLOADER_PATH)/l-loader.bin
	fastboot flash fip $(ARM_TF_PATH)/build/hikey960/$(ARM_TF_BUILD)/fip.bin
	fastboot flash nvme $(IMAGE_TOOLS_PATH)/hisi-nvme.img
	fastboot flash boot $(BOOT_IMG)
