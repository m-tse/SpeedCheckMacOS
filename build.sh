#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building Network Speed..."

SDK_PATH=$(xcrun --show-sdk-path)

swiftc \
    -target arm64-apple-macos13.0 \
    -sdk "$SDK_PATH" \
    -parse-as-library \
    -O \
    -o NetworkSpeed \
    Sources/*.swift

echo "Creating app bundle..."
rm -rf "Network Speed.app"
mkdir -p "Network Speed.app/Contents/MacOS"
mkdir -p "Network Speed.app/Contents/Resources"
cp NetworkSpeed "Network Speed.app/Contents/MacOS/"
cp Info.plist "Network Speed.app/Contents/"
rm NetworkSpeed

echo "Built successfully: Network Speed.app"
echo "Run with: open 'Network Speed.app'"
