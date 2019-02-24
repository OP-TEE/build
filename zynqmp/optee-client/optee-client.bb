OPTEE_VERSION ??= "latest"
SRCREV ??= "${AUTOREV}"
BRANCH ??= "master"

DESCRIPTION = "OP-TEE Client"

LICENSE = "BSD"
LIC_FILES_CHKSUM = "file://LICENSE;md5=69663ab153298557a59c67a60a743e5b"

PROVIDES = "virtual/optee-client"
DEPENDS += "virtual/optee-os"

S = "${WORKDIR}/git"
PV = "${OPTEE_VERSION}+git${SRCPV}"

REPO ??= "git://github.com/OP-TEE/optee_client.git;protocol=https"
SRC_URI = "${REPO};branch=${BRANCH}"

# requires CROSS_COMPILE set by hand as there is no configure script
export CROSS_COMPILE="${TARGET_PREFIX}"

EXPORT_DIR = "${TMPDIR}/deploy/images/${MACHINE}/optee/export_client"

EXTRA_OEMAKE_append = " CROSS_COMPILE=${CROSS_COMPILE}"
EXTRA_OEMAKE_append = " DESTDIR=${EXPORT_DIR}"
EXTRA_OEMAKE_append = " SBINDIR=/sbin"
EXTRA_OEMAKE_append = " LIBDIR=/lib"
EXTRA_OEMAKE_append = " INCLUDEDIR=/include"

do_install() {
	oe_runmake install
	install -d ${D}${libdir}
	install -m 0644 ${EXPORT_DIR}/lib/libteec.so.1.0.0 ${D}${libdir}
	install -d ${D}${sbindir}
	install -m 0744 ${EXPORT_DIR}/sbin/tee-supplicant ${D}${sbindir}
}
