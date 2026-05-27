#!/bin/bash

# ============================================================
# CYCommon Linux Build Script
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

# ---------- Arguments ----------
BUILD_TYPE="${1:-Release}"
LIB_TYPE="${2:-ON}"
TARGET_ARCH="${3:-x86_64}"

# ---------- Normalize BUILD_TYPE ----------
case "$BUILD_TYPE" in
    d|D|debug)   BUILD_TYPE="Debug" ;;
    r|R|release) BUILD_TYPE="Release" ;;
esac

# ---------- Normalize TARGET_ARCH ----------
case "$TARGET_ARCH" in
    x86_64|amd64|amd64_) TARGET_ARCH="x86_64" ;;
    x86|i386|i686|x86_)  TARGET_ARCH="x86" ;;
    arm64|aarch64)       TARGET_ARCH="arm64" ;;
esac

# ---------- Compiler selection ----------
# CYCommon defaults to clang if available, otherwise gcc
if [ -n "${CYCOMMON_CC:-}" ] && [ -n "${CYCOMMON_CXX:-}" ]; then
    CC="$CYCOMMON_CC"
    CXX="$CYCOMMON_CXX"
elif command -v clang &>/dev/null; then
    CC="${CC:-clang}"
    CXX="${CXX:-clang++}"
elif command -v gcc &>/dev/null; then
    CC="${CC:-gcc}"
    CXX="${CXX:-g++}"
else
    echo "ERROR: Neither clang nor gcc found."
    exit 1
fi

echo "========================================"
echo "CYCommon Linux Build"
echo "========================================"
echo "  Build Type  : $BUILD_TYPE"
echo "  Library Type: shared=$LIB_TYPE, static=ON"
echo "  Target Arch : $TARGET_ARCH"
echo "  Compiler    : $CC ($CXX)"
echo "========================================"

# ---------- Sanity check ----------
if ! command -v cmake &>/dev/null; then
    echo "ERROR: cmake not found."
    exit 1
fi

# ---------- Output directory ----------
OUTPUT_DIR="$SOURCE_DIR/Bin/Linux/$TARGET_ARCH/$BUILD_TYPE"
mkdir -p "$OUTPUT_DIR"

# ---------- Build directory ----------
BUILD_DIR="$SOURCE_DIR/build_linux_${TARGET_ARCH}_${BUILD_TYPE}_shared-${LIB_TYPE}"
mkdir -p "$BUILD_DIR"

# ---------- Architecture flags ----------
ARCH_FLAGS=""
if [ "$TARGET_ARCH" = "x86" ]; then
    ARCH_FLAGS="-m32"
elif [ "$TARGET_ARCH" = "x86_64" ]; then
    ARCH_FLAGS="-m64"
fi

# ---------- Configure ----------
cmake -S "$SCRIPT_DIR" \
      -B "$BUILD_DIR" \
      -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
      -DCMAKE_C_COMPILER="$CC" \
      -DCMAKE_CXX_COMPILER="$CXX" \
      -DCMAKE_SYSTEM_PROCESSOR="$TARGET_ARCH" \
      -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
      -DBUILD_SHARED_LIBS="$LIB_TYPE" \
      -DBUILD_STATIC_LIBS=ON

# ---------- Build ----------
cmake --build "$BUILD_DIR" --parallel

# ---------- Install to Bin ----------
cmake --install "$BUILD_DIR" --prefix "$SOURCE_DIR/Bin/Linux/$TARGET_ARCH"

echo ""
echo "========================================"
echo "Linux build completed!"
echo "Output: $SOURCE_DIR/Bin/Linux/$TARGET_ARCH/$BUILD_TYPE"
echo "========================================"
