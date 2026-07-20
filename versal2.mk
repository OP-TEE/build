################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER	:= 64
override COMPILE_NS_KERNEL	:= 64
override COMPILE_S_USER		:= 64
override COMPILE_S_KERNEL	:= 64

PLATFORM = AMD Versal Gen 2

# Network support related packages:
BR2_PACKAGE_DHCPCD	?= y
BR2_PACKAGE_ETHTOOL	?= y
BR2_PACKAGE_XINETD	?= y

# SSH Packages :
BR2_PACKAGE_OPENSSH		?= y
BR2_PACKAGE_OPENSSH_SERVER	?= y
BR2_PACKAGE_OPENSSH_KEY_UTILS	?= y

# Openssl binary
BR2_PACKAGE_LIBOPENSSL_BIN	?= y
BR2_PACKAGE_LIBP11	?= y

# Busybox
BR2_PACKAGE_BUSYBOX_WATCHDOG    ?= y

# Target specific
BR2_TARGET_GENERIC_ISSUE	?= "OP-TEE embedded distrib for $(PLATFORM)"
BR2_TARGET_GENERIC_GETTY_PORT   ?= "console"
BR2_TARGET_ROOTFS_EXT2		?= y

# OP-TEE
OPTEE_OS_PLATFORM = versal2
OPTEE_OS_COMMON_EXTRA_FLAGS ?= CFG_PKCS11_TA=y CFG_USER_TA_TARGET_pkcs11=ta_arm64 O=out/arm

################################################################################
# Paths to git projects and various binaries
################################################################################
TF_A_PATH	?= $(ROOT)/arm-trusted-firmware
U-BOOT_PATH	?= $(ROOT)/u-boot-xlnx
LINUX_PATH	?= $(ROOT)/linux-xlnx
BOOTGEN_PATH	?= $(ROOT)/bootgen
QEMU_PATH		?= $(ROOT)/qemu
QEMU_BUILD		?= $(QEMU_PATH)/build
QEMU_DEVICETREES_PATH	?= $(ROOT)/qemu-devicetrees

include common.mk

BINARIES_PATH	?= $(ROOT)/out/bin
TF_A_ELF	?= $(TF_A_PATH)/build/$(OPTEE_OS_PLATFORM)/release/bl31/bl31.elf
OPTEE_OS_RAW_BIN ?= $(OPTEE_OS_PATH)/out/arm/core/tee-raw.bin
U-BOOT_ELF	?= $(U-BOOT_PATH)/u-boot.elf
U-BOOT_DTB	?= $(U-BOOT_PATH)/arch/arm/dts/versal2-*.dtb
MKIMAGE_PATH	?= $(U-BOOT_PATH)/tools
LINUX_IMAGE	?= $(LINUX_PATH)/arch/arm64/boot/Image
ROOTFS_GZ	?= $(ROOT)/out-br/images/rootfs.cpio.gz
ROOTFS_SIGN	?= $(BINARIES_PATH)/rootfs.cpio.gz.u-boot

################################################################################
# Targets
################################################################################

all: tfa optee-os u-boot linux dtbo buildroot buildroot_mkimg bootgen \
     qemu qemu-devicetrees bootimage
run: all
	$(MAKE) run-only
run-only: bootimage run-qemu-direct
clean: tfa-clean optee-os-clean u-boot-clean linux-clean dtbo-clean \
       buildroot-clean bootimage-clean bootgen-clean run-qemu-clean \
       qemu-clean qemu-devicetrees-clean

$(BINARIES_PATH):
	mkdir -p $@

include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################

TF_A_EXPORTS = CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
	       CC="$(CCACHE)$(AARCH64_CROSS_COMPILE)gcc" \
	       LD="$(CCACHE)$(AARCH64_CROSS_COMPILE)ld"

TF_A_FLAGS = PLAT=versal2 CONSOLE=pl011 RESET_TO_BL31=1 SPD=opteed DEBUG=0 \
	     MEM_BASE=0x1600000 MEM_SIZE=0x200000 \
	     XILINX_OF_BOARD_DTB_ADDR=0x1000000 \
	     BL32_MEM_BASE=0x1800000 BL32_MEM_SIZE=0x8000000

