################################################################################
# User-defined variables
# Edit so these match your target
# NOTE: If making changes after a build, please clean before rebuilding!
################################################################################
# Non-secure user mode (root fs binaries): 32 or 64-bit [default 64]
NSU ?= 64
# Secure kernel (OP-TEE OS): 32 or 64-bit [default 64]
SK ?= 64
# Secure user mode (Trusted Apps): 32 or 64-bit [default 32, requires SK=64 for 64]
SU ?= 32

# Normal/secure world console UARTs: 3 or 0 [default 3]
CFG_NW_CONSOLE_UART ?= 3
CFG_SW_CONSOLE_UART ?= 3

################################################################################
# Includes
################################################################################
-include common.mk

################################################################################
# Mandatory definition to use common.mk
################################################################################
ifeq ($(SK),32)
ifeq ($(SU),64)
$(error 64-bit secure user mode requires 64-bit secure kernel, i.e. SK=64)
endif
endif

ifeq ($(NSU),64)
CROSS_COMPILE_NS_USER		?= "$(CCACHE)$(AARCH64_CROSS_COMPILE)"
MULTIARCH			:= aarch64-linux-gnu
else
CROSS_COMPILE_NS_USER		?= "$(CCACHE)$(AARCH32_CROSS_COMPILE)"
MULTIARCH			:= arm-linux-gnueabihf
endif
CROSS_COMPILE_NS_KERNEL		?= "$(CCACHE)$(AARCH64_CROSS_COMPILE)"
ifeq ($(SU),64)
CROSS_COMPILE_S_USER		?= "$(CCACHE)$(AARCH64_CROSS_COMPILE)"
else
CROSS_COMPILE_S_USER		?= "$(CCACHE)$(AARCH32_CROSS_COMPILE)"
endif
ifeq ($(SK),64)
CROSS_COMPILE_S_KERNEL		?= "$(CCACHE)$(AARCH64_CROSS_COMPILE)"
else
CROSS_COMPILE_S_KERNEL		?= "$(CCACHE)$(AARCH32_CROSS_COMPILE)"
endif
OPTEE_OS_BIN 			?= $(OPTEE_OS_PATH)/out/arm-plat-hikey/core/tee.bin
OPTEE_OS_TA_DEV_KIT_DIR		?= $(OPTEE_OS_PATH)/out/arm-plat-hikey/export-ta_arm$(SU)

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

MCUIMAGE_BIN			?=$(EDK2_PATH)/HisiPkg/HiKeyPkg/NonFree/mcuimage.bin
STRACE_PATH			?=$(ROOT)/strace
BOOT_IMG			?=$(ROOT)/out/boot-fat.uefi.img
LLOADER_PATH			?=$(ROOT)/l-loader
NVME_IMG			?=$(ROOT)/out/nvme.img
OUT_PATH			?=$(ROOT)/out
GRUB_PATH			?=$(ROOT)/grub
PATCHES_PATH			?=$(ROOT)/patches_hikey
AESPERF_PATH			?=$(ROOT)/aes-perf
SHAPERF_PATH			?=$(ROOT)/sha-perf

################################################################################
# Targets
################################################################################
all: prepare arm-tf boot-img lloader nvme

clean: arm-tf-clean busybox-clean edk2-clean linux-clean optee-os-clean optee-client-clean xtest-clean strace-clean update_rootfs-clean boot-img-clean lloader-clean aes-perf-clean sha-perf-clean grub-clean

cleaner: clean prepare-cleaner busybox-cleaner linux-cleaner strace-cleaner nvme-cleaner grub-cleaner

-include toolchain.mk

prepare:
	@if [ ! -d $(ROOT)/out ]; then mkdir $(ROOT)/out; fi

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
# Busybox
################################################################################
BUSYBOX_COMMON_TARGET = hikey nocpio
BUSYBOX_CLEAN_COMMON_TARGET = hikey clean
ifeq ($(NSU),64)
BUSYBOX_COMMON_CCDIR = $(AARCH64_PATH)
else
BUSYBOX_COMMON_CCDIR = $(AARCH32_PATH)
endif

busybox: busybox-common

.PHONY: busybox-clean
busybox-clean: busybox-clean-common

.PHONY: busybox-cleaner
busybox-cleaner: busybox-clean-common busybox-cleaner-common

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
	GCC49_AARCH64_PREFIX=$(AARCH64_CROSS_COMPILE) \
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
				$(CURDIR)/kconfigs/hikey.conf \
				$(PATCHES_PATH)/kernel_config/usb_net_dm9601.conf \
				$(PATCHES_PATH)/kernel_config/ftrace.conf

