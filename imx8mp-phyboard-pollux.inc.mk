################################################################################
# Board specific
# phyBOARD-Pollux i.MX 8M Plus
# Variants from 1 to 4 GB LPDDR4 (1/2/4GB)
################################################################################
TFA_PLATFORM      := imx8mp
OPTEE_OS_PLATFORM := imx-mx8mp_phyboard_pollux
U_BOOT_DEFCONFIG  := phycore-imx8mp_defconfig
U_BOOT_DT         := imx8mp-phyboard-pollux-rdk.dtb
U_BOOT_OFFSET     := 32
LINUX_DT          := imx8mp-phyboard-pollux-rdk.dtb
MKIMAGE_SOC       := iMX8MP
ATF_LOAD_ADDR     := 0x00970000
TEE_LOAD_ADDR     := 0x56000000
UART_BASE         := 0x30860000
DDR_SIZE          := 0x80000000
IMX_BOOT_SCRIPT   := imx8m_boot_script

BR2_TARGET_GENERIC_GETTY_PORT := ttymxc0

FIRMWARE_VERSION        := firmware-imx-8.22
FIRMWARE_BIN_SHA256_SUM := 94c8bceac56ec503c232e614f77d6bbd8e17c7daa71d4e651ea8fd5034c30350

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += CFG_TZDRAM_START=$(TEE_LOAD_ADDR)

################################################################################
# ARM Trusted Firmware
################################################################################
TF_A_FLAGS += BL32_BASE=$(TEE_LOAD_ADDR)
TF_A_FLAGS += ERRATA_A53_1530924=1
TF_A_FLAGS += IMX_BOOT_UART_BASE=$(UART_BASE)
