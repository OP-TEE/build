################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER    := 64
override COMPILE_S_KERNEL  := 64

# Network support related packages:
BR2_PACKAGE_DHCPCD ?= y
BR2_PACKAGE_ETHTOOL ?= y
BR2_PACKAGE_XINETD ?= y

# SSH Packages :
BR2_PACKAGE_OPENSSH ?= y
BR2_PACKAGE_OPENSSH_SERVER ?= y
BR2_PACKAGE_OPENSSH_KEY_UTILS ?= y

# Openssl binary
BR2_PACKAGE_LIBOPENSSL_BIN ?= y

PLATFORM ?= versal-vck190

VERSAL_UART1 ?=
VERSAL_UART2ND_OPTEE ?=

ifneq ($(filter versal-net%,$(PLATFORM)),)
OPTEE_OS_PLATFORM = versal-net
else
OPTEE_OS_PLATFORM = versal
endif

OPTEE_OS_COMMON_EXTRA_FLAGS = CFG_PKCS11_TA=y CFG_USER_TA_TARGET_pkcs11=ta_arm64 O=out/arm
ifeq ($(VERSAL_UART2ND_OPTEE),y)
ifneq ($(VERSAL_UART1),y)
OPTEE_OS_COMMON_EXTRA_FLAGS += CFG_VERSAL_UART1=y
endif
else
ifeq ($(VERSAL_UART1),y)
OPTEE_OS_COMMON_EXTRA_FLAGS += CFG_VERSAL_UART1=y
endif
endif

TF_A_PLAT = $(subst -,_,$(OPTEE_OS_PLATFORM))
BOOTGEN_ARCH = $(subst -,,$(OPTEE_OS_PLATFORM))

################################################################################
# Paths to git projects and various binaries
################################################################################
TF_A_PATH		?= $(ROOT)/arm-trusted-firmware
U-BOOT_PATH		?= $(ROOT)/u-boot
BOOTGEN_PATH		?= $(ROOT)/bootgen
LINUX_PATH		?= $(ROOT)/linux

include common.mk

# for Firmware, if available
ifeq ($(EMBEDDEDSW_PATH),)
EMBEDDEDSW_PATH ?= $(wildcard $(ROOT)/embeddedsw)
endif
ifneq ($(EMBEDDEDSW_PATH),)
PLM_APP_PATH := $(EMBEDDEDSW_PATH)/lib/sw_apps/versal_plm
PLM_SRC_PATH := $(PLM_APP_PATH)/src/$(TF_A_PLAT)
PLM_PATH_GEN := $(PLM_SRC_PATH)/plm.elf
PSM_APP_PATH := $(EMBEDDEDSW_PATH)/lib/sw_apps/versal_psmfw
PSM_SRC_PATH := $(PSM_APP_PATH)/src/$(TF_A_PLAT)
PSM_PATH_GEN := $(PSM_SRC_PATH)/psmfw.elf
else
PLM_PATH_GEN :=
PSM_PATH_GEN :=
endif

# for Boot Image(s)
# BSP_PATH: path to PetaLinux project directory and/or extracted BSP
# PLM_PATH: path to PLM firmware .elf file, derived from BSP_PATH if available
# PSM_PATH: path to PSM firmware .elf file, derived from BSP_PATH if available
# DTB_PATH: path to DeviceTree .dtb file, derived from BSP_PATH if available
# IUB_PATH: path to U-Boot FIT image .ub file

ifeq ($(PLATFORM),versal-vck190)
BSP_PATH ?= ../versal-vck190-bsp
endif

