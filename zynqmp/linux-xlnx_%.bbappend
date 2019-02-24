SRC_URI += "file://bsp.cfg \
            "
SRC_URI_append += "file://kernel_optee.cfg"

FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"
