# Favoriten — Design

Stand 27.10.2026, freigegeben im Gespräch mit Erik.

## Wozu

Jemand im Nebenraum soll mit **einem Klick** eine fertige Meldung wie „Telco läuft“ auf die Uhr legen,
ohne Text, Farbe, Icon, Dauer und Ziel jedes Mal neu einzustellen. Mac, iPad und iPhone können das
gleich (Regel „dieselbe App, überall dasselbe Können“).

Jede Installation hat ihre eigenen Favoriten. Wer sie anlegt, ist der, der sie benutzt; zwischen
Personen wird nichts geteilt. Zwischen den Geräten **einer** Person wandern sie mit, wenn der
bestehende iCloud-Abgleich eingeschaltet ist, wie Icons, Bilder und Slots.

## Ziele

- Ein Favorit hebt **alles** auf, was der Senden-Schirm gerade eingestellt hat, unter einem Titel.
- Ein Klick auf einen Favoriten sendet ihn sofort, ohne den Senden-Schirm zu öffnen.
- Favoriten lassen sich bearbeiten, duplizieren, umbenennen und löschen.

## Nicht-Ziele

- Kein Teilen zwischen Personen oder Apple-IDs.
- Kein Kurzbefehl „Favorit senden“, kein CLI-Befehl (kann später kommen; das Dateiformat soll es
  nicht verbauen).
- Keine Favoriten für gemalte Bilder oder Anzeigen aus der Sammlung; nur, was aus Reglern entsteht.
- Kein Umordnen per Ziehen (Reihenfolge: siehe unten).

## Anti-Ziele

- Ein Klick, der *nicht* sendet, sondern erst etwas öffnet oder nachfragt.
- Ein Favorit, der beim Senden anders aussieht als beim Anlegen in der Vorschau.
- Eine Plattform kann etwas, das die andere nicht kann.

## Was ein Favorit enthält

Titel, dazu ein Abbild **aller** Werte des Senden-Schirms. Heute liegen sie als `@AppStorage("senden.*")`
in `SendenView` und `SendeniOS`: Sendeart (Anzeige | Nachricht) samt Nachrichtoptionen (Dauerart,
Sekunden, Durchläufe, Aufwecken, Ersetzen, Klang), Text, Weg, Schrift, Größe, Fett, Großbuchstaben,
Lücke, Ausrichtung waagrecht und senkrecht, Rand, Farbe, Tempo, Icon mit Kante und Modus, Zusatzicons,
Darstellung, Lebensdauer (behalten, Zahl, Einheit, Ablauf), Dauer, Meldungsplatz (Slot) und die
Ziel-Uhren (`zielIDs`).

Gespeichert werden die **Regler**, nicht das fertige Bild: Beim Senden wird für jede Ziel-Uhr in ihrem
Maß neu gerastert (`AppZustand.senden(rahmenFuer:)`), wie bei jeder Sendung.

Gibt es eine Uhr nicht mehr, geht der Favorit an die übrigen; ist keine mehr übrig, kommt die übliche
Fehlermeldung. Fehlt das gespeicherte Icon, wird ohne Icon gesendet.

**Entscheidung des Bauenden (vorgegeben):** Ein eigener `Codable`-Typ im Kern (`Favorit`, `TC002Core`,
nur Foundation, getestet), keine Kopie von `Slotstand`. `Slotstand` trägt Slot-Eigenes (Prüfsumme,
Platz) und lässt die Nachrichtoptionen aus. Das Lesen und Schreiben der Regler (heute verdoppelt in
`SendenView`/`SendeniOS`) soll an **einer** Stelle geschehen, aus der sowohl „+ Favorit“ als auch
„Favorit laden“ schöpfen. Wie diese Stelle aussieht, entscheidet der Bauende. Neue Felder sind
`Optional` (Dateiformat, ältere Fassung auf einem anderen Gerät; siehe die Begründung an `Slotstand`).

## Ablage

Eine Datei `Favoriten.json` im gemeinsamen Datenordner (`Ablageort.gemeinsam`), damit der iCloud-Abgleich
sie mitnimmt. Eine Liste mit fester Reihenfolge: neue Favoriten kommen ans Ende, ein Duplikat direkt
hinter sein Original. Jeder Favorit hat eine `UUID`.

## Oberfläche

### Anlegen: „+ Favorit“

Der Knopf steht rechts in der Zeile **über dem Eingabefeld**, in der links „Display | Message“ und die
Dauer stehen (Eriks Bildschirmfoto vom 27.10.2026), auf Mac, iPad und iPhone an derselben Stelle.
Er fragt nach dem Titel (Vorgabe: der eingegebene Text) und speichert.

### Liste

- **Mac und iPad:** In der Seitenleiste stehen die Favoriten direkt unter „Senden“, eingerückt, je
  Favorit eine Zeile mit Titel. Ein Klick sendet. Der ausgewählte Bereich bleibt dabei, wo er ist.
- **iPhone:** im Titelmenü des Senden-Schirms (`toolbarTitleMenu`), als eigener Abschnitt
  „Favoriten“. Ein Tippen sendet.
- Ohne Favoriten gibt es keinen leeren Abschnitt.
- Ob eine Sendung geklappt hat, zeigt dasselbe Sendezeichen bzw. dieselbe Fehlermeldung wie beim
  normalen Senden, einschließlich der Auswertung von `<Thema>/result`.

