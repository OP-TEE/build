#!/usr/bin/make -f
#
# Sign/encrypt a Linux Kernel zImage, a DTB file, and a rootfs (to be used
# as an initramfs) into a FIT image tree blob for loading through U-Boot on a
# TI High Security (HS) SoC.
#
# Copyright (C) 2016-2017, Texas Instruments, Incorporated - http://www.ti.com/
#	Andreas Dannenberg <dannenberg@ti.com>
#	Andrew F. Davis <afd@ti.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#

ITB ?= fitImage
ITS ?= $(ITB:=.its)

SEC_IMAGES := $(shell sed -n 's/.*\/incbin\/.*\"\(.*\.sec\)\".*/\1/p' $(ITS))

.PHONY: all
all: $(ITB)

# Invoke signing tool from the TI Secure Dev package to sign and optionally
# encrypt a binary blob. This tool is accessed through the use of the
# TI_SECURE_DEV_PKG environmental variable in the same fashion as it is used
# when building secure U-Boot for TI devices.
%.sec: %
ifneq ($(TI_SECURE_DEV_PKG),)
ifneq ($(wildcard $(TI_SECURE_DEV_PKG)/scripts/secure-binary-image.sh),)
	$(TI_SECURE_DEV_PKG)/scripts/secure-binary-image.sh $(patsubst %.sec,%,$@) $@
else
	@echo "ERROR: $(TI_SECURE_DEV_PKG)/scripts/secure-binary-image.sh not found." \
	      "$@ was NOT created!"; exit 1
endif
else
	@echo "ERROR: TI_SECURE_DEV_PKG environment variable must be defined" \
	      "for TI secure devices. $@ was NOT created!"; exit 1
endif

# Compile a FIT image tree source file describing the final image tree blob.
# Use the mkimage tool that comes with U-Boot to make sure we have the latest/
# greatest as we are using advanced features such as FIT...
MKIMAGE ?= mkimage
$(ITB): $(ITS) $(SEC_IMAGES)
	$(MKIMAGE) -f $< -r $@

.PHONY: clean
clean:
	-$(RM) -v $(SEC_IMAGES)
	-$(RM) -v $(ITB)
