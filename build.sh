#!/bin/bash
# Baut MQTT-TC002.app aus dem Swift-Paket.
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP="build/MQTT-TC002.app"
ICON_EINTRAEGE=""

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/TC002App" "$APP/Contents/MacOS/TC002App"
for b in "$BIN_DIR"/*.bundle; do [ -e "$b" ] && cp -R "$b" "$APP/Contents/Resources/"; done

# Icon: Das Icon-Composer-Buendel wird mit actool zu Assets.car (Liquid Glass ab macOS 26)
# plus AppIcon.icns uebersetzt. Ohne actool wird Resources/AppIcon-flach.icns benutzt,
# falls vorhanden; sonst bleibt die App ohne eigenes Icon.
ICON_OK=0
if xcrun --find actool >/dev/null 2>&1 && [ -d "Resources/AppIcon.icon" ]; then
    ICONBAU="$(mktemp -d)"
    cp -R "Resources/AppIcon.icon" "$ICONBAU/AppIcon.icon"
    if xcrun actool "$ICONBAU/AppIcon.icon" \
        --compile "$(pwd)/$APP/Contents/Resources" \
        --app-icon AppIcon \
        --platform macosx \
        --minimum-deployment-target 14.0 \
        --output-partial-info-plist "$ICONBAU/icon.plist" >/dev/null 2>&1 \
       && [ -f "$APP/Contents/Resources/AppIcon.icns" ]; then
        ICON_OK=2
        echo "Icon: aus AppIcon.icon uebersetzt (Assets.car + AppIcon.icns)"
    fi
    rm -rf "$ICONBAU"
fi
if [ "$ICON_OK" -eq 0 ] && [ -f "Resources/AppIcon-flach.icns" ]; then
    cp "Resources/AppIcon-flach.icns" "$APP/Contents/Resources/AppIcon.icns"
    ICON_OK=1
    echo "Icon: flache Fassung benutzt"
fi
if [ "$ICON_OK" -ge 1 ]; then
    ICON_EINTRAEGE='    <key>CFBundleIconFile</key><string>AppIcon.icns</string>'
fi
if [ "$ICON_OK" -eq 2 ]; then
    ICON_EINTRAEGE="$ICON_EINTRAEGE
    <key>CFBundleIconName</key><string>AppIcon</string>"
fi
[ "$ICON_OK" -eq 0 ] && echo "Icon: keines gefunden, App ohne eigenes Icon"

mkdir -p "$APP/Contents/Resources/de.lproj"
cat > "$APP/Contents/Resources/de.lproj/InfoPlist.strings" <<'STRINGS'
CFBundleName = "MQTT-TC002";
CFBundleDisplayName = "MQTT-TC002";
STRINGS

cat > "$APP/Contents/Info.plist" <<PLIST
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
    <key>NSLocalNetworkUsageDescription</key><string>Die App spricht die Pixeluhr und den MQTT-Broker in Ihrem Heimnetz an.</string>
${ICON_EINTRAEGE}
</dict>
</plist>
PLIST

cp -R Icons "$APP/Contents/Resources/Icons"

echo "fertig: $APP"
