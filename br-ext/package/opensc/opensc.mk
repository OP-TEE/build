################################################################################
#
# OpenSC
#
################################################################################

OPENSC_VERSION = 0.21.0
OPENSC_SOURCE = OpenSC-$(OPENSC_VERSION).tar.gz
OPENSC_SITE = $(call github,OpenSC,OpenSC,$(OPENSC_VERSION))
#OPENSC_SITE_METHOD = git

OPENSC_INSTALL_STAGING = NO
OPENSC_INSTALL_TARGET = YES

OPENSC_AUTORECONF = YES
OPENSC_AUTORECONF_OPTS = --verbose --install --force
OPENSC_DEPENDENCIES = pcsc-lite

# Default rely on OP-TEE PKCS11 TA as PKCS11 provider
OPENSC_CONF_OPTS = --with-pkcs11-provider=/usr/lib/libckteec.so

# We don't really need OpenSSL...
ifeq ($(BR2_PACKAGE_OPENSSL),y)
OPENSC_DEPENDENCIES = openssl
OPENSC_CONF_OPTS += --with-crypto-backend=openssl
endif

$(eval $(autotools-package))
