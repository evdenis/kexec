# Dockerfile — Cross-compile kexec-tools (static, LTO, stripped)
#
# Usage:
#   DOCKER_BUILDKIT=1 docker build --build-arg KEXEC_ARCH=arm64 \
#       --target=binary --output=type=local,dest=out/ .

# ── Stage 1: Builder ──
FROM ubuntu:22.04 AS builder

ARG KEXEC_VERSION=2.0.32

ENV DEBIAN_FRONTEND=noninteractive

# Install all cross-compilation toolchains in one layer so it is shared
# across builds for different architectures (better Docker cache reuse).
RUN dpkg --add-architecture arm64 && \
    dpkg --add-architecture armhf && \
    dpkg --add-architecture i386 && \
    echo "deb [arch=arm64,armhf] http://ports.ubuntu.com/ jammy main universe" >> /etc/apt/sources.list.d/ports.list && \
    echo "deb [arch=arm64,armhf] http://ports.ubuntu.com/ jammy-updates main universe" >> /etc/apt/sources.list.d/ports.list && \
    sed -i 's/^deb /deb [arch=amd64,i386] /' /etc/apt/sources.list && \
    apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates make file xz-utils \
    gcc libc6-dev \
    autoconf automake \
    gcc-aarch64-linux-gnu libc6-dev-arm64-cross \
    gcc-arm-linux-gnueabihf libc6-dev-armhf-cross \
    gcc-i686-linux-gnu libc6-dev-i386-cross \
    zlib1g-dev:arm64 liblzma-dev:arm64 \
    zlib1g-dev:armhf liblzma-dev:armhf \
    zlib1g-dev:i386 liblzma-dev:i386 \
    zlib1g-dev liblzma-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN curl -fsSL "https://mirrors.edge.kernel.org/pub/linux/utils/kernel/kexec/kexec-tools-${KEXEC_VERSION}.tar.xz" \
    | tar xJ

COPY scripts/build-kexec.sh /build-kexec.sh
ARG KEXEC_ARCH=arm64
RUN bash /build-kexec.sh "$KEXEC_VERSION" "$KEXEC_ARCH"

# ── Stage 2: Extract binary ──
FROM scratch AS binary
COPY --from=builder /build/out/kexec /kexec
