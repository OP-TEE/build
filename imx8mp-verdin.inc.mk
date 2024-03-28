################################################################################
# Board specific
# Toradex Verdin iMX8M Plus board is based on NXP i.MX8M Plus SoC
# Variants from 1 to 8 GB LPDDR4s (1/2/4/8Gb)
################################################################################
TFA_PLATFORM      := imx8mp
OPTEE_OS_PLATFORM := imx-mx8mpevk
U_BOOT_DEFCONFIG  := verdin-imx8mp_defconfig
U_BOOT_DT         := imx8mp-verdin-wifi-dev.dtb
LINUX_DT          := imx8mp-verdin-wifi-dev.dtb
MKIMAGE_DT        := fsl-imx8mp-evk.dtb
MKIMAGE_SOC       := iMX8MP
ATF_LOAD_ADDR     := 0x00970000
TEE_LOAD_ADDR     := 0xfe000000
UART_BASE         := 0x30880000
DDR_SIZE          := 0x100000000

BR2_TARGET_GENERIC_GETTY_PORT := ttymxc2

FIRMWARE_VERSION        := firmware-imx-8.22
FIRMWARE_BIN_SHA256_SUM := 94c8bceac56ec503c232e614f77d6bbd8e17c7daa71d4e651ea8fd5034c30350

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += CFG_DDR_SIZE=$(DDR_SIZE)
OPTEE_OS_COMMON_FLAGS += CFG_TZDRAM_START=${TEE_LOAD_ADDR}
OPTEE_OS_COMMON_FLAGS += CFG_UART_BASE=$(UART_BASE)
OPTEE_OS_COMMON_FLAGS += CFG_TZC380=y

################################################################################
# ARM Trusted Firmware
################################################################################
TF_A_FLAGS += BL32_BASE=$(TEE_LOAD_ADDR)
TF_A_FLAGS += ERRATA_A53_1530924=1
TF_A_FLAGS += IMX_BOOT_UART_BASE=$(UART_BASE)