linux-defconfig: $(LINUX_PATH)/.config

linux-gen_init_cpio: linux-defconfig
	$(MAKE) -C $(LINUX_PATH)/usr \
		CROSS_COMPILE=$(CROSS_COMPILE_NS_KERNEL) \
		ARCH=arm64 \
		LOCALVERSION= \
		gen_init_cpio

LINUX_COMMON_FLAGS += ARCH=arm64 Image modules
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

ifeq ($(SK),64)
OPTEE_OS_COMMON_FLAGS += CFG_ARM64_core=y
OPTEE_OS_CLEAN_COMMON_FLAGS += CFG_ARM64_core=y
endif

optee-os: optee-os-common

.PHONY: optee-os-clean
optee-os-clean: optee-os-clean-common

optee-client: optee-client-common

.PHONY: optee-client-clean
optee-client-clean: optee-client-clean-common

################################################################################
# xtest / optee_test
################################################################################
ifeq ($(NSU),32)
XTEST_COMMON_FLAGS += CFG_ARM32=y
XTEST_CLEAN_COMMON_FLAGS += CFG_ARM32=y
endif

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
	$(MAKE) -C $(AESPERF_PATH) $(PERF_FLAGS)

.PHONY: aes-perf-clean
aes-perf-clean:
	rm -rf $(AESPERF_PATH)/out

################################################################################
# sha-perf
################################################################################
sha-perf: optee-os optee-client
	$(MAKE) -C $(SHAPERF_PATH) $(PERF_FLAGS)

.PHONY: sha-perf-clean
sha-perf-clean:
	rm -rf $(SHAPERF_PATH)/out

################################################################################
# strace
################################################################################
strace:
	cd $(STRACE_PATH); \
	./bootstrap; \
	set -e; \
	./configure --host=$(MULTIARCH) CC="$(CCACHE)$(AARCH64_CROSS_COMPILE)gcc" LD=$(AARCH64_CROSS_COMPILE)ld; \
	CC="$(CCACHE)$(AARCH64_CROSS_COMPILE)gcc" LD=$(AARCH64_CROSS_COMPILE)ld $(MAKE) -C $(STRACE_PATH)

.PHONY: strace-clean
strace-clean:
	@if [ -e $(STRACE_PATH)/Makefile ]; then $(MAKE) -C $(STRACE_PATH) clean; fi

.PHONY: strace-cleaner
strace-cleaner: strace-clean
	rm -f $(STRACE_PATH)/Makefile $(STRACE_PATH)/configure

################################################################################
# Root FS
################################################################################
# Read stdin, expand ${VAR} environment variables, output to stdout
# http://superuser.com/a/302847
define expand-env-var
awk '{while(match($$0,"[$$]{[^}]*}")) {var=substr($$0,RSTART+2,RLENGTH -3);gsub("[$$]{"var"}",ENVIRON[var])}}1'
endef

filelist-all: busybox
	cat $(GEN_ROOTFS_PATH)/filelist-final.txt | sed '/fbtest/d' > $(GEN_ROOTFS_PATH)/filelist-all.txt
	export KERNEL_VERSION=$(call KERNEL_VERSION); \
	export TOP=$(ROOT); export MULTIARCH=$(MULTIARCH); \
	$(expand-env-var) <$(PATCHES_PATH)/rootfs/initramfs-add-files.txt >> $(GEN_ROOTFS_PATH)/filelist-all.txt; \
	find $(OPTEE_TEST_OUT_PATH) -type f -name "xtest" | sed 's/\(.*\)/file \/bin\/xtest \1 755 0 0/g' >> $(GEN_ROOTFS_PATH)/filelist-all.txt; \
	find $(OPTEE_TEST_OUT_PATH) -name "*.ta" | \
		sed 's/\(.*\)\/\(.*\)/file \/lib\/optee_armtz\/\2 \1\/\2 444 0 0/g' >> $(GEN_ROOTFS_PATH)/filelist-all.txt

update_rootfs: optee-client xtest aes-perf sha-perf strace filelist-all linux-gen_init_cpio
	cd $(GEN_ROOTFS_PATH); \
	        $(LINUX_PATH)/usr/gen_init_cpio $(GEN_ROOTFS_PATH)/filelist-all.txt | gzip > $(GEN_ROOTFS_PATH)/filesystem.cpio.gz

