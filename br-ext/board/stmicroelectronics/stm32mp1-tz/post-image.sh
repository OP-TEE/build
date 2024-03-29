#!/bin/sh

die() {
	cat <<EOF >&2
Error: $@

Usage: ${0} IMG_DIR GENIMAGE_CFG EXT_BIN_DIR [BOOTFS_OVERLAY]
EOF
	exit 1
}

echo "Creating bootfs image"
echo "- image directory path: ${1}" # Generic argument set by Buildroot
echo "- genimage config file: ${2}"
echo "- external bins path:   ${3}"
echo "- bootfs overlay path:  ${4}"
echo "- TF-A DTB basename:    ${5}"
echo "- Linux DTB basename:   ${6}"

[ ! -z "${2}" -a -e ${2} ] || die "Error: missing argument genimage config file"
[ ! -z "${3}" -a -d ${3} ] || die "Error: missing argument external binaries dir"
[ -z "${4}" -o -d ${4} ] || die "Error: invalid bootfs overlay directory path"

GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
GENIMAGE_IN="${BUILD_DIR}/genimage.in"

# Create target bootfs filesystem
# - Copy uImage and DTBs from path provided in arg $3 into boot/
# - Copy bootfs overlay filetree from path provided in optional arg $4

BOOTFS_DIR=${BASE_DIR}/target-bootfs
rm -f ${BINARIES_DIR}/bootfs.ext2 || exit 1
rm -rf ${BOOTFS_DIR} && mkdir -p ${BOOTFS_DIR}/boot || exit 1
cp --dereference ${3}/uImage ${BOOTFS_DIR}/boot || exit 1
for f in ${3}/*.dtb; do
	test -f $f && { cp --dereference  $f ${BOOTFS_DIR}/boot || exit 1; }
done
[ -z "${4}" ] || { cp -ar ${4}/* ${BOOTFS_DIR} || exit 1; }

# Set TF-A file name in genimage config file
echo "[GEN] Generate genimage file for target ${5} GPT formating"
sed s/TFA_BOARD_REV/${5}/g ${2} > ${GENIMAGE_IN}

# Set Linux DTB file basename in genimage config file
echo "[GEN] Generate extlinux.conf for target ${6} autoboot"
sed -i s/LINUX_DTB_BASENAME/${6}/g ${BOOTFS_DIR}/boot/extlinux/extlinux.conf

# Create bootfs EXT2 file system.
mkfs.ext2 -L bootfs -d ${BOOTFS_DIR} ${BINARIES_DIR}/bootfs.ext2 32M || exit 1

# Generate image from generated partition images and genimage config file

rm -rf "${GENIMAGE_TMP}"

genimage --rootpath "${ROOTPATH_TMP}" \
         --tmppath "${GENIMAGE_TMP}" \
         --inputpath "${BINARIES_DIR}" \
         --outputpath "${BINARIES_DIR}" \
         --config ${GENIMAGE_IN}
