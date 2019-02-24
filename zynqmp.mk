ROOT			= $(PWD)/..
PLATFORM		?= zcu102
PETALINUX_PATH		?= /opt/Xilinx/petalinx_2018_2
BSP_PATH		?= ./xilinx-${PLATFORM}-v2018.2-final.bsp
PRJ_PATH		?= $(ROOT)/xilinx-${PLATFORM}-2018.2
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

.PHONY: check-petalinux

check-petalinux:
ifndef PETALINUX_VER
	$(error You have to source Petalinux settings)
endif
ifneq ($(PETALINUX_VER),2018.2)
	$(error This makefile only support Petalinux 2018.2)
endif

petalinux-create: check-petalinux
	@cd $(ROOT) && petalinux-create -t project -s $(BSP_PATH)
	@cd $(PRJ_PATH) && petalinux-create -t apps --template install -n optee-client --enable
	@cd $(PRJ_PATH) && petalinux-create -t apps --template install -n optee-test --enable
	@#
	$(call set_cfg,CONFIG_SUBSYSTEM_ATF_COMPILE_EXTRA_SETTINGS,"SPD=opteed ZYNQMP_BL32_MEM_BASE=0x60000000 ZYNQMP_BL32_MEM_SIZE=0x80000",$(PRJ_PATH)/project-spec/configs/config)
	$(call set_cfg,CONFIG_SUBSYSTEM_ZYNQMP_ATF_MEM_SIZE,0x16001,$(PRJ_PATH)/project-spec/configs/config)
	@#
	@cp $(PETALINUX_CFG_PATH)/kernel_optee.cfg $(PRJ_PATH)/project-spec/meta-user/recipes-kernel/linux/linux-xlnx/
	@cp $(PETALINUX_CFG_PATH)/linux-xlnx_%.bbappend $(PRJ_PATH)/project-spec/meta-user/recipes-kernel/linux/linux-xlnx_%.bbappend
	@cp $(PETALINUX_CFG_PATH)/system-user.dtsi $(PRJ_PATH)/project-spec/meta-user/recipes-bsp/device-tree/files/
	@#
	@mkdir -p $(PRJ_PATH)/project-spec/meta-user/recipes-bsp/arm-trusted-firmware/
	@cp -r $(PETALINUX_CFG_PATH)/arm-trusted-firmware/* $(PRJ_PATH)/project-spec/meta-user/recipes-bsp/arm-trusted-firmware/
	@#
	@mkdir -p $(PRJ_PATH)/project-spec/meta-user/recipes-bsp/optee-os
	@cp -r $(PETALINUX_CFG_PATH)/optee-os/* $(PRJ_PATH)/project-spec/meta-user/recipes-bsp/optee-os/
	@cp -r $(PETALINUX_CFG_PATH)/optee-client/* $(PRJ_PATH)/project-spec/meta-user/recipes-apps/optee-client/
	@cp -r $(PETALINUX_CFG_PATH)/optee-test/* $(PRJ_PATH)/project-spec/meta-user/recipes-apps/optee-test/
	
petalinux-config:
	$(call set_optee_version,$(OPTEE_VER),$(PRJ_PATH)/project-spec/meta-user/recipes-apps/optee-test/optee-test.bbappend)
	$(call set_optee_version,$(OPTEE_VER),$(PRJ_PATH)/project-spec/meta-user/recipes-apps/optee-client/optee-client.bbappend)
	$(call set_optee_version,$(OPTEE_VER),$(PRJ_PATH)/project-spec/meta-user/recipes-bsp/optee-os/optee-os.bbappend)
	@cd $(PRJ_PATH) && petalinux-config --oldconfig

petalinux-build:
	@cd $(PRJ_PATH) && petalinux-build
	
qemu:
	@cd $(PRJ_PATH) && petalinux-boot --qemu --qemu-args "-device loader,file=${PRJ_PATH}/images/linux/bl32.elf" --kernel