tfa:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) bl31
	mkdir -p $(BINARIES_PATH)
	cp $(TF_A_ELF) $(BINARIES_PATH)

tfa-clean:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) clean

################################################################################
# OP-TEE
################################################################################

OPTEE_OS_COMMON_FLAGS += CFG_TEE_CORE_LOG_LEVEL=2 CFG_TEE_TA_LOG_LEVEL=2 \
			 CFG_DT=y

optee-os: optee-os-common
	mkdir -p $(BINARIES_PATH)
	cp $(OPTEE_OS_RAW_BIN) $(BINARIES_PATH)

optee-os-clean: optee-os-clean-common
	rm -rf ${OPTEE_OS_PATH}/out/

################################################################################
# U-Boot
################################################################################

U-BOOT_EXPORTS = CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"
U-BOOT_DEFCONFIG_COMMON_FILES := $(U-BOOT_PATH)/configs/amd_versal2_virt_defconfig \
			$(BUILD_PATH)/kconfigs/u-boot_versal2.conf

u-boot-defconfig: $(U-BOOT_DEFCONFIG_COMMON_FILES)
	cd $(U-BOOT_PATH) && \
                ARCH=arm64 \
                scripts/kconfig/merge_config.sh $(U-BOOT_DEFCONFIG_COMMON_FILES)

u-boot: u-boot-defconfig
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH)
	mkdir -p $(BINARIES_PATH)
	cp $(U-BOOT_ELF) $(BINARIES_PATH)

u-boot-defconfig-clean:
	rm -f $(U-BOOT_PATH)/.config

u-boot-clean: u-boot-defconfig-clean
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean

###############################################################################
# Device-Tree
###############################################################################
dtbo: linux u-boot
	mkdir -p $(BINARIES_PATH)
	${LINUX_PATH}/scripts/dtc/dtc -@ -I dts \
		-O dtb -o $(BINARIES_PATH)/versal2-memory-reservation.dtbo \
		$(BUILD_PATH)/versal2/versal2-memory-reservation.dtso
	@$(foreach dtb,$(wildcard $(U-BOOT_DTB)), \
		${LINUX_PATH}/scripts/dtc/fdtoverlay -i $(dtb) \
		-o $(dtb) $(BINARIES_PATH)/versal2-memory-reservation.dtbo ; \
		echo "Applied overlay to $(dtb)";)
	cp $(U-BOOT_DTB) $(BINARIES_PATH)

dtbo-clean:
	rm -f $(BINARIES_PATH)/versal2-memory-reservation.dtbo

################################################################################
# Linux kernel
################################################################################

LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm64/configs/xilinx_defconfig \
		$(BUILD_PATH)/kconfigs/versal2.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64

linux: linux-common
	mkdir -p $(BINARIES_PATH)
	cp $(LINUX_IMAGE) $(BINARIES_PATH)

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

linux-cleaner: linux-cleaner-common

################################################################################
# Buildroot
################################################################################

buildroot_mkimg: buildroot
	mkdir -p $(BINARIES_PATH)
	$(MKIMAGE_PATH)/mkimage -A arm \
				-T ramdisk \
				-C gzip \
				-d $(ROOTFS_GZ) $(ROOTFS_SIGN)

################################################################################
# Boot Image with Bootgen
################################################################################

