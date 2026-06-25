#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="ReadArc"
PRODUCT_NAME="ReadArc"
BUNDLE_ID="com.local.ReadArc"
MIN_SYSTEM_VERSION="14.0"
BUILD_CONFIGURATION="${READARC_BUILD_CONFIGURATION:-debug}"
BUNDLE_SHORT_VERSION="${READARC_VERSION:-0.1}"
BUNDLE_VERSION="${READARC_BUILD:-1}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$PRODUCT_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/design/assets/readarc-logo.png"
ICONSET_DIR="$DIST_DIR/$APP_NAME.iconset"
ICON_FILE="$APP_RESOURCES/$APP_NAME.icns"

cd "$ROOT_DIR"

pkill -x "$PRODUCT_NAME" >/dev/null 2>&1 || true

if [[ "$BUILD_CONFIGURATION" == "release" ]]; then
  swift build -c release --build-system native
  BUILD_DIR="$(swift build -c release --build-system native --show-bin-path)"
else
  swift build --build-system native
  BUILD_DIR="$(swift build --build-system native --show-bin-path)"
fi
BUILD_BINARY="$BUILD_DIR/$PRODUCT_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$ICON_SOURCE" "$APP_RESOURCES/readarc-logo.png"

generate_app_icon() {
  if [[ ! -f "$ICON_SOURCE" ]]; then
    echo "warning: app icon source not found: $ICON_SOURCE" >&2
    return
  fi

  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"

  case "${ICON_SOURCE##*.}" in
    svg)
      if ! command -v rsvg-convert >/dev/null 2>&1; then
        echo "warning: rsvg-convert not found; skipping app icon generation" >&2
        return
      fi

      rsvg-convert -w 16 -h 16 "$ICON_SOURCE" -o "$ICONSET_DIR/icon_16x16.png"
      rsvg-convert -w 32 -h 32 "$ICON_SOURCE" -o "$ICONSET_DIR/icon_16x16@2x.png"
      rsvg-convert -w 32 -h 32 "$ICON_SOURCE" -o "$ICONSET_DIR/icon_32x32.png"
      rsvg-convert -w 64 -h 64 "$ICON_SOURCE" -o "$ICONSET_DIR/icon_32x32@2x.png"
      rsvg-convert -w 128 -h 128 "$ICON_SOURCE" -o "$ICONSET_DIR/icon_128x128.png"
      rsvg-convert -w 256 -h 256 "$ICON_SOURCE" -o "$ICONSET_DIR/icon_128x128@2x.png"
      rsvg-convert -w 256 -h 256 "$ICON_SOURCE" -o "$ICONSET_DIR/icon_256x256.png"
      rsvg-convert -w 512 -h 512 "$ICON_SOURCE" -o "$ICONSET_DIR/icon_256x256@2x.png"
      rsvg-convert -w 512 -h 512 "$ICON_SOURCE" -o "$ICONSET_DIR/icon_512x512.png"
      rsvg-convert -w 1024 -h 1024 "$ICON_SOURCE" -o "$ICONSET_DIR/icon_512x512@2x.png"
      ;;
    png)
      sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
      sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
      sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
      sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
      sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
      sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
      sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
      sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
      sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
      sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
      ;;
    *)
      echo "warning: unsupported app icon source: $ICON_SOURCE" >&2
      return
      ;;
  esac

  iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"
  rm -rf "$ICONSET_DIR"
}

generate_app_icon

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIconFile</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$PRODUCT_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 Zanetach</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$BUNDLE_SHORT_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUNDLE_VERSION</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>PDF Document</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>com.adobe.pdf</string>
      </array>
    </dict>
  </array>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSSupportsOpeningDocumentsInPlace</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  --package|package)
    echo "$APP_BUNDLE"
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$PRODUCT_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$PRODUCT_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--package|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
