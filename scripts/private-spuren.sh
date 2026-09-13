#!/bin/sh
# Sucht in den vorgemerkten Aenderungen nach Angaben, die nicht in ein
# oeffentliches Repo gehoeren. Rueckgabe 1, wenn etwas gefunden wurde.
#
# Warum es das gibt: Zweimal sind Hausnetzangaben ueber Planpapiere unter
# docs/superpowers/ hereingekommen — einmal zwei Adressen, einmal ein
# woertlicher Geraeteabzug mit MAC und WLAN-Namen. Beides war kein Versehen
# eines Einzelnen, sondern die Bauart: Wer misst, schreibt auf, was er sieht.
#
# Ohne Argument prueft es die vorgemerkten Aenderungen (als Hakenskript),
# mit Argument die genannten Dateien.

muster='10\.10\.[0-9]+\.|akadbrain|ghp_[A-Za-z0-9]{20}|xox[baprs]-|AKIA[A-Z0-9]{16}|sk-[A-Za-z0-9]{20}|BEGIN [A-Z ]*PRIVATE KEY'

if [ $# -gt 0 ]; then
    treffer=$(grep -nIE "$muster" "$@" 2>/dev/null)
else
    # Diese Datei selbst ist ausgenommen: Sie enthaelt das Muster
    # zwangslaeufig. (Beim allerersten Lauf hat der Haken genau daran
    # angeschlagen — er tut also, was er soll.)
    treffer=$(git diff --cached --unified=0 -- . ':!scripts/private-spuren.sh' \
              | grep -E '^\+' | grep -vE '^\+\+\+' | grep -nIE "$muster")
fi

[ -z "$treffer" ] && exit 0

echo "Private Spuren gefunden:" >&2
echo "$treffer" >&2
echo "" >&2
echo "Das Repo ist oeffentlich. Ersetze die Angabe durch einen Platzhalter." >&2
echo "Ist es wirklich harmlos: git commit --no-verify" >&2
exit 1
