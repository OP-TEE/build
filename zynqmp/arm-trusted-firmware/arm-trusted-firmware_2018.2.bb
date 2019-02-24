ATF_VERSION = "2.0"
SRCREV ??= "dbc8d9496ead9ecdd7c2a276b542a4fbbbf64027"
BRANCH ??= "master"
DESCRIPTION = "Trusted Firmware-A"

LICENSE = "BSD"
LIC_FILES_CHKSUM = "file://license.rst;md5=e927e02bca647e14efd87e9e914b2443"

PROVIDES = "virtual/arm-trusted-firmware"

inherit deploy

DEPENDS += "u-boot-mkimage-native"

S = "${WORKDIR}/git"
B = "${WORKDIR}/build"

ATF_VERSION_EXTENSION ?= "-arm"
PV = "${ATF_VERSION}${ATF_VERSION_EXTENSION}+git${SRCPV}"

BRANCH ??= ""
REPO ??= "git://github.com/ARM-software/arm-trusted-firmware.git;protocol=https"
BRANCHARG = "${@['nobranch=1', 'branch=${BRANCH}'][d.getVar('BRANCH', True) != '']}"
SRC_URI = "${REPO};${BRANCHARG}"

ATF_BASE_NAME ?= "${PN}-${PKGE}-${PKGV}-${PKGR}-${DATETIME}"
ATF_BASE_NAME[vardepsexclude] = "DATETIME"

COMPATIBLE_MACHINE = "zynqmp"
PLATFORM_zynqmp = "zynqmp"

# requires CROSS_COMPILE set by hand as there is no configure script
export CROSS_COMPILE="${TARGET_PREFIX}"

# Let the Makefile handle setting up the CFLAGS and LDFLAGS as it is a standalone application
CFLAGS[unexport] = "1"
LDFLAGS[unexport] = "1"
AS[unexport] = "1"
LD[unexport] = "1"

ATF_CONSOLE ?= ""
ATF_CONSOLE_zynqmp = "cadence"

DEBUG ?= ""
EXTRA_OEMAKE_zynqmp_append = "${@' ZYNQMP_CONSOLE=${ATF_CONSOLE}' if d.getVar('ATF_CONSOLE', True) != '' else ''}"
EXTRA_OEMAKE_append = " ${@bb.utils.contains('DEBUG', '1', ' DEBUG=${DEBUG}', '', d)}"

OUTPUT_DIR = "${@bb.utils.contains('DEBUG', '1', '${B}/${PLATFORM}/debug', '${B}/${PLATFORM}/release', d)}"

ATF_MEM_BASE ?= ""
ATF_MEM_SIZE ?= ""

EXTRA_OEMAKE_zynqmp_append = "${@' ZYNQMP_ATF_MEM_BASE=${ATF_MEM_BASE}' if d.getVar('ATF_MEM_BASE', True) != '' else ''}"
EXTRA_OEMAKE_zynqmp_append = "${@' ZYNQMP_ATF_MEM_SIZE=${ATF_MEM_SIZE}' if d.getVar('ATF_MEM_SIZE', True) != '' else ''}"

do_configure() {
	oe_runmake clean -C ${S} BUILD_BASE=${B} PLAT=${PLATFORM}
}

do_compile() {
	oe_runmake -C ${S} BUILD_BASE=${B} PLAT=${PLATFORM} RESET_TO_BL31=1 bl31
}

do_deploy() {
	install -d ${DEPLOYDIR}
	install -m 0644 ${OUTPUT_DIR}/bl31/bl31.elf ${DEPLOYDIR}/${ATF_BASE_NAME}.elf
	ln -sf ${ATF_BASE_NAME}.elf ${DEPLOYDIR}/${PN}.elf
	install -m 0644 ${OUTPUT_DIR}/bl31.bin ${DEPLOYDIR}/${ATF_BASE_NAME}.bin
	ln -sf ${ATF_BASE_NAME}.bin ${DEPLOYDIR}/${PN}.bin
}
addtask deploy before do_build after do_compile