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

# find the correct toolchain based on TARGET var
# to choose which toolchain pattern to keep
# for ARM toolchains, pick the latest version
RUN cd /build/sdk/host-tools/gcc && \
    if echo "${TARGET}" | grep -qi "riscv\|cv180\|cv181"; then \
        PATTERN="riscv64-linux"; \
        echo "using riscv64-linux toolchains matching: ${PATTERN}"; \
        mkdir -p /tmp/keep; \
        for tc in riscv64-linux-*; do \
            if [ -d "$tc" ]; then \
                echo "using: $tc"; \
                mv "$tc" /tmp/keep/; \
            fi; \
        done; \
    else \
        if echo "${TARGET}" | grep -qi "arm64\|aarch64"; then \
            PATTERN="aarch64-linux-gnu"; \
        elif echo "${TARGET}" | grep -qi "arm"; then \
            PATTERN="arm-linux-gnueabihf"; \
        else \
            PATTERN="aarch64-linux-gnu"; \
        fi; \
        echo "using arm64 toolchain matching: ${PATTERN}"; \
        SELECTED=$(find . -maxdepth 1 -type d -name "*${PATTERN}*" | sort -V | tail -1); \
        if [ -z "$SELECTED" ]; then \
            echo "no toolchain found matching pattern: ${PATTERN}"; \
            ls -la .; \
            exit 1; \
        fi; \
        echo "using: ${SELECTED}"; \
        mkdir -p /tmp/keep; \
        mv ${SELECTED} /tmp/keep/; \
    fi && \
    rm -rf ./* && \
    mv /tmp/keep/* . && \
    rm -rf /tmp/keep && \
    echo "toolchain selection complete:" && \
    ls -la .

# cross-compile container
FROM debian:12-slim AS cross-compile

ARG TARGETARCH
ARG TARGET

# install toolchains based on TARGET for cross compiling
RUN apt-get update && \
    if echo "${TARGET}" | grep -qi "riscv\|cv180\|cv181"; then \
        apt-get install -y gcc-riscv64-linux-gnu g++-riscv64-linux-gnu; \
    elif echo "${TARGET}" | grep -qi "arm64\|aarch64"; then \
        apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu; \
    elif echo "${TARGET}" | grep -qi "arm"; then \
        apt-get install -y gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf; \
    else \
        apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu; \
    fi && \
    apt-get install -y \
        build-essential \
        cmake \
        gdb-multiarch \
        openssh-server \
        findutils \
        && \
    rm -rf /var/lib/apt/lists/*

# copy the sysroot from the builder stage
COPY --from=builder /build/sdk/buildroot/output/${TARGET}/staging /opt/sysroot

# symlink sysroot to where debians cross-compiler expects libraries
RUN if echo "${TARGET}" | grep -qi "riscv\|cv180\|cv181"; then \
        mkdir -p /lib/riscv64-linux-gnu /usr/lib/riscv64-linux-gnu && \
        cp -rs /opt/sysroot/lib/* /lib/riscv64-linux-gnu/ && \
        cp -rs /opt/sysroot/usr/lib/* /usr/lib/riscv64-linux-gnu/; \
    elif echo "${TARGET}" | grep -qi "arm64\|aarch64"; then \
        mkdir -p /lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu && \
        cp -rs /opt/sysroot/lib/* /lib/aarch64-linux-gnu/ && \
        cp -rs /opt/sysroot/usr/lib/* /usr/lib/aarch64-linux-gnu/; \
    elif echo "${TARGET}" | grep -qi "arm"; then \
        mkdir -p /lib/arm-linux-gnueabihf /usr/lib/arm-linux-gnueabihf && \
        cp -rs /opt/sysroot/lib/* /lib/arm-linux-gnueabihf/ && \
        cp -rs /opt/sysroot/usr/lib/* /usr/lib/arm-linux-gnueabihf/; \
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