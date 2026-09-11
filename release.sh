#!/bin/bash
# Baut eine Fassung zum Weitergeben: signiert mit Developer ID, notarisiert bei
# Apple, Notarisierung ans Buendel geheftet, gezippt.
#
#   ./release.sh 1.0
#
# Getrennt von build.sh, weil die Notarisierung bei Apple ein paar Minuten
# dauert. Der Entwicklungsbau soll schnell bleiben.
#
# Einmalige Voraussetzungen:
#   - Zertifikat "Developer ID Application" im Schluesselbund
#     (Xcode > Einstellungen > Accounts > Manage Certificates > + )
#   - Zugangsdaten fuer die Notarisierung abgelegt:
#       xcrun notarytool store-credentials "MQTT-TC002" \
#         --apple-id <deine-apple-id> --team-id <team-id aus dem Feld OU>
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Aufruf: ./release.sh <version>    z. B. ./release.sh 1.0" >&2
    exit 1
fi

PROFIL="${TC002_NOTAR_PROFIL:-MQTT-TC002}"
APP="build/MQTT-TC002.app"
DMG="build/MQTT-TC002-$VERSION.dmg"

IDENTITAET=$(security find-identity -v -p codesigning \
             | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -1)
if [ -z "$IDENTITAET" ]; then
    echo "Kein Zertifikat 'Developer ID Application' im Schluesselbund." >&2
    echo "Xcode > Einstellungen > Accounts > Manage Certificates > + " >&2
    exit 1
fi
echo "Identitaet: $IDENTITAET"

echo "== Tests =="
swift test

echo "== Bauen =="
rm -rf build
./build.sh >/dev/null

echo "== Signieren mit Developer ID =="
# --options runtime ist die Hardened Runtime, ohne die Apple nicht notarisiert.
# --timestamp holt einen Zeitstempel von Apple, damit die Signatur gueltig bleibt,
# wenn das Zertifikat spaeter ablaeuft.
codesign --force --options runtime --timestamp -s "$IDENTITAET" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "== Installationsabbild schnueren =="
# Erst jetzt, nach dem Signieren: die App im Abbild muss die fertige sein.
scripts/dmg-bauen.sh "$VERSION"

echo "== Abbild signieren =="
codesign --force --timestamp -s "$IDENTITAET" "$DMG"

echo "== Notarisieren (das dauert ein paar Minuten) =="
# Das Abbild wird eingereicht, nicht die App darin — Apple sieht hinein.
xcrun notarytool submit "$DMG" --keychain-profile "$PROFIL" --wait

echo "== Notarisierung ans Abbild heften =="
# Damit laeuft es auch auf einem Rechner, der gerade kein Netz hat.
xcrun stapler staple "$DMG"

echo "== Gegenprobe =="
# Genau die Frage, die Gatekeeper stellt — einmal fuers Abbild, einmal fuer die
# App darin. Beide muessen durchgehen, sonst sieht der Empfaenger eine Warnung.
xcrun stapler validate "$DMG"
hdiutil attach "$DMG" -noautoopen -readonly >/dev/null
spctl -a -vvv -t install "/Volumes/MQTT-TC002/MQTT-TC002.app"
hdiutil detach "/Volumes/MQTT-TC002" >/dev/null

echo
echo "fertig: $DMG ($(du -h "$DMG" | cut -f1))"
echo
echo "Als Release veroeffentlichen:"
echo "  gh release create v$VERSION \"$DMG\" --title \"MQTT-TC002 $VERSION\" --notes-file <datei>"
