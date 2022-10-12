################################################################################
#
# docopt.cpp_ext
#
################################################################################

DOCOPT_CPP_EXT_VERSION = 0.6.3
DOCOPT_CPP_EXT_SOURCE = v$(DOCOPT_CPP_EXT_VERSION).tar.gz
DOCOPT_CPP_EXT_SITE = https://github.com/docopt/docopt.cpp/archive/refs/tags
DOCOPT_CPP_EXT_INSTALL_STAGING = YES
DOCOPT_CPP_EXT_LICENSE_FILES = LICENSE-Boost-1.0 LICENSE-MIT

$(eval $(cmake-package))
