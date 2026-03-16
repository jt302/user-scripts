#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="UserScripts"
APP_BUNDLE_PATH="$PROJECT_ROOT/${APP_NAME}.app"
OUTPUT_DIR="$PROJECT_ROOT/output/release"
STAGING_DIR="$PROJECT_ROOT/.build-release/dmg-staging"
DMG_PATH="$OUTPUT_DIR/${APP_NAME}.dmg"
SHA256_PATH="$OUTPUT_DIR/${APP_NAME}.dmg.sha256"

if [[ ! -d "$APP_BUNDLE_PATH" ]]; then
  echo "App bundle not found at: $APP_BUNDLE_PATH" >&2
  echo "Run ./build-release.sh first." >&2
  exit 1
fi

echo "==> Preparing DMG staging directory"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$OUTPUT_DIR"
cp -R "$APP_BUNDLE_PATH" "$STAGING_DIR/"

echo "==> Building DMG"
rm -f "$DMG_PATH" "$SHA256_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo "==> Writing SHA256"
shasum -a 256 "$DMG_PATH" > "$SHA256_PATH"

echo "==> Done"
echo "DMG: $DMG_PATH"
echo "SHA256: $SHA256_PATH"
