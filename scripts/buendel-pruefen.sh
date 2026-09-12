#!/bin/sh
# Prueft, ob im zuletzt gebauten MQTT-TC002-iOS.app tatsaechlich die
# Ressourcen liegen, die die App zur Laufzeit braucht. Ein erfolgreicher
# `xcodebuild`-Lauf sagt darueber nichts aus — er meldet auch dann
# BUILD SUCCEEDED, wenn XcodeGen einen `resources:`-Schluessel stillschweigend
# ueberliest und keine Ressourcen-Bauphase entsteht.
#
#   scripts/buendel-pruefen.sh [Pfad/zu/MQTT-TC002-iOS.app]
#
# Ohne Argument wird das zuletzt gebaute Buendel unter DerivedData gesucht.
set -eu

APP="${1:-}"
if [ -z "$APP" ]; then
    APP=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 6 \
          -name "MQTT-TC002-iOS.app" -path "*Debug-iphone*" \
          -exec stat -f '%m %N' {} \; 2>/dev/null \
          | sort -rn | head -1 | cut -d' ' -f2-)
fi

if [ -z "$APP" ] || [ ! -d "$APP" ]; then
    echo "kein gebautes MQTT-TC002-iOS.app gefunden — erst bauen" >&2
    exit 1
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

if [ "$fehlt" -eq 1 ]; then
    echo "Buendel unvollstaendig: $APP" >&2
    exit 1
fi

echo "Buendel vollstaendig: $APP"
