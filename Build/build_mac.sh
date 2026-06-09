#!/bin/bash

# ============================================================
# CYCommon macOS single-arch build helper
# Called by CYCoroutine CMakeLists.txt when building CYCommon as a dependency.
#   Usage: build_mac.sh <BUILD_TYPE> <LIB_TYPE> <ARCH> [CYCOMMON_OUTPUT_DIR]
#   Example: build_mac.sh Release OFF arm64
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

BUILD_TYPE="${1:-Release}"
LIB_TYPE="${2:-OFF}"
ARCH="${3:-arm64}"
# CYCOMMON_OUTPUT_DIR is the complete parent path for this arch/BT slice,
# e.g. CYCommon/Bin/MacOS/arm64/Release
CYCOMMON_OUTPUT_DIR="${4:-}"

case "$BUILD_TYPE" in
    d|D|debug)  BUILD_TYPE="Debug" ;;
    r|R|release) BUILD_TYPE="Release" ;;
esac

case "$LIB_TYPE" in
    Static|static|OFF|off|0|false|FALSE) LIB_TYPE="OFF" ;;
    Shared|shared|ON|on|1|true|TRUE)     LIB_TYPE="ON"  ;;
esac

# Use shared/static tag in build dir so static and shared builds don't conflict
if [ "$LIB_TYPE" = "ON" ]; then
    BUILD_DIR="$SOURCE_DIR/build_macos_${ARCH}_${BUILD_TYPE}_shared"
else
    BUILD_DIR="$SOURCE_DIR/build_macos_${ARCH}_${BUILD_TYPE}_static"
fi
mkdir -p "$BUILD_DIR"

cmake_output_dir_arg=""
if [ -n "$CYCOMMON_OUTPUT_DIR" ]; then
    cmake_output_dir_arg="-DCYCOMMON_OUTPUT_DIR=$CYCOMMON_OUTPUT_DIR"
fi

cmake -S "$SCRIPT_DIR" \
      -B "$BUILD_DIR" \
      -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
      -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
      -DBUILD_SHARED_LIBS="$LIB_TYPE" \
      -DBUILD_STATIC_LIBS=ON \
      ${cmake_output_dir_arg}

cmake --build "$BUILD_DIR" --target CYCommon_static --parallel
