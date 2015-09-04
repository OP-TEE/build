DEBUG ?= 1

-include common.mk

################################################################################
# Mandatory definition to use common.mk
################################################################################
CROSS_COMPILE_NS_USER	?= "$(CCACHE)$(AARCH64_CROSS_COMPILE)"
CROSS_COMPILE_NS_KERNEL	?= "$(CCACHE)$(AARCH64_CROSS_COMPILE)"
CROSS_COMPILE_S_USER	?= "$(CCACHE)$(AARCH32_CROSS_COMPILE)"
CROSS_COMPILE_S_KERNEL	?= "$(CCACHE)$(AARCH32_CROSS_COMPILE)"
OPTEE_OS_BIN		?= $(OPTEE_OS_PATH)/out/arm-plat-vexpress/core/tee.bin
OPTEE_OS_TA_DEV_KIT_DIR	?= $(OPTEE_OS_PATH)/out/arm-plat-vexpress/export-user_ta

################################################################################
# Paths to git projects and various binaries
################################################################################
ARM_TF_PATH		?= $(ROOT)/arm-trusted-firmware

EDK2_PATH		?= $(ROOT)/edk2
EDK2_BIN		?= $(EDK2_PATH)/Build/ArmVExpress-FVP-AArch64/RELEASE_GCC49/FV/FVP_AARCH64_EFI.fd

GEN_ROOTFS_PATH		?= $(ROOT)/gen_rootfs
GEN_ROOTFS_FILELIST	?= $(GEN_ROOTFS_PATH)/filelist-tee.txt

FOUNDATION_PATH		?= $(ROOT)/Foundation_Platformpkg

################################################################################
# Targets
################################################################################
all: arm-tf edk2 linux optee-os optee-client optee-linuxdriver generate-dtb xtest
all-clean: arm-tf-clean busybox-clean edk2-clean optee-os-clean \
	optee-client-clean optee-linuxdriver-clean


-include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
arm-tf: optee-os edk2
	CFLAGS="-O0 -gdwarf-2" \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_NONE_CROSS_COMPILE)" \
	BL32=$(OPTEE_OS_BIN) \
	BL33=$(EDK2_BIN) \
	make -C $(ARM_TF_PATH) \
	       -j`getconf _NPROCESSORS_ONLN` \
	       DEBUG=0 \
	       FVP_TSP_RAM_LOCATION=tdram \
	       FVP_SHARED_DATA_LOCATION=tdram \
	       PLAT=fvp \
	       SPD=opteed \
	       all fip

arm-tf-clean:
	make -C $(ARM_TF_PATH) clean

################################################################################
# Busybox
################################################################################
busybox:
	@if [ ! -d "$(GEN_ROOTFS_PATH)/build" ]; then \
		cd $(GEN_ROOTFS_PATH); \
		CC_DIR=$(AARCH64_PATH) \
		PATH=${PATH}:$(LINUX_PATH)/usr \
		$(GEN_ROOTFS_PATH)/generate-cpio-rootfs.sh fvp-aarch64; \
	fi

busybox-clean:
	cd $(GEN_ROOTFS_PATH); \
		$(GEN_ROOTFS_PATH)/generate-cpio-rootfs.sh fvp-aarch64 clean

################################################################################
# EDK2 / Tianocore
################################################################################
# Make sure edksetup.sh only will be called once and that we don't rebuild
# BaseTools again and again.
$(EDK2_PATH)/Conf/target.txt:
	cd $(EDK2_PATH); $(BASH) edksetup.sh; \
		make -C $(EDK2_PATH)/BaseTools clean; \
		make -C $(EDK2_PATH)/BaseTools;  \

define edk2-common
	GCC49_AARCH64_PREFIX=$(AARCH64_NONE_CROSS_COMPILE) \
	     make -C $(EDK2_PATH) \
	     -f ArmPlatformPkg/Scripts/Makefile EDK2_ARCH=AARCH64 \
	     EDK2_DSC=ArmPlatformPkg/ArmVExpressPkg/ArmVExpress-FVP-AArch64.dsc \
	     EDK2_TOOLCHAIN=GCC49 EDK2_BUILD=RELEASE \
	     EDK2_MACROS="-n 6 -D ARM_FOUNDATION_FVP=1"
endef

edk2: $(EDK2_PATH)/Conf/target.txt
	$(call edk2-common)

edk2-clean:
	$(call edk2-common) clean
	cd $(EDK2_PATH); \
		make -C BaseTools clean

################################################################################
# Linux kernel
################################################################################
$(LINUX_PATH)/.config:
	# Temporary fix until we have the driver integrated in the kernel
	sed -i '/config ARM64$$/a select DMA_SHARED_BUFFER' $(LINUX_PATH)/arch/arm64/Kconfig;
	make -C $(LINUX_PATH) ARCH=arm64 defconfig

linux-defconfig: $(LINUX_PATH)/.config

