#!/bin/bash

# ============================================================
# CYCommon Android Build Script
#   Usage: build_android.sh [all|Release|Debug] [all|shared|static] [ABI...]
#   Default: all all "arm64-v8a armeabi-v7a x86_64 x86"
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

# ---------- Arguments ----------
BUILD_TYPE="${1:-all}"
LIB_TYPE="${2:-all}"
ABI_ARG="${3:-}"
API_LEVEL="${4:-21}"

# Use provided ABI(s) or fall back to all
if [ -n "$ABI_ARG" ]; then
    ABIS="$ABI_ARG"
else
    ABIS="arm64-v8a armeabi-v7a x86_64 x86"
fi

# ---------- Parse BUILD_TYPE into multiple build types ----------
BUILD_TYPES=""
case "$BUILD_TYPE" in
    all|a|A|both|b|B)
        BUILD_TYPES="Release Debug"
        ;;
    d|D|debug)
        BUILD_TYPES="Debug"
        ;;
    r|R|release|Release)
        BUILD_TYPES="Release"
        ;;
    Debug)
        BUILD_TYPES="Debug"
        ;;
    *)
        echo "ERROR: Unknown BUILD_TYPE '$BUILD_TYPE'. Use: all, Release, Debug"
        exit 1
        ;;
esac

# ---------- Normalize LIB_TYPE ----------
case "$LIB_TYPE" in
    all|a|A|both|b|B)
        BUILD_SHARED="ON"
        BUILD_STATIC="ON"
        LIB_TAG="all"
        ;;
    shared|s|S|on|ON|On)
        BUILD_SHARED="ON"
        BUILD_STATIC="OFF"
        LIB_TAG="shared"
        ;;
    static|st|off|OFF|Off)
        BUILD_SHARED="OFF"
        BUILD_STATIC="ON"
        LIB_TAG="static"
        ;;
    *)
        echo "ERROR: Unknown LIB_TYPE '$LIB_TYPE'. Use: all, shared, static"
        exit 1
        ;;
esac

# ---------- Validate ABIs ----------
for ABI in $ABIS; do
    case "$ABI" in
        arm64-v8a|armeabi-v7a|x86|x86_64) ;;
        *)
            echo "ERROR: Unknown ABI '$ABI'. Valid values: arm64-v8a, armeabi-v7a, x86, x86_64"
            exit 1
            ;;
    esac
done

# ---------- Clamp API level helper ----------
clamp_api_level() {
    local abi=$1
    local api=$2
    if [ "$abi" = "armeabi-v7a" ] || [ "$abi" = "x86" ]; then
        if [ "$api" -lt 19 ]; then
            echo 19
        else
            echo "$api"
        fi
    else
        if [ "$api" -lt 21 ]; then
            echo 21
        else
            echo "$api"
        fi
    fi
}

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

# ---------- Sanity check ----------
if ! command -v cmake &>/dev/null; then
    echo "ERROR: cmake not found."
    exit 1
fi

echo "========================================"
echo "CYCommon Android Build"
echo "========================================"
echo "  Build Types : $BUILD_TYPES"
echo "  Lib Type    : $LIB_TYPE (shared=$BUILD_SHARED static=$BUILD_STATIC)"
echo "  ABI(s)      : $ABIS"
echo "  API Level   : $API_LEVEL"
echo "  NDK         : $ANDROID_NDK"
echo "========================================"

# ---------- Build function for a single ABI ----------
build_abi() {
    local ABI=$1
    local BT=$2
    local EFFECTIVE_API
    EFFECTIVE_API=$(clamp_api_level "$ABI" "$API_LEVEL")

    echo ""
    echo "=========================================="
    echo "  Building: $ABI ($BT)"
    echo "=========================================="

    local BUILD_DIR="$SOURCE_DIR/build_android_${ABI}_${BT}_${LIB_TAG}"
    mkdir -p "$BUILD_DIR"

    local OUTPUT_DIR="$SOURCE_DIR/Bin/Android/$ABI/$BT"
    mkdir -p "$OUTPUT_DIR"

    cmake -S "$SCRIPT_DIR" \
          -B "$BUILD_DIR" \
          -DCMAKE_BUILD_TYPE="$BT" \
          -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
          -DANDROID_ABI="$ABI" \
          -DANDROID_PLATFORM="android-$EFFECTIVE_API" \
          -DANDROID_STL="c++_static" \
          -DBUILD_SHARED_LIBS="$BUILD_SHARED" \
          -DBUILD_STATIC_LIBS="$BUILD_STATIC"

    local cmake_target
    if [ "$LIB_TAG" = "static" ]; then
        cmake_target="CYCommon_static"
    elif [ "$LIB_TAG" = "shared" ]; then
        cmake_target="CYCommon_shared"
    else
        cmake_target="all"
    fi

    if [ "$cmake_target" = "all" ]; then
        cmake --build "$BUILD_DIR" --parallel
    else
        cmake --build "$BUILD_DIR" --target "$cmake_target" --parallel
    fi

    if [ -f "$OUTPUT_DIR/libCYCommon.a" ]; then
        echo "    Built: $OUTPUT_DIR/libCYCommon.a"
    fi
    if [ -f "$OUTPUT_DIR/libCYCommon.so" ]; then
        echo "    Built: $OUTPUT_DIR/libCYCommon.so"
    fi
}

# ---------- Execute builds ----------
for BT in $BUILD_TYPES; do
    for ABI in $ABIS; do
        build_abi "$ABI" "$BT"
    done
done

echo ""
echo "========================================"
echo "Android build completed!"
echo "Output: $SOURCE_DIR/Bin/Android/"
echo "========================================"
