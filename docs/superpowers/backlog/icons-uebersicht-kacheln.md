# Icons-Uebersicht: Namen in zwei Zeilen, Anzeigen breiter

**Gewicht: 9 von 10.** Klein, aber jedes Mal sichtbar.

## Was heute geschieht

`EditorBereichView.swift`, `uebersicht`: `LazyVGrid` mit
`GridItem(.adaptive(minimum: 88), spacing: 12)` (1006), der Name darunter
in `caption` mit `.lineLimit(1)` (1045). Auf dem iPad stehen darum drei
Kacheln „Home Assista…" nebeneinander, die sich nur im Bild unterscheiden,
und „Moon cloud s…", „Best Real Fire…". Die Gruppe 52 × 16 benutzt
dieselbe Kachelbreite wie die Icons: Ein Banner von 52 Pixeln wird auf
gut 100 Punkte gezeigt, zwei Punkte je Pixel — Motive wie ein Schloss
oder ein Bergpanorama sind nicht zu erkennen.

## Was gelten soll

- **Name in bis zu zwei Zeilen**, `lineLimit(2)`, mittig, und die Kachel
  bekommt eine feste Hoehe, damit ein einzeiliger Name die Reihe nicht
  kuerzer macht als ein zweizeiliger (`frame(height:)` am Text oder
  `.frame(minHeight:)` an der Kachel; `@ScaledMetric` wie bei
  `kachelkante` in `IconAuswahlView`).
- **Je Groesse ein Raster:** Die Gruppe 52 × 16 bekommt ihr eigenes
  `GridItem(.adaptive(minimum: 180))` — vier Punkte je Pixel wie bei
  den Icons (8 × 8 auf 32 bis 36 Punkte). Die Gruppen stehen ohnehin
  getrennt untereinander; das Raster je Gruppe zu waehlen ist eine Zeile.
- Das Abspielzeichen an bewegten Kacheln bleibt, wo es ist.

## Abnahme

- Bildschirmfoto iPad mit drei „Home Assistant …"-Icons: alle drei mit
  unterscheidbarem Namen.
- Bildschirmfoto der 52 × 16-Gruppe: Motive erkennbar, Namen ganz.
- iPhone hat diese Uebersicht nicht (Icons am Telefon:
  `IconauswahliOS.swift`) — dort nachsehen, ob dieselbe Abschneidung
  vorkommt, und gleich behandeln.

Waechter: `EinblendtextGegenstueckTests.testDieKachelHatEinKontextmenue`
(`ausschnitt(…, von: "private func kachel")`), `KnopfstilTests`.
