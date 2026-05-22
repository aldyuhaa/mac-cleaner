#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Mac Cleaner"
BUNDLE_ID="com.aldy-uhaa.maccleaner"
EXECUTABLE_NAME="MacCleaner"
BUILD_CONFIG="release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SOURCE_EXECUTABLE="$ROOT_DIR/.build/$BUILD_CONFIG/$EXECUTABLE_NAME"
ICON_FILE="$ROOT_DIR/Packaging/MacCleaner.icns"

cd "$ROOT_DIR"

swift build -c "$BUILD_CONFIG"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$SOURCE_EXECUTABLE" "$MACOS_DIR/$EXECUTABLE_NAME"
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
if [[ -f "$ICON_FILE" ]]; then
    cp "$ICON_FILE" "$RESOURCES_DIR/MacCleaner.icns"
fi
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_DIR" >/dev/null
fi

printf "Created: %s\n" "$APP_DIR"
