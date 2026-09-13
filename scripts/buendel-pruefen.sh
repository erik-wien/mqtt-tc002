#!/bin/sh
# Prueft, ob im zuletzt gebauten App-Buendel tatsaechlich die Ressourcen
# liegen, die die App zur Laufzeit braucht. Ein erfolgreicher Bau sagt
# darueber nichts aus — `xcodebuild` meldet BUILD SUCCEEDED auch dann, wenn
# XcodeGen einen `resources:`-Schluessel stillschweigend ueberliest und keine
# Ressourcen-Bauphase entsteht; `swift build`/`build.sh` ebenso, wenn ein
# SwiftPM-Ziel mit Ressourcen sein eigenes .bundle erzeugt, das aber nicht mit
# ins Programmbuendel kopiert wird.
#
#   scripts/buendel-pruefen.sh [Pfad/zu/App.app]
#
# Ohne Argument wird das zuletzt gebaute MQTT-TC002-iOS.app unter DerivedData
# gesucht und wie bisher geprueft. Ein macOS-Buendel (build/MQTT-TC002.app,
# als Argument uebergeben) ist an seinem `Contents`-Ordner erkennbar und
# bekommt eine eigene, kuerzere Pruefung: dort geht es allein um das
# Ressourcenbuendel des geteilten Ziels TC002Ansichten und das darin
# uebersetzte Bild — Schriften, Icons und Uebersetzungen kopiert build.sh
# unabhaengig davon roh und unveraendert, dafuer braucht es diese Pruefung
# nicht.
set -eu

APP="${1:-}"
if [ -z "$APP" ]; then
    APP=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 6 \
          -name "MQTT-TC002-iOS.app" -path "*Debug-iphone*" \
          -exec stat -f '%m %N' {} \; 2>/dev/null \
          | sort -rn | head -1 | cut -d' ' -f2-)
fi

if [ -z "$APP" ] || [ ! -d "$APP" ]; then
    echo "kein gebautes App-Buendel gefunden — erst bauen" >&2
    exit 1
fi

if [ -d "$APP/Contents" ]; then
    # macOS-Layout: TC002Ansichten bringt sein eigenes .bundle mit
    # (`<Paket>_TC002Ansichten.bundle`). SwiftPM kopiert dessen Bildkatalog
    # ueber die Kommandozeile nur roh — erst `build.sh` uebersetzt ihn mit
    # `actool` zu Assets.car. Fehlt das, findet `Bundle.module` zur Laufzeit
    # kein Bild, und die Vorschau zeigt einen leeren Rahmen.
    RESSOURCEN="$APP/Contents/Resources"
    CAR=""
    for b in "$RESSOURCEN"/*_TC002Ansichten.bundle; do
        [ -f "$b/Assets.car" ] && CAR="$b/Assets.car"
    done
    if [ -z "$CAR" ]; then
        echo "fehlt   *_TC002Ansichten.bundle/Assets.car unter $RESSOURCEN" >&2
        echo "Buendel unvollstaendig: $APP" >&2
        exit 1
    fi
    # assetutil liest nur die Katalogmetadaten und sagt nichts darueber, ob
    # das Bild zur Laufzeit tatsaechlich ladbar ist. SwiftPMs nativer Bauweg
    # legt das Ressourcenbuendel ohne Info.plist an (build.sh legt seit der
    # GeraeteRahmen-Behebung eine nach), und ohne CFBundleIdentifier kann ein
    # Buendel seinen Bildkatalog bei CoreUI nicht registrieren: assetutil
    # findet "GeraeteRahmen" trotzdem, `Bundle(path:).image(forResource:)`
    # liefert dann aber still nil. Genau das hat diese Pruefung „Buendel
    # vollstaendig" gemeldet, waehrend die App am Mac keinen Rahmen zeigte —
    # deshalb hier der tatsaechliche Ladeversuch, wie AppKit ihn zur
    # Laufzeit auch macht.
    BUENDEL_PFAD="$(dirname "$CAR")"
    if ! ERGEBNIS="$(swift - "$BUENDEL_PFAD" <<'SWIFT' 2>&1
import AppKit
let pfad = CommandLine.arguments[1]
guard let buendel = Bundle(path: pfad) else {
    print("Bundle(path:) fehlgeschlagen fuer \(pfad)")
    exit(1)
}
guard let bild = buendel.image(forResource: "GeraeteRahmen") else {
    print("image(forResource: \"GeraeteRahmen\") liefert nil in \(pfad)")
    exit(1)
}
print("geladen, Groesse \(bild.size)")
SWIFT
)"; then
        echo "fehlt   Bild \"GeraeteRahmen\" nicht ladbar: $ERGEBNIS" >&2
        echo "Buendel unvollstaendig: $APP" >&2
        exit 1
    fi
    echo "Buendel vollstaendig: $APP ($BUENDEL_PFAD: $ERGEBNIS)"
    exit 0
fi

fehlt=0

if [ ! -d "$APP/Schriften" ] || [ -z "$(find "$APP/Schriften" -name '*.ttf' -print -quit 2>/dev/null)" ]; then
    echo "fehlt   Schriften (Ordner mit mindestens einer .ttf)"
    fehlt=1
fi

if [ ! -d "$APP/Icons" ] || [ -z "$(find "$APP/Icons" -type f -print -quit 2>/dev/null)" ]; then
    echo "fehlt   Icons (Ordner mit mindestens einer Datei)"
    fehlt=1
fi

if [ ! -e "$APP/Assets.car" ]; then
    echo "fehlt   Assets.car"
    fehlt=1
fi

if [ ! -f "$APP/en.lproj/Localizable.strings" ]; then
    echo "fehlt   en.lproj/Localizable.strings"
    fehlt=1
fi

# Die GPL-3.0 im Klartext. Das Ueber-Blatt liest sie ueber
# `Programmbuendel.eigenes.resourceURL` aus der Buendelwurzel; fehlt sie, steht
# dort statt des Lizenztextes eine Entschuldigung — und die Lizenz verlangt,
# den Text mitzuliefern, nicht nur einen Verweis darauf. Die drei OFL-Texte
# der Pixelschriften liegen mit den Schriften im Ordner `Schriften` und sind
# oben schon abgedeckt.
if [ ! -s "$APP/LICENSE" ]; then
    echo "fehlt   LICENSE"
    fehlt=1
fi

for ofl in OFL-Micro5.txt OFL-Silkscreen.txt OFL-Tiny5.txt; do
    if [ ! -s "$APP/Schriften/$ofl" ]; then
        echo "fehlt   Schriften/$ofl"
        fehlt=1
    fi
done

if [ "$fehlt" -eq 1 ]; then
    echo "Buendel unvollstaendig: $APP" >&2
    exit 1
fi

echo "Buendel vollstaendig: $APP"
