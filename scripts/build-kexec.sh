#!/bin/bash
# build-kexec.sh — Cross-compile kexec-tools with static linking
#
# Usage: bash build-kexec.sh [KEXEC_VERSION] [ARCH]
#
# This script runs inside the Docker build container.
# It expects the appropriate cross-compiler packages to be installed
# and the kexec-tools source tarball already extracted in /build/.
#
# Supported architectures: arm64

set -eo pipefail

KEXEC_VERSION="${1:-2.0.32}"
ARCH="${2:-arm64}"

case "$ARCH" in
    arm64)
        CROSS_PREFIX="aarch64-linux-gnu"
        ;;
    *)
        echo "ERROR: unsupported arch: $ARCH (expected: arm64)"
        exit 1
        ;;
esac

CC="${CROSS_PREFIX}-gcc"
STRIP="${CROSS_PREFIX}-strip"
JOBS="$(nproc)"
SRCDIR="/build/kexec-tools-${KEXEC_VERSION}"

echo "=== Building kexec-tools ${KEXEC_VERSION} for ${ARCH} ==="
echo "  Compiler: $($CC --version | head -1)"

cd "$SRCDIR"

if [ ! -f configure ]; then
    echo "  Running bootstrap..."
    ./bootstrap
fi

./configure \
    --host="${CROSS_PREFIX}" \
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
