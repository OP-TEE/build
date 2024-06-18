ARG VER_MAJ
ARG VER
ARG INSTALL_DIR=/root/install

FROM ubuntu:22.04 as clang-build
ARG VER_MAJ
ARG VER
ARG INSTALL_DIR
RUN apt update -y && apt install -y \
	cmake \
	g++ \
	gcc \
	gcc-aarch64-linux-gnu \
	gcc-arm-linux-gnueabihf \
	git \
	ninja-build \
	python3
WORKDIR /root
RUN git clone --depth=1 -b llvmorg-${VER}  https://github.com/llvm/llvm-project.git

RUN mkdir /root/build
WORKDIR /root/build
RUN cmake ../llvm-project/llvm -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
	-DLLVM_ENABLE_PROJECTS="clang;lld;compiler-rt" \
	-DLLVM_TARGETS_TO_BUILD="AArch64;ARM;X86" \
	-DBUILD_SHARED_LIBS=ON
RUN ninja install

RUN mkdir /root/build-rt-armhf
WORKDIR /root/build-rt-armhf
RUN cmake ../llvm-project/compiler-rt -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/lib/clang/${VER_MAJ} \
	-DCMAKE_AR=${INSTALL_DIR}/bin/llvm-ar \
	-DCMAKE_ASM_COMPILER_TARGET="arm-linux-gnueabihf" \
	-DCMAKE_ASM_FLAGS="--target=arm-linux-gnueabihf -march=armv7a -mthumb" \
	-DCMAKE_C_COMPILER=${INSTALL_DIR}/bin/clang \
	-DCMAKE_C_COMPILER_TARGET="arm-linux-gnueabihf" \
	-DCMAKE_C_FLAGS="--target=arm-linux-gnueabihf -march=armv7a -mthumb" \
	-DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld" \
	-DCMAKE_NM=${INSTALL_DIR}/bin/llvm-nm \
	-DCMAKE_RANLIB=${INSTALL_DIR}/bin/llvm-ranlib \
	-DCOMPILER_RT_BUILD_BUILTINS=ON \
	-DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
	-DCOMPILER_RT_BUILD_MEMPROF=OFF \
	-DCOMPILER_RT_BUILD_PROFILE=OFF \
	-DCOMPILER_RT_BUILD_SANITIZERS=OFF \
	-DCOMPILER_RT_BUILD_XRAY=OFF \
	-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
	-DLLVM_CONFIG_PATH=${INSTALL_DIR}/bin/llvm-config
RUN ninja install

RUN mkdir /root/build-rt-aarch64
WORKDIR /root/build-rt-aarch64
RUN cmake ../llvm-project/compiler-rt -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/lib/clang/${VER_MAJ} \
	-DCMAKE_AR=${INSTALL_DIR}/bin/llvm-ar \
	-DCMAKE_ASM_COMPILER_TARGET="aarch64-linux-gnu" \
	-DCMAKE_C_COMPILER=${INSTALL_DIR}/bin/clang \
	-DCMAKE_C_COMPILER_TARGET="aarch64-linux-gnu" \
	-DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld" \
	-DCMAKE_NM=${INSTALL_DIR}/bin/llvm-nm \
	-DCMAKE_RANLIB=${INSTALL_DIR}/bin/llvm-ranlib \
	-DCOMPILER_RT_BUILD_BUILTINS=ON \
	-DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
	-DCOMPILER_RT_BUILD_MEMPROF=OFF \
	-DCOMPILER_RT_BUILD_PROFILE=OFF \
	-DCOMPILER_RT_BUILD_SANITIZERS=OFF \
	-DCOMPILER_RT_BUILD_XRAY=OFF \
	-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
	-DLLVM_CONFIG_PATH=${INSTALL_DIR}/bin/llvm-config
RUN ninja install

FROM scratch
ARG VER
ARG INSTALL_DIR
WORKDIR /root
COPY --from=clang-build ${INSTALL_DIR} /root/clang-${VER}
ENTRYPOINT null
