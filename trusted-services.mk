################################################################################
# Paths to Trusted Services source and output
################################################################################
TS_PATH			?= $(ROOT)/trusted-services
TS_BUILD_PATH		?= $(OUT_PATH)/ts-build
TS_INSTALL_PREFIX	?= $(OUT_PATH)/ts-install

################################################################################
# Secure Partitions
################################################################################
.PHONY: ffa-sp-all ffa-sp-all-clean ffa-sp-all-realclean

optee-os-common: ffa-sp-all
optee-os-clean: ffa-sp-all-clean

ffa-sp-all-realclean:
	rm -rf $(TS_INSTALL_PREFIX)/opteesp $(TS_INSTALL_PREFIX)/sp

ifneq ($(COMPILE_S_USER),64)
$(error Trusted Services SPs only support AArch64)
endif

SP_EXT-opteesp := stripped.elf
SP_EXT-sp := bin

# The macro sets a variable if the source variable is defined, otherwise it
# results in an error.
# Parameter list:
# 1 - Destination variable name
# 2 - Source variable name
# 3 - Error message
define set_if_source_defined
ifndef $(2)
$$(error $(3))
else
$(1) := $($(2))
endif
endef

# Helper macro to build and install Trusted Services Secure Partitions (SPs).
# Invokes CMake to configure, and make to build and install the SP. (CMake's
# Makefile generator backend is used, we can run make in the build directory).
# Adds the SP output image to the optee_os_sp_paths list and complies the SP
# manifest dts to dtb.
#
# For information about the additional dependencies of the project, please see
# https://trusted-services.readthedocs.io/en/latest/developer/software-requirements.html
#
# Parameter list:
# 1 - SP deployment name (e.g. internal-trusted-storage, crypto, etc.)
# 2 - Build configuration name (e.g. config/shared-flash)
# 3 - SP canonical UUID (e.g. dc1eef48-b17a-4ccf-ac8b-dfcff7711b14)
# 4 - SP additional build flags (e.g. -DTS_PLATFORM=<...>)
define build-sp
$(eval SP_DIR := $(lastword $(subst -, ,$(2))))
$(eval $(call set_if_source_defined,SP_EXT,SP_EXT-$(lastword $(subst -, ,$(2))),Invalid $(1) SP configuration: $(2)))

.PHONY: ffa-$1-sp
ffa-$1-sp:
	CROSS_COMPILE=$(subst $(CCACHE),,$(CROSS_COMPILE_S_USER)) cmake -G"Unix Makefiles" \
		-S $(TS_PATH)/deployments/$1/$2 -B $(TS_BUILD_PATH)/$1 \
		-DCMAKE_INSTALL_PREFIX=$(TS_INSTALL_PREFIX) \
		-DCMAKE_C_COMPILER_LAUNCHER=$(CCACHE) $(SP_COMMON_FLAGS) $4
	$$(MAKE) -C $(TS_BUILD_PATH)/$1 install
	dtc -I dts -O dtb -o $(TS_INSTALL_PREFIX)/$(SP_DIR)/manifest/$3.dtb \
				$(TS_INSTALL_PREFIX)/$(SP_DIR)/manifest/$3.dts

.PHONY: ffa-$1-sp-clean
ffa-$1-sp-clean:
	- $$(MAKE) -C $(TS_BUILD_PATH)/$1 clean

.PHONY: ffa-$1-sp-realclean
ffa-$1-sp-realclean:
	rm -rf $(TS_BUILD_PATH)/$1

ffa-sp-all: ffa-$1-sp
ffa-sp-all-clean: ffa-$1-sp-clean
ffa-sp-all-realclean: ffa-$1-sp-realclean

optee_os_sp_paths += $(TS_INSTALL_PREFIX)/$(SP_DIR)/bin/$3.$(SP_EXT)
fip_sp_json_paths += $(TS_INSTALL_PREFIX)/$(SP_DIR)/json/$1.json
endef

ifeq ($(SP_PACKAGING_METHOD),embedded)
# Add the list of SP paths to the optee_os config
OPTEE_OS_COMMON_EXTRA_FLAGS += SP_PATHS="$(optee_os_sp_paths)"
else ifeq ($(SP_PACKAGING_METHOD),fip)
$(TS_INSTALL_PREFIX)/sp_layout.json: ffa-sp-all
	$(PYTHON3) $(TS_PATH)/tools/python/merge_json.py $@ $(fip_sp_json_paths)

optee-os-common: $(TS_INSTALL_PREFIX)/sp_layout.json

# Configure TF-A to load the SPs from FIP by BL2
TF_A_FLAGS += ARM_BL2_SP_LIST_DTS=$(ROOT)/build/fvp/bl2_sp_list.dtsi \
		SP_LAYOUT_FILE=$(TS_INSTALL_PREFIX)/sp_layout.json
endif

################################################################################
# Linux FF-A user space driver
################################################################################
# This driver is only used by the uefi-test app or the spmc tests
ifneq ($(filter y, $(TS_UEFI_TESTS) $(SPMC_TESTS)),)
.PHONY: linux-arm-ffa-user linux-arm-ffa-user-clean
all: linux-arm-ffa-user

