# Formatpille (iPhone): Schrift als Menue mit Zeichen, kein abgeschnittener Rand

**Gewicht: 5 von 10.**

## Was heute geschieht

`SendeniOS.swift`, die Pille ab 540 (`ScrollView(.horizontal,
showsIndicators: false)`), Schrift-Menue 642–652: Das Menue traegt als
Beschriftung den **Namen der Schrift** als Wort (`Text(schrift)`), also
„Silkscreen" in Akzentfarbe zwischen lauter Symbolen. Rechts daneben das
Groessen-Menue mit `textformat.size` und der Zahl. Auf dem iPhone ist die
Pille breiter als der Bildschirm; sie endet mit „Silkscreen AA" halb
sichtbar — es sieht aus, als waere der Text zu breit geraten, nicht als
koenne man weiterrollen.

## Was gelten soll

- **Schrift als Symbolmenue**: `Label { Text(kurz) } icon: { Image(systemName:
  "textformat") }` wie das Groessen-Menue daneben — ein Zeichen und ein
  kurzer Wert, nicht ein Wort in Akzentfarbe. Der Wert ist der
  Schriftname, aber in `caption`-Groesse unter oder neben dem Zeichen, so
  wie die Zahl beim Groessen-Menue. Sprachausgabe unveraendert („Schriftart
  Silkscreen").
- **Reihenfolge nach Haeufigkeit**: Icon, Schrift, Groesse, Fett, Grossbuchstaben,
  Farbe, dann Ausrichtungen, Rand, Abstand, Bild. Die drei, die man am
  ehesten aendert, sind links und ohne Rollen erreichbar.
- **Der rechte Rand sagt, dass es weitergeht**: ein `.mask` mit einem
  `LinearGradient` von opak zu durchsichtig auf den letzten 16 Punkten der
  Pille, das verschwindet, sobald ans Ende gerollt ist (der vorhandene
  `pilleRaum`-Versatz bei 725 misst schon, wo die Pille steht). Das ist die
  Bauart der Vorschlagsleiste ueber der Tastatur.
- Am iPad/Mac gibt es diese Pille nicht (Inspektor); nichts zu tun.

## Abnahme

- Bildschirmfoto iPhone: Pille ohne Wort in Akzentfarbe; am rechten Rand
  ausgeblendet, nicht abgeschnitten.
- Ganz nach rechts gerollt: kein Ausblenden mehr, letztes Element ganz.
- VoiceOver liest das Schriftmenue wie bisher (`accessibilityLabel` bleibt).

## Waechter, die sich melden werden

`KnopfstilTests` (Ledger `.buttonStyle(.automatic)` fuer `SendeniOS.swift`),
`EinblendtextGegenstueckTests` — `grep -rn "SendeniOS" Tests/`.
