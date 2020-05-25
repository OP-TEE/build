#!/bin/bash
#
# Download and extract Clang from the GitHub release page.
# We want a x86_64 cross-compiler capable of generating aarch64 and armv7a code
# *and* we want the compiler-rt libraries for these architectures
# (libclang_rt.*.a).
# Clang is configured to be able to cross-compile to all the supported
# architectures by default (see <clang path>/bin/llc --version) which is great,
# but compiler-rt is included only for the host architecture. Therefore we need
# to combine several packages into one, which is the purpose of this script.
#
# Usage: get_clang.sh [path]

DEST=${1:-./clang-9.0.1}

VER=9.0.1
X86_64=clang+llvm-${VER}-x86_64-linux-gnu-ubuntu-16.04
AARCH64=clang+llvm-${VER}-aarch64-linux-gnu
ARMV7A=clang+llvm-${VER}-armv7a-linux-gnueabihf

set -x

TMPDEST=${DEST}_tmp${RANDOM}

if [ -e ${TMPDEST} ]; then
  echo Error: ${TMPDEST} exists
  exit 1
fi

function cleanup() {
  rm -f ${X86_64}.tar.xz ${AARCH64}.tar.xz ${ARMV7A}.tar.xz
  rm -rf ${AARCH64} ${ARMV7A}
}

trap "{ exit 2; }" INT
trap cleanup EXIT

(wget -nv https://github.com/llvm/llvm-project/releases/download/llvmorg-${VER}/${X86_64}.tar.xz && tar xf ${X86_64}.tar.xz) &
pids=$!
(wget -nv https://github.com/llvm/llvm-project/releases/download/llvmorg-${VER}/${AARCH64}.tar.xz && tar xf ${AARCH64}.tar.xz) &
pids="$pids $!"
(wget -nv https://github.com/llvm/llvm-project/releases/download/llvmorg-${VER}/${ARMV7A}.tar.xz && tar xf ${ARMV7A}.tar.xz) &
pids="$pids $!"

wait $pids || exit 1

mv ${X86_64} ${TMPDEST} || exit 1
cp ${AARCH64}/lib/clang/${VER}/lib/linux/* ${TMPDEST}/lib/clang/${VER}/lib/linux || exit 1
cp ${ARMV7A}/lib/clang/${VER}/lib/linux/* ${TMPDEST}/lib/clang/${VER}/lib/linux || exit 1
mv ${TMPDEST} ${DEST}
