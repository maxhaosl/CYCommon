#!/bin/bash

# ============================================================
# CYCommon Cross-Platform Build Script
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

OS="$(uname -s)"

echo "========================================"
echo "CYCommon Cross-Platform Build Script"
echo "========================================"
echo "Detected OS: $OS"

case "$OS" in
    Darwin*)
        echo "Building for macOS..."
        "$SCRIPT_DIR/build_unix.sh"
        ;;
    Linux*)
        echo "Building for Linux..."
        "$SCRIPT_DIR/build_unix.sh"
        ;;
    CYGWIN*|MINGW*|MSYS*)
        echo "Building for Windows (via MSYS/cygwin)..."
        "$SCRIPT_DIR/build_windows.bat"
        ;;
    *)
        echo "Error: Unsupported operating system: $OS"
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "Build completed successfully!"
    echo "Output files are in: $SOURCE_DIR/Bin"
    echo "========================================"
else
    echo ""
    echo "========================================"
    echo "Build failed!"
    echo "========================================"
    exit 1
fi
