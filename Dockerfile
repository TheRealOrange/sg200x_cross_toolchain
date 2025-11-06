ARG TARGET=milkv-duos-glibc-arm64-emmc
ARG SDK_HASH=6f8962c394dd0a05729abb089f0feb7d5cc4aa5e
ARG BUILDPLATFORM
ARG TARGETPLATFORM
ARG TARGETARCH

FROM --platform=linux/amd64 milkvtech/milkv-duo:latest AS builder

WORKDIR /build
RUN git clone https://github.com/milkv-duo/duo-buildroot-sdk-v2.git sdk
RUN git clone https://github.com/milkv-duo/host-tools.git host-tools
RUN wget https://github.com/milkv-duo/duo-buildroot-sdk-v2/releases/download/dl/dl.tar

ARG SDK_HASH
WORKDIR /build/sdk
RUN git checkout ${SDK_HASH}

WORKDIR /build
RUN cp -a host-tools sdk/
RUN tar xf dl.tar -C sdk/buildroot/ && rm dl.tar

WORKDIR /build/sdk
# patch parallel build race condition in build_middleware() (https://github.com/milkv-duo/duo-buildroot-sdk-v2/issues/57)
RUN sed -i '/^function build_middleware()/,/^}/s/make all -j\$(nproc)/make all/' build/envsetup_milkv.sh

ARG TARGET
ENV FORCE_UNSAFE_CONFIGURE=1

# build all SDK components individually
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && clean_all
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && build_uboot
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && build_kernel
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && build_ramboot
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && build_osdrv
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && build_3rd_party
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && build_middleware
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && build_cvi_rtsp
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && build_tpu_sdk
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && build_ive_sdk
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && build_ivs_sdk
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && build_tdl_sdk
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && build_pqtool_server

# patch parallel build race condition (does not work otherwise)
RUN sed -i 's|utils/brmake -j\${NPROC}|utils/brmake|' /build/sdk/build/Makefile

RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && pack_cfg
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && pack_rootfs
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && pack_rootfs
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && pack_data
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && pack_system
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && copy_tools
RUN cd /build/sdk && . build/envsetup_milkv.sh ${TARGET} && pack_upgrade

FROM ubuntu:22.04 AS cross-compile

ARG TARGETARCH
ARG TARGET

# base development tools
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    curl \
    wget \
    file \
    gdb-multiarch \
    qemu-user-static \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# copy toolchain and sysroot from builder stage
COPY --from=builder /build/sdk/host-tools /opt/toolchain
COPY --from=builder /build/sdk/buildroot/output/${TARGET}/staging /opt/sysroot

RUN mkdir -p /run/sshd && \
    echo 'root:root' | chpasswd && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# set envars for cross-compilation environment
RUN TOOLCHAIN=$(find /opt/toolchain/gcc -type d -name "*-x86_64" | head -1) && \
    CROSS=$(basename $TOOLCHAIN | sed 's/-x86_64//')-  && \
    echo "export TOOLCHAIN_PATH=${TOOLCHAIN}" >> /root/.bashrc && \
    echo "export CROSS_COMPILE=${CROSS}" >> /root/.bashrc && \
    echo "export SYSROOT=/opt/sysroot" >> /root/.bashrc && \
    echo "export CC=\${TOOLCHAIN}/bin/\${CROSS}gcc" >> /root/.bashrc && \
    echo "export CXX=\${TOOLCHAIN}/bin/\${CROSS}g++" >> /root/.bashrc && \
    echo "export AR=\${TOOLCHAIN}/bin/\${CROSS}ar" >> /root/.bashrc && \
    echo "export STRIP=\${TOOLCHAIN}/bin/\${CROSS}strip" >> /root/.bashrc && \
    echo "export PATH=\${TOOLCHAIN}/bin:\$PATH" >> /root/.bashrc

WORKDIR /workspace
EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]