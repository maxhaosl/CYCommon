#!/bin/bash

# ============================================================
# CYCommon Cross-Platform Matrix Build Script
# Builds all combinations of platform / arch / build-type / lib-flavor
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

# ---------- Color output ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ---------- CLI argument defaults ----------
PLATFORMS="${PLATFORMS:-macos,ios,linux,android,windows}"
BUILD_TYPES="${BUILD_TYPES:-Release,Debug}"
SHARED_KINDS="${SHARED_KINDS:-static,shared}"
MAC_ARCHES="${MAC_ARCHES:-arm64,x86_64}"
IOS_ARCHES="${IOS_ARCHES:-arm64,x86_64}"
ANDROID_ABIS="${ANDROID_ABIS:-arm64-v8a,armeabi-v7a,x86_64,x86}"
ANDROID_API_LEVEL="${ANDROID_API_LEVEL:-21}"
FORCE_LINUX="${FORCE_LINUX:-0}"

# ---------- Parse CLI flags ----------
while [ $# -gt 0 ]; do
    case "$1" in
        --platforms)       PLATFORMS="$2";          shift 2 ;;
        --build-types)     BUILD_TYPES="$2";         shift 2 ;;
        --shared-kinds)    SHARED_KINDS="$2";        shift 2 ;;
        --mac-arches)      MAC_ARCHES="$2";          shift 2 ;;
        --ios-arches)      IOS_ARCHES="$2";          shift 2 ;;
        --android-abis)    ANDROID_ABIS="$2";        shift 2 ;;
        --android-api-level) ANDROID_API_LEVEL="$2"; shift 2 ;;
        --force-linux)     FORCE_LINUX=1;            shift ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --platforms        CSV list: macos,ios,linux,android,windows (default: all)"
            echo "  --build-types      CSV list: Release,Debug (default: Release,Debug)"
            echo "  --shared-kinds     CSV list: static,shared (default: static,shared)"
            echo "  --mac-arches       CSV list: arm64,x86_64 (default: arm64,x86_64)"
            echo "  --ios-arches       CSV list: arm64,x86_64 (default: arm64,x86_64)"
            echo "  --android-abis     CSV list: arm64-v8a,armeabi-v7a,x86_64,x86 (default: all)"
            echo "  --android-api-level  integer (default: 21)"
            echo "  --force-linux      Allow Linux builds on non-Linux hosts"
            echo "  -h, --help         Show this help"
            exit 0
            ;;
        *) shift ;;
    esac
done

# ---------- Sanity checks ----------
if ! command -v cmake &>/dev/null; then
    error "cmake not found. Please install CMake 3.16+."
    exit 1
fi

# Source helper utilities
if [ -f "$SCRIPT_DIR/output_layout.sh" ]; then
    source "$SCRIPT_DIR/output_layout.sh"
fi

# Detect OS
HOST_OS="$(uname -s)"

echo "========================================"
echo "CYCommon Cross-Platform Matrix Build"
echo "========================================"
info "Host OS       : $HOST_OS"
info "Platforms     : $PLATFORMS"
info "Build types   : $BUILD_TYPES"
info "Shared kinds  : $SHARED_KINDS"
info "macOS arches  : $MAC_ARCHES"
info "iOS arches    : $IOS_ARCHES"
info "Android ABIs  : $ANDROID_ABIS"
info "Android API   : $ANDROID_API_LEVEL"
echo "========================================"

FAILED=0

# =====================================================================
# macOS matrix
# =====================================================================
if [[ ",$PLATFORMS," == *,macos,* ]]; then
    info "===== Building macOS ====="

    if [ "$HOST_OS" != "Darwin" ]; then
        warn "Skipping macOS build: not running on macOS."
    else
        for BUILD_TYPE in $(echo "$BUILD_TYPES" | tr ',' ' '); do
            for SHARED_KIND in $(echo "$SHARED_KINDS" | tr ',' ' '); do
                info ">>> macOS $BUILD_TYPE shared=$SHARED_KIND arches=$MAC_ARCHES"

                "$SCRIPT_DIR/build_mac.sh" "$BUILD_TYPE" "$SHARED_KIND" "$MAC_ARCHES"
                if [ $? -ne 0 ]; then
                    error "macOS build failed for $BUILD_TYPE shared=$SHARED_KIND"
                    FAILED=1
                fi
            done
        done
    fi
fi

# =====================================================================
# iOS matrix
# =====================================================================
if [[ ",$PLATFORMS," == *,ios,* ]]; then
    info "===== Building iOS ====="

    if [ "$HOST_OS" != "Darwin" ]; then
        warn "Skipping iOS build: not running on macOS."
    else
        for BUILD_TYPE in $(echo "$BUILD_TYPES" | tr ',' ' '); do
            for SHARED_KIND in $(echo "$SHARED_KINDS" | tr ',' ' '); do
                info ">>> iOS $BUILD_TYPE shared=$SHARED_KIND arches=$IOS_ARCHES"

                "$SCRIPT_DIR/build_ios.sh" "$BUILD_TYPE" "$SHARED_KIND" "$IOS_ARCHES"
                if [ $? -ne 0 ]; then
                    error "iOS build failed for $BUILD_TYPE shared=$SHARED_KIND"
                    FAILED=1
                fi
            done
        done
    fi
