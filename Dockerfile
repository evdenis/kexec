# Dockerfile — Cross-compile kexec-tools (static, LTO, stripped)
#
# Usage:
#   DOCKER_BUILDKIT=1 docker build --build-arg KEXEC_ARCH=arm64 \
#       --target=binary --output=type=local,dest=out/ .

# ── Stage 1: Builder ──
FROM ubuntu:22.04 AS builder

ARG KEXEC_VERSION=2.0.32

ENV DEBIAN_FRONTEND=noninteractive

# Enable arm64 arch via ports.ubuntu.com for cross-platform dev packages.
RUN dpkg --add-architecture arm64 && \
    echo "deb [arch=arm64] http://ports.ubuntu.com/ jammy main universe" >> /etc/apt/sources.list.d/arm64.list && \
    echo "deb [arch=arm64] http://ports.ubuntu.com/ jammy-updates main universe" >> /etc/apt/sources.list.d/arm64.list && \
    sed -i 's/^deb /deb [arch=amd64] /' /etc/apt/sources.list && \
    apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates make file xz-utils \
    gcc libc6-dev \
    autoconf automake \
    gcc-aarch64-linux-gnu libc6-dev-arm64-cross \
    zlib1g-dev:arm64 liblzma-dev:arm64 \
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
