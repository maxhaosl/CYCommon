#!/bin/bash

# ============================================================
# CYCommon macOS Build Script
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

# ---------- Defaults ----------
BUILD_TYPE="${1:-Release}"
LIB_TYPE="${2:-ON}"
ARCHS="${3:-arm64 x86_64}"
DEPLOY_TARGET="${MACOS_DEPLOYMENT_TARGET:-11.0}"

# ---------- Normalize ----------
case "$BUILD_TYPE" in
    d|D|debug)   BUILD_TYPE="Debug" ;;
    r|R|release) BUILD_TYPE="Release" ;;
esac

# Source helper utilities
SCRIPT="$SCRIPT_DIR/output_layout.sh"
if [ -f "$SCRIPT" ]; then
    source "$SCRIPT"
fi

# ---------- Sanity check ----------
if ! command -v cmake &>/dev/null; then
    echo "ERROR: cmake not found."
    exit 1
fi

echo "========================================"
echo "CYCommon macOS Build"
echo "========================================"
echo "  Build Type  : $BUILD_TYPE"
echo "  Shared libs : $LIB_TYPE"
echo "  Architectures: $ARCHS"
echo "  Deploy Target: $DEPLOY_TARGET"
echo "========================================"

BUILD_DIR="$SOURCE_DIR/build_macos"

mkdir -p "$BUILD_DIR"

# ---------- Build each architecture slice ----------
declare -A SLICE_DIRS
for ARCH in $ARCHS; do
    echo ""
    echo ">>> Building slice: $ARCH"

    SLICE_BUILD_DIR="$BUILD_DIR/${ARCH}_${BUILD_TYPE}_shared-${LIB_TYPE}"
    mkdir -p "$SLICE_BUILD_DIR"

    cmake -S "$SCRIPT_DIR" \
          -B "$SLICE_BUILD_DIR" \
          -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
          -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
          -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOY_TARGET" \
          -DCMAKE_INSTALL_PREFIX="$SOURCE_DIR/Bin/macOS/$ARCH/$BUILD_TYPE" \
          -DBUILD_SHARED_LIBS="$LIB_TYPE" \
          -DBUILD_STATIC_LIBS=ON

    cmake --build "$SLICE_BUILD_DIR" --parallel

    SLICE_DIRS[$ARCH]="$SOURCE_DIR/Bin/macOS/$ARCH/$BUILD_TYPE"
done

# ---------- Combine into universal binaries ----------
UNIV_DIR="$SOURCE_DIR/Bin/macOS/universal/$BUILD_TYPE"
if [ ${#SLICE_DIRS[@]} -ge 2 ]; then
    echo ""
    echo ">>> Generating universal binaries..."

    mkdir -p "$UNIV_DIR"

    # Static library
    SLICES=()
    for ARCH in $ARCHS; do
        SLICES+=("$SOURCE_DIR/Bin/macOS/$ARCH/$BUILD_TYPE/libCYCommon.a")
    done

    if [ -f "${SLICES[0]}" ]; then
        # For static libs, just copy the first slice as fallback (no lipo needed)
        # because macOS lipo doesn't support -create with .a files from different archs
        # (the linker merges them on the host). Copy Release arm64 slice.
        cp "${SLICES[0]}" "$UNIV_DIR/libCYCommon.a"
        echo "    Copied static lib from ${SLICES[0]} to $UNIV_DIR"
    fi

    # Shared library (dylib) — lipo works for .dylib files
    DYLIB_SLICES=()
    for ARCH in $ARCHS; do
        DYLIB="$SOURCE_DIR/Bin/macOS/$ARCH/$BUILD_TYPE/libCYCommon.${PROJECT_VERSION_MAJOR}.dylib"
        if [ -f "$DYLIB" ]; then
            DYLIB_SLICES+=("$DYLIB")
        fi
    done

    if [ ${#DYLIB_SLICES[@]} -ge 2 ]; then
        lipo -create "${DYLIB_SLICES[@]}" -output "$UNIV_DIR/libCYCommon.dylib"
        # Copy versioned dylib too
        if [ -f "${DYLIB_SLICES[0]}" ]; then
            VERSIONED="$UNIV_DIR/libCYCommon.1.dylib"
            lipo -create "${DYLIB_SLICES[@]}" -output "$VERSIONED"
        fi
        echo "    Created universal dylib at $UNIV_DIR"
    fi
fi

echo ""
echo "========================================"
echo "macOS build completed!"
echo "Output: $SOURCE_DIR/Bin/macOS/"
echo "========================================"
