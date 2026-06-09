#!/bin/bash

# ============================================================
# CYCommon macOS Build Script
#   Usage: build_mac.sh [all|Release|Debug] [ON|OFF] [archs...]
#   Default: all ON "arm64 x86_64"
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

# ---------- Arguments ----------
BUILD_TYPE="${1:-all}"
LIB_TYPE="${2:-OFF}"
ARCHS="${3:-arm64 x86_64}"
# Optional: override the CYCOMMON_OUTPUT_DIR (e.g., for iOS deps builds)
# Can also be set via environment variable for CYLogger integration.
CYCOMMON_OUTPUT_DIR="${4:-${CYCOMMON_OUTPUT_DIR:-}}"
# Allow env var override of IS_FINAL flag (used by CYLogger's build_macos.sh)
CYCOMMON_OUTPUT_DIR_IS_FINAL="${CYCOMMON_OUTPUT_DIR_IS_FINAL:-OFF}"
DEPLOY_TARGET="${MACOS_DEPLOYMENT_TARGET:-11.0}"

# Normalize LIB_TYPE to ON/OFF
case "$LIB_TYPE" in
    Static|static|OFF|off|0|false|FALSE) LIB_TYPE="OFF"  ;;
    Shared|shared|ON|on|1|true|TRUE)     LIB_TYPE="ON"   ;;
esac

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

echo "========================================"
echo "CYCommon macOS Build"
echo "========================================"
echo "  Build Types  : $BUILD_TYPES"
echo "  Shared libs  : $LIB_TYPE"
echo "  Architectures: $ARCHS"
echo "  Deploy Target: $DEPLOY_TARGET"
echo "========================================"

BUILD_DIR="$SOURCE_DIR/build_macos"

    # ---------- Build function for a single configuration ----------
