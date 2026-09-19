# Verlauf: die Zeile zeigt den Inhalt, nicht die Uhrzeit

**Gewicht: 2 von 6.**

## Was heute geschieht

`TC002Ansichten/Verlaufsliste.swift`, `zeile(_:aufDerUhr:)` (etwa 175–220):
Links in einer 96 Punkte breiten Spalte die Zeit („Gestern, 19:13") und
darunter „Platz 1", dann die Icon-Nummer als graue Monospace-Zahl („5610"),
dann der Text in Sendefarbe und darunter die Uhren.

Drei Dinge daran:

1. **Die Zeit ist das Auffaelligste, der Inhalt das Unauffaelligste.** Bei
   einer Sendung ohne Text (nur Icon) besteht die Zeile aus „Gestern, 19:13
   · 5610 · Uhrennamen" — niemand weiss, was 5610 ist. Der Verlauf soll
   „dasselbe noch einmal" ermoeglichen; dafuer muss man das Dasselbe
   erkennen.
2. **Dieselbe Sendung steht mehrfach da**, nur mit anders geordneten Uhren
   („A, B, C" / „B, A, C"). `AppZustand.swift:1191` baut `uhr:` aus
   `erreicht.joined(separator: ", ")`, und `erreicht` kommt aus einer Menge —
   die Reihenfolge ist Zufall. `Verlaufseintrag.gleichtInhaltlich`
   (`TC002Core/Sendeverlauf.swift:42`) vergleicht den String und haelt zwei
   gleiche Sendungen darum fuer verschieden.
3. **Die Uhrennamen werden abgeschnitten** („awtrix-a…"), weil sie in einer
   Zeile stehen, die auch der Text braucht.

## Was gelten soll

**Reihenfolge der Auskunft:** Was — an wen — wann.

- **Vorn das Icon als Bildchen** (`Rasterbild`, wie in `IconAuswahlView`),
  Kante 8 oder 16 nach `iconKante`, gezeigt in 24–28 Punkten. Dazu braucht
  die Zeile die Datei des Icons: `Verlaufseintrag` traegt nur `iconNummer`
  und `iconKante`; die Datei liefert `Iconsammlung` ueber die Nummer. Die
  Suche gehoert in den Kern oder in `AppZustand` (ein `icon(fuer:
  Verlaufseintrag) -> Icon?`), nicht in die Ansicht — und sie darf nicht
  bei jedem Zeichnen die Platte lesen: einmal je Eintrag merken. Ohne Icon
  bleibt der Platz leer, nicht die Nummer.
- **Dann der Text** in Sendefarbe, `.body`, eine Zeile. Ohne Text (nur
  Icon) steht dort der Icon-Name aus der Sammlung in `.secondary` — nicht
  die Nummer.
- **Darunter klein die Uhren**, `caption2`, alphabetisch, ganz — bei
  Platznot mit `.lineLimit(2)`, nicht abgeschnitten nach dem ersten Namen.
  Bei nur einer eingerichteten Uhr entfaellt die Zeile (heute schon so
  gedacht laut Kommentar, nachpruefen).
- **Rechts die Zeit** in `caption`/`.secondary`, relativ („Gestern, 19:13",
  „19:13" fuer heute — `Self.zeitform` kann das), und darunter „Platz 1"
  in `caption2`. Das `display`-Zeichen fuer „liegt auf der Uhr" bleibt
  rechts aussen.

**Sortierte Uhren an der Quelle:** `AppZustand.swift:1191` sortiert
`erreicht` mit `localizedStandardCompare`, bevor es verbindet. Damit
findet `gleichtInhaltlich` gleiche Sendungen wieder, und die Doppelten
verschwinden von selbst. Alte Eintraege in Dateien bleiben, wie sie sind —
sie sind Vergangenheit; kein Umschreiben beim Lesen.

**Fremdzeilen** (`fremdzeile`, „auf der Uhr / meldung2") bekommen dieselbe
Ordnung: vorn ein leerer Icon-Platz, dann der Name der Anzeige in
Monospace, rechts „Platz 2" — ohne Zeit, weil es keine gibt.

## Abnahme

- Bildschirmfoto iPhone mit einer Nur-Icon-Sendung: Bildchen vorn, Name
  daneben, keine nackte Zahl.
- Zwei Sendungen desselben Inhalts an dieselben Uhren in verschiedener
  Reihenfolge ergeben **eine** Zeile — Test in `Tests/TC002ModellTests` oder
  `TC002CoreTests`, der `Verlaufseintrag` mit „A, B" und „B, A" anlegt und
  nach der Sortierung an der Quelle Gleichheit erwartet (der Test greift an
  der Stelle an, die sortiert; welche das ist, entscheidet der Bearbeiter
  und schreibt es an die Stelle).
- Kein Plattenzugriff im `body`: `Iconsammlung.alle()` wird beim Zeichnen
  der Liste nicht je Zeile gerufen (Instruments oder ein Zaehler im Test
  gegen einen Doppelgaenger).
- Mac und iPhone zeigen dieselbe Zeile (dieselbe Datei).

## Nicht anfassen

Wisch-Aktionen, der Druck auf die Zeile, `Sendeverlauf` als Ablage.
