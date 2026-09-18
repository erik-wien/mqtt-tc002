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
# Alles Erzeugte liegt unter `erzeugt/` — die fertige Mac-App also in
# `erzeugt/mac/`. Der Ordner ist ignoriert; in der Wurzel stehen dadurch nur
# noch die Quellen und die drei Skripte, die man wirklich aufruft.
# **Der Dateiname bleibt.** Die App heisst seit dem 14.09.2026 „Pixel Clock
# Messenger" — das ist `CFBundleName`/`CFBundleDisplayName`, also was in der
# Menueleiste und unter dem Symbol steht. Das **Buendel** weiter umzubenennen
# waere teuer: Die Freigabe „Lokales Netzwerk" haengt am Programm, und ein
# anders benanntes gilt als ein anderes (siehe CLAUDE.md, „Nach /Applications
# installieren"). Kennung, Datenordner und der Befehl `mqtttc002` bleiben aus
# demselben Grund, wie sie sind.
APP="erzeugt/mac/MQTT-TC002.app"
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

# Ein Ziel mit einem Bildkatalog (z.B. TC002Ansichten) bringt sein eigenes
# .bundle mit, darin den Katalog aber nur roh kopiert: `swift build` uebersetzt
# .xcassets ueber die Kommandozeile nicht selbst zu Assets.car — das tut nur
# Xcode als Bauherr (wie beim iOS-Ziel). Ohne diesen Schritt bliebe
# Bundle.module fuer benannte Bilder leer und die Vorschau zeigte einen leeren
# Rahmen, ohne dass der Bau etwas meldet.
for b in "$APP/Contents/Resources"/*.bundle; do
    [ -d "$b" ] || continue
    for katalog in "$b"/*.xcassets; do
        [ -d "$katalog" ] || continue
        if ! xcrun --find actool >/dev/null 2>&1; then
            echo "Warnung: actool fehlt, $katalog bleibt unuebersetzt und seine Bilder fehlen der App." >&2
            continue
        fi
        PARTIAL="$(mktemp)"
        if xcrun actool "$katalog" --compile "$b" --platform macosx \
            --minimum-deployment-target 14.0 \
            --output-partial-info-plist "$PARTIAL" >/dev/null 2>&1 \
           && [ -f "$b/Assets.car" ]; then
            rm -rf "$katalog"
        else
            echo "Warnung: $katalog konnte nicht uebersetzt werden, seine Bilder fehlen der App." >&2
        fi
        rm -f "$PARTIAL"
    done
done

# SwiftPMs nativer Bauweg legt ein Ressourcenbuendel ohne Info.plist an — die
# Datei landet nirgends im Quelltext, `swift build` erzeugt sie nur fuer
# Xcode-Bauten. Ohne CFBundleIdentifier kann das Buendel seinen Bildkatalog
# aber nicht bei CoreUI registrieren: `Bundle(path:)` gelingt, `Assets.car`
# ist da und lesbar (auch fuer assetutil), doch `image(forResource:)` liefert
# trotzdem still nil — genau der Fehler, der den Geraeterahmen am Mac
# unsichtbar machte, waehrend die alte Pruefung nur nach der Datei sah statt
# nach ihrer Benutzbarkeit. Die Kennung wird aus dem Buendelnamen abgeleitet,
# damit mehrere Ziele mit eigenem Katalog sich nicht ins Gehege kommen.
for b in "$APP/Contents/Resources"/*.bundle; do
    [ -d "$b" ] || continue
    [ -f "$b/Info.plist" ] && continue
    NAME="$(basename "$b" .bundle)"
    KENNUNG="cloud.eriks.mqtt-tc002.bundle.$(printf '%s' "$NAME" | tr -c 'A-Za-z0-9' '-')"
    cat > "$b/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>${KENNUNG}</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundlePackageType</key><string>BNDL</string>
    <key>CFBundleName</key><string>${NAME}</string>
</dict>
</plist>
PLIST
done

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
CFBundleName = "Pixel Clock Messenger";
CFBundleDisplayName = "Pixel Clock Messenger";
STRINGS
done

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Pixel Clock Messenger</string>
    <!-- **Beide Schluessel, nicht nur einer.** `CFBundleDisplayName` stand bis
         zum 18.09.2026 allein in den `InfoPlist.strings` — und eine
         Uebersetzung kann nur ueberschreiben, was es im Original gibt. Ohne den
         Schluessel hier griff sie ins Leere, und Finder, Dock und Menueleiste
         fielen auf den **Dateinamen** zurueck: „MQTT-TC002". Der Dateiname
         bleibt genau so (die Freigabe „Lokales Netzwerk" haengt daran, siehe
         CLAUDE.md); sichtbar ist kuenftig der Anzeigename. -->
    <key>CFBundleDisplayName</key><string>Pixel Clock Messenger</string>
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
    <!-- Derselbe Eintrag wie in project.yml fuer iOS: Damit der iCloud-Behaelter
         in iCloud Drive auftaucht und einen Namen hat, statt unsichtbar zu
         bleiben. Icons und Bilder werden als GIF gesichert, gerade damit man
         sie auch ausserhalb der App sieht — im Behaelter soll das so bleiben.
         Ohne registrierten Behaelter beschreibt der Schluessel nur etwas, das
         es nicht gibt, und schadet nichts. -->
    <key>NSUbiquitousContainers</key>
    <dict>
        <key>iCloud.cloud.eriks.mqtt-tc002</key>
        <dict>
            <key>NSUbiquitousContainerIsDocumentScopePublic</key><true/>
            <key>NSUbiquitousContainerName</key><string>Pixel Clock Messenger</string>
            <key>NSUbiquitousContainerSupportedFolderLevels</key><string>Any</string>
        </dict>
    </dict>
${ICON_EINTRAEGE}
</dict>
</plist>
PLIST

cp -R Icons "$APP/Contents/Resources/Icons"
cp -R Resources/Schriften "$APP/Contents/Resources/Schriften"
cp docs/tc002-protokoll.md "$APP/Contents/Resources/tc002-protokoll.md"
# Die englische Fassung, wenn es sie gibt — die Ansicht waehlt danach.
[ -f docs/en/tc002-protocol.md ] && cp docs/en/tc002-protocol.md "$APP/Contents/Resources/tc002-protocol.md"
# Dasselbe fuer AWTRIX NG, die zweite Gattung.
cp docs/awtrix-ng-protokoll.md "$APP/Contents/Resources/awtrix-ng-protokoll.md"
[ -f docs/en/awtrix-ng-protocol.md ] && cp docs/en/awtrix-ng-protocol.md "$APP/Contents/Resources/awtrix-ng-protocol.md"
cp LICENSE "$APP/Contents/Resources/LICENSE"
# Die zusaetzliche Erlaubnis nach GPL-Abschnitt 7 faehrt mit: Wer sie nicht im
# Buendel hat, kann sich nicht darauf berufen.
cp LIZENZ-AUSNAHME.md "$APP/Contents/Resources/LIZENZ-AUSNAHME.md"

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
# Die Berechtigungen fuer den iCloud-Abgleich — **nur auf Verlangen**.
#
# `Resources/MQTT-TC002.entitlements` liegt im Baum, wird aber nicht von selbst
# benutzt: `com.apple.developer.icloud-*` sind eingeschraenkte Berechtigungen,
# die Apple nur ueber ein Bereitstellungsprofil erteilt. Ohne Profil signiert
# codesign entweder gar nicht oder das System ignoriert sie stillschweigend —
# und dann gaebe es einen Bau, der laut Signatur iCloud kann und es doch nicht
# tut. Solange TC002_ENTITLEMENTS leer ist, bleibt alles wie bisher; die App
# arbeitet dann oertlich, was der vorgesehene Normalfall ist.
#
#   TC002_PROFIL=~/Downloads/MQTT_TC002.provisionprofile \
#   TC002_ENTITLEMENTS=Resources/MQTT-TC002.entitlements ./build.sh
#
# **Auch das Werkzeug bekommt sie.** `mqtttc002` faehrt im Buendel mit und
# liest denselben Bestand; ohne dieselben Berechtigungen saehe es den
# iCloud-Behaelter nicht und schriebe seine Slots weiter auf die Platte —
# ein Werkzeug, das andere Meldungen sieht als die App.
# **Vorgabe statt Schalter — und das ist die Lehre vom 14.09.2026.**
#
# Bis dahin musste man `TC002_ENTITLEMENTS` und `TC002_PROFIL` bei jedem Bau
# von Hand mitgeben. Ein blosses `./build.sh` erzeugte dann stillschweigend
# eine App **ohne** iCloud-Berechtigungen und ohne Profil — sie baut, sie
# laeuft, und nur zwei Dinge fehlen: Der iCloud-Schalter bleibt tot, und
# macOS haelt sie fuer ein **anderes Programm**. Damit ist die Freigabe
# „Lokales Netzwerk" weg, und die App meldet „keine Verbindung zum Internet",
# obwohl die Uhr in Millisekunden antwortet. Genau so passiert, dreimal
# hintereinander, ohne dass irgendetwas es gemeldet haette.
#
# Liegen Berechtigungsdatei und Profil da, werden sie darum **benutzt**. Wer
# ausdruecklich ohne bauen will, setzt die Variable auf einen leeren Wert:
#     TC002_ENTITLEMENTS= ./build.sh
if [ -z "${TC002_ENTITLEMENTS+gesetzt}" ] && [ -f Resources/MQTT-TC002.entitlements ]; then
    TC002_ENTITLEMENTS=Resources/MQTT-TC002.entitlements
fi
if [ -z "${TC002_PROFIL+gesetzt}" ]; then
    for p in erzeugt/*.provisionprofile *.provisionprofile; do
        [ -f "$p" ] && { TC002_PROFIL="$p"; break; }
    done
fi
BERECHTIGUNGEN="${TC002_ENTITLEMENTS:-}"
if [ -n "$BERECHTIGUNGEN" ] && [ ! -f "$BERECHTIGUNGEN" ]; then
    echo "Fehler: TC002_ENTITLEMENTS zeigt auf keine Datei: $BERECHTIGUNGEN" >&2
    exit 1
fi
# Ein Bereitstellungsprofil gehoert ins Buendel, sonst erteilt macOS die
# eingeschraenkten Berechtigungen nicht — und zwar **vor** dem Signieren.
if [ -n "${TC002_PROFIL:-}" ]; then
    cp "$TC002_PROFIL" "$APP/Contents/embedded.provisionprofile"
fi

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
BERECHTIGUNGSARGUMENT=""
[ -n "$BERECHTIGUNGEN" ] && BERECHTIGUNGSARGUMENT="--entitlements $BERECHTIGUNGEN"
if [ -n "$SIGNATUR" ]; then
    # shellcheck disable=SC2086
    codesign --force $BERECHTIGUNGSARGUMENT -s "$SIGNATUR" "$APP/Contents/MacOS/mqtttc002" >/dev/null 2>&1 || true
fi
# shellcheck disable=SC2086
if [ -n "$SIGNATUR" ] && codesign --force $BERECHTIGUNGSARGUMENT -s "$SIGNATUR" "$APP" >/dev/null 2>&1; then
    echo "signiert als $(codesign -dv "$APP" 2>&1 | sed -n 's/^Identifier=//p')"
else
    echo "Hinweis: keine Signieridentitaet gefunden, die App bleibt ad hoc signiert." >&2
    echo "         Der Schluesselbund fragt dann nach jedem Bau erneut nach dem Broker-Kennwort." >&2
fi

if [ -n "$BERECHTIGUNGEN" ]; then
    echo "Berechtigungen: $BERECHTIGUNGEN"
    [ -n "${TC002_PROFIL:-}" ] && echo "Profil: $TC002_PROFIL"
else
    echo "Warnung: ohne Berechtigungen gebaut. iCloud bleibt tot, und macOS haelt die App fuer ein anderes Programm - die Freigabe fuers lokale Netzwerk faellt damit weg." >&2
fi
echo "fertig: $APP — Fassung $VERSION ($COMMIT), Bau $BAUNUMMER"