build_config() {
    local BT="$1"

    echo ""
    echo "=========================================="
    echo "  Building: $BT"
    echo "=========================================="

    # ---------- Build each architecture slice ----------
    for ARCH in $ARCHS; do
        echo ""
        echo ">>> Building slice: $ARCH ($BT)"

        # Determine output directory for this architecture
        if [ -n "$CYCOMMON_OUTPUT_DIR" ]; then
            local CYCOMMON_OUT_PARENT="$CYCOMMON_OUTPUT_DIR"
        else
            local CYCOMMON_OUT_PARENT="$SOURCE_DIR/Bin/MacOS/$ARCH"
        fi

        local SLICE_BUILD_DIR="$BUILD_DIR/${ARCH}_${BT}_shared-${LIB_TYPE}"
        mkdir -p "$SLICE_BUILD_DIR"

        # CMAKE_ARCHIVE_OUTPUT_DIRECTORY controls where .a files go
        local cmake_output_dir_arg=""
        if [ -n "$CYCOMMON_OUTPUT_DIR" ]; then
            cmake_output_dir_arg="-DCYCOMMON_OUTPUT_DIR=$CYCOMMON_OUTPUT_DIR"
            if [ "$CYCOMMON_OUTPUT_DIR_IS_FINAL" = "ON" ]; then
                cmake_output_dir_arg="$cmake_output_dir_arg -DCYCOMMON_OUTPUT_DIR_IS_FINAL=ON"
            fi
        fi

        cmake -S "$SCRIPT_DIR" \
              -B "$SLICE_BUILD_DIR" \
              -DCMAKE_BUILD_TYPE="$BT" \
              -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
              -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOY_TARGET" \
              -DCMAKE_INSTALL_PREFIX="$CYCOMMON_OUT_PARENT" \
              -DBUILD_SHARED_LIBS="$LIB_TYPE" \
              -DBUILD_STATIC_LIBS=ON \
              ${cmake_output_dir_arg}

        cmake --build "$SLICE_BUILD_DIR" --parallel
    done

    # ---------- Collect successfully built architectures ----------
    BUILT_ARCHS=""
    for ARCH in $ARCHS; do
        if [ -n "$CYCOMMON_OUTPUT_DIR" ] && [ "$CYCOMMON_OUTPUT_DIR_IS_FINAL" = "ON" ]; then
            # IS_FINAL: CYCOMMON_OUTPUT_DIR already includes arch+BT
            local CYCOMMON_OUT_PARENT="$CYCOMMON_OUTPUT_DIR"
        elif [ -n "$CYCOMMON_OUTPUT_DIR" ]; then
            # Non-IS_FINAL: CYCOMMON_OUTPUT_DIR is parent of BT subdirectory
            local CYCOMMON_OUT_PARENT="$CYCOMMON_OUTPUT_DIR"
        else
            local CYCOMMON_OUT_PARENT="$SOURCE_DIR/Bin/MacOS/$ARCH"
        fi
        local sta_check
        if [ -n "$CYCOMMON_OUTPUT_DIR" ] && [ "$CYCOMMON_OUTPUT_DIR_IS_FINAL" = "ON" ]; then
            # IS_FINAL: file is directly inside CYCOMMON_OUT_PARENT
            if [ "$BT" = "Debug" ]; then
                sta_check="$CYCOMMON_OUT_PARENT/libCYCommonD.a"
            else
                sta_check="$CYCOMMON_OUT_PARENT/libCYCommon.a"
            fi
        else
            # Standard layout: file is in CYCOMMON_OUT_PARENT/<BT>/
            if [ "$BT" = "Debug" ]; then
                sta_check="$CYCOMMON_OUT_PARENT/$BT/libCYCommonD.a"
            else
                sta_check="$CYCOMMON_OUT_PARENT/$BT/libCYCommon.a"
            fi
        fi
        if [ -f "$sta_check" ]; then
            if [ -z "$BUILT_ARCHS" ]; then
                BUILT_ARCHS="$ARCH"
            else
                BUILT_ARCHS="$BUILT_ARCHS $ARCH"
            fi
        fi
    done

    ARCH_COUNT=0
    for A in $BUILT_ARCHS; do
        ARCH_COUNT=$((ARCH_COUNT + 1))
    done

    # ---------- Combine into universal binaries ----------
    if [ -n "$CYCOMMON_OUTPUT_DIR" ] && [ "$CYCOMMON_OUTPUT_DIR_IS_FINAL" = "ON" ]; then
        # IS_FINAL: CYCOMMON_OUTPUT_DIR already includes arch+BT, e.g. Bin/MacOS/arm64/Debug.
        # Universal should go to the top-level MacOS/ directory: Bin/MacOS/universal/Debug.
        # Use dirname to strip the BT component, then /../universal
        local _univ_base
        _univ_base="$(dirname "$CYCOMMON_OUTPUT_DIR")"  # e.g. Bin/MacOS/arm64
        _univ_base="$(dirname "$_univ_base")"         # e.g. Bin/MacOS
        local UNIV_DIR="$_univ_base/universal/$BT"
    elif [ -n "$CYCOMMON_OUTPUT_DIR" ]; then
        # Non-IS_FINAL: CYCOMMON_OUTPUT_DIR is Bin/MacOS/<arch>, file is in Bin/MacOS/<arch>/<BT>/
        local UNIV_DIR="$CYCOMMON_OUTPUT_DIR/$BT/universal"
    else
        local UNIV_DIR="$SOURCE_DIR/Bin/MacOS/universal/$BT"
    fi
    mkdir -p "$UNIV_DIR"

    if [ $ARCH_COUNT -ge 2 ]; then
        echo ""
        echo ">>> Generating universal binaries from: $BUILT_ARCHS"
    elif [ $ARCH_COUNT -eq 1 ]; then
        echo ""
        echo ">>> Single architecture ($BUILT_ARCHS), copying to universal..."
    else
        echo ""
        echo "ERROR: No architectures were built successfully for $BT."
        exit 1
    fi

    # --- Static library ---
    STATIC_SLICES=()
    for ARCH in $BUILT_ARCHS; do
        if [ -n "$CYCOMMON_OUTPUT_DIR" ] && [ "$CYCOMMON_OUTPUT_DIR_IS_FINAL" = "ON" ]; then
            # IS_FINAL: CYCOMMON_OUTPUT_DIR already includes arch+BT
            local CYCOMMON_OUT_PARENT="$CYCOMMON_OUTPUT_DIR"
        elif [ -n "$CYCOMMON_OUTPUT_DIR" ]; then
            local CYCOMMON_OUT_PARENT="$CYCOMMON_OUTPUT_DIR"
        else
            local CYCOMMON_OUT_PARENT="$SOURCE_DIR/Bin/MacOS/$ARCH"
        fi
        if [ -n "$CYCOMMON_OUTPUT_DIR" ] && [ "$CYCOMMON_OUTPUT_DIR_IS_FINAL" = "ON" ]; then
            # IS_FINAL: file is directly inside CYCOMMON_OUT_PARENT
            if [ "$BT" = "Debug" ]; then
                STA="$CYCOMMON_OUT_PARENT/libCYCommonD.a"
            else
                STA="$CYCOMMON_OUT_PARENT/libCYCommon.a"
            fi
        else
            # Standard layout: file is in CYCOMMON_OUT_PARENT/<BT>/
            if [ "$BT" = "Debug" ]; then
                STA="$CYCOMMON_OUT_PARENT/$BT/libCYCommonD.a"
            else
                STA="$CYCOMMON_OUT_PARENT/$BT/libCYCommon.a"
            fi
        fi
        if [ -f "$STA" ]; then
            STATIC_SLICES+=("$STA")
        fi
    done

    if [ ${#STATIC_SLICES[@]} -ge 2 ]; then
        if [ "$BT" = "Debug" ]; then
            lipo -create "${STATIC_SLICES[@]}" -output "$UNIV_DIR/libCYCommonD.a"
            echo "    Created universal static lib: $UNIV_DIR/libCYCommonD.a"
        else
            lipo -create "${STATIC_SLICES[@]}" -output "$UNIV_DIR/libCYCommon.a"
            echo "    Created universal static lib: $UNIV_DIR/libCYCommon.a"
        fi
    elif [ ${#STATIC_SLICES[@]} -eq 1 ]; then
        if [ "$BT" = "Debug" ]; then
            cp "${STATIC_SLICES[0]}" "$UNIV_DIR/libCYCommonD.a"
            echo "    Copied static lib to: $UNIV_DIR/libCYCommonD.a"
        else
            cp "${STATIC_SLICES[0]}" "$UNIV_DIR/libCYCommon.a"
            echo "    Copied static lib to: $UNIV_DIR/libCYCommon.a"
        fi
    fi

    # --- Shared library (dylib) ---
    if [ "$LIB_TYPE" = "ON" ]; then
        DYLIB_SLICES=()
        for ARCH in $BUILT_ARCHS; do
            if [ -n "$CYCOMMON_OUTPUT_DIR" ]; then
                local CYCOMMON_OUT_PARENT="$CYCOMMON_OUTPUT_DIR"
            else
                local CYCOMMON_OUT_PARENT="$SOURCE_DIR/Bin/MacOS/$ARCH"
            fi
            DYLIB=""
            # CYCOMMON_OUTPUT_DIR already includes BT subdirectory when IS_FINAL=ON
            local _dysearch_dir="$CYCOMMON_OUT_PARENT"
            [ -z "$CYCOMMON_OUTPUT_DIR" ] && _dysearch_dir="$CYCOMMON_OUT_PARENT/$BT"
            for f in "$_dysearch_dir"/libCYCommon*.dylib; do
                if [ -f "$f" ] && [ ! -L "$f" ]; then
                    DYLIB="$f"
                    break
                fi
            done
            if [ -z "$DYLIB" ]; then
                if [ "$BT" = "Debug" ]; then
                    DYLIB="$CYCOMMON_OUT_PARENT/$BT/libCYCommonD.dylib"
                else
                    DYLIB="$CYCOMMON_OUT_PARENT/$BT/libCYCommon.dylib"
                fi
            fi
            if [ -n "$DYLIB" ] && [ -f "$DYLIB" ]; then
                DYLIB_SLICES+=("$DYLIB")
            fi
        done

        if [ ${#DYLIB_SLICES[@]} -ge 2 ]; then
            if [ "$BT" = "Debug" ]; then
                lipo -create "${DYLIB_SLICES[@]}" -output "$UNIV_DIR/libCYCommonD.1.0.0.dylib"
                echo "    Created universal dylib: $UNIV_DIR/libCYCommonD.1.0.0.dylib"
            else
                lipo -create "${DYLIB_SLICES[@]}" -output "$UNIV_DIR/libCYCommon.1.0.0.dylib"
                echo "    Created universal dylib: $UNIV_DIR/libCYCommon.1.0.0.dylib"
            fi
        elif [ ${#DYLIB_SLICES[@]} -eq 1 ]; then
            if [ "$BT" = "Debug" ]; then
                cp "${DYLIB_SLICES[0]}" "$UNIV_DIR/libCYCommonD.1.0.0.dylib"
                echo "    Copied dylib to: $UNIV_DIR/libCYCommonD.1.0.0.dylib"
            else
                cp "${DYLIB_SLICES[0]}" "$UNIV_DIR/libCYCommon.1.0.0.dylib"
                echo "    Copied dylib to: $UNIV_DIR/libCYCommon.1.0.0.dylib"
            fi
        fi

        if [ "$BT" = "Debug" ]; then
            if [ -f "$UNIV_DIR/libCYCommonD.1.0.0.dylib" ]; then
                rm -f "$UNIV_DIR/libCYCommonD.1.dylib" "$UNIV_DIR/libCYCommonD.dylib"
                ln -s libCYCommonD.1.0.0.dylib "$UNIV_DIR/libCYCommonD.1.dylib"
                ln -s libCYCommonD.1.dylib "$UNIV_DIR/libCYCommonD.dylib"
                echo "    Created symlinks: libCYCommonD.1.dylib, libCYCommonD.dylib"
            fi
        else
            if [ -f "$UNIV_DIR/libCYCommon.1.0.0.dylib" ]; then
                rm -f "$UNIV_DIR/libCYCommon.1.dylib" "$UNIV_DIR/libCYCommon.dylib"
                ln -s libCYCommon.1.0.0.dylib "$UNIV_DIR/libCYCommon.1.dylib"
                ln -s libCYCommon.1.dylib "$UNIV_DIR/libCYCommon.dylib"
                echo "    Created symlinks: libCYCommon.1.dylib, libCYCommon.dylib"
            fi
        fi
    fi
}

# ---------- Execute builds ----------
for BT in $BUILD_TYPES; do
    build_config "$BT"
done

echo ""
echo "========================================"
echo "macOS build completed!"
echo "Output: $SOURCE_DIR/Bin/MacOS/"
echo "========================================"
