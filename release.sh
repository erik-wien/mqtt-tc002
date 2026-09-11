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
ZIP="build/MQTT-TC002-$VERSION.zip"

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

echo "== Einpacken =="
# ditto statt zip: erhaelt die Symbolverweise und erweiterten Attribute des Buendels.
ditto -c -k --keepParent "$APP" "$ZIP"

echo "== Notarisieren (das dauert ein paar Minuten) =="
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFIL" --wait

echo "== Notarisierung ans Buendel heften =="
# Damit laeuft die App auch, wenn der Rechner gerade kein Netz hat.
xcrun stapler staple "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "== Gegenprobe =="
# Das ist die Frage, die Gatekeeper beim Oeffnen stellt.
spctl -a -vvv -t install "$APP"
xcrun stapler validate "$APP"

echo
echo "fertig: $ZIP"
echo
echo "Als Release veroeffentlichen:"
echo "  gh release create v$VERSION \"$ZIP\" --title \"MQTT-TC002 $VERSION\" --notes-file <datei>"
