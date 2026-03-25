#!/usr/bin/env bash
#
# bump-kexec.sh — Check for new upstream kexec-tools release and update the module.
#
# If a new kexec-tools version is available, this script:
#   1. Updates KEXEC_VERSION in Dockerfile and scripts/build-kexec.sh
#   2. Rebuilds and tests all architecture binaries
#   3. Bumps module.prop (version, versionCode, description)
#   4. Regenerates CHANGELOG.md via git-cliff
#   5. Creates a git commit and tag
#   6. Writes the new tag to .new-tag for the CI workflow to push
#
# Requires: git, docker, make, git-cliff, qemu-user-static (for cross-arch tests)
#
# Usage: bash scripts/bump-kexec.sh

set -euo pipefail

UPSTREAM_REPO="https://git.kernel.org/pub/scm/utils/kernel/kexec/kexec-tools.git/"

# --- Detect latest upstream release ---

LATEST=$(git ls-remote --tags "$UPSTREAM_REPO" \
    | grep -oP 'refs/tags/v\K[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V \
    | tail -1)

if [ -z "$LATEST" ]; then
    echo "ERROR: Failed to detect latest kexec-tools release"
    exit 1
fi

CURRENT=$(grep '^ARG KEXEC_VERSION=' Dockerfile | cut -d= -f2)
if [ -z "$CURRENT" ]; then
    echo "ERROR: Failed to parse KEXEC_VERSION from Dockerfile"
    exit 1
fi

if [ "$LATEST" = "$CURRENT" ]; then
    echo "Already on kexec-tools $CURRENT — nothing to do"
    exit 0
fi

echo "=== New kexec-tools release: $CURRENT → $LATEST ==="

# --- Install QEMU for cross-arch tests (if not already present) ---

if ! command -v qemu-aarch64-static >/dev/null 2>&1; then
    echo "Installing qemu-user-static..."
    sudo apt-get update && sudo apt-get install -y qemu-user-static
fi

# --- Update KEXEC_VERSION in build files ---

sed -i "s/^ARG KEXEC_VERSION=.*/ARG KEXEC_VERSION=${LATEST}/" Dockerfile
sed -i "s/KEXEC_VERSION=\"\${1:-[^}]*}\"/KEXEC_VERSION=\"\${1:-${LATEST}}\"/" scripts/build-kexec.sh

grep -qF "ARG KEXEC_VERSION=${LATEST}" Dockerfile
grep -qF "\${1:-${LATEST}}" scripts/build-kexec.sh
echo "Updated KEXEC_VERSION in Dockerfile and scripts/build-kexec.sh"

# --- Build and test ---

make build-kexec-all
make test-kexec-all

# --- Bump module.prop ---

CUR_VER=$(grep '^version=' module.prop | cut -d= -f2)
CUR_CODE=$(grep '^versionCode=' module.prop | cut -d= -f2)

NEW_CODE=$((CUR_CODE + 1))
MAJOR=$(echo "$CUR_VER" | sed 's/^v//' | cut -d. -f1)
case "$CUR_VER" in
    *.*) MINOR="${CUR_VER#v*.}" ;;
    *)   MINOR="" ;;
esac
if [ -z "$MINOR" ]; then
    NEW_VER="v${MAJOR}.1"
else
    NEW_VER="v${MAJOR}.$((MINOR + 1))"
fi

sed -i \
    -e "s/^version=.*/version=${NEW_VER}/" \
    -e "s/^versionCode=.*/versionCode=${NEW_CODE}/" \
    -e "s/^description=.*/description=Kexec-tools v${LATEST} for ARM64, ARM, x86_64, and x86./" \
    module.prop

echo "Module version: $CUR_VER → $NEW_VER (versionCode: $CUR_CODE → $NEW_CODE)"

# --- Commit and tag ---

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add Dockerfile scripts/build-kexec.sh module.prop kexec-bin/
git commit -m "build: bump kexec-tools from v${CURRENT} to v${LATEST}"

# Generate CHANGELOG.md with the new tag so release workflow finds the ## heading
git-cliff --config cliff.toml --tag "$NEW_VER" -o CHANGELOG.md
git add CHANGELOG.md
git commit --amend --no-edit

git tag "$NEW_VER"

# Signal to the CI workflow that there's a new tag to push
echo "$NEW_VER" > .new-tag
echo "=== Ready to push: $NEW_VER ==="