linux-arm-ffa-user: linux
	mkdir -p $(OUT_PATH)/linux-arm-ffa-user
	$(MAKE) -C $(ROOT)/linux-arm-ffa-user $(LINUX_COMMON_FLAGS) install \
		TARGET_DIR=$(OUT_PATH)/linux-arm-ffa-user
	echo "ed32d533-99e6-4209-9cc0-2d72cdd998a7,\
	5c9edbc3-7b3a-4367-9f83-7c191ae86a37,\
	7817164c-c40c-4d1a-867a-9bb2278cf41a,\
	23eb0100-e32a-4497-9052-2f11e584afa6,\
	bdcd76d7-825e-4751-963b-86d4f84943ac,\
	54b5440e-a3d2-48d1-872a-7b6cbfc34855" > \
		$(OUT_PATH)/linux-arm-ffa-user/sp_uuid_list.txt

linux-arm-ffa-user-clean:
	$(MAKE) -C $(ROOT)/linux-arm-ffa-user clean

# Disable CONFIG_STRICT_DEVMEM option in the Linux kernel config. This allows
# userspace access to the whole NS physical address space through /dev/mem. It's
# needed by the uefi-test app to communicate with the smm-gateway SP using a
# static carveout. If changed, run "make linux-defconfig-clean" to take effect.
LINUX_DEFCONFIG_COMMON_FILES += $(CURDIR)/kconfigs/fvp_trusted-services_uefi.conf
endif

################################################################################
# Trusted Services test applications
################################################################################
.PHONY: ffa-test-all ffa-test-all-clean ffa-test-all-realclean
all: ffa-test-all

ffa-test-all-realclean:
	rm -rf $(TS_INSTALL_PREFIX)/arm-linux

ifneq ($(COMPILE_NS_USER),64)
$(error Trusted Services test apps only support AArch64)
endif

# Helper macro to build and install Trusted Services test applications.
# Invokes CMake to configure, and make to build and install the apps.
#
# Parameter list:
# 1 - SP deployment name (e.g. psa-api-test/internal-trusted-storage,
#     ts-demo, etc.)
# 2 - Additional build flags

define build-ts-app
.PHONY: ffa-$1
ffa-$1:
	CROSS_COMPILE=$(subst $(CCACHE),,$(CROSS_COMPILE_NS_USER)) cmake -G"Unix Makefiles" \
		-S $(TS_PATH)/deployments/$1/arm-linux -B $(TS_BUILD_PATH)/$1 \
		-DCMAKE_INSTALL_PREFIX=$(TS_INSTALL_PREFIX) \
		-Dlibts_DIR=${TS_INSTALL_PREFIX}/arm-linux/lib/cmake/libts \
		-DCFG_FORCE_PREBUILT_LIBTS=On \
		-Dlibpsats_DIR=${TS_INSTALL_PREFIX}/arm-linux/lib/cmake/libpsats \
		-DCFG_FORCE_PREBUILT_LIBPSATS=On \
		-DCMAKE_C_COMPILER_LAUNCHER=$(CCACHE) $(TS_APP_COMMON_FLAGS) $2
	$$(MAKE) -C $(TS_BUILD_PATH)/$1 install

ifneq ($1,libts)

ifeq ($1,libpsats)
ffa-libpsats: ffa-libts
else
ffa-$1: ffa-libpsats
endif

endif

.PHONY: ffa-$1-clean
ffa-$1-clean:
	- $$(MAKE) -C $(TS_BUILD_PATH)/$1 clean

.PHONY: ffa-$1-realclean
ffa-$1-realclean:
	rm -rf $(TS_BUILD_PATH)/$1

ffa-test-all: ffa-$1
ffa-test-all-clean: ffa-$1-clean
ffa-test-all-realclean: ffa-$1-realclean
endef

################################################################################
# Trusted Services hot applications
################################################################################
.PHONY: ts-host-all ts-host-all-clean ts-host-all-realclean
all: ts-host-all

ts-host-all-realclean:
	rm -rf $(TS_INSTALL_PREFIX)/linux-pc

# Helper macro to build and install Trusted Services applications which
# run on the host.
# Invokes CMake to configure, and make to build and install the apps.
#
# Parameter list:
# 1 - deployment name (e.g. fwu-app )
# 2 - Additional build flags

define build-ts-host-app
.PHONY: ts-host-$1
$(if $1, ,$(error build-ts-host-app: missing deployment name argument))

ts-host-$1:
	cmake -G"Unix Makefiles" \
		-S $(TS_PATH)/deployments/$1/linux-pc -B $(TS_BUILD_PATH)/$1 \
		-DCMAKE_INSTALL_PREFIX=$(TS_INSTALL_PREFIX) \
		-DCMAKE_C_COMPILER_LAUNCHER=$(CCACHE) \
		$(TS_HOST_COMMON_FLAGS) $2
	$$(MAKE) -C $(TS_BUILD_PATH)/$1 install

.PHONY: ts-host-$1-clean
ts-host-$1-clean:
	$$(MAKE) -C $(TS_BUILD_PATH)/$1 clean

.PHONY: ts-host-$1-realclean
ts-host-$1-realclean:
	rm -rf $(TS_BUILD_PATH)/$1

ts-host-all: ts-host-$1
ts-host-all-clean: ts-host-$1-clean
ts-host-all-realclean: ts-host-$1-realclean

endef