linux: linux-defconfig
	make -C $(LINUX_PATH) \
		CROSS_COMPILE="$(CCACHE)$(AARCH64_NONE_CROSS_COMPILE)" \
		LOCALVERSION= \
		ARCH=arm64 \
		-j`getconf _NPROCESSORS_ONLN`

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += PLATFORM=vexpress-fvp
optee-os: optee-os-common

OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=vexpress-fvp
optee-os-clean: optee-os-clean-common

optee-client: optee-client-common

optee-client-clean: optee-client-clean-common

OPTEE_LINUXDRIVER_COMMON_FLAGS += ARCH=arm64
optee-linuxdriver: optee-linuxdriver-common

OPTEE_LINUXDRIVER_CLEAN_COMMON_FLAGS += ARCH=arm64
optee-linuxdriver-clean: optee-linuxdriver-clean-common

generate-dtb:
	$(LINUX_PATH)/scripts/dtc/dtc \
		-O dtb \
		-o $(FOUNDATION_PATH)/fdt.dtb \
		-b 0 \
		-i . $(OPTEE_LINUXDRIVER_PATH)/fdts/fvp-foundation-gicv2-psci.dts

################################################################################
# xtest / optee_test
################################################################################
XTEST_COMMON_FLAGS += CFG_ARM32=y
xtest: xtest-common

XTEST_CLEAN_COMMON_FLAGS += CFG_ARM32=y
xtest-clean: xtest-clean-common

XTEST_PATCH_COMMON_FLAGS += CFG_ARM32=y
xtest-patch: xtest-patch-common

################################################################################
# Root FS
################################################################################
.PHONY: filelist-tee
filelist-tee:
	@echo "# xtest / optee_test" > $(GEN_ROOTFS_FILELIST)
	@find $(OPTEE_TEST_OUT_PATH) -type f -name "xtest" | sed 's/\(.*\)/file \/bin\/xtest \1 755 0 0/g' >> $(GEN_ROOTFS_FILELIST)
	@echo "# TAs" >> $(GEN_ROOTFS_FILELIST)
	@echo "dir /lib/optee_armtz 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@find $(OPTEE_TEST_OUT_PATH) -name "*.ta" | \
		sed 's/\(.*\)\/\(.*\)/file \/lib\/optee_armtz\/\2 \1\/\2 444 0 0/g' >> $(GEN_ROOTFS_FILELIST)
	@echo "# Secure storage dig" >> $(GEN_ROOTFS_FILELIST)
	@echo "dir /data 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "dir /data/tee 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "# OP-TEE device" >> $(GEN_ROOTFS_FILELIST)
	@echo "dir /lib/modules 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "dir /lib/modules/$(call KERNEL_VERSION) 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "file /lib/modules/$(call KERNEL_VERSION)/optee.ko $(OPTEE_LINUXDRIVER_PATH)/core/optee.ko 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "file /lib/modules/$(call KERNEL_VERSION)/optee_armtz.ko $(OPTEE_LINUXDRIVER_PATH)/armtz/optee_armtz.ko 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "# OP-TEE Client" >> $(GEN_ROOTFS_FILELIST)
	@echo "file /bin/tee-supplicant $(OPTEE_CLIENT_EXPORT)/bin/tee-supplicant 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "dir /lib/aarch64-linux-gnu 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "file /lib/aarch64-linux-gnu/libteec.so.1.0 $(OPTEE_CLIENT_EXPORT)/lib/libteec.so.1.0 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "slink /lib/aarch64-linux-gnu/libteec.so.1 libteec.so.1.0 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@echo "slink /lib/aarch64-linux-gnu/libteec.so libteec.so.1 755 0 0" >> $(GEN_ROOTFS_FILELIST)

update_rootfs: busybox optee-client optee-linuxdriver xtest filelist-tee
	cat $(GEN_ROOTFS_PATH)/filelist-final.txt $(GEN_ROOTFS_PATH)/filelist-tee.txt > $(GEN_ROOTFS_PATH)/filelist.tmp
	cd $(GEN_ROOTFS_PATH); \
	        $(LINUX_PATH)/usr/gen_init_cpio $(GEN_ROOTFS_PATH)/filelist.tmp | gzip > $(GEN_ROOTFS_PATH)/filesystem.cpio.gz

################################################################################
# Run targets
################################################################################
# This target enforces updating root fs etc
run: | update_rootfs run-only

run-only:
	@ln -sf $(LINUX_PATH)/arch/arm64/boot/Image $(FOUNDATION_PATH)
	@ln -sf $(GEN_ROOTFS_PATH)/filesystem.cpio.gz $(FOUNDATION_PATH)
	@cd $(FOUNDATION_PATH); \
	$(FOUNDATION_PATH)/models/Linux64_GCC-4.1/Foundation_Platform \
	--cores=4 \
	--secure-memory \
	--visualization \
	--gicv3 \
	--data="$(ARM_TF_PATH)/build/fvp/release/bl1.bin"@0x0 \
	--data="$(ARM_TF_PATH)/build/fvp/release/fip.bin"@0x8000000
