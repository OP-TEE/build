-include common.mk

################################################################################
# Mandatory definition to use common.mk
################################################################################
CROSS_COMPILE_NS_USER		?= "$(CCACHE)$(AARCH64_CROSS_COMPILE)"
CROSS_COMPILE_NS_KERNEL		?= "$(CCACHE)$(AARCH64_CROSS_COMPILE)"
CROSS_COMPILE_S_USER		?= "$(CCACHE)$(AARCH32_CROSS_COMPILE)"
CROSS_COMPILE_S_KERNEL		?= "$(CCACHE)$(AARCH64_CROSS_COMPILE)"
OPTEE_OS_BIN 			?= $(OPTEE_OS_PATH)/out/arm-plat-hikey/core/tee.bin
OPTEE_OS_TA_DEV_KIT_DIR		?= $(OPTEE_OS_PATH)/out/arm-plat-hikey/export-user_ta

################################################################################
# Paths to git projects and various binaries
################################################################################
ARM_TF_PATH			?= $(ROOT)/arm-trusted-firmware
ifeq ($(DEBUG),1)
ARM_TF_BUILD			?= debug
else
ARM_TF_BUILD			?= release
# In case user types something like 'make DEBUG=nonsensical ..',
# we default to release build
DEBUG				= 0
endif

EDK2_PATH 			?= $(ROOT)/edk2
ifeq ($(DEBUG),1)
EDK2_BIN 			?= $(EDK2_PATH)/Build/HiKey/DEBUG_GCC49/FV/BL33_AP_UEFI.fd
EDK2_BUILD			?= DEBUG
else
EDK2_BIN 			?= $(EDK2_PATH)/Build/HiKey/RELEASE_GCC49/FV/BL33_AP_UEFI.fd
EDK2_BUILD			?= RELEASE
endif

LINUX_PATH 			?= $(ROOT)/linux
LINUX_CONFIG_ADDLIST		?= $(LINUX_PATH)/kernel.config

GEN_ROOTFS_PATH 		?= $(ROOT)/gen_rootfs
GEN_ROOTFS_FILELIST 		?= $(GEN_ROOTFS_PATH)/filelist-tee.txt

MCUIMAGE_BIN			?=$(ROOT)/out/mcuimage.bin
USBNETSH_PATH			?=$(ROOT)/out/usbnet.sh
STRACE_PATH			?=$(ROOT)/strace
BOOT_IMG			?=$(ROOT)/out/boot-fat.uefi.img
LLOADER_PATH			?=$(ROOT)/l-loader

################################################################################
# Targets
################################################################################
all: mcuimage arm-tf edk2 linux optee-os optee-client optee-linuxdriver xtest strace update_rootfs boot-img lloader

clean: arm-tf-clean busybox-clean edk2-clean linux-clean optee-os-clean optee-client-clean optee-linuxdriver-clean xtest-clean strace-clean update_rootfs_clean boot-img-clean lloader-clean

cleaner: clean mcuimage-cleaner busybox-cleaner linux-cleaner strace-cleaner

-include toolchain.mk

################################################################################
# MCU Image
################################################################################
mcuimage:
	@if [ ! -f "$(MCUIMAGE_BIN)" ]; then \
		mkdir -p `dirname $(MCUIMAGE_BIN)` ; \
		curl https://builds.96boards.org/releases/hikey/linaro/binaries/latest/mcuimage.bin -o $(MCUIMAGE_BIN); \
	fi

mcuimage-cleaner:
	rm -f $(MCUIMAGE_BIN)

################################################################################
# ARM Trusted Firmware
################################################################################
arm-tf: mcuimage optee-os edk2
	CFLAGS="-O0 -gdwarf-2" \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
	BL32=$(OPTEE_OS_BIN) \
	BL33=$(EDK2_BIN) \
	NEED_BL30=yes \
	BL30=$(MCUIMAGE_BIN) \
	make -C $(ARM_TF_PATH) \
	       -j`getconf _NPROCESSORS_ONLN` \
	       DEBUG=$(DEBUG) \
	       PLAT=hikey \
	       SPD=opteed \
	       all fip

