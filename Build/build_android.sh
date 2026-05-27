#!/bin/bash

# ============================================================
# CYCommon Android Build Script
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

# ---------- Arguments ----------
BUILD_TYPE="${1:-Release}"
LIB_TYPE="${2:-OFF}"
ABI="${3:-arm64-v8a}"
API_LEVEL="${4:-21}"

# ---------- Normalize BUILD_TYPE ----------
case "$BUILD_TYPE" in
    d|D|debug)   BUILD_TYPE="Debug" ;;
    r|R|release) BUILD_TYPE="Release" ;;
esac

# ---------- Valid ABIs ----------
case "$ABI" in
    arm64-v8a|armeabi-v7a|x86|x86_64) ;;
    *)
        echo "ERROR: Unknown ABI '$ABI'. Valid values: arm64-v8a, armeabi-v7a, x86, x86_64"
        exit 1
        ;;
esac

# ---------- Clamp API level by ABI ----------
if [ "$ABI" = "armeabi-v7a" ] || [ "$ABI" = "x86" ]; then
    if [ "$API_LEVEL" -lt 19 ]; then
        echo "WARNING: ABI '$ABI' requires API level >= 19, clamping to 19."
        API_LEVEL=19
    fi
else
    if [ "$API_LEVEL" -lt 21 ]; then
        echo "WARNING: ABI '$ABI' requires API level >= 21, clamping to 21."
        API_LEVEL=21
    fi
fi

# ---------- Find Android NDK ----------
ANDROID_NDK=""
if [ -n "${ANDROID_NDK_HOME:-}" ] && [ -d "$ANDROID_NDK_HOME" ]; then
    ANDROID_NDK="$ANDROID_NDK_HOME"
elif [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -d "${ANDROID_SDK_ROOT}/ndk" ]; then
    ANDROID_NDK="$(find "${ANDROID_SDK_ROOT}/ndk" -maxdepth 1 -type d | sort -V | tail -1)"
elif [ -d "$HOME/Library/Android/sdk/ndk" ]; then
    ANDROID_NDK="$(find "$HOME/Library/Android/sdk/ndk" -maxdepth 1 -type d | sort -V | tail -1)"
elif [ -d "/usr/local/share/android-sdk/ndk" ]; then
    ANDROID_NDK="$(find "/usr/local/share/android-sdk/ndk" -maxdepth 1 -type d | sort -V | tail -1)"
fi

if [ -z "$ANDROID_NDK" ] || [ ! -d "$ANDROID_NDK" ]; then
    echo "ERROR: Android NDK not found."
    echo "Please set ANDROID_NDK_HOME or ANDROID_SDK_ROOT."
    exit 1
fi

TOOLCHAIN="$ANDROID_NDK/build/cmake/android.toolchain.cmake"
if [ ! -f "$TOOLCHAIN" ]; then
    echo "ERROR: Android toolchain not found at: $TOOLCHAIN"
    exit 1
fi

echo "========================================"
echo "CYCommon Android Build"
echo "========================================"
echo "  Build Type  : $BUILD_TYPE"
echo "  Shared libs : $LIB_TYPE"
echo "  ABI         : $ABI"
echo "  API Level   : $API_LEVEL"
echo "  NDK         : $ANDROID_NDK"
echo "========================================"

# ---------- Sanity check ----------
if ! command -v cmake &>/dev/null; then
    echo "ERROR: cmake not found."
    exit 1
fi

# ---------- Output directory ----------
OUTPUT_DIR="$SOURCE_DIR/Bin/Android/$ABI/$BUILD_TYPE"
mkdir -p "$OUTPUT_DIR"

# ---------- Build directory ----------
BUILD_DIR="$SOURCE_DIR/build_android_${ABI}_${BUILD_TYPE}_shared-${LIB_TYPE}"
mkdir -p "$BUILD_DIR"

# ---------- Configure ----------
cmake -S "$SCRIPT_DIR" \
      -B "$BUILD_DIR" \
      -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
      -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
      -DANDROID_ABI="$ABI" \
      -DANDROID_PLATFORM="android-$API_LEVEL" \
      -DANDROID_STL="c++_static" \
      -DBUILD_SHARED_LIBS="$LIB_TYPE" \
      -DBUILD_STATIC_LIBS=ON

# ---------- Build ----------
cmake --build "$BUILD_DIR" --parallel

echo ""
echo "========================================"
echo "Android build completed!"
echo "Output: $OUTPUT_DIR"
echo "========================================"
