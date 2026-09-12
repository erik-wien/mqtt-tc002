#!/bin/bash
# Baut MQTT-TC002.app aus dem Swift-Paket.
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"

# Die Fassungsnummer allein sagt nicht, welchen Bau man vor sich hat: Zwischen
# zwei Veroeffentlichungen entstehen viele, und alle tragen dieselbe. Deshalb
# wandert der Commit mit ins Buendel — damit laesst sich ein laufendes Programm
# eindeutig zuordnen, und ein „warum wirkt meine Aenderung nicht" ist in
# Sekunden geklaert statt in einer Dreiviertelstunde.
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unbekannt)"
git diff --quiet 2>/dev/null || COMMIT="$COMMIT+"
# Die Fassung kommt von aussen (release.sh setzt sie) oder vom juengsten Tag —
# fest eingetragen driftete sie: ein DMG „1.5" mit einer App, die sich als 1.4
# ausgibt. Die Baunummer ist die Zahl der Commits, damit sie von selbst steigt.
VERSION="${TC002_VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')}"
[ -n "$VERSION" ] || VERSION="0.0"
BAUNUMMER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
APP="build/MQTT-TC002.app"
ICON_EINTRAEGE=""

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/TC002App" "$APP/Contents/MacOS/TC002App"
# Das Kommandozeilenwerkzeug reist im Buendel mit. Dort findet es die
# mitgelieferten Schriften und die Uebersetzungen ueber Bundle.main, und es
# bleibt mit der App zusammen — eine zweite Auslieferung braucht es nicht.
cp "$BIN_DIR/mqtttc002" "$APP/Contents/MacOS/mqtttc002"
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

# Die Uebersetzungen. `de` ist die Entwicklungssprache: Dort steht der deutsche
# Wortlaut schon im Quelltext, deshalb braucht es dafuer keine Localizable.strings.
# Jeder .lproj-Ordner unter Resources/Sprachen kommt mit — an seiner Anwesenheit
# erkennt macOS, welche Sprachen die App anbietet.
mkdir -p "$APP/Contents/Resources/de.lproj"
for sprache in Resources/Sprachen/*.lproj; do
    [ -d "$sprache" ] || continue
    cp -R "$sprache" "$APP/Contents/Resources/"
done
for lproj in "$APP/Contents/Resources"/*.lproj; do
    cat > "$lproj/InfoPlist.strings" <<'STRINGS'
CFBundleName = "MQTT-TC002";
CFBundleDisplayName = "MQTT-TC002";
STRINGS
done

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>MQTT-TC002</string>
    <key>CFBundleExecutable</key><string>TC002App</string>
    <key>CFBundleIdentifier</key><string>cloud.eriks.mqtt-tc002</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BAUNUMMER}</string>
    <key>TC002Commit</key><string>${COMMIT}</string>
    <key>CFBundleDevelopmentRegion</key><string>de</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSLocalNetworkUsageDescription</key><string>Die App spricht die Pixeluhr und den MQTT-Broker in Ihrem Heimnetz an.</string>
${ICON_EINTRAEGE}
</dict>
</plist>
PLIST

cp -R Icons "$APP/Contents/Resources/Icons"
cp -R Resources/Schriften "$APP/Contents/Resources/Schriften"
cp docs/tc002-protokoll.md "$APP/Contents/Resources/tc002-protokoll.md"
# Die englische Fassung, wenn es sie gibt — die Ansicht waehlt danach.
[ -f docs/en/tc002-protocol.md ] && cp docs/en/tc002-protocol.md "$APP/Contents/Resources/tc002-protocol.md"
cp LICENSE "$APP/Contents/Resources/LICENSE"

# Signieren, wenn eine Identitaet dafuer da ist. Ohne sie signiert macOS ad hoc,
# und die Kennung traegt dann einen Hash ueber die Binaerdatei: nach jedem Bau
# ist das fuer den Schluesselbund ein anderes Programm, das an einen fremden
# Eintrag will — er fragt also erneut nach dem Broker-Kennwort. Mit fester
# Identitaet ist die Kennung die Buendelkennung und bleibt ueber Baeue gleich.
#
# Anlegen: Schluesselbundverwaltung > Zertifikatsassistent > Zertifikat
# erstellen, selbstsigniertes Root-Zertifikat, Typ Codesignatur.
# Gegen Gatekeeper hilft das NICHT, dafuer braucht es Notarisierung.
# Bevorzugt die Developer ID, weil release.sh dieselbe nimmt. Zwei verschiedene
# Identitaeten waeren fuer den Schluesselbund zwei verschiedene Programme, und er
# fragt bei jedem Wechsel erneut nach dem Broker-Kennwort.
SIGNATUR="${TC002_SIGNATUR:-}"
if [ -z "$SIGNATUR" ]; then
    SIGNATUR=$(security find-identity -v -p codesigning \
               | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -1)
fi
if [ -z "$SIGNATUR" ] && security find-certificate -c "MQTT-TC002" >/dev/null 2>&1; then
    SIGNATUR="MQTT-TC002"
fi
# Das mitreisende Werkzeug ist eine eigene Mach-O-Datei und muss vor dem
# Buendel signiert werden — danach besiegelt die Signatur des Buendels es mit.
if [ -n "$SIGNATUR" ]; then
    codesign --force -s "$SIGNATUR" "$APP/Contents/MacOS/mqtttc002" >/dev/null 2>&1 || true
fi
if [ -n "$SIGNATUR" ] && codesign --force -s "$SIGNATUR" "$APP" >/dev/null 2>&1; then
    echo "signiert als $(codesign -dv "$APP" 2>&1 | sed -n 's/^Identifier=//p')"
else
    echo "Hinweis: keine Signieridentitaet gefunden, die App bleibt ad hoc signiert." >&2
    echo "         Der Schluesselbund fragt dann nach jedem Bau erneut nach dem Broker-Kennwort." >&2
fi

echo "fertig: $APP — Fassung $VERSION ($COMMIT), Bau $BAUNUMMER"
