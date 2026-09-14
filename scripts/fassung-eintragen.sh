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
# **Laeuft als erster Bauschritt und schreibt in die QUELLE**, nicht in die
# fertige Info.plist des Buendels. Der Unterschied hat am 14.09.2026 eine
# Stunde gekostet und waere beim zweiten TestFlight-Upload aufgefallen:
#
#     /bin/sh -c …/Script-F83B9C67….sh      ← dieser Schritt, schreibt 1.5/456
#     Fassung 1.5, Bau 456
#     ProcessInfoPlistFile …/MQTT-TC002-iOS.app/Info.plist  erzeugt/InfoiOS.plist
#
# Xcode kopiert die Quell-Plist **nach** den Skriptschritten ueber das Produkt.
# Wer dort hineinschreibt, schreibt gegen etwas an, das gleich wieder
# ueberbuegelt wird — das Buendel trug weiterhin 1.0 (1), bei jedem Bau
# dieselbe Baunummer, und App Store Connect nimmt keine zweimal an.
#
# In der Quelle steht sie dagegen, bevor sie kopiert wird. `erzeugt/InfoiOS.plist`
# erzeugt `xcodegen` und ist ignoriert; dass dieser Schritt sie aendert, ist
# deshalb folgenlos fuer das Repo.
PLIST="${PROJECT_DIR:?}/${INFOPLIST_FILE:?}"
[ -f "$PLIST" ] || { echo "warning: Info.plist nicht gefunden: $PLIST"; exit 0; }

cd "${PROJECT_DIR:?}"
VERSION="${TC002_VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')}"
[ -n "$VERSION" ] || VERSION="0.0"
BAUNUMMER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BAUNUMMER" "$PLIST"
echo "Fassung $VERSION, Bau $BAUNUMMER"
