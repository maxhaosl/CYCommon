#!/bin/bash

# ============================================================
# CYCommon Linux Build Script
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

# ---------- Arguments ----------
BUILD_TYPE="${1:-Release}"
TARGET_ARCH="${2:-x86_64}"

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
detect_compiler() {
    if [ -n "${CYCOMMON_CC:-}" ] && [ -n "${CYCOMMON_CXX:-}" ]; then
        CC="$CYCOMMON_CC"
        CXX="$CYCOMMON_CXX"
        return 0
    fi

    for candidate_cc in clang clang-19 clang-18 clang-17 clang-16 clang-15 clang-14 \
                        gcc gcc-14 gcc-13 gcc-12 gcc-11 gcc-10 \
                        cc; do
        if command -v "$candidate_cc" &>/dev/null; then
            CC="${CC:-$candidate_cc}"
            break
        fi
    done

    if [ -z "${CC:-}" ]; then
        return 1
    fi

    case "$CC" in
        clang-*)   CXX="${CXX:-${CC/clang/clang++}}" ;;
        gcc-*)     CXX="${CXX:-${CC/gcc/g++}}" ;;
        clang)     CXX="${CXX:-clang++}" ;;
        gcc)       CXX="${CXX:-g++}" ;;
        cc)        CXX="${CXX:-c++}" ;;
    esac

    if ! command -v "${CXX:-}" &>/dev/null; then
        return 1
    fi

    return 0
}

linux_cxx_toolchain_works() {
    local cxx="$1" tmpdir probe
    [ -z "$cxx" ] && return 1
    tmpdir=$(mktemp -d)
    probe="$tmpdir/probe.cxx"
    printf 'int main(){return 0;}\n' >"$probe"
    "$cxx" "$probe" -o "$tmpdir/probe" -std=c++20 2>/dev/null && [ -x "$tmpdir/probe" ]
    local ok=$?
    rm -rf "$tmpdir"
    return "$ok"
}

if ! detect_compiler; then
    echo "ERROR: No C/C++ compiler found."
    echo "  Debian/Ubuntu : sudo apt install build-essential  (gcc)"
    echo "                  sudo apt install clang             (clang)"
    echo "  CentOS/RHEL   : sudo yum groupinstall 'Development Tools'"
    echo "  Alpine        : sudo apk add build-base"
    echo "  Or set CYCOMMON_CC / CYCOMMON_CXX to your compiler paths."
    exit 1
fi

if ! linux_cxx_toolchain_works "$CXX"; then
    if command -v gcc &>/dev/null && command -v g++ &>/dev/null; then
        CC="gcc"
        CXX="g++"
    fi
fi

if ! linux_cxx_toolchain_works "$CXX"; then
    echo "ERROR: C++ toolchain cannot compile and link a test program ($CXX)."
    exit 1
fi

echo "========================================"
echo "CYCommon Linux Build"
echo "========================================"
echo "  Build Type  : $BUILD_TYPE"
echo "  Library Type: static only"
echo "  Target Arch : $TARGET_ARCH"
echo "  Compiler    : $CC ($CXX)"
echo "========================================"

# ---------- Sanity check ----------
if ! command -v cmake &>/dev/null; then
    echo "ERROR: cmake not found."
    exit 1
fi

# ---------- Output directory ----------
if [ -n "${CYCOMMON_OUTPUT_DIR:-}" ]; then
    OUTPUT_DIR="$CYCOMMON_OUTPUT_DIR"
else
    OUTPUT_DIR="$SOURCE_DIR/Bin/Linux/$TARGET_ARCH/$BUILD_TYPE"
fi
mkdir -p "$OUTPUT_DIR"

# ---------- Build directory ----------
BUILD_DIR="$SOURCE_DIR/build_linux_${TARGET_ARCH}_${BUILD_TYPE}_static"
mkdir -p "$BUILD_DIR"

# ---------- Architecture flags ----------
if [ "$TARGET_ARCH" = "x86" ]; then
    ARCH_FLAGS="-m32"
elif [ "$TARGET_ARCH" = "x86_64" ]; then
    ARCH_FLAGS="-m64"
else
    ARCH_FLAGS=""
fi

# ---------- Configure ----------
CMAKE_EXTRA_ARGS=()
if [ -n "${CYCOMMON_OUTPUT_DIR:-}" ]; then
    CMAKE_EXTRA_ARGS+=(
        "-DCYCOMMON_OUTPUT_DIR=$CYCOMMON_OUTPUT_DIR"
        -DCYCOMMON_OUTPUT_DIR_IS_FINAL=ON
    )
fi

cmake -S "$SCRIPT_DIR" \
      -B "$BUILD_DIR" \
      -DCMAKE_SYSTEM_NAME=Linux \
      -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
      -DCMAKE_C_COMPILER="$CC" \
      -DCMAKE_CXX_COMPILER="$CXX" \
      -DCMAKE_CXX_FLAGS="$ARCH_FLAGS" \
      -DCMAKE_C_FLAGS="$ARCH_FLAGS" \
      -DCMAKE_SYSTEM_PROCESSOR="$TARGET_ARCH" \
      -DBUILD_SHARED_LIBS=OFF \
      -DBUILD_STATIC_LIBS=ON \
      "${CMAKE_EXTRA_ARGS[@]}"

# ---------- Build ----------
cmake --build "$BUILD_DIR" --parallel

echo ""
echo "========================================"
echo "Linux build completed!"
echo "Output: $OUTPUT_DIR"
echo "========================================"
