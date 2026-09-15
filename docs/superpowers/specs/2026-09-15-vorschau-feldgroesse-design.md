# Die Vorschau auf der wirklichen Feldgröße — Entwurf

Stand 15.09.2026, abends. Entstanden aus einem Bildschirmfoto vom iPad: Bei
einer als AWTRIX NG eingerichteten TC001 endet der Inhalt der Vorschau nach
etwa vier Fünfteln, rechts bleibt ein schwarzer Streifen im Displayfeld
stehen. Punkt 1 des Rückstandsdokuments (`offene-punkte-13-09.md`) hat das
vorausgesagt.

## Der Fehler, nachgerechnet

Die AWTRIX-Zeichnung (`Geraetezeichnung.awtrixNG`) hat ein Displayfeld von
584 × 146 Zeichenraumeinheiten — ein Verhältnis von 4 : 1, also die echten
32 × 8 des Geräts. `GeraeteRahmen` skaliert die Zeichnung so, dass ihr Feld
genau so hoch wird wie der Inhalt. Der Inhalt aber ist weiterhin ein
52 × 16-Raster (`Meldungsbau.feld` kennt die Geräteart nicht), Verhältnis
3,25 : 1.

Bei Zellenkante *k* ist der Inhalt 52 · *k* breit, das Feld dagegen
584 · (16 · *k*) / 146 = 64 · *k*. Es bleiben **12 · *k* Punkte ungenutzt** —
knapp ein Fünftel der Displaybreite. Bis zur Umstellung auf linksbündige
Einpassung (`Geraetezeichnung.inhaltEcke`) verteilte sich das auf zwei halbe
Ränder und fiel weniger auf; seither liegt alles rechts.

Die Zahl ist nur das Symptom. Der Sachverhalt darunter: **Auf acht Zeilen wird
ein Sechzehn-Zeilen-Bild gezeigt.** Die Zellen sind halb so groß wie die
wirklichen Punkte des Geräts, und es sind mehr davon, als das Gerät hat.

## Was den Umbau ungefährlich macht

Der Rückstandseintrag hielt das für „nichts für nebenbei, weil daran die
funktionierende TC002 hängt". Der Befund dieses Entwurfs nimmt dem die
Schärfe:

**Für AWTRIX NG werden unsere Pixel überhaupt nie gesendet.**
`Anzeigen.nutzlast` verzweigt nach Gattung: Die Werksfirmware bekommt
`frame.alsJSON()`, NG bekommt `NGNutzlast.anzeige(herkunft.optionen, …)` —
also die Regler, aus denen das Bild entstand, und das Icon. Fehlen die Regler
(ein gemaltes Bild), wird für NG gar nichts geschickt.

Daraus folgt: Die Rasterung auf einem anderen Maß ist bei NG **ausschließlich
Vorschau**. Bleibt die Vorgabe 52 × 16, ist die Nutzlast der TC002 unberührt —
und `MQTTPaketTests` (Bytevergleich gegen eine echte `mosquitto_pub`-Aufnahme)
bewacht genau das.

## Der Weg: ein Maß als ein Wert

Im Kern ein kleiner Typ, der die Geometrie trägt:

```swift
public struct Anzeigemass: Equatable, Sendable {
    public let breite: Int
    public let hoehe: Int
    public static let tc002 = Anzeigemass(breite: 52, hoehe: 16)
    public static func fuer(_ uhr: Uhr) -> Anzeigemass
    public func iconY(kante: Int) -> Int
}
```

`fuer(_:)` liest `Uhr.anzeigemass`, das es bereits gibt: bei der Werksfirmware
52 × 16, bei NG `panelbreite ?? 32` auf 8 Zeilen. Die Panelbreite holt die App
beim Abfragen vom Gerät; zulässig ist 32 bis 128 (`Geraetetyp.ngBreitenbereich`).
Wer zwei Panels hängen hat, sieht damit zwei.

Der Wert geht als **ein** Parameter mit Vorgabe `= .tc002` durch die Einstiege
von `Meldungsbau`, die auf dem Feld rechnen — `iconY`, `flaecheX`,
`flaecheBreite`, `puffer`, `breite`, `passt`, `versatzX`, `versatzY`, `feld`,
`laufschriftBilder`, `textblock`, `rahmen` — und durch die elf Fundstellen von
`Pixelfeld.breiteStandard`/`hoeheStandard` in `Textraster`. `name(fuer:)` und
`platz(fuerName:)` rechnen nichts und bleiben unberührt.

