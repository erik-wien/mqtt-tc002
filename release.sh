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
APP="erzeugt/mac/MQTT-TC002.app"
DMG="erzeugt/mac/MQTT-TC002-$VERSION.dmg"

IDENTITAET=$(security find-identity -v -p codesigning \
             | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -1)
if [ -z "$IDENTITAET" ]; then
    echo "Kein Zertifikat 'Developer ID Application' im Schluesselbund." >&2
    echo "Xcode > Einstellungen > Accounts > Manage Certificates > + " >&2
    exit 1
fi
echo "Identitaet: $IDENTITAET"

# Ein veroeffentlichter Bau traegt den Commit im Ueber-Fenster. Mit „+" hiesse
# das „aus einem geaenderten, nicht eingecheckten Stand gebaut" — genau das
# soll niemand herunterladen koennen.
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Der Arbeitsbaum ist geaendert — erst einchecken, dann veroeffentlichen." >&2
    exit 1
fi

echo "== Tests =="
swift test

echo "== Bauen =="
rm -rf erzeugt/mac
TC002_VERSION="$VERSION" ./build.sh >/dev/null

# Gegenprobe: Die App im Abbild muss sich als genau diese Fassung ausgeben.
GEBAUT="$(defaults read "$PWD/$APP/Contents/Info" CFBundleShortVersionString)"
if [ "$GEBAUT" != "$VERSION" ]; then
    echo "Info.plist traegt $GEBAUT, verlangt war $VERSION." >&2
    exit 1
fi

echo "== Signieren mit Developer ID =="
# --options runtime ist die Hardened Runtime, ohne die Apple nicht notarisiert.
# --timestamp holt einen Zeitstempel von Apple, damit die Signatur gueltig bleibt,
# wenn das Zertifikat spaeter ablaeuft.
# Erst das mitreisende Kommandozeilenwerkzeug, dann das Buendel: eine zweite
# Mach-O-Datei in Contents/MacOS wird nicht von der Buendelsignatur miterfasst,
# sondern muss ihre eigene tragen — sonst scheitert die Notarisierung.
codesign --force --options runtime --timestamp -s "$IDENTITAET" "$APP/Contents/MacOS/mqtttc002"
# Das Buendel bekommt die Berechtigungen aus derselben Quelle wie build.sh
# (TC002_ENTITLEMENTS, sonst die Datei im Baum); das Werkzeug oben bekommt sie
# ausdruecklich nicht (SIGKILL ohne Profil, siehe build.sh). Ohne --entitlements
# wuerde --force die iCloud-Berechtigungen aus dem Bau stillschweigend entfernen.
BERECHTIGUNGEN="${TC002_ENTITLEMENTS-Resources/MQTT-TC002.entitlements}"
if [ -z "$BERECHTIGUNGEN" ] || [ ! -f "$BERECHTIGUNGEN" ]; then
    echo "Berechtigungsdatei fehlt: '$BERECHTIGUNGEN' — ein Release ohne iCloud-Berechtigungen wird nicht gebaut." >&2
    exit 1
fi
codesign --force --options runtime --timestamp --entitlements "$BERECHTIGUNGEN" -s "$IDENTITAET" "$APP"
codesign --verify --strict --verbose=2 "$APP"
if ! codesign -d --entitlements - --xml "$APP" 2>/dev/null \
     | grep -aq "com.apple.developer.icloud-container-identifiers"; then
    echo "Die signierte App traegt keine iCloud-Berechtigungen (com.apple.developer.icloud-container-identifiers fehlt)." >&2
    exit 1
fi

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

# ditto fuehrt nur zusammen: Was das neue Buendel nicht mehr enthaelt, bleibt im
# installierten liegen und bricht dessen Siegel. Entfernt wird einzeln, tiefste
# Pfade zuerst; das Buendel selbst bleibt stehen (Identitaet, siehe CLAUDE.md).
ueberzaehliges_entfernen() {
    local neu="$1" alt="$2" pfad
    comm -13 <(cd "$neu" && find . | LC_ALL=C sort) <(cd "$alt" && find . | LC_ALL=C sort) \
        | LC_ALL=C sort -r \
        | while IFS= read -r pfad; do
            [ "$pfad" = "." ] && continue
            if [ -d "$alt/$pfad" ] && [ ! -L "$alt/$pfad" ]; then
                rmdir "$alt/$pfad"
            else
                rm -f "$alt/$pfad"
            fi
            echo "entfernt (nicht mehr im Buendel): $pfad"
        done
}

echo "== Verteilen =="
# Die App selbst bekommt das Ticket auch (Apple hat sie im Abbild mitgeprueft), dann:
# auf diesem Mac installieren und in den geteilten iCloud-Ordner legen.
# Abschalten: TC002_VERTEILEN=0 ./release.sh <fassung>
if [ "${TC002_VERTEILEN:-1}" = "1" ]; then
    xcrun stapler staple "$APP"
    ZIEL_ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Emir/Eriks Apps"
    osascript -e 'quit app id "cloud.eriks.mqtt-tc002"' 2>/dev/null || true
    sleep 1
    # An Ort und Stelle ersetzen, nie rm -rf (Freigabe „Lokales Netzwerk“, siehe CLAUDE.md).
    ditto "$APP" /Applications/MQTT-TC002.app
    ueberzaehliges_entfernen "$APP" /Applications/MQTT-TC002.app
    if ! codesign --verify --deep --strict /Applications/MQTT-TC002.app; then
        echo "FEHLER: Signatur des installierten Buendels ungueltig" >&2
        exit 1
    fi
    xcrun stapler validate /Applications/MQTT-TC002.app >/dev/null
    echo "installiert: /Applications/MQTT-TC002.app"
    if [ -d "$ZIEL_ICLOUD" ]; then
        rm -rf "$ZIEL_ICLOUD/MQTT-TC002.app" "$ZIEL_ICLOUD"/MQTT-TC002-*.dmg
        cp "$DMG" "$ZIEL_ICLOUD/"
        echo "kopiert: $ZIEL_ICLOUD/$(basename "$DMG")"
    else
        echo "Hinweis: $ZIEL_ICLOUD fehlt — nicht kopiert" >&2
    fi
    # Werbeseite www.eriks.cloud/apps: festes DMG unter downloads/ (Ablauf: ~/GitSwift/CLAUDE.md, „Werbeseiten“).
    WEB_DMG="MQTT-TC002.dmg"
    [ -d "$HOME/GitSwift/Marketing/downloads" ] && cp "$DMG" "$HOME/GitSwift/Marketing/downloads/$WEB_DMG"
    if rsync -t --chmod=Fu=rw,Fgo=r "$DMG" "akadbrain:/opt/homebrew/var/www/apps/downloads/$WEB_DMG"; then
        echo "hochgeladen: https://www.eriks.cloud/apps/downloads/$WEB_DMG"
    else
        echo "Hinweis: Upload nach akadbrain fehlgeschlagen — Werbeseite zeigt noch das alte DMG" >&2
    fi
    open /Applications/MQTT-TC002.app
fi

echo
echo "fertig: $DMG ($(du -h "$DMG" | cut -f1))"
echo
echo "Als Release veroeffentlichen:"
echo "  gh release create v$VERSION \"$DMG\" --title \"MQTT-TC002 $VERSION\" --notes-file <datei>"