### Kontextmenü (Rechtsklick, langes Drücken)

- **Bearbeiten:** Öffnet den Senden-Schirm mit allen Werten des Favoriten. An die Stelle von
  „+ Favorit“ tritt das Paar **„Abbrechen | Favorit speichern“**. Der Sendeknopf bleibt, damit sich der
  Favorit ausprobieren lässt. „Favorit speichern“ überschreibt den Favoriten. Beide Knöpfe beenden den
  Bearbeitungsstand.
- **Duplizieren:** dasselbe, aber „Favorit speichern“ legt einen neuen Favoriten an (Titel „<Titel>
  Kopie“, beim Speichern abgefragt).
- **Umbenennen:** fragt nach dem neuen Titel.
- **Löschen:** entfernt den Favoriten (mit Rückfrage).

**Was mit den bisherigen Senden-Werten geschieht:** Bearbeiten und Duplizieren überschreiben die
aktuellen Werte des Senden-Schirms. „Abbrechen“ stellt die Werte wieder her, die vor dem Bearbeiten
eingestellt waren; „Favorit speichern“ lässt die Werte des Favoriten stehen.

## Rahmenbedingungen

- Logik (Favorit, Liste, Ablage, Duplizieren, Umbenennen) gehört in `TC002Core`/`TC002Modell` und wird
  dort getestet. Die Ansichten bleiben dünn. Kein AppKit/UIKit in den ersten drei Zielen.
- Bedienelemente aus dem System (Kontextmenü, `alert` mit Textfeld o. Ä.), kein Nachbau.
- Alle Texte nach den Sprachregeln (`lok`, `en.lproj`); `python3 scripts/texte-sammeln.py --pruefen`
  muss `0 ohne Uebersetzung` melden.
- Hilfe (beide Oberflächen, gemeinsame Absätze in `HilfeInhalt`), README und
  `docs/funktionen-je-uhr.md`, falls betroffen, werden nachgezogen.
- Tests nie gegen echtes Gerät oder Broker. Für den ganzen Sendeweg die virtuelle Uhr.
- Prüfen im Simulator (iPhone) und an der Mac-App. Die iPhone-Zeile über dem Eingabefeld darf mit „+ Favorit“
  nicht abgeschnitten werden.

## Festlegungen nach der Gegenlese (Claudes Entscheidungen, von Erik zu prüfen)

- **Senden ohne Senden-Schirm:** Der Sendeweg (Rastern je Uhr, Icon nachschlagen, Anzeige oder
  Nachricht) wandert aus `SendenView`/`SendeniOS` ins Modell, damit ein Favorit ohne offene Ansicht
  gesendet werden kann. Der Senden-Schirm nutzt danach denselben Weg. Das ist der größte Teil der
  Arbeit und gewollt: Die Regel „Logik nicht in den Views“ verlangt es ohnehin.
- **Ein Klick ändert nichts am Senden-Schirm** und nichts an der globalen Zielauswahl (`zielIDs`).
  Gesendet wird an die Uhren des Favoriten, gefiltert wie üblich auf beschickbare.
- **Slotgedächtnis:** Ein Favorit schreibt beim Senden in das Slotgedächtnis wie jede andere Sendung
  auf einen der fünf Plätze.
- **Rückmeldung:** Der Sendestand eines Favoriten liegt im Modell. Seine Zeile in der Seitenleiste
  bzw. im Titelmenü zeigt „läuft“, Erfolg oder Warnung; ein Fehler kommt über die allgemeine
  Fehlermeldung der App (`zustand.fehler`). Das funktioniert auch dann, wenn am Mac gerade ein
  anderer Bereich offen ist.
- **Bearbeiten setzt auch die Ziel-Uhren** des Senden-Schirms auf die des Favoriten; „Abbrechen“
  stellt sie mit den übrigen Werten wieder her.
- **Der Bearbeitungsstand lebt nur im Speicher.** Er überdauert einen Wechsel des Bereichs bzw. das
  Verlassen des Senden-Schirms (die Leiste ist bei der Rückkehr wieder da), aber keinen Neustart. Nach
  einem Neustart stehen die Werte des Favoriten im Senden-Schirm, ohne Leiste. Ein Klick auf einen
  anderen Favoriten während des Bearbeitens sendet ihn und lässt das Bearbeiten unberührt. Wird
  während des Bearbeitens „Bearbeiten“ auf einem anderen Favoriten gewählt, wechselt das Ziel ohne
  Rückfrage; „Abbrechen“ stellt weiterhin den Stand vor dem ersten Bearbeiten her.
- **Icon-Modus** heißt `iconLaeuftMit` und `iconEinmal`.
- **Gleichzeitige Änderungen auf zwei Geräten:** Wer zuletzt schreibt, gewinnt, wie bei den übrigen
  Dateien im gemeinsamen Ordner.
- **Titel:** dürfen nicht leer sein, doppelte Titel sind erlaubt.
- **Löschen** fragt nach, wie andere Löschungen in der App.

## Dem Bauenden überlassen

- Name und Form der gemeinsamen Stelle für die Senden-Werte.
- Symbol der Favoriten in der Seitenleiste (z. B. `star`).
- Wie der Bearbeitungsstand im Modell gehalten wird.