arm-tf-clean:
	CFLAGS="-O0 -gdwarf-2" \
        CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
        BL32=$(OPTEE_OS_BIN) \
        BL33=$(EDK2_BIN) \
        NEED_BL30=yes \
        BL30=$(MCUIMAGE_BIN) \
        make -C $(ARM_TF_PATH) \
               -j`getconf _NPROCESSORS_ONLN` \
               DEBUG=$(DEBUG) \
               PLAT=hikey \
               SPD=opteed \
               clean

################################################################################
# Busybox
################################################################################
busybox:
	@if [ ! -d "$(GEN_ROOTFS_PATH)/build" ]; then \
		cd $(GEN_ROOTFS_PATH); \
		CC_DIR=$(AARCH64_PATH) \
		$(GEN_ROOTFS_PATH)/generate-cpio-rootfs.sh hikey nocpio; \
	fi

busybox-clean:
	cd $(GEN_ROOTFS_PATH); \
	$(GEN_ROOTFS_PATH)/generate-cpio-rootfs.sh hikey clean

busybox-cleaner:
	rm -rf $(GEN_ROOTFS_PATH)/build
	rm -rf $(GEN_ROOTFS_PATH)/filelist-final.txt

################################################################################
# EDK2 / Tianocore
################################################################################
define edk2-call
	GCC49_AARCH64_PREFIX=$(AARCH64_CROSS_COMPILE) \
	$(MAKE) -j1 -C $(EDK2_PATH) \
		-f HisiPkg/HiKeyPkg/Makefile EDK2_ARCH=AARCH64 \
		EDK2_DSC=HisiPkg/HiKeyPkg/HiKey.dsc \
		EDK2_TOOLCHAIN=GCC49 EDK2_BUILD=$(EDK2_BUILD)
endef

edk2: edk2-common

edk2-clean: edk2-clean-common

################################################################################
# Linux kernel
################################################################################
$(LINUX_PATH)/.config:
	echo "# This file is merged with the kernel's default configuration" > $(LINUX_CONFIG_ADDLIST)
	echo "# Disabling BTRFS gets rid of the RAID6 performance tests at boot time." >> $(LINUX_CONFIG_ADDLIST)
	echo "# This shaves off a few seconds." >> $(LINUX_CONFIG_ADDLIST)
	echo "CONFIG_USB_NET_DM9601=y" >> $(LINUX_CONFIG_ADDLIST)
	echo "# CONFIG_BTRFS_FS is not set" >> $(LINUX_CONFIG_ADDLIST)
	echo "" >> $(LINUX_CONFIG_ADDLIST)
	echo "# Enable ftrace as per https://github.com/OP-TEE/optee_os/blob/master/documentation/debug.md#2-ftrace" >> $(LINUX_CONFIG_ADDLIST)
	echo "CONFIG_GENERIC_TRACER=y" >> $(LINUX_CONFIG_ADDLIST)
	echo "CONFIG_FTRACE=y" >> $(LINUX_CONFIG_ADDLIST)
	echo "CONFIG_FUNCTION_TRACER=y" >> $(LINUX_CONFIG_ADDLIST)
	echo "CONFIG_FUNCTION_GRAPH_TRACER=y" >> $(LINUX_CONFIG_ADDLIST)
	echo "CONFIG_FTRACE_SYSCALLS=y" >> $(LINUX_CONFIG_ADDLIST)
	echo "CONFIG_BRANCH_PROFILE_NONE=y" >> $(LINUX_CONFIG_ADDLIST)
	echo "CONFIG_STACK_TRACER=y" >> $(LINUX_CONFIG_ADDLIST)
	echo "CONFIG_DYNAMIC_FTRACE=y" >> $(LINUX_CONFIG_ADDLIST)
	echo "CONFIG_FUNCTION_PROFILER=y" >> $(LINUX_CONFIG_ADDLIST)
	echo "CONFIG_FTRACE_MCOUNT_RECORD=y" >> $(LINUX_CONFIG_ADDLIST)
	cd $(LINUX_PATH); \
	LOCALVERSION= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
	ARCH=arm64 scripts/kconfig/merge_config.sh \
    		arch/arm64/configs/defconfig $(LINUX_CONFIG_ADDLIST);

