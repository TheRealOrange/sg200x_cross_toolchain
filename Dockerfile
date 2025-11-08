ARG TARGET=milkv-duos-glibc-arm64-emmc
ARG SDK_HASH=6f8962c394dd0a05729abb089f0feb7d5cc4aa5e
ARG ARM_TOOLCHAIN_VERSION=14.3.Rel1
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

# we wont use the toolchains from host-tools because
# we will just use official toolchains

# cross-compile container
FROM debian:12-slim AS cross-compile

# install base dependencies
RUN apt-get update && \
    apt-get install -y \
        wget \
        xz-utils \
        build-essential \
        cmake \
        gdb-multiarch \
        openssh-server \
        findutils \
        && \
    rm -rf /var/lib/apt/lists/*

ARG TARGETARCH
ARG TARGET
ARG ARM_TOOLCHAIN_VERSION

# install toolchains based on TARGET
# for riscv64 use debian's toolchain (needs symlinks)
# for arm64/arm32 download arm's official toolchain
RUN if echo "${TARGET}" | grep -qi "riscv\|cv180\|cv181"; then \
        apt-get update && \
        apt-get install -y gcc-riscv64-linux-gnu g++-riscv64-linux-gnu && \
        rm -rf /var/lib/apt/lists/*; \
    elif echo "${TARGET}" | grep -qi "arm64\|aarch64"; then \
        # Map TARGETARCH to ARM's toolchain host naming
        if [ "${TARGETARCH}" = "amd64" ]; then \
            TOOLCHAIN_HOST="x86_64"; \
        elif [ "${TARGETARCH}" = "arm64" ]; then \
            TOOLCHAIN_HOST="aarch64"; \
        else \
            echo "unsupported TARGETARCH: ${TARGETARCH}"; \
            exit 1; \
        fi; \
        TOOLCHAIN_URL="https://developer.arm.com/-/media/Files/downloads/gnu/${ARM_TOOLCHAIN_VERSION}/binrel/arm-gnu-toolchain-${ARM_TOOLCHAIN_VERSION}-${TOOLCHAIN_HOST}-aarch64-none-linux-gnu.tar.xz"; \
        echo "downloading arm toolchain for aarch64 (host: ${TOOLCHAIN_HOST}) from: ${TOOLCHAIN_URL}"; \
        wget -q "${TOOLCHAIN_URL}" -O /tmp/toolchain.tar.xz && \
        mkdir -p /opt/toolchain && \
        tar xf /tmp/toolchain.tar.xz -C /opt/toolchain --strip-components=1 && \
        rm /tmp/toolchain.tar.xz; \
    elif echo "${TARGET}" | grep -qi "arm"; then \
        # Map TARGETARCH to ARM's toolchain host naming
        if [ "${TARGETARCH}" = "amd64" ]; then \
            TOOLCHAIN_HOST="x86_64"; \
        elif [ "${TARGETARCH}" = "arm64" ]; then \
            TOOLCHAIN_HOST="aarch64"; \
        else \
            echo "Unsupported TARGETARCH: ${TARGETARCH}"; \
            exit 1; \
        fi; \
        TOOLCHAIN_URL="https://developer.arm.com/-/media/Files/downloads/gnu/${ARM_TOOLCHAIN_VERSION}/binrel/arm-gnu-toolchain-${ARM_TOOLCHAIN_VERSION}-${TOOLCHAIN_HOST}-arm-none-linux-gnueabihf.tar.xz"; \
        echo "downloading arm toolchain for arm32 (host: ${TOOLCHAIN_HOST}) from: ${TOOLCHAIN_URL}"; \
        wget -q "${TOOLCHAIN_URL}" -O /tmp/toolchain.tar.xz && \
        mkdir -p /opt/toolchain && \
        tar xf /tmp/toolchain.tar.xz -C /opt/toolchain --strip-components=1 && \
        rm /tmp/toolchain.tar.xz; \
    fi

# add arm toolchain to path
RUN if echo "${TARGET}" | grep -qi "arm64\|aarch64\|arm"; then \
        echo 'export PATH="/opt/toolchain/bin:$PATH"' >> /root/.bashrc; \
    fi
ENV PATH="/opt/toolchain/bin:${PATH}"

# copy the sysroot from the builder stage
COPY --from=builder /build/sdk/buildroot/output/${TARGET}/staging /opt/sysroot

# symlink sysroot for riscv targets (debian is stinky and its toolchain has hardcoded paths)
# arm's official toolchain respects --sysroot
# hacky as hell i hate this actually
RUN if echo "${TARGET}" | grep -qi "riscv\|cv180\|cv181"; then \
        mkdir -p /lib/riscv64-linux-gnu /usr/lib/riscv64-linux-gnu && \
        cd /opt/sysroot/lib && for f in *; do ln -sf "/opt/sysroot/lib/$f" "/lib/riscv64-linux-gnu/$f"; done && \
        cd /opt/sysroot/usr/lib && for f in *; do ln -sf "/opt/sysroot/usr/lib/$f" "/usr/lib/riscv64-linux-gnu/$f"; done; \
    fi

# enable ssh
RUN mkdir -p /run/sshd && \
    echo 'root:root' | chpasswd && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# set up envars for cross compilation environment based on TARGET
RUN if echo "${TARGET}" | grep -qi "riscv\|cv180\|cv181"; then \
        CROSS_PREFIX="riscv64-linux-gnu"; \
    elif echo "${TARGET}" | grep -qi "arm64\|aarch64"; then \
        CROSS_PREFIX="aarch64-linux-gnu"; \
    elif echo "${TARGET}" | grep -qi "arm"; then \
        CROSS_PREFIX="arm-linux-gnueabihf"; \
    else \
        CROSS_PREFIX="aarch64-linux-gnu"; \
    fi && \
    { \
        echo "export CROSS_COMPILE=${CROSS_PREFIX}-"; \
        echo "export SYSROOT=/opt/sysroot"; \
        echo "export CC=${CROSS_PREFIX}-gcc"; \
        echo "export CXX=${CROSS_PREFIX}-g++"; \
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