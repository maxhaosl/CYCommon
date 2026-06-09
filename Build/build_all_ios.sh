#!/bin/bash

# ============================================================
# CYCommon iOS Build Script
#   Builds device and simulator slices, creates universal
#   binaries for each platform, and optionally an XCFramework.
#
#   Usage: build_ios.sh [all|Release|Debug] [ON|OFF] [archs...]
#   Default: all OFF "arm64 x86_64 arm64-simulator"
#
#   Device architectures:  arm64
#   Simulator architectures: x86_64 arm64-simulator
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

# ---------- Arguments ----------
BUILD_TYPE="${1:-all}"
LIB_TYPE="${2:-OFF}"
ARCHS="${3:-arm64 x86_64 arm64-simulator}"
DEPLOY_TARGET="${IOS_DEPLOYMENT_TARGET:-14.0}"

# ---------- Build types ----------
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
echo "  Build Types  : $BUILD_TYPES"
echo "  Shared libs  : $LIB_TYPE"
echo "  Architectures: $ARCHS"
echo "  Deploy Target: $DEPLOY_TARGET"
echo "========================================"

BUILD_DIR="$SOURCE_DIR/build_ios"

# ---------- Architecture -> SDK mapping ----------
get_sdk_info() {
    local arch="$1"
    case "$arch" in
        arm64)
            echo "iphoneos" "$arch" "$DEPLOY_TARGET"
            ;;
        armv7|armv7s|i386)
            echo "ERROR: Architecture '$arch' is no longer supported by modern iOS SDKs. Use arm64 or x86_64." >&2
            return 1
            ;;
        arm64-simulator)
            echo "iphonesimulator" "arm64" "$DEPLOY_TARGET"
            ;;
        x86_64)
            echo "iphonesimulator" "$arch" "$DEPLOY_TARGET"
            ;;
        *)
            echo "iphonesimulator" "$arch" "$DEPLOY_TARGET"
            ;;
    esac
}

