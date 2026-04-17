#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building SpeedCheck..."

SDK_PATH=$(xcrun --show-sdk-path)

swiftc \
    -target arm64-apple-macos13.0 \
    -sdk "$SDK_PATH" \
    -parse-as-library \
    -O \
    -o SpeedCheck \
    Sources/*.swift

echo "Creating app bundle..."
rm -rf "SpeedCheck.app"
mkdir -p "SpeedCheck.app/Contents/MacOS"
mkdir -p "SpeedCheck.app/Contents/Resources"
cp SpeedCheck "SpeedCheck.app/Contents/MacOS/"
cp Info.plist "SpeedCheck.app/Contents/"
cp AppIcon.icns "SpeedCheck.app/Contents/Resources/"
rm SpeedCheck

echo "Built successfully: SpeedCheck.app"
echo "Run with: open 'SpeedCheck.app'"
