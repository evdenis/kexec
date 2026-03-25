#!/bin/bash
# build-kexec.sh — Cross-compile kexec-tools with static linking
#
# Usage: bash build-kexec.sh [KEXEC_VERSION] [ARCH]
#
# This script runs inside the Docker build container.
# It expects the appropriate cross-compiler packages to be installed
# and the kexec-tools source tarball already extracted in /build/.
#
# Supported architectures: arm64, arm, x86_64, x86

set -eo pipefail

KEXEC_VERSION="${1:-2.0.32}"
ARCH="${2:-arm64}"

case "$ARCH" in
    arm64)
        CROSS_PREFIX="aarch64-linux-gnu"
        ;;
    arm)
        CROSS_PREFIX="arm-linux-gnueabihf"
        ;;
    x86_64)
        CROSS_PREFIX=""
        ;;
    x86)
        CROSS_PREFIX="i686-linux-gnu"
        ;;
    *)
        echo "ERROR: unsupported arch: $ARCH (expected: arm64, arm, x86_64, x86)"
        exit 1
        ;;
esac

if [ -n "$CROSS_PREFIX" ]; then
    CC="${CROSS_PREFIX}-gcc"
    STRIP="${CROSS_PREFIX}-strip"
    HOST_FLAG="--host=${CROSS_PREFIX}"
else
    CC="gcc"
    STRIP="strip"
    HOST_FLAG=""
fi

JOBS="$(nproc)"
SRCDIR="/build/kexec-tools-${KEXEC_VERSION}"

echo "=== Building kexec-tools ${KEXEC_VERSION} for ${ARCH} ==="
echo "  Compiler: $($CC --version | head -1)"

cd "$SRCDIR"

if [ ! -f configure ]; then
    echo "  Running bootstrap..."
    ./bootstrap
fi

# shellcheck disable=SC2086
./configure \
    $HOST_FLAG \
    --without-xen \
    CC="$CC" \
    CFLAGS="-O2 -flto" \
    LDFLAGS="-static -flto"

make -j"$JOBS"

KEXEC_BIN="build/sbin/kexec"
if [ ! -f "$KEXEC_BIN" ]; then
    echo "ERROR: kexec binary not found at $KEXEC_BIN"
    exit 1
fi

"$STRIP" "$KEXEC_BIN"

mkdir -p /build/out
cp "$KEXEC_BIN" /build/out/kexec

echo "=== Build complete ==="
ls -la /build/out/kexec
file /build/out/kexec