bootimage: bootgen tfa optee-os u-boot dtbo
	mkdir -p $(BINARIES_PATH)
	@test -f $(BINARIES_PATH)/bl31.elf || \
		(echo "Error: bl31.elf missing: run 'make tfa'." && exit 1)
	@test -f $(BINARIES_PATH)/tee-raw.bin || \
		(echo "Error: tee-raw.bin missing: run 'make optee-os'." && exit 1)
	@test -f $(BINARIES_PATH)/u-boot.elf || \
		(echo "Error: u-boot.elf missing: run 'make u-boot'." && exit 1)
	@test -f $(BINARIES_PATH)/versal2-vek385-revA.dtb || \
		(echo "Error: versal2-vek385-revA.dtb missing: run 'make dtbo'." && exit 1)
	@test -f $(BOOTGEN_BIN) || \
		(echo "Error: bootgen binary missing: run 'make bootgen'." && exit 1)
	cp $(BUILD_PATH)/versal2/bootgen.bif $(BINARIES_PATH)
	cp $(BUILD_PATH)/versal2/platconfig.pdi $(BINARIES_PATH)
	cp $(BUILD_PATH)/versal2/platconfig.elf $(BINARIES_PATH)
	cd $(BINARIES_PATH) && $(BOOTGEN_BIN) -arch versal_2ve_2vm \
		-padimageheader=0 -log info \
		-image bootgen.bif -w -o $(BINARIES_PATH)/BOOT.BIN
	cp $(BINARIES_PATH)/BOOT.BIN \
		$(BINARIES_PATH)/qemu-ospi.bin
	truncate -s 256M \
		$(BINARIES_PATH)/qemu-ospi.bin
	cd $(BINARIES_PATH) && $(BOOTGEN_BIN) -arch versal_2ve_2vm \
		-dump $(BINARIES_PATH)/BOOT.BIN boot_files

bootimage-clean:
	rm -f $(BINARIES_PATH)/bootgen.bif $(BINARIES_PATH)/platconfig.pdi \
		$(BINARIES_PATH)/platconfig.elf $(BINARIES_PATH)/BOOT.BIN \
		$(BINARIES_PATH)/BOOT_bh.BIN $(BINARIES_PATH)/plm.bin \
		$(BINARIES_PATH)/pmc_cdo.bin $(BINARIES_PATH)/Hashblock0.bin \
		$(BINARIES_PATH)/qemu-ospi.bin

################################################################################
# Bootgen
################################################################################

bootgen:
	$(MAKE) -C $(BOOTGEN_PATH)
	mkdir -p $(BINARIES_PATH)
	cp $(BOOTGEN_PATH)/build/bin/bootgen $(BINARIES_PATH)

bootgen-clean:
	$(MAKE) -C $(BOOTGEN_PATH) clean
	rm -f $(BINARIES_PATH)/bootgen

qemu-devicetrees:
	$(MAKE) -C $(QEMU_DEVICETREES_PATH)

qemu-devicetrees-clean:
	$(MAKE) -C $(QEMU_DEVICETREES_PATH) clean

################################################################################
# QEMU Build
################################################################################

$(QEMU_BUILD)/config-host.mak:
	mkdir -p $(QEMU_BUILD)
	cd $(QEMU_BUILD) && $(QEMU_PATH)/configure \
		--target-list="aarch64-softmmu,microblazeel-softmmu,riscv32-softmmu" \
		--enable-fdt --disable-kvm --disable-xen --enable-gcrypt --enable-slirp

qemu: $(QEMU_BUILD)/.stamp_qemu

$(QEMU_BUILD)/.stamp_qemu: $(QEMU_BUILD)/config-host.mak
	$(MAKE) -C $(QEMU_BUILD)
	touch $@

qemu-clean:
	rm -f $(QEMU_BUILD)/.stamp_qemu
	test -d $(QEMU_BUILD) && $(MAKE) -C $(QEMU_BUILD) distclean || true

################################################################################
# QEMU Run-Only Recipe
################################################################################

# Path definitions for QEMU
QEMU_BINARIES_PATH	:= $(QEMU_BUILD)
DEVICE_TREE_PATH	:= $(QEMU_DEVICETREES_PATH)/LATEST/MULTI_ARCH
BOOT_IMAGES_PATH	:= $(BINARIES_PATH)
BOOTGEN_BIN		:= $(BINARIES_PATH)/bootgen

# QEMU binaries (similar to how qemu_v8.mk defines QEMU_BIN)
QEMU_MICROBLAZE_BIN	= $(QEMU_BINARIES_PATH)/qemu-system-microblazeel
QEMU_RISCV_BIN		= $(QEMU_BINARIES_PATH)/qemu-system-riscv32
QEMU_AARCH64_BIN	= $(QEMU_BINARIES_PATH)/qemu-system-aarch64

