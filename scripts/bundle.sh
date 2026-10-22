#!/usr/bin/env bash
# Builds a release binary and wraps it in FloatingLyrics.app under dist/.
# The bundle is what gives macOS a usage description for the Automation prompt
# and lets the app run without a Dock icon (LSUIElement).
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product FloatingLyrics 2>&1 | grep -vE "ld: warning: search path" || true
BIN="$(swift build -c release --product FloatingLyrics --show-bin-path 2>/dev/null)/FloatingLyrics"
[ -x "$BIN" ] || { echo "build failed"; exit 1; }
APP=dist/FloatingLyrics.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/FloatingLyrics"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>dev.yolandahp.floatinglyrics</string>
  <key>CFBundleName</key><string>FloatingLyrics</string>
  <key>CFBundleExecutable</key><string>FloatingLyrics</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Floating Lyrics asks Spotify which song is playing so it can show the lyrics.</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "built $APP"
