#!/bin/sh
# Xcode Cloud, unmittelbar nach dem Klonen.
#
# Ohne diesen Schritt bricht jeder Lauf ab mit
#
#     Project MQTT-TC002-iOS.xcodeproj does not exist at the root of the repository
#
# und das ist kein Fehler, sondern die Bauart: Die `.xcodeproj` wird aus
# `project.yml` erzeugt und ist ignoriert (`CLAUDE.md`, „Die iOS-Fassung").
# Wer sie einchecken wollte, schnitte kuenftig in erzeugtem XML statt in der
# YAML. Auf dem eigenen Rechner laeuft `xcodegen generate` von Hand; hier
# laeuft es eben hier.
#
# Xcode Cloud sucht dieses Skript unter `ci_scripts/` in der Wurzel des
# Klons und fuehrt es aus, bevor es das Projekt oeffnet. Es muss ausfuehrbar
# eingecheckt sein — ohne das Ausfuehrungsrecht wird es stillschweigend
# uebergangen.
set -eu

# Das Skript laeuft in seinem eigenen Ordner, gebaut wird eine Ebene darueber.
cd "${CI_PRIMARY_REPOSITORY_PATH:-$(dirname "$0")/..}"

# Homebrew liegt auf den Abbildern unter /opt/homebrew, steht aber nicht in
# jedem PATH. Kein Selbstlauf und kein Aufraeumen: Beides kostet Minuten und
# aendert nichts am Ergebnis.
export PATH="/opt/homebrew/bin:$PATH"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

command -v xcodegen >/dev/null 2>&1 || brew install xcodegen
xcodegen generate

# Fassung und Baunummer kommen aus dem juengsten Tag und der Zahl der Commits
# (`scripts/fassung-eintragen.sh`). Ein flacher Klon kennt weder Tags noch die
# volle Zahl; die Baunummer bliebe dann klein und stiege nicht — und App Store
# Connect nimmt keine Baunummer zweimal an. Schlaegt das Nachholen fehl, ist
# das kein Grund abzubrechen: Der Bau selbst haengt nicht daran.
git fetch --tags --unshallow 2>/dev/null || git fetch --tags 2>/dev/null || true