linux-defconfig: $(LINUX_PATH)/.config

linux-gen_init_cpio: linux-defconfig
	make -C $(LINUX_PATH)/usr \
		CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
		ARCH=arm64 \
		LOCALVERSION= \
		gen_init_cpio

linux: linux-defconfig
	make -C $(LINUX_PATH) \
		CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
		ARCH=arm64 \
		LOCALVERSION= \
		-j`getconf _NPROCESSORS_ONLN` \
		Image modules dtbs

linux-defconfig-clean:
	@if [ -f "$(LINUX_PATH)/.config" ]; then \
		rm $(LINUX_PATH)/.config; \
	fi
	@if [ -f "$(LINUX_CONFIG_ADDLIST)" ]; then \
		rm $(LINUX_CONFIG_ADDLIST); \
	fi

linux-clean: linux-defconfig-clean
	make -C $(LINUX_PATH) \
		CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
		ARCH=arm64 \
		LOCALVERSION= \
		-j`getconf _NPROCESSORS_ONLN` \
		clean

linux-cleaner: linux-defconfig-clean
	make -C $(LINUX_PATH) \
		CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
		ARCH=arm64 \
		LOCALVERSION= \
		-j`getconf _NPROCESSORS_ONLN` \
		distclean

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += PLATFORM=hikey CFG_ARM64_core=y
optee-os: optee-os-common

OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=hikey CFG_ARM64_core=y
optee-os-clean: optee-os-clean-common

optee-client: optee-client-common

optee-client-clean: optee-client-clean-common

OPTEE_LINUXDRIVER_COMMON_FLAGS += ARCH=arm64
optee-linuxdriver: optee-linuxdriver-common

OPTEE_LINUXDRIVER_CLEAN_COMMON_FLAGS += ARCH=arm64
optee-linuxdriver-clean: optee-linuxdriver-clean-common

################################################################################
# xtest / optee_test
################################################################################
xtest: xtest-common
xtest-clean: xtest-clean-common
xtest-patch: xtest-patch-common

################################################################################
# strace
################################################################################
strace:
	@if [ ! -f $(STRACE_PATH)/strace ]; then \
		cd $(STRACE_PATH); \
		./bootstrap; \
		./configure --host=aarch64-linux-gnu CC="$(CCACHE)$(AARCH64_CROSS_COMPILE)gcc" LD=$(AARCH64_CROSS_COMPILE)ld; \
		CC="$(CCACHE)$(AARCH64_CROSS_COMPILE)gcc" LD=$(AARCH64_CROSS_COMPILE)ld \
			make -C $(STRACE_PATH); \
	fi

strace-clean:
	@if [ -f $(STRACE_PATH)/strace ]; then \
		CC="$(CCACHE)$(AARCH64_CROSS_COMPILE)gcc" LD=$(AARCH64_CROSS_COMPILE)ld \
			make -C $(STRACE_PATH) clean; \
	fi

strace-cleaner:
	rm -f $(STRACE_PATH)/Makefile $(STRACE_PATH)/configure