fi

# =====================================================================
# Linux matrix
# =====================================================================
if [[ ",$PLATFORMS," == *,linux,* ]]; then
    info "===== Building Linux ====="

    CAN_BUILD_LINUX=0
    if [ "$HOST_OS" == "Linux" ]; then
        CAN_BUILD_LINUX=1
    elif [ "$FORCE_LINUX" == "1" ]; then
        warn "FORCE_LINUX=1: attempting Linux build on $HOST_OS."
        CAN_BUILD_LINUX=1
    else
        warn "Skipping Linux build: not running on Linux (use --force-linux to override)."
    fi

    if [ "$CAN_BUILD_LINUX" == "1" ]; then
        for BUILD_TYPE in $(echo "$BUILD_TYPES" | tr ',' ' '); do
            for SHARED_KIND in $(echo "$SHARED_KINDS" | tr ',' ' '); do
                for ARCH in $(echo "$MAC_ARCHES" | tr ',' ' '); do
                    if [ "$ARCH" == "arm64" ]; then
                        LINUX_ARCH="arm64"
                    else
                        LINUX_ARCH="x86_64"
                    fi

                    info ">>> Linux $BUILD_TYPE shared=$SHARED_KIND arch=$LINUX_ARCH"

                    "$SCRIPT_DIR/build_linux.sh" "$BUILD_TYPE" "$SHARED_KIND" "$LINUX_ARCH"
                    if [ $? -ne 0 ]; then
                        error "Linux build failed for $BUILD_TYPE shared=$SHARED_KIND arch=$LINUX_ARCH"
                        FAILED=1
                    fi
                done
            done
        done
    fi
fi

# =====================================================================
# Android matrix
# =====================================================================
if [[ ",$PLATFORMS," == *,android,* ]]; then
    info "===== Building Android ====="

    # Find Android NDK
    if [ -n "${ANDROID_NDK_HOME:-}" ] && [ -d "$ANDROID_NDK_HOME" ]; then
        info "Android NDK: $ANDROID_NDK_HOME (via ANDROID_NDK_HOME)"
    elif [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -d "${ANDROID_SDK_ROOT}/ndk" ]; then
        info "Android SDK/NDK found (via ANDROID_SDK_ROOT)"
    elif [ -d "$HOME/Library/Android/sdk/ndk" ]; then
        info "Android SDK/NDK found at ~/Library/Android/sdk/ndk"
    else
        warn "Android NDK not found. Skipping Android builds."
        warn "Set ANDROID_NDK_HOME or ANDROID_SDK_ROOT to enable."
    fi

    if [ -d "${ANDROID_NDK_HOME:-}" ] || [ -d "${ANDROID_SDK_ROOT:-}/ndk" ] || [ -d "$HOME/Library/Android/sdk/ndk" ]; then
        for BUILD_TYPE in $(echo "$BUILD_TYPES" | tr ',' ' '); do
            for SHARED_KIND in $(echo "$SHARED_KINDS" | tr ',' ' '); do
                for ABI in $(echo "$ANDROID_ABIS" | tr ',' ' '); do
                    info ">>> Android $BUILD_TYPE shared=$SHARED_KIND abi=$ABI"

                    "$SCRIPT_DIR/build_android.sh" "$BUILD_TYPE" "$SHARED_KIND" "$ABI" "$ANDROID_API_LEVEL"
                    if [ $? -ne 0 ]; then
                        error "Android build failed for $BUILD_TYPE shared=$SHARED_KIND abi=$ABI"
                        FAILED=1
                    fi
                done
            done
        done
    else
        warn "Skipping Android builds: NDK not found."
    fi
fi

# =====================================================================
# Windows matrix
# =====================================================================
if [[ ",$PLATFORMS," == *,windows,* ]]; then
    info "===== Building Windows ====="

    if [ "$HOST_OS" == "Linux" ] || [ "$HOST_OS" == "Darwin" ]; then
        warn "Skipping Windows build: not running on Windows."
    else
        for BUILD_TYPE in $(echo "$BUILD_TYPES" | tr ',' ' '); do
            for SHARED_KIND in $(echo "$SHARED_KINDS" | tr ',' ' '); do
                info ">>> Windows $BUILD_TYPE shared=$SHARED_KIND"

                "$SCRIPT_DIR/build_windows.bat" "$BUILD_TYPE" "$SHARED_KIND" "x64" "MD"
                if [ $? -ne 0 ]; then
                    error "Windows build failed for $BUILD_TYPE shared=$SHARED_KIND"
                    FAILED=1
                fi
            done
        done
    fi
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "========================================"
if [ "$FAILED" == "0" ]; then
    info "All builds completed successfully!"
    info "Output: $SOURCE_DIR/Bin/"
else
    error "One or more builds failed. Check the output above."
    exit 1
fi
echo "========================================"