# ---------- Build function for a single configuration ----------
build_config() {
    local BT="$1"
    echo ""
    echo "=========================================="
    echo "  Building: $BT"
    echo "=========================================="

    DEVICE_ARCHS=""
    SIM_ARCHS=""
    ARM64_SIM_ARCH=""

    for ARCH in $ARCHS; do
        echo ""
        echo ">>> Building slice: $ARCH ($BT)"

        SDK_INFO=$(get_sdk_info "$ARCH") || continue
        SDK_NAME=$(echo "$SDK_INFO" | awk '{print $1}')
        CMAKE_ARCH=$(echo "$SDK_INFO" | awk '{print $2}')
        ARCH_DEPLOY_TARGET=$(echo "$SDK_INFO" | awk '{print $3}')

        # Detect arm64-simulator: arm64 architecture with iPhoneSimulator SDK
        if [ "$ARCH" = "arm64-simulator" ]; then
            ARM64_SIM_ARCH="arm64-simulator"
        fi

        SYSROOT=$(xcrun --sdk "$SDK_NAME" --show-sdk-path 2>/dev/null || echo "")
        if [ -z "$SYSROOT" ]; then
            echo "    WARNING: SDK '$SDK_NAME' not found, skipping $ARCH"
            continue
        fi

        SLICE_BUILD_DIR="$BUILD_DIR/${ARCH}_${BT}_shared-${LIB_TYPE}"
        mkdir -p "$SLICE_BUILD_DIR"

        ARCH_OUT_DIR="$SOURCE_DIR/Bin/iOS/$ARCH"

        cmake -S "$SCRIPT_DIR" \
              -B "$SLICE_BUILD_DIR" \
              -DCMAKE_BUILD_TYPE="$BT" \
              -DCMAKE_SYSTEM_NAME="iOS" \
              -DCMAKE_OSX_ARCHITECTURES="$CMAKE_ARCH" \
              -DCMAKE_OSX_DEPLOYMENT_TARGET="$ARCH_DEPLOY_TARGET" \
              -DCMAKE_OSX_SYSROOT="$SYSROOT" \
              -DCMAKE_INSTALL_PREFIX="$ARCH_OUT_DIR" \
              -DBUILD_SHARED_LIBS="$LIB_TYPE" \
              -DBUILD_STATIC_LIBS=ON \
              -DIOS=ON \
              -DCYCOMMON_OUTPUT_ARCH="$ARCH"

        cmake --build "$SLICE_BUILD_DIR" --parallel

        if [ "$SDK_NAME" = "iphoneos" ]; then
            if [ -z "$DEVICE_ARCHS" ]; then
                DEVICE_ARCHS="$ARCH"
            else
                DEVICE_ARCHS="$DEVICE_ARCHS $ARCH"
            fi
        else
            if [ -z "$SIM_ARCHS" ]; then
                SIM_ARCHS="$ARCH"
            else
                SIM_ARCHS="$SIM_ARCHS $ARCH"
            fi
        fi
    done

    echo ""
    echo ">>> Combining $BT binaries"

    # --- Device universal binary ---
    if [ -n "$DEVICE_ARCHS" ]; then
        create_fat "device" "$DEVICE_ARCHS" "$BT"
    fi

    # --- Simulator universal binary ---
    if [ -n "$SIM_ARCHS" ]; then
        create_fat "simulator" "$SIM_ARCHS" "$BT"
    fi

    # --- arm64-simulator standalone (single-arch, same as arm64 device slice) ---
    if [ -n "$ARM64_SIM_ARCH" ]; then
        create_fat "arm64-simulator" "$ARM64_SIM_ARCH" "$BT"
    fi

    # --- Combined universal library ---
    # CMake outputs to $A/$BT/ (Debug uses libCYCommonD.a; Release uses libCYCommon.a).
    if [ "$BT" = "Debug" ]; then
        _CYCOMMON_SLICE_NAME="libCYCommonD.a"
        _CYCOMMON_UNIV_NAME="libCYCommonD.a"
    else
        _CYCOMMON_SLICE_NAME="libCYCommon.a"
        _CYCOMMON_UNIV_NAME="libCYCommon.a"
    fi

    UNIV_DIR="$SOURCE_DIR/Bin/iOS/universal/$BT"
    mkdir -p "$UNIV_DIR"

    USED_ARCH_LIST=""
    DEDUPED_SLICES=()
    for A in $DEVICE_ARCHS $SIM_ARCHS; do
        SLICE="$SOURCE_DIR/Bin/iOS/$A/$BT/$_CYCOMMON_SLICE_NAME"
        if [ ! -f "$SLICE" ]; then
            continue
        fi
        SLICE_ARCHS=$(lipo -archs "$SLICE" 2>/dev/null)
        for SA in $SLICE_ARCHS; do
            ALREADY=0
            for UA in $USED_ARCH_LIST; do
                if [ "$UA" = "$SA" ]; then
                    ALREADY=1
                    break
                fi
            done
            if [ $ALREADY -eq 0 ]; then
                USED_ARCH_LIST="$USED_ARCH_LIST $SA"
                DEDUPED_SLICES+=("$SLICE")
            fi
        done
    done

    SLICE_COUNT=${#DEDUPED_SLICES[@]}
    if [ $SLICE_COUNT -ge 2 ]; then
        lipo -create "${DEDUPED_SLICES[@]}" -output "$UNIV_DIR/$_CYCOMMON_UNIV_NAME" && \
            echo "    Created combined universal: $UNIV_DIR/$_CYCOMMON_UNIV_NAME ($USED_ARCH_LIST)"
    elif [ $SLICE_COUNT -eq 1 ]; then
        if [ "${DEDUPED_SLICES[0]}" != "$UNIV_DIR/$_CYCOMMON_UNIV_NAME" ]; then
            cp "${DEDUPED_SLICES[0]}" "$UNIV_DIR/$_CYCOMMON_UNIV_NAME"
            echo "    Copied single-arch lib to: $UNIV_DIR/$_CYCOMMON_UNIV_NAME"
        else
            echo "    Combined universal already in place: $UNIV_DIR/$_CYCOMMON_UNIV_NAME"
        fi
    else
        echo "    NOTE: No slices available for combined universal"
    fi

    # --- XCFramework ---
    if [ -n "$DEVICE_ARCHS" ] && [ -n "$SIM_ARCHS" ]; then
        XCFRAMEWORK_DIR="$SOURCE_DIR/Bin/iOS/CYCommon.xcframework"

        DEV_SLICES=()
        SIM_SLICES=()
        for A in $DEVICE_ARCHS; do
            SLICE="$SOURCE_DIR/Bin/iOS/$A/$BT/$_CYCOMMON_SLICE_NAME"
            if [ -f "$SLICE" ]; then
                DEV_SLICES+=("$SLICE")
            fi
        done
        for A in $SIM_ARCHS; do
            SLICE="$SOURCE_DIR/Bin/iOS/$A/$BT/$_CYCOMMON_SLICE_NAME"
            if [ -f "$SLICE" ]; then
                SIM_SLICES+=("$SLICE")
            fi
        done

        if [ ${#DEV_SLICES[@]} -ge 1 ] && [ ${#SIM_SLICES[@]} -ge 1 ]; then
            rm -rf "$XCFRAMEWORK_DIR"
            XCARGS=()
            for SLICE in "${DEV_SLICES[@]}"; do
                XCARGS+=(-library "$SLICE")
            done
            for SLICE in "${SIM_SLICES[@]}"; do
                XCARGS+=(-library "$SLICE")
            done

            if xcodebuild -create-xcframework "${XCARGS[@]}" -output "$XCFRAMEWORK_DIR" 2>/dev/null; then
                echo "    Created XCFramework ($BT): $XCFRAMEWORK_DIR"
            fi
        fi
    fi
}

# ---------- Helper: create fat binary ----------
create_fat() {
    local PLATFORM="$1"
    local ARCH_LIST="$2"
    local BT="$3"
    # CMake outputs to $A/$BT/ (no CYCOMMON_OUTPUT_DIR_IS_FINAL).
    # Debug builds use libCYCommonD.a; Release uses libCYCommon.a.
    if [ "$BT" = "Debug" ]; then
        _CYCOMMON_FAT_NAME="libCYCommonD.a"
    else
        _CYCOMMON_FAT_NAME="libCYCommon.a"
    fi
    local OUT_DIR="$SOURCE_DIR/Bin/iOS/$PLATFORM/$BT"
    mkdir -p "$OUT_DIR"

    local COUNT=0
    local SLICES=()
    for A in $ARCH_LIST; do
        local SLICE="$SOURCE_DIR/Bin/iOS/$A/$BT/$_CYCOMMON_FAT_NAME"
        if [ -f "$SLICE" ]; then
            SLICES+=("$SLICE")
            COUNT=$((COUNT + 1))
        fi
    done

    if [ $COUNT -eq 0 ]; then
        echo "    WARNING: No slices for $PLATFORM ($BT)"
        return
    fi

    if [ $COUNT -ge 2 ]; then
        lipo -create "${SLICES[@]}" -output "$OUT_DIR/$_CYCOMMON_FAT_NAME"
        echo "    Created $PLATFORM fat static lib ($BT, $COUNT slices)"
    elif [ $COUNT -eq 1 ]; then
        if [ "${SLICES[0]}" != "$OUT_DIR/$_CYCOMMON_FAT_NAME" ]; then
            cp "${SLICES[0]}" "$OUT_DIR/$_CYCOMMON_FAT_NAME"
            echo "    Copied $PLATFORM static lib ($BT, 1 slice)"
        else
            echo "    $PLATFORM static lib already in place ($BT, 1 slice)"
        fi
    fi

    if [ "$LIB_TYPE" = "ON" ]; then
        local DYLIB_NAME
        if [ "$BT" = "Debug" ]; then
            DYLIB_NAME="libCYCommonD.dylib"
        else
            DYLIB_NAME="libCYCommon.dylib"
        fi
        local DYLIB_SLICES=()
        for A in $ARCH_LIST; do
            local DYLIB="$SOURCE_DIR/Bin/iOS/$A/$BT/$DYLIB_NAME"
            if [ -f "$DYLIB" ]; then
                DYLIB_SLICES+=("$DYLIB")
            fi
        done
        if [ ${#DYLIB_SLICES[@]} -ge 2 ]; then
            lipo -create "${DYLIB_SLICES[@]}" -output "$OUT_DIR/$DYLIB_NAME"
        elif [ ${#DYLIB_SLICES[@]} -eq 1 ]; then
            cp "${DYLIB_SLICES[0]}" "$OUT_DIR/$DYLIB_NAME"
        fi
    fi
}

# ---------- Execute builds ----------
for BT in $BUILD_TYPES; do
    build_config "$BT"
done

echo ""
echo "========================================"
echo "iOS build completed!"
echo "  Device   : $SOURCE_DIR/Bin/iOS/device/"
echo "  Simulator: $SOURCE_DIR/Bin/iOS/simulator/"
echo "  Universal: $SOURCE_DIR/Bin/iOS/universal/"
echo "========================================"
