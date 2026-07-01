#!/usr/bin/env bash
# Build a signed Macmd.app (release) into the project directory.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --product Macmd
BIN="$(swift build -c release --show-bin-path)/Macmd"

APP="./Macmd.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Macmd"
[ -f Icon/Macmd.icns ] && cp Icon/Macmd.icns "$APP/Contents/Resources/Macmd.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Macmd</string>
  <key>CFBundleDisplayName</key><string>Macmd</string>
  <key>CFBundleIdentifier</key><string>com.deepcells.macmd</string>
  <key>CFBundleExecutable</key><string>Macmd</string>
  <key>CFBundleIconFile</key><string>Macmd</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>0.1</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"
