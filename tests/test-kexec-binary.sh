#!/usr/bin/env bash
#
# Binary sanity tests for the kexec binary.
# Usage: ./tests/test-kexec-binary.sh [path/to/kexec] [arch]
#   arch: arm64 (default), arm, x86_64, x86
#

set -euo pipefail

BINARY="${1:-kexec-bin/arm64/kexec}"
ARCH="${2:-arm64}"

if [[ ! -f "$BINARY" ]]; then
    echo "ERROR: binary not found: $BINARY"
    exit 1
fi

case "$ARCH" in
    arm64)
        ELF_PATTERN="ELF 64-bit LSB executable, ARM aarch64"
        MACHINE_PATTERN="Machine:.*AArch64"
        QEMU_BIN="qemu-aarch64-static"
        ;;
    arm)
        ELF_PATTERN="ELF 32-bit LSB executable, ARM, EABI5"
        MACHINE_PATTERN="Machine:.*ARM"
        QEMU_BIN="qemu-arm-static"
        ;;
    x86_64)
        ELF_PATTERN="ELF 64-bit LSB executable, x86-64"
        MACHINE_PATTERN="Machine:.*Advanced Micro Devices X86-64"
        QEMU_BIN="qemu-x86_64-static"
        ;;
    x86)
        ELF_PATTERN="ELF 32-bit LSB executable, Intel"
        MACHINE_PATTERN="Machine:.*Intel 80386"
        QEMU_BIN="qemu-i386-static"
        ;;
    *)
        echo "ERROR: unsupported arch: $ARCH (expected: arm64, arm, x86_64, x86)"
        exit 1
        ;;
esac

echo "Testing $BINARY (expected arch: $ARCH)"
echo ""

PASS=0
FAIL=0

pass() {
    echo "PASS: $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "FAIL: $1"
    FAIL=$((FAIL + 1))
}

FILE_OUT="$(file "$BINARY")"

# 1. ELF format + correct architecture
if echo "$FILE_OUT" | grep -q "$ELF_PATTERN"; then
    pass "$ELF_PATTERN"
else
    fail "$ELF_PATTERN — got: $FILE_OUT"
fi

# 2. Statically linked
if echo "$FILE_OUT" | grep -q "statically linked"; then
    pass "statically linked"
else
    fail "statically linked — got: $FILE_OUT"
fi

# 3. Stripped
if echo "$FILE_OUT" | grep -q "stripped" && ! echo "$FILE_OUT" | grep -q "not stripped"; then
    pass "stripped"
else
    fail "stripped — got: $FILE_OUT"
fi

# 4. No dynamic section (no NEEDED libs)
READELF_D="$(readelf -d "$BINARY" 2>&1 || true)"
if echo "$READELF_D" | grep -qi "no dynamic section\|there is no dynamic section"; then
    pass "no dynamic section"
else
    fail "no dynamic section — got: $READELF_D"
fi

# 5. ELF type is EXEC (not DYN/shared)
READELF_H="$(readelf -h "$BINARY")"
if echo "$READELF_H" | grep -q "Type:.*EXEC"; then
    pass "ELF type is EXEC"
else
    fail "ELF type is EXEC — got: $(echo "$READELF_H" | grep 'Type:')"
fi

# 6. Machine matches expected architecture
if echo "$READELF_H" | grep -q "$MACHINE_PATTERN"; then
    pass "machine matches $ARCH"
else
    fail "machine matches $ARCH — got: $(echo "$READELF_H" | grep 'Machine:')"
fi

# 7. Reasonable file size (200KB–3MB)
SIZE="$(stat --format='%s' "$BINARY" 2>/dev/null || stat -f '%z' "$BINARY")"
MIN=$((200 * 1024))
MAX=$((3 * 1024 * 1024))
if [[ "$SIZE" -ge "$MIN" && "$SIZE" -le "$MAX" ]]; then
    pass "file size is reasonable ($(( SIZE / 1024 ))KB)"
else
    fail "file size out of range: $SIZE bytes (expected ${MIN}–${MAX})"
fi

# 8. Contains expected strings
# Pipe to grep -c (not -q) to avoid SIGPIPE killing strings under pipefail
if [ "$(strings "$BINARY" | grep -c "kexec")" -gt 0 ]; then
    pass "contains 'kexec' string"
else
    fail "binary does not contain 'kexec' string"
fi

# 9–10. Smoke tests (native execution or QEMU)
QEMU_TIMEOUT=5
HOST_ARCH="$(uname -m)"
CAN_RUN=false
RUN_CMD=""

if { [[ "$ARCH" == "x86_64" ]] && [[ "$HOST_ARCH" == "x86_64" ]]; } ||
   { [[ "$ARCH" == "x86" ]] && [[ "$HOST_ARCH" == "x86_64" ]]; }; then
    CAN_RUN=true
elif command -v "$QEMU_BIN" >/dev/null 2>&1; then
    CAN_RUN=true
    RUN_CMD="$QEMU_BIN"
else
    echo "SKIP: smoke tests ($QEMU_BIN not installed)"
fi

if [[ "$CAN_RUN" == true ]]; then

    # 9. --version prints version string
    VER_OUT="$(timeout -k 3 "$QEMU_TIMEOUT" $RUN_CMD "$BINARY" --version 2>&1 || true)"
    if echo "$VER_OUT" | grep -qE "kexec-tools [0-9]+\.[0-9]+"; then
        pass "smoke --version: $VER_OUT"
    else
        fail "smoke --version — output: $VER_OUT"
    fi

    # 10. --help prints usage text
    HELP_OUT="$(timeout -k 3 "$QEMU_TIMEOUT" $RUN_CMD "$BINARY" --help 2>&1 || true)"
    if echo "$HELP_OUT" | grep -qi "usage\|kexec"; then
        pass "smoke --help shows usage text"
    else
        fail "smoke --help — output: $(echo "$HELP_OUT" | head -3)"
    fi
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