################################################################################
# Root FS
################################################################################
.PHONY: filelist-tee
filelist-tee: xtest strace
	@if [ ! -f "$(USBNETSH_PATH)" ]; then \
		echo "#!/bin/sh" > $(USBNETSH_PATH); \
		echo "#" >> $(USBNETSH_PATH); \
		echo "# Script to bring eth0 up and start DHCP client" >> $(USBNETSH_PATH); \
		echo "# Run it after plugging a USB ethernet adapter, for instance" >> $(USBNETSH_PATH); \
		echo "" >> $(USBNETSH_PATH); \
		echo "ip link set eth0 up" >> $(USBNETSH_PATH); \
		echo "udhcpc -i eth0 -s /etc/udhcp/simple.script" >> $(USBNETSH_PATH); \
	fi

	@echo "# Files to add to filesystem.cpio.gz" > $(GEN_ROOTFS_FILELIST)
	@echo "# Syntax: same as gen_rootfs/filelist.txt" >> $(GEN_ROOTFS_FILELIST)
	@echo "" >> $(GEN_ROOTFS_FILELIST)

	@echo "# Script called by udhcpc (DHCP client) to update the network configuration" >> $(GEN_ROOTFS_FILELIST)
	@echo "dir /etc/udhcp 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "file /etc/udhcp/simple.script $(GEN_ROOTFS_PATH)/busybox/examples/udhcp/simple.script 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "" >> $(GEN_ROOTFS_FILELIST)

	@echo "# Run this manually after plugging a USB to ethernet adapter" >> $(GEN_ROOTFS_FILELIST)
	@echo "file /usbnet.sh $(USBNETSH_PATH) 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "" >> $(GEN_ROOTFS_FILELIST)

	@echo "# xtest / optee_test" >> $(GEN_ROOTFS_FILELIST)
	@find $(OPTEE_TEST_OUT_PATH) -type f -name "xtest" | sed 's/\(.*\)/file \/bin\/xtest \1 755 0 0/g' >> $(GEN_ROOTFS_FILELIST)
	@echo "" >> $(GEN_ROOTFS_FILELIST)

	@echo "# TAs" >> $(GEN_ROOTFS_FILELIST)
	@echo "dir /lib/optee_armtz 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@find $(OPTEE_TEST_OUT_PATH) -name "*.ta" | \
		sed 's/\(.*\)\/\(.*\)/file \/lib\/optee_armtz\/\2 \1\/\2 444 0 0/g' >> $(GEN_ROOTFS_FILELIST)
	@echo "" >> $(GEN_ROOTFS_FILELIST)

	@echo "# Secure storage dig" >> $(GEN_ROOTFS_FILELIST)
	@echo "dir /data 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "dir /data/tee 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "" >> $(GEN_ROOTFS_FILELIST)

	@echo "# OP-TEE device" >> $(GEN_ROOTFS_FILELIST)
	@echo "dir /lib/modules 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "dir /lib/modules/$(call KERNEL_VERSION) 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "file /lib/modules/$(call KERNEL_VERSION)/optee.ko $(OPTEE_LINUXDRIVER_PATH)/core/optee.ko 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "file /lib/modules/$(call KERNEL_VERSION)/optee_armtz.ko $(OPTEE_LINUXDRIVER_PATH)/armtz/optee_armtz.ko 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "" >> $(GEN_ROOTFS_FILELIST)

	@echo "# OP-TEE Client" >> $(GEN_ROOTFS_FILELIST)
	@echo "file /bin/tee-supplicant $(OPTEE_CLIENT_EXPORT)/bin/tee-supplicant 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "dir /lib/aarch64-linux-gnu 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "file /lib/aarch64-linux-gnu/libteec.so.1.0 $(OPTEE_CLIENT_EXPORT)/lib/libteec.so.1.0 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "slink /lib/aarch64-linux-gnu/libteec.so.1 libteec.so.1.0 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "slink /lib/aarch64-linux-gnu/libteec.so libteec.so.1 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "" >> $(GEN_ROOTFS_FILELIST)

	@echo "# strace tool" >> $(GEN_ROOTFS_FILELIST)
	@echo "file /bin/strace $(STRACE_PATH)/strace 755 0 0" >> $(GEN_ROOTFS_FILELIST)

