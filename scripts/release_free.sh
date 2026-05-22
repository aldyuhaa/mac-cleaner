#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Mac Cleaner.app"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$DIST_DIR/release"
APP_PATH="$DIST_DIR/$APP_NAME"
ZIP_PATH="$RELEASE_DIR/Mac-Cleaner.zip"
SHA_PATH="$RELEASE_DIR/Mac-Cleaner.sha256"

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/package_app.sh"

mkdir -p "$RELEASE_DIR"
rm -f "$ZIP_PATH" "$SHA_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

(
    cd "$RELEASE_DIR"
    shasum -a 256 "Mac-Cleaner.zip" > "Mac-Cleaner.sha256"
)

printf "Release zip: %s\n" "$ZIP_PATH"
printf "Checksum: %s\n" "$SHA_PATH"
