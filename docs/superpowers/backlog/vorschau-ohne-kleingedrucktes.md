# Vorschau: kein Kleingedrucktes darunter

**Gewicht: 4 von 10.**

## Was heute geschieht

`SendenView.swift:462–468` (Mac und iPad): Wenn die angesehene Uhr den Text
selbst setzt (AWTRIX NG, `gattung.setztSelbst`), stehen unter der Vorschau
zwei Zeilen in `footnote`:

    ⓘ Nur eine Näherung — die Uhr setzt diesen Text selbst und zeigt ihn
      anders. Läuft er, weil er nicht passt, gilt das Lauftempo dieser Meldung.
    Hinaus geht der Text samt Reglern · unter 1 KB Nutzlast

Das ist eine Erklaerung und eine Messung unter jedem Bild, dauerhaft. Beides
ist richtig, aber es liest sich wie ein Beipackzettel; Apples eigene Apps
erklaeren sich nicht unter jedem Element.

Der `else`-Zweig fuer die Werksfirmware (`Nutzlastzeile`, „Laufschrift · N
Bilder · KB") ist derselbe Fall in anderer Form.

## Was gelten soll

- **Die Erklaerung wandert in den Einblendtext.** Unter der Vorschau bleibt
  ein einzelnes ⓘ-Zeichen rechts unten am Rahmen oder rechts neben der
  Punktreihe, `secondary`; sein `.help(…)` traegt den Satz „Nur eine
  Näherung — …". Am iPad ist ein `.help` nicht zu sehen (siehe
  `namensichtbarAmIPad` und die Tests dazu) — dort wird das Zeichen ein
  Knopf, der ein `.popover` mit demselben Satz oeffnet. Ein Zeichen, zwei
  Wege, derselbe Text (ein Schluessel).
- **Die Nutzlast steht am Sendeknopf**, nicht unter dem Bild: `.help` am
  Knopf „Hinaus geht der Text samt Reglern · unter 1 KB" bzw. „Laufschrift ·
  12 Bilder · 3 KB". Sie ist die Antwort auf „was passiert, wenn ich
  druecke" und gehoert dorthin, wo man drueckt. Ueberschreitet sie die
  Grenze der Werksfirmware (§4.2a), bleibt die **sichtbare** Warnung — das
  ist dann ein Fehler, kein Kleingedrucktes; `Nutzlastzeile` weiss das
  heute schon und bleibt fuer diesen Fall.
- **iPhone (`SendeniOS.swift`)** hat dieselben zwei Auskuenfte? Nachsehen
  (`grep -n "Näherung\|Nutzlast" Sources/TC002iOS/SendeniOS.swift`); was
  dort steht, wird gleich behandelt.
- Die Hilfe (`HilfeView.swift`, Abschnitt Senden, Absatz zur Nutzlastgroesse
  und zur NG-Vorschau) beschreibt danach den neuen Ort.

## Abnahme

- Bildschirmfoto iPad mit angesehener NG: Unter der Vorschau ein Zeichen,
  kein Satz. Druck darauf zeigt den Satz.
- Bildschirmfoto Mac: Ueberfahren des Zeichens zeigt den Satz; Ueberfahren
  des Sendeknopfs zeigt die Nutzlast.
- Eine Werksfirmware-Uhr mit Laufschrift ueber der Grenze zeigt die Warnung
  weiterhin sichtbar (Test in `Tests/TC002AnsichtenTests`, der den
  Waechter `Nutzlastzeile` prueft, bleibt gruen oder wird auf die neue
  Stelle umgeschrieben).

## Waechter, die sich melden werden

`EinblendtextGegenstueckTests.testSendenViewHatKeineUnbeobachteteEinblendtextstelle`
(zaehlt `.help(` in `SendenView.swift`) und Tests, die den Satz „Nur eine
Näherung" suchen — `grep -rn "Näherung\|Nutzlastzeile" Tests/`.
