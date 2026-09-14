#!/bin/sh
# Traegt Fassung und Baunummer aus Git in die **fertige** Info.plist des
# iOS-Buendels ein.
#
# **Warum nicht in `project.yml`?** Dort stuenden feste Zahlen, und
# `xcodegen generate` laeuft nicht bei jedem Bau. Jeder TestFlight-Upload
# traege dann dieselbe Baunummer — App Store Connect nimmt keine zweimal an,
# der erste ginge durch und der zweite nicht. Die Zahlen muessen also zur
# **Bauzeit** entstehen.
#
# Dieselbe Quelle wie beim Mac (`build.sh`): die Fassung aus dem juengsten Tag,
# die Baunummer aus der Zahl der Commits. Damit tragen Mac- und iOS-Fassung
# desselben Standes dieselben Zahlen.
#
# Laeuft als letzter Bauschritt, also **vor** dem Signieren — danach waere die
# Signatur ungueltig.
set -eu

PLIST="${TARGET_BUILD_DIR:?}/${INFOPLIST_PATH:?}"
[ -f "$PLIST" ] || { echo "warning: Info.plist nicht gefunden: $PLIST"; exit 0; }

cd "${PROJECT_DIR:?}"
VERSION="${TC002_VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')}"
[ -n "$VERSION" ] || VERSION="0.0"
BAUNUMMER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BAUNUMMER" "$PLIST"
echo "Fassung $VERSION, Bau $BAUNUMMER"
