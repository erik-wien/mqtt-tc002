# Hilfe-Nachzug: Umformen und der Eimer

**Anlass.** Der Editor hat vier Umformungen (links/rechts drehen, waagrecht/
senkrecht spiegeln) und ein drittes Werkzeug („mit Farbe fuellen") bekommen.
Die Hilfe war fuer diese Arbeit gesperrt und weiss davon nichts. Was unten
steht, ist die Schuld — jeder Punkt ein Satz in der Hilfe und seine
Uebersetzung in `Resources/Sprachen/en.lproj/Localizable.strings`.

Zustaendig sind `HilfeView.swift` (Mac und iPad) und `HilfeInhalt.swift`
(gemeinsam). Der Editor ist eine Schreibtisch-Oberflaeche; ein Absatz gehoert
nur dann nach `HilfeInhalt`, wenn er auch am iPhone wahr ist.

## Falsch geworden

- Der Absatz „Gemalt wird mit gedrückter Maustaste oder mit dem Finger …"
  nennt den Waehler noch **„Stift"** und sagt, er schalte „zwischen Malen und
  Radieren um". Der Waehler heisst jetzt „Werkzeug" und hat drei Segmente:
  Stift, Radierer, Eimer. Der Schluessel `"Stift" = "Pen";` ist damit
  entfallen.
- Der Absatz „Das Verschiebekreuz schiebt die Grafik um ein Pixel …" sagt, die
  Wahl „alle zusammen oder nur das bearbeitete" stehe **unter dem Kreuz**. Sie
  steht jetzt als letzte Zeile der Karte „Umformen" und gilt fuer Verschieben,
  Drehen und Spiegeln zugleich.
- Der Absatz „Ein Strich ist ein Schritt, nicht ein Pixel …" zaehlt auf, was
  je ein Schritt fuer „Rueckgaengig" ist. Drehen, Spiegeln und eine Fuellung
  fehlen in der Aufzaehlung; sie sind je ein Schritt.

## Neu zu schreiben

- **Karte „Umformen".** Kreuz, Drehen, Spiegeln und darunter die Wahl „Alle
  Bilder / Nur dieses" fuer alle drei.
- **Drehen nur quadratisch.** Auf der 52 × 16 sind die beiden Drehknoepfe
  gesperrt: Gedreht waere die Anzeige 16 × 52 hoch, und diese Groesse zeigt
  keine Uhr. Beschneiden kaeme nicht in Frage — 36 Spalten waeren weg, und
  nichts holte sie zurueck. Spiegeln geht in jeder Groesse.
- **Der Eimer.** Er faerbt die zusammenhaengende Flaeche gleicher Farbe unter
  dem angetippten Punkt um, nicht das ganze Bild (dafuer gibt es „Alles
  loeschen"). Er laeuft ueber die vier Nachbarn, nicht ueber Eck — eine
  diagonal gemalte Linie ist also eine Grenze. Durchsichtig zaehlt dabei als
  Farbe: Der leere Untergrund eines frischen Icons laesst sich fuellen.
  Umgekehrt nimmt der Eimer nichts weg — wer eine Flaeche loswerden will,
  faehrt mit dem Radierer darueber.
- **Einmal je Beruehrung.** Der Eimer wirkt dort, wo die Beruehrung beginnt,
  und nur einmal — Ziehen faerbt nicht weiter.
