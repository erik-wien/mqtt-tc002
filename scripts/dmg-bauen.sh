#!/bin/bash
# Schnuert aus der gebauten App ein Installationsabbild mit Hintergrundbild,
# Symbolen an festen Plaetzen und einem Verweis auf den Programme-Ordner.
#
#   scripts/dmg-bauen.sh 1.0
#
# Wird von release.sh aufgerufen; einzeln aufrufbar zum Ausprobieren der
# Gestaltung, ohne jedes Mal zu notarisieren.
#
# ACHTUNG: Das Setzen der Symbolplaetze laeuft ueber den Finder. Beim ersten Mal
# fragt macOS, ob das Terminal den Finder steuern darf — einmal erlauben, sonst
# bleiben die Symbole an beliebigen Stellen liegen.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-1.0}"
APP="build/MQTT-TC002.app"
NAME="MQTT-TC002"
DMG="build/MQTT-TC002-$VERSION.dmg"
ROH="build/roh.dmg"
BERG="/Volumes/$NAME"

[ -d "$APP" ] || { echo "$APP fehlt — erst ./build.sh" >&2; exit 1; }

# Hintergrundbild bei Bedarf erzeugen.
if [ ! -f "Resources/dmg-hintergrund.png" ]; then
    echo "== Hintergrundbild zeichnen =="
    swift scripts/dmg-hintergrund.swift Resources/dmg-hintergrund.png
fi

# Alte Reste wegraeumen — ein haengengebliebenes Abbild blockiert sonst den Namen.
hdiutil detach "$BERG" >/dev/null 2>&1 || true
rm -f "$DMG" "$ROH"

echo "== Abbild anlegen =="
BAU="$(mktemp -d)"
cp -R "$APP" "$BAU/"
ln -s /Applications "$BAU/Programme"
mkdir "$BAU/.hintergrund"
cp Resources/dmg-hintergrund.png "$BAU/.hintergrund/hintergrund.png"

# Beschreibbar anlegen, weil der Finder gleich hineinschreibt. Grosszuegig
# bemessen und am Ende beim Zusammenpressen wieder verkleinert.
hdiutil create -srcfolder "$BAU" -volname "$NAME" -fs HFS+ \
    -format UDRW -size 120m "$ROH" >/dev/null
rm -rf "$BAU"

echo "== Einhaengen und einrichten =="
hdiutil attach "$ROH" -noautoopen >/dev/null
sleep 1

osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        -- 660 x 420 Inhaltsflaeche, genau das Mass des Hintergrundbildes
        set the bounds of container window to {200, 120, 860, 540}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 96
        set text size of opts to 12
        set background picture of opts to file ".hintergrund:hintergrund.png"
        set position of item "MQTT-TC002.app" of container window to {165, 220}
        set position of item "Programme" of container window to {495, 220}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
APPLESCRIPT

# Die Platzierung landet in .DS_Store; der Finder schreibt sie verzoegert.
sync
sleep 2
# Der Finder haelt den Datentraeger manchmal noch ein paar Sekunden — dann
# scheitert das Aushaengen, und ein haengengebliebenes Abbild blockiert den
# naechsten Lauf. Deshalb ein paar Anlaeufe statt eines.
for versuch in 1 2 3 4 5; do
    hdiutil detach "$BERG" >/dev/null 2>&1 && break
    [ "$versuch" -eq 5 ] && { echo "$BERG laesst sich nicht aushaengen." >&2; exit 1; }
    sleep 2
done
sleep 1

echo "== Zusammenpressen =="
hdiutil convert "$ROH" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$ROH"

echo "fertig: $DMG ($(du -h "$DMG" | cut -f1))"