update_rootfs: busybox optee-client optee-linuxdriver filelist-tee linux-gen_init_cpio
	cat $(GEN_ROOTFS_PATH)/filelist-final.txt | sed '/fbtest/d' > $(GEN_ROOTFS_PATH)/filelist-all.txt
	cat $(GEN_ROOTFS_PATH)/filelist-all.txt $(GEN_ROOTFS_PATH)/filelist-tee.txt > $(GEN_ROOTFS_PATH)/filelist.tmp
	cd $(GEN_ROOTFS_PATH); \
	        $(LINUX_PATH)/usr/gen_init_cpio $(GEN_ROOTFS_PATH)/filelist.tmp | gzip > $(GEN_ROOTFS_PATH)/filesystem.cpio.gz

update_rootfs_clean:
	cd $(GEN_ROOTFS_PATH); \
	rm -f $(GEN_ROOTFS_PATH)/filesystem.cpio.gz $(GEN_ROOTFS_PATH)/filelist.tmp $(GEN_ROOTFS_PATH)/filelist-tee.txt $(GEN_ROOTFS_PATH)/filelist-all.txt; \
	if [ -f "$(USBNETSH_PATH)" ]; then rm $(USBNETSH_PATH); fi;

################################################################################
# Boot Image
################################################################################
boot-img: linux update_rootfs
	sudo -p "[sudo] Password:" true
	if [ -d .tmpbootimg ] ; then sudo rm -rf .tmpbootimg ; fi
	mkdir -p .tmpbootimg
	dd if=/dev/zero of=$(BOOT_IMG) bs=512 count=131072 status=none
	sudo mkfs.fat -n "BOOT IMG" $(BOOT_IMG) >/dev/null
	sudo mount -o loop,rw,sync $(BOOT_IMG) .tmpbootimg
	sudo cp $(LINUX_PATH)/arch/arm64/boot/Image $(LINUX_PATH)/arch/arm64/boot/dts/hi6220-hikey.dtb .tmpbootimg/
	sudo cp $(GEN_ROOTFS_PATH)/filesystem.cpio.gz .tmpbootimg/initrd.img
	sudo cp $(EDK2_PATH)/Build/HiKey/$(EDK2_BUILD)_GCC49/AARCH64/AndroidFastbootApp.efi .tmpbootimg/fastboot.efi
	sudo umount .tmpbootimg
	sudo rm -rf .tmpbootimg

boot-img-clean:
	rm -f $(BOOT_IMG)

################################################################################
# l-loader
################################################################################
lloader: arm-tf
	if [ ! -h "$(LLOADER_PATH)/bl1.bin" ]; then \
		ln -s $(ARM_TF_PATH)/build/hikey/$(ARM_TF_BUILD)/bl1.bin $(LLOADER_PATH)/bl1.bin; \
	fi
	make -C $(LLOADER_PATH) BL1=$(ARM_TF_PATH)/build/hikey/$(ARM_TF_BUILD)/bl1.bin CROSS_COMPILE="$(CCACHE)$(AARCH32_CROSS_COMPILE)"

lloader-clean:
	if [ -h "$(LLOADER_PATH)/bl1.bin" ]; then \
		unlink $(LLOADER_PATH)/bl1.bin; \
	fi
	make -C $(LLOADER_PATH) clean;
	if [ -f "$(LLOADER_PATH)/ptable.img" ]; then \
		rm -f $(LLOADER_PATH)/ptable.img; \
		rm -f $(LLOADER_PATH)/prm_ptable.img; \
		rm -f $(LLOADER_PATH)/sec_ptable.img; \
	fi
	if [ -f "$(LLOADER_PATH)/l-loader" ]; then \
		rm -f $(LLOADER_PATH)/l-loader; \
		rm -f $(LLOADER_PATH)/temp.bin; \
		rm -f $(LLOADER_PATH)/temp; \
	fi
