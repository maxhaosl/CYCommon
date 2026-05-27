#!/bin/bash

# ============================================================
# CYCommon Unix (macOS/Linux) Dispatcher Script
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

OS="$(uname -s)"

echo "========================================"
echo "CYCommon Unix Build Dispatcher"
echo "========================================"
echo "Detected OS: $OS"

if [ -z "${CYCOROUTINE_BUILD_TYPES:-}" ]; then
    CYCOROUTINE_BUILD_TYPES="${1:-Release}"
fi
if [ -z "${CYCOROUTINE_LIB_TYPES:-}" ]; then
    CYCOROUTINE_LIB_TYPES="${2:-ON}"
fi
if [ -z "${CYCOROUTINE_LINUX_ARCH:-}" ]; then
    CYCOROUTINE_LINUX_ARCH="${3:-x86_64}"
fi

case "$OS" in
    Darwin*)
        echo "Dispatching to macOS build script..."
        exec "$SCRIPT_DIR/build_mac.sh" "$@"
        ;;
    Linux*)
        echo "Dispatching to Linux matrix build script..."
        exec "$SCRIPT_DIR/build_linux_all.sh" \
            "$CYCOROUTINE_BUILD_TYPES" \
            "$CYCOROUTINE_LIB_TYPES" \
            "$CYCOROUTINE_LINUX_ARCH"
        ;;
    *)
        echo "Error: Unsupported operating system: $OS"
        exit 1
        ;;
esac
