#!/bin/bash
#
# Download and extract Clang from the GitHub release page.
# We want a x86_64 cross-compiler capable of generating aarch64 and armv7a code
# *and* we want the compiler-rt libraries for these architectures
# (libclang_rt.*.a).
# Clang is configured to be able to cross-compile to all the supported
# architectures by default (see <clang path>/bin/llc --version) which is great,
# but compiler-rt is included only for the host architecture. Therefore we need
# a custom build of clang, which is achieved by [1].
# This script retrieves a pre-compiled image from the Docker Hub and extracts
# the compiler.

[ "$1" ] || { echo "Usage: get_clang.sh version [path]"; exit 1; }

VER=${1}
DEST=${2:-./clang-${VER}}

ARCH=$(uname -m)
set -e -x

id=$(docker create jforissier/clang-${VER}-${ARCH})
docker cp $id:/root/clang-${VER} ${DEST}
docker rm ${id}
docker rmi jforissier/clang-${VER}-${ARCH}
