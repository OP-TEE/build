cmake_minimum_required (VERSION 3.5)
project(ftpm_optee_ext)

# This is a dummy Makefile. When this package is invoked, the fTPM service
# has been built already.
install(FILES /dev/null DESTINATION /dev/null)
