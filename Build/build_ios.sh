#!/bin/bash

# ============================================================
# CYCommon iOS Build Script
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

# ---------- Arguments ----------
BUILD_TYPE="${1:-Release}"
LIB_TYPE="${2:-OFF}"
ARCHS="${3:-arm64 x86_64}"
DEPLOY_TARGET="${IOS_DEPLOYMENT_TARGET:-14.0}"

# ---------- Normalize BUILD_TYPE ----------
case "$BUILD_TYPE" in
    d|D|debug)   BUILD_TYPE="Debug" ;;
    r|R|release) BUILD_TYPE="Release" ;;
esac

# ---------- Sanity check ----------
if ! command -v cmake &>/dev/null; then
    echo "ERROR: cmake not found."
    exit 1
fi

if ! command -v xcrun &>/dev/null; then
    echo "ERROR: xcrun not found. This script must be run on macOS."
    exit 1
fi

echo "========================================"
echo "CYCommon iOS Build"
echo "========================================"
echo "  Build Type   : $BUILD_TYPE"
echo "  Shared libs : $LIB_TYPE"
echo "  Architectures: $ARCHS"
echo "  Deploy Target: $DEPLOY_TARGET"
echo "========================================"

BUILD_DIR="$SOURCE_DIR/build_ios"

declare -A SLICE_DIRS

for ARCH in $ARCHS; do
    echo ""
    echo ">>> Building slice: $ARCH"

    SLICE_BUILD_DIR="$BUILD_DIR/${ARCH}_${BUILD_TYPE}_shared-${LIB_TYPE}"
    mkdir -p "$SLICE_BUILD_DIR"

    if [ "$ARCH" = "arm64" ]; then
        SYSROOT=$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || echo "")
        CMAKE_SYSTEM_NAME="iOS"
        CMAKE_OSX_ARCH="$ARCH"
    elif [ "$ARCH" = "arm64-simulator" ]; then
        SYSROOT=$(xcrun --sdk iphonesimulator --show-sdk-path 2>/dev/null || echo "")
        CMAKE_SYSTEM_NAME="iOS"
        CMAKE_OSX_ARCH="arm64"
    else
        SYSROOT=$(xcrun --sdk iphonesimulator --show-sdk-path 2>/dev/null || echo "")
        CMAKE_SYSTEM_NAME="iOS"
        CMAKE_OSX_ARCH="$ARCH"
    fi

    cmake -S "$SCRIPT_DIR" \
          -B "$SLICE_BUILD_DIR" \
          -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
          -DCMAKE_SYSTEM_NAME="$CMAKE_SYSTEM_NAME" \
          -DCMAKE_OSX_ARCHITECTURES="$CMAKE_OSX_ARCH" \
          -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOY_TARGET" \
          -DCMAKE_OSX_SYSROOT="$SYSROOT" \
          -DCMAKE_INSTALL_PREFIX="$SOURCE_DIR/Bin/iOS/$ARCH/$BUILD_TYPE" \
          -DBUILD_SHARED_LIBS="$LIB_TYPE" \
          -DBUILD_STATIC_LIBS=ON

    cmake --build "$SLICE_BUILD_DIR" --parallel

    SLICE_DIRS[$ARCH]="$SOURCE_DIR/Bin/iOS/$ARCH/$BUILD_TYPE"
done

# ---------- Combine into universal binaries ----------
UNIV_DIR="$SOURCE_DIR/Bin/iOS/universal/$BUILD_TYPE"
if [ ${#SLICE_DIRS[@]} -ge 2 ]; then
    echo ""
    echo ">>> Generating universal libraries..."

    mkdir -p "$UNIV_DIR"

    # Static library
    STATIC_SLICES=()
    for ARCH in $ARCHS; do
        SLICE_PATH="$SOURCE_DIR/Bin/iOS/$ARCH/$BUILD_TYPE/libCYCommon.a"
        if [ -f "$SLICE_PATH" ]; then
            STATIC_SLICES+=("$SLICE_PATH")
        fi
    done

    if [ ${#STATIC_SLICES[@]} -ge 2 ]; then
        lipo -create "${STATIC_SLICES[@]}" -output "$UNIV_DIR/libCYCommon.a"
        echo "    Created universal static lib: $UNIV_DIR/libCYCommon.a"
    elif [ ${#STATIC_SLICES[@]} -eq 1 ]; then
        cp "${STATIC_SLICES[0]}" "$UNIV_DIR/libCYCommon.a"
    fi

    # Shared library (dylib)
    DYLIB_SLICES=()
    for ARCH in $ARCHS; do
        DYLIB_PATH="$SOURCE_DIR/Bin/iOS/$ARCH/$BUILD_TYPE/libCYCommon.dylib"
        if [ -f "$DYLIB_PATH" ]; then
            DYLIB_SLICES+=("$DYLIB_PATH")
        fi
    done

    if [ ${#DYLIB_SLICES[@]} -ge 2 ]; then
        lipo -create "${DYLIB_SLICES[@]}" -output "$UNIV_DIR/libCYCommon.dylib"
        echo "    Created universal dylib: $UNIV_DIR/libCYCommon.dylib"
    elif [ ${#DYLIB_SLICES[@]} -eq 1 ]; then
        cp "${DYLIB_SLICES[0]}" "$UNIV_DIR/libCYCommon.dylib"
    fi
fi

echo ""
echo "========================================"
echo "iOS build completed!"
echo "Output: $SOURCE_DIR/Bin/iOS/"
echo "========================================"
