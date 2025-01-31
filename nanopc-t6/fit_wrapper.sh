#!/bin/sh
# file: fit_wrapper.sh
export TEE_LOAD_ADDR=0x30000000
exec arch/arm/mach-rockchip/make_fit_atf.sh
