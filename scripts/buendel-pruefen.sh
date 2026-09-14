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
# gesucht und wie bisher geprueft. Ein macOS-Buendel (erzeugt/mac/MQTT-TC002.app,
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
    # Uebersetzungen und die beiden Nachschlagewerke. Fehlt en.lproj, laeuft
    # die App weiter und bleibt still deutsch; fehlt ein Dokument, zeigt das
    # Fenster einen Fehlerschirm. Beides verdeckt ein gruener Bau.
    mac_fehlt=0
    for pflicht in en.lproj/Localizable.strings tc002-protokoll.md tc002-protocol.md \
                   awtrix-ng-protokoll.md awtrix-ng-protocol.md LICENSE; do
        if [ ! -s "$RESSOURCEN/$pflicht" ]; then
            echo "fehlt   $pflicht unter $RESSOURCEN" >&2
            mac_fehlt=1
        fi
    done
    if [ "$mac_fehlt" -eq 1 ]; then
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

# Das Datenschutzmanifest. Apple verlangt es seit Mai 2024, sobald die App eine
# „API mit Begruendungspflicht" benutzt — `UserDefaults` ist eine, und diese App
# benutzt sie durchgehend. Fehlt es, beanstandet App Store Connect den Upload,
# und zwar erst **dort**: Der Bau gelingt, das Buendel sieht fertig aus, und
# auffallen wuerde es beim Hochladen. Es muss in der Buendelwurzel liegen.
if [ ! -s "$APP/PrivacyInfo.xcprivacy" ]; then
    echo "fehlt   PrivacyInfo.xcprivacy"
    fehlt=1
fi

# Die Geraetereferenz in beiden Sprachen — dieselbe Pflicht wie am Mac.
# `GeraeteReferenzView` sucht sie ueber `Bundle.main.resourceURL` in der
# Buendelwurzel; fehlt sie, steht statt des Dokuments ein Fehlerschirm, der
# aufs Bauen mit ./build.sh verweist und damit am iPhone in die falsche
# Richtung zeigt. Ein gruener Bau sagt darueber nichts.
for dok in tc002-protokoll.md tc002-protocol.md awtrix-ng-protokoll.md awtrix-ng-protocol.md; do
    if [ ! -s "$APP/$dok" ]; then
        echo "fehlt   $dok"
        fehlt=1
    fi
done

# Die Lagen. Das iPad zeigt seit S7 die Schreibtischoberflaeche und muss sich
# drehen duerfen; das iPhone bleibt im Hochformat, weil `SendeniOS` darauf
# gerechnet ist. Beides haengt an zwei Schluesseln der Info.plist, und der
# `~ipad`-Schluessel ist genau die Sorte Eintrag, die ein gruener Bau nicht
# belegt: XcodeGen kann ihn ueberlesen, und Xcodes Plist-Verarbeitung koennte
# ihn beim Zusammenbau fallen lassen. Geprueft wird deshalb das **gebaute**
# Buendel, nicht project.yml.
LAGEN_IPAD=$(plutil -extract 'UISupportedInterfaceOrientations~ipad' xml1 -o - "$APP/Info.plist" 2>/dev/null || true)
for lage in Portrait PortraitUpsideDown LandscapeLeft LandscapeRight; do
    case "$LAGEN_IPAD" in
        *"UIInterfaceOrientation$lage"*) ;;
        *)
            echo "fehlt   UISupportedInterfaceOrientations~ipad: UIInterfaceOrientation$lage"
            fehlt=1
            ;;
    esac
done
LAGEN_IPHONE=$(plutil -extract 'UISupportedInterfaceOrientations' xml1 -o - "$APP/Info.plist" 2>/dev/null || true)
case "$LAGEN_IPHONE" in
    *Landscape*|*UpsideDown*)
        echo "falsch  UISupportedInterfaceOrientations (iPhone) ist nicht mehr nur Hochformat"
        fehlt=1
        ;;
esac

for ofl in OFL-Micro5.txt OFL-Silkscreen.txt OFL-Tiny5.txt; do
    if [ ! -s "$APP/Schriften/$ofl" ]; then
        echo "fehlt   Schriften/$ofl"
        fehlt=1
    fi
done

# Die Kurzbefehle. `appintentsmetadataprocessor` baut aus dem Quelltext eine
# eigene Fassung jedes sichtbaren Textes — aus `Summary("\(\.$text) …")` wird
# im Buendel `${text} …`, und genau dieser Wortlaut wird zur Laufzeit
# nachgeschlagen, nicht der aus dem Quelltext. `texte-sammeln.py --pruefen`
# kann das nicht sehen: Es liest die Quellen. Deshalb hier gegen das
# **gebaute** Buendel: Jeder Schluessel, den die Kurzbefehle-App nachschlaegt,
# muss in en.lproj stehen — sonst bleibt der Eintrag auf einem englischen
# Telefon deutsch, ohne dass irgendetwas darauf hinweist.
DATEN="$APP/Metadata.appintents/extract.actionsdata"
if [ -f "$DATEN" ]; then
    if ! OHNE=$(python3 - "$DATEN" "$APP/en.lproj/Localizable.strings" <<'PYTHON'
import json, re, sys
daten = json.load(open(sys.argv[1]))
da = set(re.findall(r'^\s*"((?:[^"\\]|\\.)*)"\s*=',
                    open(sys.argv[2], encoding="utf-8").read(), re.M))
gesucht = []
for name, a in daten.get("actions", {}).items():
    gesucht.append(a["title"]["key"])
    gesucht.append(a["descriptionMetadata"]["descriptionText"]["key"])
    zus = a["actionConfiguration"]["actionSummary"]["wrapper"]["summaryString"]
    gesucht.append(zus["formatString"])
    for p in a.get("parameters", []):
        gesucht.append(p["title"]["key"])
        if "parameterDescription" in p:
            gesucht.append(p["parameterDescription"]["key"])
for e in daten.get("enums", []):
    gesucht.append(e["displayTypeName"]["key"])
    for f in e["cases"]:
        gesucht.append(f["displayRepresentation"]["title"]["key"])
fehlend = sorted({k for k in gesucht if k not in da})
print("\n".join(fehlend))
sys.exit(1 if fehlend else 0)
PYTHON
    ); then
        echo "fehlt   Uebersetzung fuer Kurzbefehle-Texte aus dem Buendel:"
        echo "$OHNE" | sed 's/^/        /'
        fehlt=1
    fi
fi

if [ "$fehlt" -eq 1 ]; then
    echo "Buendel unvollstaendig: $APP" >&2
    exit 1
fi

echo "Buendel vollstaendig: $APP"
