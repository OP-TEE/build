#!/usr/bin/env bash
# Helper script to make a SD-card image for the official OP-TEE Raspberry Pi 3
# build.

set -e
WORKDIR=""

display_usage() {
	echo "Usage: $0 [options]"
	echo "Options:"
	echo "  -w|--workdir <dir> : The OP-TEE RPI3 working directory"
	echo "  -h|--help          : Display this help message"
}

while [[ $# -gt 0 ]]; do
	key="$1"
	case $key in
	-w | --workdir)
		WORKDIR="$2"
		shift 2
		;;
	-h | --help)
		display_usage
		exit 0
		;;
	*)
		echo "Invalid option: $1"
		display_usage
		exit 1
		;;
	esac
done

# No point to continue if files/folders we depend on are not existing.
check_exist() {
	local dir="$1"
	if [ ! -e "${dir}" ]; then
		echo "Folder ${dir} does not exist. Exiting..."
		exit 1
	fi
}

check_exist ${WORKDIR}

IMAGE_FILE=${WORKDIR}/out/rpi3-sdcard.img
rm -f ${IMAGE_FILE}

################################################################################
# Configuration
################################################################################
OFFSET_KIB=1024
BOOT_PARTITION_SIZE_MB=64
# ROOT FS size is read out from the rootfs file created by Buildroot, therefore
# we don't need to configure that here.

################################################################################
# Image and partition generation
################################################################################
# In bytes, always 512, when creating msdos/MBR images.
SECTOR_SIZE=512

# 1. Compute the sector size for the offset to the first partition.
OFFSET_SECTOR_SIZE=$((OFFSET_KIB * 1024 / SECTOR_SIZE))
echo "OFFSET_SECTOR_SIZE: $((OFFSET_KIB * 1024)) bytes ($((OFFSET_KIB / 1024))MB in ${OFFSET_SECTOR_SIZE} sectors)"

# 2. Calculate the boot partition sizes.
BOOT_PARTITION_SIZE_KIB=$((BOOT_PARTITION_SIZE_MB * 1024))
BOOT_PARTITION_SIZE_BYTES=$((BOOT_PARTITION_SIZE_KIB * 1024))
BOOT_PARTITION_SECTOR_SIZE=$((BOOT_PARTITION_SIZE_BYTES / SECTOR_SIZE))
echo "BOOT PARTITION SIZE: ${BOOT_PARTITION_SIZE_BYTES} bytes ($(($BOOT_PARTITION_SIZE_BYTES / 1024 / 1024))MB in ${BOOT_PARTITION_SECTOR_SIZE} sectors)"

# 3. Find out the size of the rootfs produced by Buildroot and calculate the
#    rootfs partition sizes.
ROOTFS_IMG=${WORKDIR}/out-br/images/rootfs.ext2
check_exist ${ROOTFS_IMG}
ROOTFS_SIZE_BYTES=$(stat -c %s ${ROOTFS_IMG})
ROOTFS_SECTOR_SIZE=$((ROOTFS_SIZE_BYTES / SECTOR_SIZE))
echo "ROOTFS PARTITION SIZE: ${ROOTFS_SIZE_BYTES} bytes ($((ROOTFS_SIZE_BYTES / 1024 / 1024))MB in ${ROOTFS_SECTOR_SIZE} sectors)"

# 4. Compute the images size, based on the rootfs size, the
#    desired boot image size and the offset to the first partition.
IMG_SECTOR_SIZE=$((OFFSET_SECTOR_SIZE + BOOT_PARTITION_SECTOR_SIZE + ROOTFS_SECTOR_SIZE))
IMG_SIZE_KIB=$((IMG_SECTOR_SIZE * SECTOR_SIZE / 1024))
echo "TOTAL IMAGE SIZE: ${IMG_SIZE_KIB} bytes ($((IMG_SIZE_KIB / 1024))MB in ${IMG_SECTOR_SIZE} sectors)"

# Create empty disk image
truncate -s ${IMG_SIZE_KIB}KiB ${IMAGE_FILE}

parted -s ${IMAGE_FILE} unit kiB mklabel msdos
parted -a optimal ${IMAGE_FILE} unit kiB mkpart primary fat16 ${OFFSET_KIB} ${BOOT_PARTITION_SIZE_KIB}
parted -a optimal ${IMAGE_FILE} set 1 boot on
parted -a optimal ${IMAGE_FILE} unit kiB mkpart primary ext4 $((OFFSET_KIB + BOOT_PARTITION_SIZE_KIB)) 100%

# Show some useful information about the image we just created.
echo ""
fdisk -l ${IMAGE_FILE}

################################################################################
# Copy the ext2 partition from Buildroot to the second partition.
################################################################################
dd if=${ROOTFS_IMG} of=${IMAGE_FILE} bs=${SECTOR_SIZE} seek=$((OFFSET_SECTOR_SIZE + BOOT_PARTITION_SECTOR_SIZE)) conv=notrunc,fsync

################################################################################
# Create the boot image and copy it to the boot partition
################################################################################
GENIMAGE=${WORKDIR}/out-br/host/bin/genimage
check_exist ${GENIMAGE}

# Used for a temporary genimage config file.
RPI3_GENIMAGE_CFG=$(mktemp)

# Used for temporarily storing files when creating the boot vfat image.
RPI3_GENIMAGE_TMPPATH=$(mktemp -d)
echo "RPI3_GENIMAGE_CFG: ${RPI3_GENIMAGE_CFG}"
echo "RPI3_GENIMAGE_TMPPATH: ${RPI3_GENIMAGE_TMPPATH}"

trap "rm -rf ${RPI3_GENIMAGE_CFG} ${RPI3_GENIMAGE_TMPPATH}" EXIT

BOOT_PARTITION_FILES=${WORKDIR}/out/boot
check_exist ${BOOT_PARTITION_FILES}

# Create the config file for genimage on the fly.
cat <<EOF >${RPI3_GENIMAGE_CFG}
image boot.vfat {
        vfat {
        }

        size = ${BOOT_PARTITION_SIZE_MB}M
        mountpoint = "/"
}
EOF

# Create the boot.vfat image.
${GENIMAGE} --rootpath ${BOOT_PARTITION_FILES} --config ${RPI3_GENIMAGE_CFG} --tmppath=${RPI3_GENIMAGE_TMPPATH} --outputpath=${WORKDIR}/out

# Copy the contents of boot.vfat to the boot partition in the image we prepared.
dd if=${WORKDIR}/out/boot.vfat of=${IMAGE_FILE} bs=${SECTOR_SIZE} seek=${OFFSET_SECTOR_SIZE} conv=notrunc,fsync
