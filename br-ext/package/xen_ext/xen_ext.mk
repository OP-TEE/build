################################################################################
#
# Xen_ext
#
################################################################################

XEN_EXT_VERSION = git
XEN_EXT_SITE = $(if $(BR2_PACKAGE_XEN_EXT_SITE),$(BR2_PACKAGE_XEN_EXT_SITE),"")
XEN_EXT_SITE_METHOD = local
XEN_EXT_LICENSE = GPL-2.0
XEN_EXT_LICENSE_FILES = COPYING
XEN_EXT_CPE_ID_VENDOR = xen
XEN_EXT_CPE_ID_PREFIX = cpe:2.3:o
XEN_EXT_DEPENDENCIES = host-acpica host-python3 host-meson host-pkgconf libglib2 zlib pixman

# Calculate XEN_EXT_ARCH
ifeq ($(ARCH),aarch64)
XEN_EXT_ARCH = arm64
else ifeq ($(ARCH),arm)
XEN_EXT_ARCH = arm32
endif

XEN_EXT_CONF_OPTS = \
	--disable-golang \
	--disable-ocamltools \
	--with-initddir=/etc/init.d

XEN_EXT_CONF_ENV = PYTHON=$(HOST_DIR)/bin/python3
XEN_EXT_MAKE_ENV = \
	XEN_TARGET_ARCH=$(XEN_EXT_ARCH) \
	CROSS_COMPILE=$(TARGET_CROSS) \
	HOST_EXTRACFLAGS="-Wno-error" \
	XEN_HAS_CHECKPOLICY=n \
	$(TARGET_CONFIGURE_OPTS)

ifeq ($(BR2_PACKAGE_XEN_EXT_HYPERVISOR),y)
XEN_EXT_MAKE_OPTS += dist-xen
XEN_EXT_INSTALL_IMAGES = YES
define XEN_EXT_INSTALL_IMAGES_CMDS
	cp $(@D)/xen/xen $(BINARIES_DIR)
endef
else
XEN_EXT_CONF_OPTS += --disable-xen
endif

ifeq ($(BR2_PACKAGE_XEN_EXT_TOOLS),y)
XEN_EXT_DEPENDENCIES += \
	dtc libaio libglib2 ncurses openssl pixman slirp util-linux yajl
ifeq ($(BR2_PACKAGE_ARGP_STANDALONE),y)
XEN_EXT_DEPENDENCIES += argp-standalone
endif
XEN_EXT_INSTALL_TARGET_OPTS += DESTDIR=$(TARGET_DIR) install-tools
XEN_EXT_MAKE_OPTS += dist-tools

define XEN_EXT_INSTALL_INIT_SYSV
	mv $(TARGET_DIR)/etc/init.d/xencommons $(TARGET_DIR)/etc/init.d/S50xencommons
	mv $(TARGET_DIR)/etc/init.d/xen-watchdog $(TARGET_DIR)/etc/init.d/S50xen-watchdog
	mv $(TARGET_DIR)/etc/init.d/xendomains $(TARGET_DIR)/etc/init.d/S60xendomains
endef

XEN_EXT_CONF_OPTS += --with-system-qemu
XEN_EXT_INSTALL_STAGING = YES
else
XEN_EXT_INSTALL_TARGET = NO
XEN_EXT_CONF_OPTS += --disable-tools
endif

$(eval $(autotools-package))