**Warum ein Wert und nicht zwei Zahlen:** Wer `breite:` und `hoehe:` einzeln
durchreicht, vergisst eines davon an einer Stelle und rastert dann 52 breit in
ein Feld, das 32 ist — ein Fehler, der wie der jetzige aussieht und schwerer zu
finden wäre.

**Warum ein Parameter mit Vorgabe und nicht `Meldungsbau` als Instanz:** Die
Instanz wäre sauberer, zwänge aber dazu, jeden bestehenden Aufruf anzufassen.
Gerade dass alle Aufrufe unverändert bleiben, macht die vorhandene Testreihe
zum Beweis, dass der TC002-Weg sich nicht gerührt hat.

## Die Näherung für NG

NG setzt den Text mit **ihrer eigenen** Schrift. Unsere Schriftwahl ist dort
gesperrt (`Geraetetyp.wirkt(.schriftart)`), der gespeicherte Wert kann
trotzdem „Tiny5, 16 px" sein — in acht Zeilen gerastert wäre das abgeschnitten,
und die Vorschau zeigte einen Fehler, den das Gerät nicht hat.

Deshalb rastert die Vorschau auf NG immer mit derselben Näherung: **Silkscreen,
8 px** (steht auf `Pixelgroessen.abgesegnet`).

```swift
extension Meldungsoptionen {
    public func naeherung(fuer gattung: Geraetetyp) -> Meldungsoptionen
}
```

Im Kern und nicht in den Ansichten: Mac und iPhone rufen dasselbe und können
gar nicht auseinanderlaufen — der Fehler, den `Geraetetyp.swift` als in diesem
Projekt bereits dreimal vorgekommen festhält.

Die Vorschau bleibt damit eine **Näherung und kein Abbild**. Das ist dieselbe
Aussage, die `AppZustand.slotzustand` schon trifft, wenn sie für NG lieber
„belegt, Inhalt unbekannt" sagt als ein gerechnetes Bild.

## Die Fußzeile unter der Vorschau

Heute steht dort auch bei einer NG-Uhr „Laufschrift · 128 Bilder · rund 16 KB
Nutzlast". Kein einziges dieser Bilder wird an NG gesendet; die Angabe ist
schlicht falsch.

Künftig sagt sie bei NG, was wirklich hinausgeht: die Bytezahl von
`NGNutzlast.anzeige(…)`. Die ist exakt messbar und kein Schätzwert.

## Nicht in diesem Durchgang

- **Die fünf Slotblöcke und der Verlauf** behalten ihr 52 × 16-Format. Bei NG
  zeigen sie ohnehin „belegt, Inhalt unbekannt"; ihre Form ist ein
  Platzhalterkasten, kein Abbild.
- **Der Editor** malt weiter in seinen drei festen Größen. Der Bestand ist
  geräteunabhängig — was gesperrt gehört, ist das Senden, nicht das Zeichnen
  (eigener Durchgang, siehe unten).
- **Die 16er-Sperre** — 16 × 16-Icons und 16 × 52-Bilder bei einer Uhr mit acht
  Zeilen — ist entworfen und freigegeben, aber auf Wunsch des Auftraggebers
  hinter diesen Durchgang gestellt.

## Geprüft wird

Zuerst der Kern, weil dort gerechnet wird:

- `Anzeigemass.fuer(_:)` gibt für eine Werksfirmware-Uhr 52 × 16, für eine
  NG-Uhr ohne gemeldete Breite 32 × 8, mit gemeldeten 64 dann 64 × 8.
- `Meldungsbau.feld(…, mass: …)` liefert ein Feld dieser Größe; `passt` misst
  gegen die neue Breite; `laufschriftEinzelbilder` baut Einzelbilder dieser
  Größe.
- `Meldungsoptionen.naeherung(fuer: .awtrixNG)` setzt Silkscreen und 8;
  `naeherung(fuer: .tc002)` ändert nichts.
- Die Bytezahl der NG-Fußzeile gegen `NGNutzlast.anzeige(…)`.

Dann die beiden Vorschauen als Textbeweis (Bauart `KnopfstilTests`): dass sie
das Maß der angesehenen Uhr durchreichen und die Näherung benutzen.

**Der Beweis, dass nichts kaputtging, ist die unveränderte bestehende
Testreihe** — alle Aufrufe ohne `mass:` müssen weiter gelten, `MQTTPaketTests`
eingeschlossen. Ein Test, der dafür angefasst werden müsste, wäre ein Zeichen,
dass die Vorgabe nicht hält.
