# Hilfe: Die Einleitung kennt nur die TC002

**Gewicht: 10 von 10.** Ein Satz, aber der erste, den jemand liest.

## Was heute geschieht

`TC002Ansichten/HilfeInhalt.swift:20`: *„Pixel Clock Messenger schickt
Anzeigen an eine oder mehrere Ulanzi-TC002-Pixeluhren."* Die App bedient
seit `SendeWeg`/`Geraetetyp` auch TC001 unter AWTRIX NG (Gattung in den
Einstellungen, eigene Nutzlast `NGNutzlast`, eigene Referenz
`docs/awtrix-ng-protokoll.md`). Die Einleitung sagt das nicht; der Absatz
danach spricht von „der Uhr" so, als gaebe es eine Bauart.

## Was gelten soll

- Erster Satz nennt beide: „… an Pixeluhren — Ulanzi TC002 mit
  Werksfirmware und TC001 unter AWTRIX NG." Dann wie bisher der Weg
  (HTTP oder Broker). Ein Satz, dass die **Gattung** je Uhr in den
  Einstellungen steht und entscheidet, was die Regler bewirken (Schrift
  und Groesse setzt eine NG selbst — das steht heute in den Einblendtexten
  der gesperrten Regler, gehoert aber auch hierher, einmal).
- Durchsicht der uebrigen Hilfe auf „TC002", wo „die Uhr" gemeint ist:
  `grep -n "TC002" Sources/TC002Ansichten/Hilfe*.swift Sources/TC002iOS/HilfeiOS.swift`.
  Nur dort aendern, wo der Satz fuer beide Gattungen gelten soll und es
  nicht tut; wo die Werksfirmware gemeint ist (Slots, `customList`,
  Werknummer), bleibt „TC002" richtig.
- „Hilfe → Gerätereferenz" gibt es fuer beide Gattungen
  (`GeraeteReferenzView`, `docs/awtrix-ng-protokoll.md`)? Wenn die
  Referenz nur die TC002 zeigt, sagt der Verweis das dazu, oder die
  Referenz bekommt einen zweiten Reiter. Nachsehen, entscheiden, an die
  Stelle schreiben.
- Uebersetzung (`en.lproj`) nachziehen; `HilfeInhalt` ist fuer Mac, iPad
  und iPhone dieselbe Quelle — einmal aendern.

## Abnahme

- Bildschirmfoto Hilfe → „Was das Programm tut" auf iPad und iPhone: Beide
  Gattungen im ersten Absatz.
- `python3 scripts/texte-sammeln.py --pruefen` bei `0 ohne Uebersetzung`.
- `HilfeauszeichnungTests`/`HilfebildTests` gruen.
