OPTEE_VERSION ??= "latest"
SRCREV ??= "${AUTOREV}"
BRANCH ??= "master"

DESCRIPTION = "OP-TEE OS"

# Define as closed license to prevent MD5 checksum verification since
# LICENSE file changed around 3.5.0 making this recipe less flexible.
# LICENSE = "BSD"
# ante-3.5.0: LIC_FILES_CHKSUM = "file://LICENSE;md5=69663ab153298557a59c67a60a743e5b"
# post-3.5.0: LIC_FILES_CHKSUM = "file://LICENSE;md5=c1f21c4f72f372ef38a5a4aee55ec173"
LICENSE = "CLOSED"

PROVIDES = "virtual/optee-os"
DEPENDS += "\
            u-boot-mkimage-native \
            python3-pycryptodome-native \
            python3-pycryptodomex-native \
            python3-pyelftools-native \
            "

S = "${WORKDIR}/git"
PV = "${OPTEE_VERSION}+git${SRCPV}"

REPO ??= "git://github.com/OP-TEE/optee_os.git;protocol=https"
SRC_URI = "${REPO};branch=${BRANCH}"

inherit deploy python3native

OPTEE_BASE_NAME ?= "${PN}-${PKGE}-${PKGV}-${PKGR}-${DATETIME}"
OPTEE_BASE_NAME[vardepsexclude] = "DATETIME"

COMPATIBLE_MACHINE = "zynqmp"
PLATFORM_zynqmp = "zynqmp"
FLAVOR_zynqmp = "${@d.getVar('MACHINE').split('-')[0]}"

# requires CROSS_COMPILE set by hand as there is no configure script
export CROSS_COMPILE="${TARGET_PREFIX}"

# Let the Makefile handle setting up the CFLAGS and LDFLAGS as it is a standalone application
CFLAGS[unexport] = "1"
LDFLAGS[unexport] = "1"
AS[unexport] = "1"
LD[unexport] = "1"

DEBUG ??= "0"
TA_DEV_KIT_DIR = "${TMPDIR}/deploy/images/${MACHINE}/optee/export-ta_arm64"
OUTPUT_DIR = "${S}/out/arm-plat-zynqmp"
TEE_LOG_LEVEL = "${@bb.utils.contains('DEBUG', '1', '3', '2', d)}"
TEE_CORE_DEBUG = "${@bb.utils.contains('DEBUG', '1', 'y', 'n', d)}"

EXTRA_OEMAKE_append = " comp-cflagscore=--sysroot=${STAGING_DIR_HOST}"
EXTRA_OEMAKE_append = " CROSS_COMPILE=${CROSS_COMPILE}"
EXTRA_OEMAKE_append = " CROSS_COMPILE_core=${CROSS_COMPILE}"
EXTRA_OEMAKE_append = " CROSS_COMPILE_ta_arm64=${CROSS_COMPILE}"
EXTRA_OEMAKE_append = " PLATFORM=${PLATFORM}-${FLAVOR}"
EXTRA_OEMAKE_append = " CFG_ARM64_core=y"
EXTRA_OEMAKE_append = " CFG_ARM32_core=n"
EXTRA_OEMAKE_append = " CFG_USER_TA_TARGETS=ta_arm64"
EXTRA_OEMAKE_append = " CFG_TEE_CORE_LOG_LEVEL=${TEE_LOG_LEVEL}"
EXTRA_OEMAKE_append = " CFG_TEE_CORE_DEBUG=${TEE_CORE_DEBUG}"
EXTRA_OEMAKE_append = " DEBUG=${DEBUG}"

do_install() {
	install -d ${TA_DEV_KIT_DIR}
	cp -aR ${OUTPUT_DIR}/export-ta_arm64/* ${TA_DEV_KIT_DIR}
}

do_deploy() {
	install -d ${DEPLOYDIR}
	install -d ${TMPDIR}/../../images/linux/
	install -m 0644 ${OUTPUT_DIR}/core/tee.elf ${DEPLOYDIR}/${OPTEE_BASE_NAME}.elf
	install -m 0644 ${OUTPUT_DIR}/core/tee.elf ${TMPDIR}/../../images/linux/bl32.elf
	install -m 0644 ${OUTPUT_DIR}/core/tee.bin ${DEPLOYDIR}/${OPTEE_BASE_NAME}.bin
	install -m 0644 ${OUTPUT_DIR}/core/tee.bin ${TMPDIR}/../../images/linux/bl32.bin
}
addtask deploy before do_build after do_install
