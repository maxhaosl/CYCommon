#!/bin/bash

# ============================================================
# CYCommon Linux All Build Script
# Builds Debug + Release static libraries in one run
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

# ---------- Arguments ----------
BUILD_TYPES="${1:-Release,Debug}"
ARCHES="${2:-x86_64}"

echo "========================================"
echo "CYCommon Linux All Build"
echo "========================================"
echo "  Build Types   : $BUILD_TYPES"
echo "  Architectures : $ARCHES"
echo "  Library Type  : static only"
echo "========================================"

FAILED=0

for BUILD_TYPE in $(echo "$BUILD_TYPES" | tr ',' ' '); do
    for TARGET_ARCH in $(echo "$ARCHES" | tr ',' ' '); do
        echo ""
        echo ">>> Building: arch=$TARGET_ARCH type=$BUILD_TYPE"

        "$SCRIPT_DIR/build_linux.sh" "$BUILD_TYPE" "$TARGET_ARCH"

        if [ $? -ne 0 ]; then
            echo "ERROR: build_linux.sh failed for arch=$TARGET_ARCH type=$BUILD_TYPE"
            FAILED=1
        fi
    done
done

if [ $FAILED -ne 0 ]; then
    echo ""
    echo "========================================"
    echo "One or more builds failed!"
    echo "========================================"
    exit 1
fi

echo ""
echo "========================================"
echo "All Linux builds completed!"
echo "Output: $SOURCE_DIR/Bin/Linux/"
echo "========================================"
