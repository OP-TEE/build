################################################################################
# Board specific
################################################################################
TFA_PLATFORM      := imx8mp
OPTEE_OS_PLATFORM := imx-mx8mpevk
U_BOOT_DEFCONFIG  := imx8mp_evk_defconfig
U_BOOT_DT         := imx8mp-evk.dtb
U_BOOT_OFFSET     := 32
LINUX_DT          := imx8mp-evk.dtb
MKIMAGE_SOC       := iMX8MP
IMX_BOOT_SCRIPT   := imx8m_boot_script

BR2_TARGET_GENERIC_GETTY_PORT := ttymxc2

FIRMWARE_VERSION	:= firmware-imx-8.10.1
FIRMWARE_BIN_SHA256_SUM := da415c32063c08fce8f52734f198b19ab06bd7d4333a4df900f8831df562f8fc
