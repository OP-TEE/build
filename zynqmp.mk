PLATFORM		?= zcu102
BSP_PATH		?= ../xilinx-${PLATFORM}-v$(PETALINUX_VER)-final.bsp
PRJ_PATH		?= ../petalinux-optee-$(PLATFORM)
OPTEE_VER		?= latest

PYTHON_PATH	?= ${PRJ_PATH}/project-spec/meta-user/recipes-devtools/python

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
all: create build package

.PHONY: check
check:
ifndef PETALINUX_VER
	$(error You have to source Petalinux settings)
endif
ifneq ($(PETALINUX_VER),2020.2)
	$(error This makefile only support Petalinux 2020.2)
endif

create: check
	@# Create TMP directory to avoid issues with .. in the path name
	@mkdir -p /tmp/petalinux-optee-${PLATFORM}
	@petalinux-create -n $(PRJ_PATH) -t project -s $(BSP_PATH) --tmpdir /tmp/petalinux-optee-${PLATFORM}
	@#
	@# Append the ATF recipe to include opteed as SPD
	@mkdir -p ${PRJ_PATH}/project-spec/meta-user/recipes-bsp/arm-trusted-firmware
	@cp zynqmp/arm-trusted-firmware/*.bbappend ${PRJ_PATH}/project-spec/meta-user/recipes-bsp/arm-trusted-firmware/.
	@#
	@# Download optee package  recipes from meta-arm layer using gatesgarth branch as there were not available for zeus
	@curl -s https://git.yoctoproject.org/cgit/cgit.cgi/meta-arm/snapshot/meta-arm-3.2.tar.gz -o ../meta-arm-3.2.tar.gz
	@tar -C ${PRJ_PATH}/project-spec/meta-user --strip-components=2 -xvf ../meta-arm-3.2.tar.gz meta-arm-3.2/meta-arm/recipes-security > /dev/null
	@#
	@# Copy the bbapend files for our target
	@cp zynqmp/optee/* ${PRJ_PATH}/project-spec/meta-user/recipes-security/optee/.
	@#
	@# Download python package dependencies from meta-core layer using gatesgarth branch as there were not available for zeus
	@mkdir -p ${PYTHON_PATH}
	@curl -s http://cgit.openembedded.org/openembedded-core/plain/meta/recipes-devtools/python/python3-pycryptodome_3.9.8.bb?h=gatesgarth \
	-o ${PYTHON_PATH}/python3-pycryptodome_3.9.8.bb
	@curl -s http://cgit.openembedded.org/openembedded-core/plain/meta/recipes-devtools/python/python3-pycryptodomex_3.9.8.bb?h=gatesgarth \
	 -o ${PYTHON_PATH}/python3-pycryptodomex_3.9.8.bb
	@curl -s http://cgit.openembedded.org/openembedded-core/plain/meta/recipes-devtools/python/python3-pyelftools_0.26.bb?h=gatesgarth  \
	-o ${PYTHON_PATH}/python3-pyelftools_0.26.bb
	@curl -s http://cgit.openembedded.org/openembedded-core/plain/meta/recipes-devtools/python/python-pycryptodome.inc?h=gatesgarth \
	-o ${PYTHON_PATH}/python-pycryptodome.inc
	@#
	@# Add packages to the image
	@echo IMAGE_INSTALL_append = \" optee-os optee-client optee-test\" >> ${PRJ_PATH}/project-spec/meta-user/conf/petalinuxbsp.conf
	@#
	@# Add optee kernel options to the exisiting kernel append recipe
	@echo SRC_URI_append += \"file://kernel_optee.cfg\" >> ${PRJ_PATH}/project-spec/meta-user/recipes-kernel/linux/linux-xlnx_%.bbappend
	@cp zynqmp/kernel/kernel_optee.cfg ${PRJ_PATH}/project-spec/meta-user/recipes-kernel/linux/linux-xlnx/kernel_optee.cfg
	@#
	@# Replace exisiting user configued dts file to add optee node
	@cp zynqmp/device-tree/system-user.dtsi ${PRJ_PATH}/project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi


build: create
	@petalinux-build -p $(PRJ_PATH)
	
qemu: check
	@cd $(PRJ_PATH) && petalinux-boot --qemu \
	    --qemu-args "-device loader,file=${PRJ_PATH}/images/linux/bl32.elf" \
	    --kernel

package: check
	@petalinux-package --boot --pmufw --fpga --u-boot --add ${PRJ_PATH}/images/linux/tee_raw.bin --cpu a53-0 \
	    --file-attribute "load=0x60000000, startup=0x60000000, exception_level=el-1, trustzone" --force -p ${PRJ_PATH}
