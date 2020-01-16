OPTEE_VERSION ??= "latest"
SRCREV ??= "${AUTOREV}"
BRANCH ??= "master"

DESCRIPTION = "OP-TEE Test"

LICENSE = "BSD"
LIC_FILES_CHKSUM = "file://LICENSE.md;md5=daa2bcccc666345ab8940aab1315a4fa"

PROVIDES = "virtual/optee-test"
DEPENDS += "\
            virtual/optee-os \
            virtual/optee-client \
            python3-pycryptodome-native \
            python3-pycryptodomex-native\
            "

S = "${WORKDIR}/git"
PV = "${OPTEE_VERSION}+git${SRCPV}"

REPO ??= "git://github.com/OP-TEE/optee_test.git;protocol=git"
SRC_URI = "${REPO};branch=${BRANCH}"

inherit python3native

# requires CROSS_COMPILE set by hand as there is no configure script
export CROSS_COMPILE="${TARGET_PREFIX}"

TA_DEV_KIT_DIR = "${TMPDIR}/deploy/images/${MACHINE}/optee/export-ta_arm64"
OPTEE_CLIENT_EXPORT = "${TMPDIR}/deploy/images/${MACHINE}/optee/export_client"

EXTRA_OEMAKE_append = " CROSS_COMPILE=${CROSS_COMPILE}"
EXTRA_OEMAKE_append = " CROSS_COMPILE_TA=${CROSS_COMPILE}"
EXTRA_OEMAKE_append = " TA_DEV_KIT_DIR=${TA_DEV_KIT_DIR}"
EXTRA_OEMAKE_append = " OPTEE_CLIENT_EXPORT=${OPTEE_CLIENT_EXPORT}"
EXTRA_OEMAKE_append = " COMPILE_NS_USER=64"

do_install() {
	install -d ${D}/lib/optee_armtz
	find ${S}/out/ta -type f -iname '*.ta' -exec install -m 0644 {} ${D}/lib/optee_armtz/ \;
	install -d ${D}${bindir}
	install -m 0744 ${S}/out/xtest/xtest ${D}${bindir}
}

FILES_${PN} = "/lib/optee_armtz"
FILES_${PN} += "/lib"
FILES_${PN} += "${bindir}"
