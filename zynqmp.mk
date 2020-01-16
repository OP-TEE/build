ROOT			= $(PWD)/..
PLATFORM		?= zcu102
PETALINUX_PATH		?= $(PETALINUX)
BSP_PATH		?= ./xilinx-${PLATFORM}-v$(PETALINUX_VER)-final.bsp
PRJ_PATH		?= $(ROOT)/$(PLATFORM)-$(PETALINUX_VER)
PETALINUX_CFG_PATH	?= $(ROOT)/build/zynqmp
OPTEE_VER		?= latest

define set_cfg
	@sed -i 's/$(1)=.*/$(1)=$(2)/' $(3)
endef

define set_optee_version
	@if [ "$(1)" != "latest" ]; then \
		echo 'OPTEE_VERSION ?= "$(1)"' > $(2); \
		echo 'SRCREV ?= "$(1)"' >> $(2); \
	else \
		echo 'OPTEE_VERSION ?= "latest"' > $(2); \
		echo 'SRCREV ?= "$${AUTOREV}"' >> $(2); \
	fi
endef

ifeq ($(PLATFORM),ultra96-reva)
	ZYNQMP_CONSOLE=cadence1
else
	ZYNQMP_CONSOLE=cadence0
endif

.PHONY: all
all: petalinux-create petalinux-config petalinux-build petalinux-package

.PHONY: check-petalinux
check-petalinux:
ifndef PETALINUX_VER
	$(error You have to source Petalinux settings)
endif
ifneq ($(PETALINUX_VER),2018.2)
	$(error This makefile only support Petalinux 2018.2)
endif

petalinux-create: check-petalinux	
	@cd $(ROOT) && petalinux-create -n $(PLATFORM)-$(PETALINUX_VER) \
	    -t project -s $(BSP_PATH)
	$(call set_cfg,CONFIG_SUBSYSTEM_ATF_COMPILE_EXTRA_SETTINGS,"SPD=opteed ZYNQMP_BL32_MEM_BASE=0x60000000 ZYNQMP_BL32_MEM_SIZE=0x80000",$(PRJ_PATH)/project-spec/configs/config)
	$(call set_cfg,CONFIG_SUBSYSTEM_ZYNQMP_ATF_MEM_SIZE,0x16001,$(PRJ_PATH)/project-spec/configs/config)
	@#
	@# Replace BSP default rootfs by a minimal one to speed up building 
	@# process and ease compatibility between different boards. Default
	@# rootfs is saved in rootfs_config_full file
	@mv $(PRJ_PATH)/project-spec/configs/rootfs_config \
	    $(PRJ_PATH)/project-spec/configs/rootfs_config_full
	@cp $(PETALINUX_CFG_PATH)/rootfs_config \
	    $(PRJ_PATH)/project-spec/configs/
	@#
	@mkdir -p $(PRJ_PATH)/project-spec/meta-user/recipes-kernel/linux/linux-xlnx/
	@cp $(PETALINUX_CFG_PATH)/kernel_optee.cfg \
	    $(PRJ_PATH)/project-spec/meta-user/recipes-kernel/linux/linux-xlnx/
	@cp $(PETALINUX_CFG_PATH)/linux-xlnx_%.bbappend \
	    $(PRJ_PATH)/project-spec/meta-user/recipes-kernel/linux/linux-xlnx_%.bbappend
	@cp $(PETALINUX_CFG_PATH)/system-user.dtsi \
	    $(PRJ_PATH)/project-spec/meta-user/recipes-bsp/device-tree/files/
	@#
	@# Override default TF-A 1.4 with TF-A 1.5 because it does not work with
	@# OP-TEE
	@mkdir -p $(PRJ_PATH)/project-spec/meta-user/recipes-bsp/arm-trusted-firmware/
	@cp -r $(PETALINUX_CFG_PATH)/arm-trusted-firmware/* \
	    $(PRJ_PATH)/project-spec/meta-user/recipes-bsp/arm-trusted-firmware/
	@#
	@petalinux-create -p $(PRJ_PATH) -t apps --template install \
	    -n optee-client --enable
	@petalinux-create -p $(PRJ_PATH) -t apps --template install \
	    -n optee-test --enable
	@mkdir -p $(PRJ_PATH)/project-spec/meta-user/recipes-bsp/optee-os
	@cp -r $(PETALINUX_CFG_PATH)/optee-os/* \
	    $(PRJ_PATH)/project-spec/meta-user/recipes-bsp/optee-os/
	@cp -r $(PETALINUX_CFG_PATH)/optee-client/* \
	    $(PRJ_PATH)/project-spec/meta-user/recipes-apps/optee-client/
	@cp -r $(PETALINUX_CFG_PATH)/optee-test/* \
	    $(PRJ_PATH)/project-spec/meta-user/recipes-apps/optee-test/
	@mkdir -p $(PRJ_PATH)/project-spec/meta-user/recipes-devtools/python
	@cp -r $(PETALINUX_CFG_PATH)/python/* \
	    $(PRJ_PATH)/project-spec/meta-user/recipes-devtools/python/
	
petalinux-config: check-petalinux
	$(call set_optee_version,$(OPTEE_VER),$(PRJ_PATH)/project-spec/meta-user/recipes-apps/optee-test/optee-test.bbappend)
	$(call set_optee_version,$(OPTEE_VER),$(PRJ_PATH)/project-spec/meta-user/recipes-apps/optee-client/optee-client.bbappend)
	$(call set_optee_version,$(OPTEE_VER),$(PRJ_PATH)/project-spec/meta-user/recipes-bsp/optee-os/optee-os.bbappend)
	@petalinux-config -p $(PRJ_PATH) --oldconfig

petalinux-build: check-petalinux
	@petalinux-build -p $(PRJ_PATH)
	
qemu: check-petalinux
	@cd $(PRJ_PATH) && petalinux-boot --qemu \
	    --qemu-args "-device loader,file=${PRJ_PATH}/images/linux/bl32.elf" \
	    --kernel

petalinux-package: check-petalinux
	@cd $(PRJ_PATH) && petalinux-package --boot --pmufw --fpga --u-boot \
	    --add ${PRJ_PATH}/images/linux/bl32.elf --cpu a53-0 \
	    --file-attribute "exception_level=el-1, trustzone" --force
