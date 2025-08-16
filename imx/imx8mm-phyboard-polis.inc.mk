################################################################################
# Board specific
# phyBOARD-Polis i.MX 8M Mini
# Variants from 1 to 4 GiB LPDDR4 RAM (1/2/4GiB)
################################################################################
TFA_PLATFORM      := imx8mm
OPTEE_OS_PLATFORM := imx-mx8mm_phyboard_polis
U_BOOT_DEFCONFIG  := phycore-imx8mm_defconfig
U_BOOT_DT         := imx8mm-phyboard-polis-rdk.dtb
U_BOOT_OFFSET     := 33
LINUX_DT          := imx8mm-phyboard-polis-rdk.dtb
MKIMAGE_SOC       := iMX8MM
ATF_LOAD_ADDR     := 0x00970000
TEE_LOAD_ADDR     := 0x7e000000
IMX_BOOT_SCRIPT   := imx8m_boot_script

BR2_TARGET_GENERIC_GETTY_PORT := ttymxc2

FIRMWARE_VERSION        := firmware-imx-8.22
FIRMWARE_BIN_SHA256_SUM := 94c8bceac56ec503c232e614f77d6bbd8e17c7daa71d4e651ea8fd5034c30350

################################################################################
# ARM Trusted Firmware
################################################################################
TF_A_FLAGS += BL32_BASE=$(TEE_LOAD_ADDR)
TF_A_FLAGS += ERRATA_A53_1530924=1
TF_A_FLAGS += IMX_BOOT_UART_BASE=auto
