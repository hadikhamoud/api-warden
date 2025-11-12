#!/usr/bin/env bash

set -e


REPO="hadikhamoud/api-warden"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
BINARY_NAME="api-warden"

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Linux*)
        PLATFORM="linux"
        ;;
    Darwin*)
        PLATFORM="macos"
        ;;
    *)
        echo "Unsupported operating system: $OS"
        exit 1
        ;;
esac

case "$ARCH" in
    x86_64)
        ARCH_NAME="x86_64"
        ;;
    arm64|aarch64)
        ARCH_NAME="aarch64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

ASSET_NAME="${BINARY_NAME}-${PLATFORM}-${ARCH_NAME}"

echo "Installing API Warden..."
echo "Platform: $PLATFORM"
echo "Architecture: $ARCH_NAME"
echo "Install directory: $INSTALL_DIR"
echo

RELEASE_URL="https://api.github.com/repos/$REPO/releases/latest"
DOWNLOAD_URL=$(curl -sL "$RELEASE_URL" | grep "browser_download_url.*${ASSET_NAME}.tar.gz" | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: Could not find release for $ASSET_NAME"
    echo "Building from source instead..."
    
    if ! command -v zig &> /dev/null; then
        echo "Error: Zig is not installed. Please install Zig first:"
        echo "  https://ziglang.org/download/"
        exit 1
    fi
    
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    git clone "https://github.com/$REPO.git"
    cd api-warden
    zig build -Doptimize=ReleaseSafe
    
    if [ -w "$INSTALL_DIR" ]; then
        cp zig-out/bin/api-warden "$INSTALL_DIR/"
    else
        sudo cp zig-out/bin/api-warden "$INSTALL_DIR/"
    fi
    
    cd /
    rm -rf "$TEMP_DIR"
else
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    echo "Downloading $ASSET_NAME..."
    curl -sL "$DOWNLOAD_URL" -o "${ASSET_NAME}.tar.gz"
    
    echo "Extracting..."
    tar xzf "${ASSET_NAME}.tar.gz"
    
    echo "Installing to $INSTALL_DIR..."
    if [ -w "$INSTALL_DIR" ]; then
        mv api-warden "$INSTALL_DIR/"
    else
        sudo mv api-warden "$INSTALL_DIR/"
    fi
    
    cd /
    rm -rf "$TEMP_DIR"
fi

echo
echo "API Warden installed successfully!"
echo "Run 'api-warden --help' to get started."
