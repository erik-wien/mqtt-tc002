#!/bin/bash
# Legt `Contents/Resources/Metadata.appintents` in die Mac-App, damit die
# Kurzbefehle-App ihre Aktionen findet.
#
#   scripts/kurzbefehle-metadaten.sh <App.app> <Bauordner> [Ziel]
#
# Warum es das braucht: Kurzbefehle (App Intents) findet das System nicht im
# Programm, sondern in einem Verzeichnis `Metadata.appintents` im Buendel. Das
# erzeugt `appintentsmetadataprocessor` aus den Konstantenwerten, die der
# Swift-Compiler neben den Objektdateien ablegt — Xcode ruft ihn als
# Bauschritt auf, `build.sh` (SwiftPM) nicht. Ohne diesen Schritt baut und
# laeuft die App, und in der Kurzbefehle-App fehlt jede Aktion, ohne dass
# irgendetwas es meldet.
#
# Der Bauordner ist `swift build --show-bin-path`; die Zwischenergebnisse des
# Ziels liegen daneben unter `Intermediates.noindex/TC002.build/<Konfig>/`.
# Der Compiler schreibt die Konstantenwerte (`*.swiftconstvalues`) von selbst;
# ein eigener Lauf mit swiftc ist nicht noetig.
set -euo pipefail

APP="${1:?App-Buendel fehlt}"
BIN_DIR="${2:?Bauordner fehlt}"
ZIEL="${3:-TC002Kurzbefehle}"
KENNUNG="cloud.eriks.mqtt-tc002"

KONFIG="$(basename "$BIN_DIR")"
ZWISCHEN="$(cd "$BIN_DIR/../.." && pwd)/Intermediates.noindex/TC002.build/$KONFIG/$ZIEL-t.build/Objects-normal"
BINAERDATEI="$APP/Contents/MacOS/TC002App"
[ -f "$BINAERDATEI" ] || { echo "Fehler: $BINAERDATEI fehlt." >&2; exit 1; }

ARCH="$(uname -m)"
[ -d "$ZWISCHEN/$ARCH" ] || { echo "Fehler: keine Zwischenergebnisse fuer $ZIEL unter $ZWISCHEN/$ARCH." >&2; exit 1; }

ARBEIT="$(mktemp -d)"
trap 'rm -rf "$ARBEIT"' EXIT
ls "$ZWISCHEN/$ARCH"/*.swiftconstvalues > "$ARBEIT/konstanten.txt"
[ -s "$ARBEIT/konstanten.txt" ] || { echo "Fehler: keine *.swiftconstvalues fuer $ZIEL." >&2; exit 1; }
cp "$ZWISCHEN/$ARCH/$ZIEL.SwiftFileList" "$ARBEIT/quellen.txt"

TOOLCHAIN="$(dirname "$(dirname "$(dirname "$(xcrun --find appintentsmetadataprocessor)")")")"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
XCODEBAU="$(xcodebuild -version | sed -n 's/^Build version //p')"
ZIELSYSTEM="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")"

rm -rf "$APP/Contents/Resources/Metadata.appintents"
xcrun appintentsmetadataprocessor \
    --toolchain-dir "$TOOLCHAIN" \
    --module-name "$ZIEL" \
    --sdk-root "$SDK" \
    --xcode-version "$XCODEBAU" \
    --platform-family macOS \
    --deployment-target "$ZIELSYSTEM" \
    --bundle-identifier "$KENNUNG" \
    --output "$APP/Contents/Resources" \
    --target-triple "$ARCH-apple-macos$ZIELSYSTEM" \
    --binary-file "$BINAERDATEI" \
    --source-file-list "$ARBEIT/quellen.txt" \
    --swift-const-vals-list "$ARBEIT/konstanten.txt" \
    --compile-time-extraction \
    --deployment-aware-processing \
    --no-app-shortcuts-localization

if [ ! -f "$APP/Contents/Resources/Metadata.appintents/extract.actionsdata" ]; then
    echo "Fehler: Metadata.appintents wurde nicht erzeugt — die Kurzbefehle fehlen der App." >&2
    exit 1
fi
echo "Kurzbefehle: Metadata.appintents angelegt"