# QEMU run recipes
.PHONY: run run-only all clean tfa optee-os u-boot linux \
	qemu qemu-devicetrees bootgen bootimage bootimage-clean \
	bootgen-clean run-qemu-clean

# Individual QEMU target recipes
.PHONY: run-qemu-microblaze
run-qemu-microblaze:
	@echo "=== Starting MicroBlaze PMC QEMU ==="
	@echo "Working directory: $(BOOT_IMAGES_PATH)"
	@echo "Device tree: $(DEVICE_TREE_PATH)/board-versal2-pmxc-virt.dtb"
	@test -f $(QEMU_MICROBLAZE_BIN) || \
		(echo "Error: $(QEMU_MICROBLAZE_BIN) missing: run 'make qemu'." && exit 1)
	@test -f $(DEVICE_TREE_PATH)/board-versal2-pmxc-virt.dtb || \
		(echo "Error: pmxc-virt.dtb missing: run 'make qemu-devicetrees'." && exit 1)
	@test -f $(BOOT_IMAGES_PATH)/BOOT_bh.bin || \
		(echo "Error: BOOT_bh.bin missing: run 'make bootimage'." && exit 1)
	@test -f $(BOOT_IMAGES_PATH)/HashBlock0.bin || \
		(echo "Error: HashBlock0.bin missing: run 'make bootimage'." && exit 1)
	@test -f $(BOOT_IMAGES_PATH)/pmc_cdo.bin || \
		(echo "Error: pmc_cdo.bin missing: run 'make bootimage'." && exit 1)
	@test -f $(BOOT_IMAGES_PATH)/plm.bin || \
		(echo "Error: plm.bin missing: run 'make bootimage'." && exit 1)
	@mkdir -p $(BOOT_IMAGES_PATH)/temp/qemu_temp
	@echo "==================================="
	cd $(BOOT_IMAGES_PATH) && $(QEMU_MICROBLAZE_BIN) -M microblaze-fdt \
		-display none \
		-device loader,addr=0xf0000000,data=0xba020004,data-len=4 \
		-device loader,addr=0xf0000004,data=0xb800fffc,data-len=4 \
		-device loader,addr=0xF1110624,data=0x0,data-len=4 \
		-device loader,addr=0xF1110620,data=0x1,data-len=4 \
		-hw-dtb $(DEVICE_TREE_PATH)/board-versal2-pmxc-virt.dtb \
		-device loader,file=$(BOOT_IMAGES_PATH)/BOOT_bh.bin,addr=0xf201eec0,force-raw=on \
		-device loader,file=$(BOOT_IMAGES_PATH)/HashBlock0.bin,addr=0xf201ecc0 \
		-device loader,file=$(BOOT_IMAGES_PATH)/pmc_cdo.bin,addr=0xf2000000,force-raw=on \
		-device loader,file=$(BOOT_IMAGES_PATH)/plm.bin,addr=0xf0200000,force-raw=on \
		-device loader,addr=0xf0200000,cpu-num=1 \
		-machine-path $(BOOT_IMAGES_PATH)/temp/qemu_temp/

.PHONY: run-qemu-riscv
run-qemu-riscv:
	@echo "=== Starting RISC-V ASU QEMU ==="
	@echo "Working directory: $(BOOT_IMAGES_PATH)"
	@echo "Device tree: $(DEVICE_TREE_PATH)/board-versal2-asu-virt.dtb"
	@test -f $(QEMU_RISCV_BIN) || \
		(echo "Error: $(QEMU_RISCV_BIN) missing: run 'make qemu'." && exit 1)
	@test -f $(DEVICE_TREE_PATH)/board-versal2-asu-virt.dtb || \
		(echo "Error: asu-virt.dtb missing: run 'make qemu-devicetrees'." && exit 1)
	@mkdir -p $(BOOT_IMAGES_PATH)/temp/qemu_temp
	@echo "================================"
	cd $(BOOT_IMAGES_PATH) && $(QEMU_RISCV_BIN) -M riscv-fdt \
		-hw-dtb $(DEVICE_TREE_PATH)/board-versal2-asu-virt.dtb \
		-display none \
		-machine-path $(BOOT_IMAGES_PATH)/temp/qemu_temp/

