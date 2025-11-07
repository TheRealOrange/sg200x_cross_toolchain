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

# patch parallel build race condition (does not work otherwise)
RUN sed -i 's|utils/brmake -j\${NPROC}|utils/brmake|' /build/sdk/build/Makefile

ARG TARGET
ENV FORCE_UNSAFE_CONFIGURE=1

RUN ./build.sh ${TARGET}

# cross-compile container
FROM debian:12-slim AS cross-compile

ARG TARGETARCH
ARG TARGET

# base development tools
RUN apt-get update && apt-get install -y \
    build-essential cmake gdb-multiarch openssh-server findutils \
    && rm -rf /var/lib/apt/lists/*

# copy toolchain and sysroot from builder stage
COPY --from=builder /build/sdk/host-tools /opt/toolchain
COPY --from=builder /build/sdk/buildroot/output/${TARGET}/staging /opt/sysroot

# enable ssh
RUN mkdir -p /run/sshd && \
    echo 'root:root' | chpasswd && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# set up cross-compilation environment
RUN TOOLCHAIN=$(find /opt/toolchain/gcc -type d -name "*aarch64-linux-gnu" | sort -V | tail -1) && \
    ln -sf ${TOOLCHAIN}/bin/* /usr/local/bin/ && \
    { \
        echo "export TOOLCHAIN_PATH=${TOOLCHAIN}"; \
        echo "export CROSS_COMPILE=aarch64-linux-gnu-"; \
        echo "export SYSROOT=/opt/sysroot"; \
        echo "export CC=${TOOLCHAIN}/bin/aarch64-linux-gnu-gcc"; \
        echo "export CXX=${TOOLCHAIN}/bin/aarch64-linux-gnu-g++"; \
        echo "export PATH=${TOOLCHAIN}/bin:\$PATH"; \
        echo "export PKG_CONFIG_LIBDIR=/opt/sysroot/usr/lib/pkgconfig:/opt/sysroot/usr/share/pkgconfig"; \
        echo "export PKG_CONFIG_SYSROOT_DIR=/opt/sysroot"; \
    } >> /root/.bashrc

# set environment variables for build tools
ENV PKG_CONFIG_LIBDIR=/opt/sysroot/usr/lib/pkgconfig:/opt/sysroot/usr/share/pkgconfig
ENV PKG_CONFIG_SYSROOT_DIR=/opt/sysroot
ENV CMAKE_SYSROOT_DIR=/opt/sysroot

WORKDIR /workspace
EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]