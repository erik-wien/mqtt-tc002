# Hilfeschuld: das Icons-Blatt am Telefon

> **Erledigt.** Alle vier Punkte. Der neue geteilte Absatz (Punkt 4) heisst
> `HilfeInhalt.iconOderAnzeige` und steht in beiden Hilfen. Nachgesehen:
> `Hilfebilder.swift` zeigt kein Formatpillen-Bild, dafuer aber die
> **Sendezeile des Schreibtischs** — samt blauem Sendeknopf, den es am Telefon
> nicht gibt. Die Abbildung ist aus der Telefonhilfe genommen, und
> `HilfebildTests` haelt das fest.

Die Bedienung hat sich geaendert, die Hilfe nicht — sie war fuer diese Aufgabe
gesperrt. Was die Hilfe heute behauptet, stimmt danach in drei Absaetzen nicht
mehr; ein vierter fehlt ganz.

**Was sich geaendert hat.** `IconauswahliOS` und `BildauswahliOS` sind zu einem
Blatt „Icons" (`Sources/TC002iOS/IconsblattiOS.swift`) geworden. Es zeigt alle
drei Groessen nach Groesse gruppiert — 8 × 8, 16 × 16 und die 52 × 16-Anzeigen
—, hat Suche, Filterleiste ueber alle drei Groessen und ein Zuruecksetzen, das
nur dasteht, wenn etwas eingeschraenkt ist. Ein Icon fuehrt auf seine
Einzelansicht, eine 52 × 16 auf eine eigene Seite mit Vorschau und
„An Platz N senden". Hinzufuegen geht ueber die LaMetric-Nummer und neu ueber
„Dateien …". Der einzige Einstieg ist der Icon-Knopf am Anfang der
Formatpille; das 🖼 am Ende der Pille gibt es nicht mehr.

## 1. `HilfeiOS.swift`, Abschnitt „Ein Bild schicken" (erster Absatz)

Heute:

> Das Bildsymbol in der Formatpille öffnet den Bestand der 52 × 16-Anzeigen —
> jener Bilder, die im Editor am Mac und am iPad entstehen und über iCloud hier
> ankommen. Eines wählen, „Senden“: Es geht an den Platz, der gerade gewählt
> ist, und ersetzt dort Text und Icon, denn eine Anzeige füllt das ganze
> Display.

Falsch daran: Das Bildsymbol gibt es nicht mehr, und gewaehlt und gesendet wird
nicht mehr in einer Liste, sondern auf einer eigenen Seite.

Soll lauten:

> Der Icon-Knopf in der Formatpille öffnet „Icons", und dort steht unter
> „52 × 16" der Bestand der ganzen Anzeigen — jener Bilder, die im Editor am
> Mac und am iPad entstehen und über iCloud hier ankommen. Eine antippen führt
> auf ihre Seite: die Vorschau und „An Platz N senden". Sie geht an den Platz,
> der gerade gewählt ist, und ersetzt dort Text und Icon, denn eine Anzeige
> füllt das ganze Display.

Der zweite Absatz des Abschnitts („Gemalt wird am Telefon nicht …") bleibt
richtig und bleibt stehen.

## 2. `HilfeiOS.swift`, Abschnitt „Formatpille"

Heute endet der Absatz mit:

> … und ganz hinten der Pinsel für das Blatt „Format“ (Dauer, Lauftempo,
> mitlaufendes Icon) und das Bild aus dem Bestand.

Falsch daran: „das Bild aus dem Bestand" ist kein Knopf der Pille mehr.

Soll lauten: `… und ganz hinten der Pinsel für das Blatt „Format“ (Dauer,
Lauftempo, mitlaufendes Icon).`

## 3. `HilfeiOS.swift`, Abschnitt „Icon wählen"

Zwei Stellen sind falsch geworden.

Erster Absatz, heute:

> … Ein Druck öffnet ein Blatt mit Suchfeld, Filterleiste und Raster — die
> Leiste grenzt nach Größe (8 × 8 oder 16 × 16) und auf bewegte Icons ein …

Die Leiste kennt jetzt drei Groessen, und das Blatt heisst „Icons".

Dritter Absatz, heute:

> Über dem Raster lässt sich außerdem eine Nummer von developer.lametric.com
> eintragen und mit „Nachladen“ holen; das Icon steht danach bei den eigenen.
> Gemalt wird hier nicht — eigene Icons entstehen am Mac und auf dem iPad, wo
> ein Editor daneben Platz hat. Zur Wahl stehen beide Größen: die 8×8-Icons und
> die eigenen 16×16, die am Schreibtisch entstehen und über iCloud hier
> ankommen.

Falsch daran: „beide Größen" — es sind drei; und „Dateien …" fehlt.

Vorschlag fuer den ganzen Abschnitt (Ueberschrift „Icons" statt „Icon wählen"):

> Ganz links in der Formatpille sitzt der Icon-Knopf: ohne Wahl ein Smiley, mit
> Wahl das gewählte Icon. Ein Druck öffnet „Icons" — die ganze Sammlung, nach
> Größe gruppiert: die 8 × 8-Icons, die eigenen 16 × 16 und die
> 52 × 16-Anzeigen. Darüber ein Suchfeld und eine Filterleiste, die nach Größe
> und auf bewegte Einträge eingrenzt; „Zurücksetzen“ steht nur da, solange
> etwas eingeschränkt ist. Ein Icon antippen zeigt es groß — bei einem
> animierten auch laufend —, „Übernehmen“ wählt es. „Kein Icon“ nimmt die Wahl
> zurück, „Abbrechen“ schließt ohne Änderung.
>
> In der großen Ansicht steht rechts oben ein Menü mit „Umbenennen“ und
> „Löschen“. (unveraendert)
>
> Unter „Hinzufügen“ stehen zwei Wege: eine Nummer von developer.lametric.com
> eintragen und mit „Nachladen“ holen, oder „Dateien …“ — eine GIF-, PNG- oder
> JPEG-Datei aus den Dateien. Sie landet im Bestand ihrer eigenen Größe;
> Kleineres wird mittig eingepasst, Größeres als die Anzeige abgelehnt, denn
> verkleinert wird nicht. Gemalt wird hier nicht — eigene Icons entstehen am
> Mac und auf dem iPad, wo ein Editor daneben Platz hat.

## 4. Was fehlt: warum eine 52 × 16 kein Icon ist

Der Unterschied steht am Telefon jetzt in zwei Gruppen desselben Blattes und
war dort vorher nie zu erklaeren, weil es die Anzeigen dort nicht zu sehen gab.
Ein Absatz dazu gehoert nach `HilfeInhalt.swift` — er ist auf beiden
Oberflaechen wahr, am Schreibtisch traegt ihn heute die Uebersicht:

> Ein Icon und eine Anzeige sind zweierlei. Ein Icon steht *neben* dem Text und
> ist 8 × 8 oder 16 × 16; eine 52 × 16-Anzeige **ist** das ganze Display und
> ersetzt Text und Icon. Deshalb wird ein Icon gewählt und eine Anzeige
> geschickt.

## 5. Nachzupruefen

- `Hilfebilder.swift`: Ob eines der Bilder das 🖼 in der Formatpille zeigt.
  Diese Aufgabe hat es nicht angesehen.
- Die englische Fassung in `Resources/Sprachen/en.lproj/Localizable.strings`:
  Jeder geaenderte Absatz ist ein neuer Schluessel; der alte faellt weg und
  meldet sich sonst als „ueberzaehlig".
- `HilfeauszeichnungTests` und `HilfebildTests` zaehlen Absaetze und Bilder.
