BASH := $(shell which bash)
ROOT ?= $(subst /build/,,$(shell pwd)/)

################################################################################
# Paths to git projects and various binaries
################################################################################
LINUX_PATH 			?= $(ROOT)/linux
LINUX_PATCH_PATH 		?= $(ROOT)/patches-upstream

OPTEE_OS_PATH 			?= $(ROOT)/optee_os
OPTEE_OS_BIN 			?= $(OPTEE_OS_PATH)/out/arm-plat-mediatek/core/tee-pager.bin

OPTEE_CLIENT_PATH 		?= $(ROOT)/optee_client
OPTEE_CLIENT_EXPORT		?= $(OPTEE_CLIENT_PATH)/out/export
OPTEE_LINUXDRIVER_PATH 		?= $(ROOT)/optee_linuxdriver

OPTEE_TEST_PATH 		?= $(ROOT)/optee_test
OPTEE_TEST_OUT_PATH 		?= $(ROOT)/out/optee_test

GEN_ROOTFS_PATH 		?= $(ROOT)/gen_rootfs
GEN_ROOTFS_FILELIST 		?= $(GEN_ROOTFS_PATH)/filelist-tee.txt

MTK_TOOLS_PATH 			?= $(ROOT)/mtk_tools

################################################################################
# defines, macros, configuration etc
################################################################################
define KERNEL_VERSION
$(shell cd $(LINUX_PATH) && make kernelversion)
endef

CCACHE ?= $(shell which ccache) # Don't remove this comment (space is needed)

################################################################################
# Targets
################################################################################
all: linux optee-os optee-client optee-linuxdriver xtest
all-clean: busybox-clean optee-os-clean \
	optee-client-clean optee-linuxdriver-clean


-include toolchain.mk

################################################################################
# Busybox
################################################################################
busybox:
	@if [ ! -d "$(GEN_ROOTFS_PATH)/build" ]; then \
		cd $(GEN_ROOTFS_PATH); \
		CC_DIR=$(AARCH64_PATH) \
		PATH=${PATH}:$(LINUX_PATH)/usr \
		$(GEN_ROOTFS_PATH)/generate-cpio-rootfs.sh mt8173-evb; \
	fi

busybox-clean:
	cd $(GEN_ROOTFS_PATH); \
		$(GEN_ROOTFS_PATH)/generate-cpio-rootfs.sh mt8173-evb clean

################################################################################
# Linux kernel
################################################################################
.ONESHELL:
$(LINUX_PATCH_PATH)/.patched:
	cd $(LINUX_PATH); \
		$(LINUX_PATCH_PATH)/patch-all.sh
	touch $@

$(LINUX_PATH)/.config:
	# Temporary fix until we have the driver integrated in the kernel
	sed -i '/config ARM64$$/a select DMA_SHARED_BUFFER' $(LINUX_PATH)/arch/arm64/Kconfig;
	make -C $(LINUX_PATH) ARCH=arm64 defconfig

linux-defconfig: $(LINUX_PATH)/.config
linux-patched: $(LINUX_PATCH_PATH)/.patched

linux: linux-defconfig linux-patched
	make -C $(LINUX_PATH) \
		CROSS_COMPILE="$(CCACHE)$(AARCH64_NONE_CROSS_COMPILE)" \
		LOCALVERSION= \
		ARCH=arm64 \
		-j`getconf _NPROCESSORS_ONLN`

################################################################################
# OP-TEE
################################################################################
optee-os:
	make -C $(OPTEE_OS_PATH) \
		CROSS_COMPILE="$(CCACHE)$(AARCH32_CROSS_COMPILE)" \
		CROSS_COMPILE_core="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
		CFG_ARM64_core=y \
		PLATFORM=mediatek \
		PLATFORM_FLAVOR=mt8173 \
		CFG_TEE_CORE_LOG_LEVEL=4 \
		DEBUG=0 \
		-j`getconf _NPROCESSORS_ONLN`

optee-os-clean:
	make -C $(OPTEE_OS_PATH) \
		PLATFORM=mediatek \
		PLATFORM_FLAVOR=mt8173 \
		clean

optee-client:
	make -C $(OPTEE_CLIENT_PATH) \
		CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
		-j`getconf _NPROCESSORS_ONLN`

optee-client-clean:
	make -C $(OPTEE_CLIENT_PATH) clean

optee-linuxdriver: linux
	make -C $(LINUX_PATH) \
		V=0 \
		ARCH=arm64 \
		CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
		LOCALVERSION= \
		M=$(OPTEE_LINUXDRIVER_PATH) modules

optee-linuxdriver-clean:
	make -C $(LINUX_PATH) \
		M=$(OPTEE_LINUXDRIVER_PATH) clean

################################################################################
# xtest / optee_test
################################################################################
xtest: optee-os optee-client
	@if [ -d "$(OPTEE_TEST_PATH)" ]; then \
		make -C $(OPTEE_TEST_PATH) \
		-j`getconf _NPROCESSORS_ONLN` \
		CROSS_COMPILE_HOST="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
		CROSS_COMPILE_TA="$(CCACHE)$(AARCH32_CROSS_COMPILE)" \
		TA_DEV_KIT_DIR=$(OPTEE_OS_PATH)/out/arm-plat-mediatek/export-user_ta \
		O=$(OPTEE_TEST_OUT_PATH); \
	fi

xtest-clean:
	@if [ -d "$(OPTEE_TEST_PATH)" ]; then \
		rm -rf $(OPTEE_TEST_OUT_PATH); \
	fi

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
# Image Tools
################################################################################
.PHONY: build_image flash_image run
build-image: update_rootfs optee-os
	cd $(MTK_TOOLS_PATH); \
	./build_trustzone.sh $(OPTEE_OS_BIN); \
	./build_bootimg.sh $(LINUX_PATH) $(GEN_ROOTFS_PATH)/filesystem.cpio.gz

flash-image: build-image
	@echo "Please press reset button ..."
	@cd $(MTK_TOOLS_PATH); \
	./fastboot flash boot ./boot.img; \
	./fastboot flash TEE1 ./trustzone.bin
	@echo "Please press reset button again..."

run: flash-image