ifneq ($(BSP_PATH),)
PDI_PATH ?= $(wildcard $(BSP_PATH)/project-spec/hw-description/*.pdi)
ifneq ($(wildcard $(BSP_PATH)/images/linux),)
PLM_PATH ?= $(wildcard $(BSP_PATH)/images/linux/plm.elf)
PSM_PATH ?= $(wildcard $(BSP_PATH)/images/linux/psmfw.elf)
DTB_PATH ?= $(wildcard $(BSP_PATH)/images/linux/system.dtb)
else
PLM_PATH ?= $(wildcard $(BSP_PATH)/pre-built/linux/images/plm.elf)
PSM_PATH ?= $(wildcard $(BSP_PATH)/pre-built/linux/images/psmfw.elf)
DTB_PATH ?= $(wildcard $(BSP_PATH)/pre-built/linux/images/system.dtb)
endif
endif

ifeq ($(PLATFORM),versal-vck190)
DTB_PATH ?= ../u-boot/arch/arm/dts/versal-vck190-revA-x-ebm-01-revA.dtb
else
ifeq ($(PLATFORM),versal-net-vnx-b2197-revA)
PDI_PATH ?= ../versal-net-bsp/design.pdi
ifneq ($(wildcard ../versal-net-bsp/design.dtb),)
DTB_PATH ?= ../versal-net-bsp/design.dtb
else
#DTB_PATH ?= ../u-boot/arch/arm/dts/versal-net-vn-x-b2197-00-revA.dtb
DTB_PATH ?= ../linux/arch/arm64/boot/dts/xilinx/versal-net-vn-x-b2197-00-revA.dtb
endif
endif
endif

IUB_PATH ?= versal/$(PLATFORM).ub

ifeq ($(OPTEE_OS_PLATFORM),versal-net)
IUB_BIF_LOAD ?= 0x27200000
else
IUB_BIF_LOAD ?= 0x20000000
endif


_PDI_PATH := $(PDI_PATH)
ifeq ($(PLM_PATH),generate)
_PLM_PATH := $(PLM_PATH_GEN)
else
_PLM_PATH := $(PLM_PATH)
endif
ifeq ($(PSM_PATH),generate)
_PSM_PATH := $(PSM_PATH_GEN)
else
_PSM_PATH := $(PSM_PATH)
endif
_DTB_PATH := $(DTB_PATH)
ifeq ($(IUB_BIF_PATH),)
_IUB_BIF_PATH := $(IUB_PATH)
endif
ifeq ($(IUB_BIF_PATH),n)
_IUB_BIF_PATH :=
endif
_IUB_BIF_LOAD := $(IUB_BIF_LOAD)

ifeq ($(_PDI_PATH);$(findstring image,$(MAKECMDGOALS)),;image)
$(error PDI_PATH not set, use make PDI_PATH=<path-to-.pdi>)
endif
ifeq ($(_DTB_PATH);$(findstring image,$(MAKECMDGOALS)),;image)
$(error DTB_PATH not set, use make DTB_PATH=<path-to-.dtb>)
endif

################################################################################
# Targets
################################################################################

all: tfa optee-os u-boot linux dtbo buildroot
clean: tfa-clean optee-os-clean u-boot-clean linux-clean dtbo-clean buildroot-clean

include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################

TF_A_EXPORTS = CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

TF_A_FLAGS = PLAT=$(TF_A_PLAT) RESET_TO_BL31=1 SPD=opteed DEBUG=1
ifeq (${VERSAL_UART1},y)
TF_A_FLAGS += VERSAL_CONSOLE=pl011_1
else
TF_A_FLAGS += VERSAL_CONSOLE=pl011
endif
ifeq ($(OPTEE_OS_PLATFORM),versal-net)
TF_A_FLAGS += VERSAL_NET_ATF_MEM_BASE=0x26200000 VERSAL_NET_ATF_MEM_SIZE=0x100000
endif

tfa:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) bl31

tfa-clean:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) clean

################################################################################
# OP-TEE
#################################################################################

optee-os: optee-os-common

optee-os-clean: optee-os-clean-common

################################################################################
# U-Boot
################################################################################

U-BOOT_EXPORTS = CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"
U-BOOT_CONFIGS = \
	$(UBOOT_PATH)/configs/xilinx_$(TF_A_PLAT)_virt_defconfig \
	$(CURDIR)/kconfigs/u-boot_$(TF_A_PLAT).conf
U-BOOT_BOOTCMD_CONFIG = $(BUILD_PATH)/versal/u-boot_bootcmd.conf
U-BOOT_DTS = xilinx-$(OPTEE_OS_PLATFORM)-virt

$(U-BOOT_BOOTCMD_CONFIG):
	truncate -s0 $@
ifneq ($(_IUB_BIF_PATH),)
	echo 'CONFIG_BOOTCOMMAND="bootm $(_IUB_BIF_LOAD)"' >>$@
	echo 'CONFIG_BOOTDELAY=1' >>$@
endif
.PHONY: $(U-BOOT_BOOTCMD_CONFIG)

U-BOOT_CONFIGS += $(U-BOOT_BOOTCMD_CONFIG)

$(UBOOT_PATH)/.config: $(U-BOOT_CONFIGS)
	cd $(UBOOT_PATH) && \
		$(U-BOOT_EXPORTS) \
		scripts/kconfig/merge_config.sh $(U-BOOT_CONFIGS)

u-boot-defconfig: $(UBOOT_PATH)/.config

u-boot: u-boot-defconfig
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) DEVICE_TREE=$(U-BOOT_DTS) DTC_FLAGS="-@"

u-boot-defconfig-clean:
	rm -f $(UBOOT_PATH)/.config
	rm -f $(U-BOOT_BOOTCMD_CONFIG)

u-boot-clean: u-boot-defconfig-clean
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean

###############################################################################
# Device-Tree
###############################################################################
%.dtbo: %.dtso linux
	${LINUX_PATH}/scripts/dtc/dtc -@ -I dts -O dtb -o $@ $<

DTBO_FILES = versal/versal-optee.dtbo
ifeq ($(OPTEE_OS_PLATFORM),versal)
dtbo: versal/versal-optee-mem.dtbo
endif

dtbo: $(DTBO_FILES)

dtbo-clean:
	rm -f $(DTBO_FILES)

################################################################################
# Linux kernel
################################################################################

LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm64/configs/xilinx_$(TF_A_PLAT)_defconfig \
		$(CURDIR)/kconfigs/versal.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64 -j8

linux: linux-common

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

linux-cleaner: linux-cleaner-common

###############################################################################
# Buildroot
###############################################################################

BR2_TARGET_GENERIC_ISSUE="OP-TEE embedded distrib for $(PLATFORM)"
BR2_TARGET_ROOTFS_EXT2=y
BR2_PACKAGE_BUSYBOX_WATCHDOG=y

# TF-A, Linux kernel, U-Boot and OP-TEE OS/Client/... are not built from their
# related Buildroot native package.
BR2_TARGET_ARM_TRUSTED_FIRMWARE=n
BR2_LINUX_KERNEL=n
BR2_TARGET_OPTEE_OS=n
BR2_TARGET_UBOOT=n
BR2_PACKAGE_OPTEE_CLIENT=n
BR2_PACKAGE_OPTEE_TEST=n
BR2_PACKAGE_OPTEE_EXAMPLES=n
BR2_PACKAGE_OPTEE_BENCHMARK=n


###############################################################################
# Images
###############################################################################
image: bootimage fitimage
image-clean: bootimage-clean fitimage-clean


###############################################################################
# Firmware
###############################################################################

ifneq ($(EMBEDDEDSW_PATH),)

PLM_PARAMS_PATH := $(PLM_APP_PATH)/misc/$(TF_A_PLAT)/xparameters.h
PLM_PARAMS_BAK_PATH := $(PLM_PARAMS_PATH).bak

ifeq ($(OPTEE_OS_PLATFORM),versal)
ifeq (${VERSAL_UART1},y)
PLM_UART_BASEADDR ?= 0xFF010000
else
PLM_UART_BASEADDR ?= 0xFF000000
endif
else
# versal-net
ifeq (${VERSAL_UART1},y)
PLM_UART_BASEADDR ?= 0xF1930000
else
PLM_UART_BASEADDR ?= 0xF1920000
endif
endif
PLM_UART_HIGHADDR := $(shell printf 0x%08X $$(echo $$(($(PLM_UART_BASEADDR) + 0xFFFF))))

$(PLM_PARAMS_BAK_PATH): $(PLM_PARAMS_PATH)
	# backup original xparameters.h file before modification
	cp -a $< $@
	# adjust UART base address
	sed -i \
		-e 's#^\(.*\s\+STD\(IN\|OUT\)_BASEADDRESS\)\s\+.*\+$$#\1 $(PLM_UART_BASEADDR)#g' \
		-e 's#^\(.*\(SBSAUART\|XUARTPSV\)_0_BASEADDR\)\s\+.*$$#\1 $(PLM_UART_BASEADDR)#g' \
		-e 's#^\(.*\(SBSAUART\|XUARTPSV\)_0_HIGHADDR\)\s\+.*$$#\1 $(PLM_UART_HIGHADDR)#g' \
		$<
ifeq ($(OPTEE_OS_PLATFORM),versal)
	# replace PLM_DEBUG by PLM_PRINT to save space on Versal
	sed -i -e 's#^\(.*\)\s\+PLM_DEBUG$$#\1 PLM_PRINT#' $<
	# disable QSPI and OSPI handlers to make room for NVM and PUF handlers on Versal
	if ! grep -q -e '^.*\s\+PLM_QSPI_EXCLUDE$$' $<; then \
		sed -i -e '/^.*\s\+XPAR_XILPM_ENABLED$$/a #define PLM_QSPI_EXCLUDE' $<; \
	fi
	if ! grep -q -e '^.*\s\+PLM_OSPI_EXCLUDE$$' $<; then \
		sed -i -e '/^.*\s\+XPAR_XILPM_ENABLED$$/a #define PLM_OSPI_EXCLUDE' $<; \
	fi
endif
	# re-enable NVM and PUF handlers
	if grep -q -e '^.*\s\+PLM_NVM_EXCLUDE$$' $<; then \
		sed -i -e '/^.*\s\+PLM_NVM_EXCLUDE$$/d' $<; \
	fi
	if grep -q -e '^.*\s\+PLM_PUF_EXCLUDE$$' $<; then \
		sed -i -e '/^.*\s\+PLM_PUF_EXCLUDE$$/d' $<; \
	fi
	# enable ECC curves NIST P256 and P521
	if ! grep -q -e '^.*\s\+XSECURE_ECC_SUPPORT_NIST_P256$$' $<; then \
		sed -i -e '/^.*\s\+XPAR_XILPM_ENABLED$$/a #define XSECURE_ECC_SUPPORT_NIST_P256' $<; \
	fi
	if ! grep -q -e '^.*\s\+XSECURE_ECC_SUPPORT_NIST_P521$$' $<; then \
		sed -i -e '/^.*\s\+XPAR_XILPM_ENABLED$$/a #define XSECURE_ECC_SUPPORT_NIST_P521' $<; \
	fi
.PHONY: $(PLM_PARAMS_BAK_PATH)

$(PLM_PATH_GEN): $(PLM_PARAMS_BAK_PATH)
	env PATH=$(PATH):$(shell dirname $(CROSS_COMPILE_FIRMWARE)) \
		$(MAKE) -C $(PLM_SRC_PATH)/
	# restore original xparameters.h file to avoid unstaged changes
	mv $< $(PLM_PARAMS_PATH)


ifeq ($(OPTEE_OS_PLATFORM),versal)
PSM_PARAMS_PATH := $(PSM_APP_PATH)/misc/xparameters.h
else
PSM_PARAMS_PATH := $(PSM_APP_PATH)/misc/$(TF_A_PLAT)/xparameters.h
endif
PSM_PARAMS_BAK_PATH := $(PSM_PARAMS_PATH).bak

PSM_UART_BASEADDR ?= $(PLM_UART_BASEADDR)
PSM_UART_HIGHADDR ?= $(PLM_UART_HIGHADDR)

$(PSM_PARAMS_BAK_PATH): $(PSM_PARAMS_PATH)
	# backup original xparameters.h file before modification
	cp -a $< $@
	# adjust UART base address
	sed -i \
		-e 's#^\(.*\s\+STD\(IN\|OUT\)_BASEADDRESS\)\s\+.*\+$$#\1 $(PSM_UART_BASEADDR)#g' \
		-e 's#^\(.*\(SBSAUART\|XUARTPSV\)_0_BASEADDR\)\s\+.*$$#\1 $(PSM_UART_BASEADDR)#g' \
		-e 's#^\(.*\(SBSAUART\|XUARTPSV\)_0_HIGHADDR\)\s\+.*$$#\1 $(PSM_UART_HIGHADDR)#g' \
		$<
.PHONY: $(PSM_PARAMS_BAK_PATH)

$(PSM_PATH_GEN): $(PSM_PARAMS_BAK_PATH)
	env PATH=$(PATH):$(shell dirname $(CROSS_COMPILE_FIRMWARE)) \
		$(MAKE) -C $(PSM_SRC_PATH)/
	# restore original xparameters.h file to avoid unstaged changes
	mv $< $(PSM_PARAMS_PATH)

firmware: $(PLM_PATH_GEN) $(PSM_PATH_GEN)

firmware-clean:
	$(MAKE) -C $(PLM_SRC_PATH)/ clean
	$(MAKE) -C $(PSM_SRC_PATH)/ clean
	# restore original xparameters.h files to avoid unstaged changes
	if [ -e $(PLM_PARAMS_BAK_PATH) ]; then \
		mv $(PLM_PARAMS_BAK_PATH) $(PLM_PARAMS_PATH); \
	fi
	if [ -e $(PSM_PARAMS_BAK_PATH) ]; then \
		mv $(PSM_PARAMS_BAK_PATH) $(PSM_PARAMS_PATH); \
	fi
else
firmware:

firmware-clean:

endif

.PHONY: firmware firmware-clean


###############################################################################
# Boot Image
###############################################################################

OPTEE_OS_ELF ?= $(shell dirname $(OPTEE_OS_BIN))/tee.elf
OPTEE_OS_RAWBIN ?= $(shell dirname $(OPTEE_OS_BIN))/tee-raw.bin
$(OPTEE_OS_ELF): optee-os-common
$(OPTEE_OS_RAWBIN): optee-os-common

OPTEE_OS_RAWBIN_OBJ ?= versal/$(shell basename $(OPTEE_OS_RAWBIN)).o
OPTEE_OS_RAWBIN_ELF ?= versal/$(shell basename $(OPTEE_OS_RAWBIN)).elf

# NOTE: Since we need to reference an ELF file in the .bif file to make PLM
#       firmware really recognize OP-TEE OS as a SEL-1 binary and provide
#       matching "handoff" parameters to ATF (API id 0x70b,
#       get_atf_handoff_params), we wrap the regular tee-raw.bin file in ELF
#       format with a single .text section and the appropriate entry point.
#
#       The tee.elf file cannot be used directly, since OP-TEE OS entry code
#       (entry_a64.S) depends on a struct boot_embdata placed right at symbol
#       __data_end. The script gen_tee_bin.py does this placement while crafting
#       tee-raw.bin (and similarly tee.bin) from tee.elf.
$(OPTEE_OS_RAWBIN_OBJ): $(OPTEE_OS_RAWBIN)
	$(subst ",,$(CROSS_COMPILE_S_KERNEL))objcopy \
		-I binary -O elf64-littleaarch64 -B aarch64 \
		--rename-section .data=.text \
		--set-section-flags .text=alloc,code,load,readonly,contents \
		$< $@
$(OPTEE_OS_RAWBIN_ELF).load: $(OPTEE_OS_ELF)
	$(subst ",,$(CROSS_COMPILE_S_KERNEL))nm $< | \
		awk '/\s_start$$/ {printf "0x%s\n", $$1}' >$@
$(OPTEE_OS_RAWBIN_ELF): $(OPTEE_OS_RAWBIN_OBJ) $(OPTEE_OS_RAWBIN_ELF).load
	$(subst ",,$(CROSS_COMPILE_S_KERNEL))ld \
		-Ttext $(shell cat $(OPTEE_OS_RAWBIN_ELF).load) \
		-e $(shell cat $(OPTEE_OS_RAWBIN_ELF).load) \
		$< -o $@
.PHONY: $(OPTEE_OS_RAWBIN_OBJ) $(OPTEE_OS_RAWBIN_ELF).load $(OPTEE_OS_RAWBIN_ELF)

BIF_PATH := versal/bootImage-$(PLATFORM).bif

$(BIF_PATH): versal/bootImage-$(OPTEE_OS_PLATFORM).bif.in \
	$(_PDI_PATH) $(_PLM_PATH) $(_PSM_PATH) $(_DTB_PATH) $(_IUB_BIF_PATH) \
	$(OPTEE_OS_RAWBIN_ELF)
	cp -a $< $@
# PLM firmware is optional, if already in .pdi file
ifeq ($(_PLM_PATH),)
	sed -i -e '/%PLM_PATH%/d' $@
endif
# PSM firmware is optional, if already in .pdi file
ifeq ($(_PSM_PATH),)
	sed -i -e '/%PSM_PATH%/d' $@
endif
ifeq ($(_IUB_BIF_PATH),)
	sed -i -e '/%IUB_PATH%/d' $@
endif
	sed -i \
		-e 's#%PDI_PATH%#$(shell realpath -m $(_PDI_PATH))#g' \
		-e 's#%PLM_PATH%#$(shell realpath -m $(_PLM_PATH) 2>/dev/null)#g' \
		-e 's#%PSM_PATH%#$(shell realpath -m $(_PSM_PATH) 2>/dev/null)#g' \
		-e 's#%DTB_PATH%#$(shell realpath -m $(_DTB_PATH))#g' \
		-e 's#%TEE_PATH%#$(shell realpath -m $(OPTEE_OS_RAWBIN_ELF))#g' \
		-e 's#%IUB_PATH%#$(shell realpath -m ${_IUB_BIF_PATH} 2>/dev/null)#g' \
		-e 's#%IUB_LOAD%#$(_IUB_BIF_LOAD)#g' \
		$@
.PHONY: $(BIF_PATH)

bootimage: $(BIF_PATH) bootgen tfa optee-os u-boot
	$(BOOTGEN_PATH)/bootgen -arch $(BOOTGEN_ARCH) -image $< -w -o versal/BOOT.BIN

bootimage-clean: bootgen-clean tfa-clean optee-os-clean u-boot-clean
	rm -f versal/BOOT.BIN
	rm -f $(OPTEE_OS_RAWBIN_ELF) $(OPTEE_OS_RAWBIN_ELF).load \
		$(OPTEE_OS_RAWBIN_OBJ)
	rm -f versal/bootImage-${PLATFORM}.bif


###############################################################################
# Bootgen
###############################################################################

bootgen:
	make -C $(BOOTGEN_PATH)

bootgen-clean:
	make -C $(BOOTGEN_PATH) clean


###############################################################################
# FIT Image
###############################################################################

_IUB_PATH := $(IUB_PATH)

ITS_PATH := versal/fitImage-$(PLATFORM).its

$(ITS_PATH): versal/fitImage-$(OPTEE_OS_PLATFORM).its.in
	cp -a $< $@
	sed -i \
		-e 's#%DTB_PATH%#$(shell realpath -m $(_DTB_PATH))#g' \
		$@
.PHONY: $(ITS_PATH)

$(_IUB_PATH): $(ITS_PATH) u-boot linux dtbo buildroot
	$(U-BOOT_PATH)/tools/mkimage -f $< $@
.PHONY: $(_IUB_PATH)

fitimage: $(_IUB_PATH)

fitimage-clean: linux-clean dtbo-clean buildroot-clean
	rm -f versal/${PLATFORM}.ub
	rm -f versal/fitImage-$(PLATFORM).its
