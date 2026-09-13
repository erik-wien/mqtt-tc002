# Editor: Import in der Quellgroesse, Umrechnen als eigene Funktion

**Entschieden am 13.09.2026.** Woertlich: *„er muss beim importieren icons auch
in der richtigen breite importieren und nicht in der in der sich der editor
gerade befindet. Upscaling von 8x8 auf 16x16 ist eine eigene Funktion, ebenso
8x8|16x16 in 16x52 importieren."*

## Was heute geschieht

`Editorbestand.einlesen(daten:)` rechnet jede Datei auf die **gerade
eingestellte** Leinwandgroesse herunter (`Bildraster.lesen(…, breite: kante,
hoehe: kante)`). Ein 16×16-GIF landet also als 8×8, wenn der Editor auf 8×8
steht — ohne dass jemand danach gefragt haette. Genau darueber ist der
Auftraggeber mit seinen beiden `maze`-GIFs gestolpert.

## Was gelten soll

**1. Import behaelt die Quellgroesse.** Eine Datei wird in der Groesse
aufgenommen, die sie hat — 8×8 als 8×8, 16×16 als 16×16. Der Editor stellt sich
darauf ein, statt die Datei sich auf ihn einstellen zu lassen.

Zu klaeren: Was bei einer Groesse geschieht, die keine der drei ist (32×32,
104×32, irgendetwas). Heruntergerechnet auf die naechstliegende? Abgelehnt mit
Begruendung? **Das ist eine Entscheidung, keine Ableitung** — sie gehoert
gestellt, bevor jemand baut.

**2. Umrechnen ist eine eigene Funktion**, sichtbar und gewollt:
- **8×8 → 16×16** (Verdoppeln)
- **8×8 oder 16×16 → 16×52** (Einsetzen in die Anzeige)

Nicht als stiller Nebeneffekt des Imports, sondern als Befehl, den man
aufruft. Der umgekehrte Weg (16×52 → 8×8) ist damit ausdruecklich **nicht**
gemeint — Verkleinern zerstoert.

**„Icon einfuegen"** im 16×52-Bereich ist bereits ein Fall von 2 und sollte
derselbe Weg werden, nicht ein zweiter daneben.

## Was schon da ist

- Die **Dreier-Umschaltung** 8×8 / 16×16 / 16×52 gibt es seit der
  Zusammenlegung (`EditorBereichView`, Abschnitt „Groesse").
- `Bildraster.groesse(_:)` liefert die Quellgroesse einer Datei — der Import
  weiss also schon, was er vor sich hat, und verwirft es nur.
