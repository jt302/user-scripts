#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="UserScripts"
EXECUTABLE_NAME="UserScriptsApp"
APP_BUNDLE_PATH="$PROJECT_ROOT/${APP_NAME}.app"
CONTENTS_PATH="$APP_BUNDLE_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"
SCRATCH_PATH="$PROJECT_ROOT/.build-release"
ARM64_SCRATCH_PATH="$SCRATCH_PATH/arm64"
X86_SCRATCH_PATH="$SCRATCH_PATH/x86_64"
UNIVERSAL_DIR="$SCRATCH_PATH/universal"
ARM64_MODULE_CACHE_PATH="$SCRATCH_PATH/clang-module-cache-arm64"
X86_MODULE_CACHE_PATH="$SCRATCH_PATH/clang-module-cache-x86_64"
ICON_SOURCE_SVG="$PROJECT_ROOT/assets/icon/userscripts-icon.svg"
ICON_RENDER_DIR="$SCRATCH_PATH/icon-render"
ICONSET_PATH="$SCRATCH_PATH/${APP_NAME}.iconset"
ICON_FILE_NAME="${APP_NAME}.icns"
ARM64_BIN_PATH=""
X86_BIN_PATH=""
BIN_PATH="$UNIVERSAL_DIR/$EXECUTABLE_NAME"

echo "==> Building release binaries"
mkdir -p \
  "$ARM64_SCRATCH_PATH" \
  "$X86_SCRATCH_PATH" \
  "$UNIVERSAL_DIR" \
  "$ARM64_MODULE_CACHE_PATH" \
  "$X86_MODULE_CACHE_PATH"

env \
  CLANG_MODULE_CACHE_PATH="$ARM64_MODULE_CACHE_PATH" \
  swift build \
  -c release \
  --arch arm64 \
  --product "$EXECUTABLE_NAME" \
  --scratch-path "$ARM64_SCRATCH_PATH"

env \
  CLANG_MODULE_CACHE_PATH="$X86_MODULE_CACHE_PATH" \
  swift build \
  -c release \
  --arch x86_64 \
  --product "$EXECUTABLE_NAME" \
  --scratch-path "$X86_SCRATCH_PATH"

ARM64_BIN_DIR="$(
  env \
    CLANG_MODULE_CACHE_PATH="$ARM64_MODULE_CACHE_PATH" \
    swift build \
    -c release \
    --arch arm64 \
    --product "$EXECUTABLE_NAME" \
    --scratch-path "$ARM64_SCRATCH_PATH" \
    --show-bin-path
)"
X86_BIN_DIR="$(
  env \
    CLANG_MODULE_CACHE_PATH="$X86_MODULE_CACHE_PATH" \
    swift build \
    -c release \
    --arch x86_64 \
    --product "$EXECUTABLE_NAME" \
    --scratch-path "$X86_SCRATCH_PATH" \
    --show-bin-path
)"

ARM64_BIN_PATH="$ARM64_BIN_DIR/$EXECUTABLE_NAME"
X86_BIN_PATH="$X86_BIN_DIR/$EXECUTABLE_NAME"

if [[ ! -x "$ARM64_BIN_PATH" ]]; then
  echo "Build succeeded but arm64 executable was not found at: $ARM64_BIN_PATH" >&2
  exit 1
fi

if [[ ! -x "$X86_BIN_PATH" ]]; then
  echo "Build succeeded but x86_64 executable was not found at: $X86_BIN_PATH" >&2
  exit 1
fi

echo "==> Creating universal binary"
lipo -create -output "$BIN_PATH" "$ARM64_BIN_PATH" "$X86_BIN_PATH"

echo "==> Packaging app bundle"
rm -rf "$APP_BUNDLE_PATH"
mkdir -p "$MACOS_PATH" "$RESOURCES_PATH"
cp "$BIN_PATH" "$MACOS_PATH/$EXECUTABLE_NAME"
chmod +x "$MACOS_PATH/$EXECUTABLE_NAME"

if [[ -f "$ICON_SOURCE_SVG" ]]; then
  echo "==> Building app icon"
  rm -rf "$ICON_RENDER_DIR" "$ICONSET_PATH"
  mkdir -p "$ICON_RENDER_DIR" "$ICONSET_PATH"

  qlmanage -t -s 1024 -o "$ICON_RENDER_DIR" "$ICON_SOURCE_SVG" >/dev/null 2>&1
  BASE_ICON_PNG="$ICON_RENDER_DIR/$(basename "$ICON_SOURCE_SVG").png"

  if [[ ! -f "$BASE_ICON_PNG" ]]; then
    echo "Failed to render icon source: $ICON_SOURCE_SVG" >&2
    exit 1
  fi

  make_icon() {
    local size="$1"
    local filename="$2"
    sips -z "$size" "$size" "$BASE_ICON_PNG" --out "$ICONSET_PATH/$filename" >/dev/null
  }

  make_icon 16 "icon_16x16.png"
  make_icon 32 "icon_16x16@2x.png"
  make_icon 32 "icon_32x32.png"
  make_icon 64 "icon_32x32@2x.png"
  make_icon 128 "icon_128x128.png"
  make_icon 256 "icon_128x128@2x.png"
  make_icon 256 "icon_256x256.png"
  make_icon 512 "icon_256x256@2x.png"
  make_icon 512 "icon_512x512.png"
  cp "$BASE_ICON_PNG" "$ICONSET_PATH/icon_512x512@2x.png"

  iconutil -c icns "$ICONSET_PATH" -o "$RESOURCES_PATH/$ICON_FILE_NAME"
fi

cat > "$CONTENTS_PATH/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>UserScripts</string>
  <key>CFBundleIconFile</key>
  <string>UserScripts.icns</string>
  <key>CFBundleExecutable</key>
  <string>UserScriptsApp</string>
  <key>CFBundleIdentifier</key>
  <string>com.tt.userscripts</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>UserScripts</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if command -v plutil >/dev/null 2>&1; then
  plutil -lint "$CONTENTS_PATH/Info.plist" >/dev/null
fi

if command -v codesign >/dev/null 2>&1; then
  echo "==> Applying ad-hoc signature"
  if ! codesign --force --deep --sign - "$APP_BUNDLE_PATH"; then
    echo "Warning: ad-hoc signing failed, app bundle was still generated." >&2
  fi
fi

echo "==> Done"
echo "App bundle: $APP_BUNDLE_PATH"