.PHONY: update_rootfs-clean
update_rootfs-clean:
	rm -f $(GEN_ROOTFS_PATH)/filesystem.cpio.gz $(GEN_ROOTFS_PATH)/filelist-all.txt $(GEN_ROOTFS_PATH)/filelist-tmp.txt

################################################################################
# grub
################################################################################
grub-flags := CC="$(CCACHE)gcc" \
	TARGET_CC="$(AARCH64_CROSS_COMPILE)gcc" \
	TARGET_OBJCOPY="$(AARCH64_CROSS_COMPILE)objcopy" \
	TARGET_NM="$(AARCH64_CROSS_COMPILE)nm" \
	TARGET_RANLIB="$(AARCH64_CROSS_COMPILE)ranlib" \
	TARGET_STRIP="$(AARCH64_CROSS_COMPILE)strip"

.PHONY: grub
grub: prepare
	cd $(GRUB_PATH); \
	./autogen.sh; \
	./configure --target=aarch64 --enable-boot-time $(grub-flags); \
	$(MAKE) -C $(GRUB_PATH); \
	./grub-mkimage \
		--verbose \
		--output=$(OUT_PATH)/grubaa64.efi \
		--config=$(PATCHES_PATH)/grub/grub.configfile \
		--format=arm64-efi \
		--directory=grub-core \
		--prefix=/boot/grub \
		boot chain configfile efinet ext2 fat gettext help linux loadenv lsefi normal part_gpt part_msdos read search search_fs_file search_fs_uuid search_label terminal terminfo tftp time

.PHONY: grub-clean
grub-clean:
	@if [ -e $(GRUB_PATH)/Makefile ]; then $(MAKE) -C $(GRUB_PATH) clean; fi
	rm -f $(OUT_PATH)/grubaa64.efi

.PHONY: grub-cleaner
grub-cleaner: grub-clean
	@if [ -e $(GRUB_PATH)/Makefile ]; then $(MAKE) -C $(GRUB_PATH) distclean; fi
	rm -f $(GRUB_PATH)/configure

################################################################################
# Boot Image
################################################################################
LINUX_CONSOLE_UART ?= $(CFG_NW_CONSOLE_UART)
ifeq ($(LINUX_CONSOLE_UART),3)
GRUBCFG = $(PATCHES_PATH)/grub/grub_uart3.cfg
else
GRUBCFG = $(PATCHES_PATH)/grub/grub_uart0.cfg
endif

boot-img: linux update_rootfs edk2 grub
	sudo -p "[sudo] Password:" true
	if [ -d .tmpbootimg ] ; then sudo rm -rf .tmpbootimg ; fi
	mkdir -p .tmpbootimg
	dd if=/dev/zero of=$(BOOT_IMG) bs=512 count=131072 status=none
	sudo mkfs.vfat -n "BOOT IMG" $(BOOT_IMG) >/dev/null
	sudo mount -o loop,rw,sync $(BOOT_IMG) .tmpbootimg
	sudo cp $(LINUX_PATH)/arch/arm64/boot/Image $(DTB) .tmpbootimg/
	sudo mkdir -p .tmpbootimg/EFI/BOOT
	sudo cp $(OUT_PATH)/grubaa64.efi .tmpbootimg/EFI/BOOT/
	sudo cp $(GRUBCFG) .tmpbootimg/EFI/BOOT/grub.cfg
	sudo cp $(GEN_ROOTFS_PATH)/filesystem.cpio.gz .tmpbootimg/initrd.img
	sudo cp $(EDK2_PATH)/Build/HiKey/$(EDK2_BUILD)_GCC49/AARCH64/AndroidFastbootApp.efi .tmpbootimg/EFI/BOOT/fastboot.efi
	# We cannot figure out why we need the sleep here, but from time to time
	# we can see that we get "device/resource busy" when trying to unmount
	# .tmpbootimg below. A short sleep seems to solve the problem and has to
	# be here until we figure out why this happens.
	sleep 3
	sudo umount .tmpbootimg
	sudo rm -rf .tmpbootimg

.PHONY: boot-img-clean
boot-img-clean:
	rm -f $(BOOT_IMG)

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
	wget https://builds.96boards.org/releases/hikey/linaro/binaries/latest/nvme.img -O $(NVME_IMG)

.PHONY: nvme-cleaner
nvme-cleaner:
	rm -f $(NVME_IMG)

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
