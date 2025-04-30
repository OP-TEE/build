cmake_minimum_required (VERSION 3.5)
project(optee_os_ext)

# This is a dummy Makefile. When this package is invoked, OP-TEE has been built
# already, and the only installation step occurs in optee_os.mk.
install(FILES /dev/null DESTINATION /dev/null)
