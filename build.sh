#!/bin/bash
# Baut MQTT-TC002.app aus dem Swift-Paket.
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP="build/MQTT-TC002.app"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/TC002App" "$APP/Contents/MacOS/TC002App"
for b in "$BIN_DIR"/*.bundle; do [ -e "$b" ] && cp -R "$b" "$APP/Contents/Resources/"; done

mkdir -p "$APP/Contents/Resources/de.lproj"
cat > "$APP/Contents/Resources/de.lproj/InfoPlist.strings" <<'STRINGS'
CFBundleName = "MQTT-TC002";
CFBundleDisplayName = "MQTT-TC002";
STRINGS

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>MQTT-TC002</string>
    <key>CFBundleExecutable</key><string>TC002App</string>
    <key>CFBundleIdentifier</key><string>cloud.eriks.mqtt-tc002</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleDevelopmentRegion</key><string>de</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "fertig: $APP"
