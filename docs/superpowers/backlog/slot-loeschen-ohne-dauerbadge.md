# Slots: Loeschen ueber das Kontextmenue, kein Dauerbadge

**Gewicht: 3 von 6.**

## Was heute geschieht

Jeder belegte Slotblock traegt oben rechts ein rotes `xmark.circle.fill`
(`MeldungLoeschenKnopf`, `SendenView.swift` etwa 1005–1030; auf dem iPhone
`SendeniOS.swift:440–444` als `.overlay(alignment: .topTrailing)` mit
`.offset(x: 6, y: -6)`, Zeichen bei 905). Es steht immer da, ueberlappt das
Motiv des Blocks („TESTNAC✗") und sieht aus wie der Wackelmodus des
Home-Bildschirms — ein Zustand, den man absichtlich betritt, nicht die
Ruhelage. Am Finger ist die Trefferflaeche zudem kleiner als 44 Punkte und
liegt auf dem Block, der selbst ein Knopf ist.

Am Mac hat der Knopf bereits ein `.contextMenu` (SendenView 1025).

## Was gelten soll

- **iPhone und iPad:** kein Badge. Loeschen und, wo es das gibt, „Zeigen"
  stehen im **Kontextmenue** des Slotblocks (`.contextMenu` am Block, mit
  `Label("Löschen", systemImage: "trash")` und `role: .destructive`). Ein
  langer Druck ist die Geste, die das System dafuer vorsieht; die
  Slotleiste im Verlauf darunter hat das Loeschen ohnehin als Wischgeste.
- **Mac:** Das Badge darf bleiben, aber nur **beim Ueberfahren** des Blocks
  (`onHover`), sonst unsichtbar — so machen es Safari-Tabs und der Finder
  mit Schliess- und Auswurfzeichen. Das ist der eine begruendete
  Unterschied (Zeiger gegen Finger) und steht als Satz an der Stelle.
  Das Kontextmenue bleibt zusaetzlich.
- Der Loeschvorgang selbst (`AppZustand.loeschen`, `anzeigeGeloescht`,
  Slotgedaechtnis vergessen) aendert sich nicht.

## Abnahme

- Bildschirmfoto iPhone: Slotleiste ohne rote Zeichen.
- Langer Druck auf einen belegten Block oeffnet ein Menue mit „Löschen";
  auf einen leeren Block kein Menue oder ein leeres — pruefen, was das
  System bei leerem `contextMenu` zeigt, und den Modifier nur an belegte
  Bloecke haengen.
- Bildschirmfoto Mac: Zeichen erscheint beim Ueberfahren, sonst nicht.
- Sprachausgabe: Der Block nennt weiterhin „Slot 2, belegt", und das
  Loeschen ist als Aktion erreichbar (`accessibilityAction` oder das
  Kontextmenue, das VoiceOver als „Aktionen" anbietet — im Simulator mit
  dem Accessibility Inspector nachsehen).

## Waechter, die sich melden werden

`KnopfstilTests`, `EinblendtextGegenstueckTests` (die `.help(` an
`MeldungLoeschenKnopf` zaehlen) — `grep -rn "MeldungLoeschenKnopf\|xmark.circle.fill" Tests/`.
