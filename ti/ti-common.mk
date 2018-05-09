###############################################################################
# Targets
###############################################################################
.PHONY: all clean cleaner prepare

all: u-boot linux optee-os build-fit buildroot
clean: linux-clean u-boot-clean optee-os-clean build-fit-clean buildroot-clean
cleaner: clean prepare-cleaner busybox-cleaner linux-cleaner

include toolchain.mk

prepare:
	@if [ ! -d $(STAGING_AREA) ]; then mkdir -p $(STAGING_AREA); fi

.PHONY: prepare-cleaner
prepare-cleaner:
	rm -r $(STAGING_AREA)

###############################################################################
# Das U-Boot
###############################################################################
.PHONY: u-boot u-boot-clean

U-BOOT_EXPORTS ?= CROSS_COMPILE=$(CROSS_COMPILE_NS_KERNEL) ARCH=arm

u-boot:
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) $(U-BOOT_CONFIG)
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) all

u-boot-clean:
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean

###############################################################################
# Linux kernel
###############################################################################
.PHONY: linux-defconfig linux linux-defconfig-clean linux-clean linux-cleaner

linux-defconfig:
	cd $(LINUX_PATH) && \
		ti_config_fragments/defconfig_builder.sh -t $(CONFIG_TYPE)
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS) $(CONFIG_TYPE)_defconfig

LINUX_COMMON_FLAGS += ARCH=arm
linux: linux-common
linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm
linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm
linux-cleaner: linux-cleaner-common

###############################################################################
# OP-TEE
###############################################################################
.PHONY: optee-os optee-os-clean optee-client optee-client-clean

OPTEE_OS_COMMON_FLAGS += PLATFORM=$(OPTEE_PLATFORM)
optee-os: optee-os-common

OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=$(OPTEE_PLATFORM)
optee-os-clean: optee-os-clean-common

optee-client: optee-client-common
optee-client-clean: optee-client-clean-common

###############################################################################
# Build FIT
###############################################################################
.PHONY: build-fit build-fit-clean

build-fit: prepare linux optee-os
	cp $(LINUX_IMAGE) $(STAGING_AREA)/
	cp $(LINUX_DTBS) $(STAGING_AREA)/
	cp $(OPTEE_OS_BIN) $(STAGING_AREA)/
	cp $(FIT_SOURCE) $(STAGING_AREA)/fitImage.its
	cp $(FIT_MAKEFILE) $(STAGING_AREA)/
	MKIMAGE=$(U-BOOT_PATH)/tools/mkimage $(MAKE) -C $(STAGING_AREA)

build-fit-clean:
	$(RM) $(STAGING_AREA)/Makefile
	$(RM) $(STAGING_AREA)/fitImage.its
	$(RM) $(STAGING_AREA)/tee.bin
	$(RM) $(STAGING_AREA)/*.dtb
	$(RM) $(STAGING_AREA)/zImage

###############################################################################
# Root FS
###############################################################################
.PHONY: update_rootfs
# Make sure this is built before the buildroot target which will create the
# root file system based on what's in $(BUILDROOT_TARGET_ROOT)
buildroot: update_rootfs

update_rootfs: u-boot build-fit
	@mkdir -p --mode=755 $(BUILDROOT_TARGET_ROOT)/boot
	@install -v -p --mode=644 $(UBOOT_SPL) $(BUILDROOT_TARGET_ROOT)/boot/MLO
	@install -v -p --mode=644 $(UBOOT_IMG) \
		$(BUILDROOT_TARGET_ROOT)/boot/u-boot.img
	@install -v -p --mode=644 $(STAGING_AREA)/fitImage \
		$(BUILDROOT_TARGET_ROOT)/boot/fitImage