.PHONY: run-qemu-aarch64
run-qemu-aarch64:
	@echo "=== Starting AArch64 PSXC QEMU ==="
	@echo "Working directory: $(BOOT_IMAGES_PATH)"
	@echo "Device tree: $(DEVICE_TREE_PATH)/board-versal2-psxc-vek385.dtb"
	@test -f $(QEMU_AARCH64_BIN) || \
		(echo "Error: $(QEMU_AARCH64_BIN) missing: run 'make qemu'." && exit 1)
	@test -f $(DEVICE_TREE_PATH)/board-versal2-psxc-vek385.dtb || \
		(echo "Error: psxc-vek385.dtb missing: run 'make qemu-devicetrees'." && exit 1)
	@test -f $(BOOT_IMAGES_PATH)/qemu-ospi.bin || \
		(echo "Error: qemu-ospi.bin missing: run 'make bootimage'." && exit 1)
	@test -f $(BOOT_IMAGES_PATH)/Image || \
		(echo "Error: Image missing: run 'make linux'." && exit 1)
	@test -f $(BOOT_IMAGES_PATH)/rootfs.cpio.gz.u-boot || \
		(echo "Error: rootfs image missing: run 'make buildroot_mkimg'." && exit 1)
	@mkdir -p $(BOOT_IMAGES_PATH)/temp/qemu_temp
	@echo "===================================="
	cd $(BOOT_IMAGES_PATH) && $(QEMU_AARCH64_BIN) -machine arm-generic-fdt -m 8G \
		-nographic \
		-serial null -serial null -serial null -serial mon:stdio -nodefaults \
		-boot mode=8 \
		-drive file=$(BOOT_IMAGES_PATH)/qemu-ospi.bin,if=mtd,format=raw,index=0 \
		-hw-dtb $(DEVICE_TREE_PATH)/board-versal2-psxc-vek385.dtb \
		-device loader,addr=0x21000000,file=$(BOOT_IMAGES_PATH)/Image \
		-device loader,force-raw=on,addr=0x30000000,file=$(BOOT_IMAGES_PATH)/rootfs.cpio.gz.u-boot \
		-machine-path $(BOOT_IMAGES_PATH)/temp/qemu_temp/

# Clean QEMU temporary files
run-qemu-clean:
	@echo "Cleaning QEMU temporary files..."
	@rm -rf $(BINARIES_PATH)/temp/qemu_temp
	@echo "QEMU temporary files cleaned."

# Run all three QEMU instances — MicroBlaze and RISC-V in background,
# AArch64 interactive
.PHONY: run-qemu-direct
run-qemu-direct: bootimage qemu qemu-devicetrees linux buildroot_mkimg
	@mkdir -p $(BOOT_IMAGES_PATH)/temp/qemu_temp
	@echo "Launching MicroBlaze PMC in background (log: $(BOOT_IMAGES_PATH)/mb-pmc.log)..."
	@$(MAKE) run-qemu-microblaze > $(BOOT_IMAGES_PATH)/mb-pmc.log 2>&1 & MB_PID=$$!; \
	 echo "Launching RISC-V ASU in background (log: $(BOOT_IMAGES_PATH)/riscv-asu.log)..."; \
	 $(MAKE) run-qemu-riscv > $(BOOT_IMAGES_PATH)/riscv-asu.log 2>&1 & RV_PID=$$!; \
	 echo "Launching AArch64 PSXC (interactive - Ctrl+a x to exit)..."; \
	 $(MAKE) run-qemu-aarch64; \
	 echo "AArch64 exited. Stopping background QEMU instances..."; \
	 kill $$MB_PID $$RV_PID 2>/dev/null || true; \
	 echo "All QEMU instances stopped."
