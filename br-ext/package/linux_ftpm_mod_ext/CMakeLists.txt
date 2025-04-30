cmake_minimum_required (VERSION 3.5)
project(linux_ftpm_mod_ext)

# This is a dummy Makefile. When this package is invoked, the TPM Kernel
# module has been built already.
install(FILES /dev/null DESTINATION /dev/null)
