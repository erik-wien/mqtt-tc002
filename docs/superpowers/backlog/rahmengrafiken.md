# Rahmengrafiken — ein Satz 16×52 mit durchsichtigem Grund

**Idee des Auftraggebers, 13.09.2026:** *„ein Satz von 16x52 Grafiken mit
transparentem Hintergrund um Rahmen anzubieten."* Ausdruecklich **spaeter**.

## Was gemeint ist

Zierrahmen, die **um** eine Meldung liegen: Der Rand traegt das Muster, die
Mitte bleibt frei, damit der Text durchscheint.

## Warum es ins Modell passt

Ein Pixelfeld ist `[String?]` — **„nichts" ist bereits ein unbeleuchtetes
Pixel.** Durchsichtigkeit ist also keine neue Eigenschaft, sondern die
vorhandene. Ein Rahmen ist ein Feld, in dem die meisten Zellen `nil` sind.

Und die Uhr hilft mit: Ein `draw` setzt **nur die genannten Pixel**; was nicht
genannt ist, bleibt dunkel. Rahmen und Text muessen also nicht nacheinander
geschickt werden, sondern **einmal zusammengerechnet**.

## Was zu bauen waere

1. **Uebereinanderlegen** — Rahmenfeld und Textfeld zu einem verrechnen. Wo der
   Rahmen etwas setzt, gewinnt er; sonst der Text. `Meldungsbau.feld` liefert
   das Textfeld schon, `Leinwand.iconEinsetzen` legt bereits ein Bild in ein
   groesseres — **derselbe Weg, nur ganzflaechig.**
2. **Eine Auswahl in der Sendeansicht** — „Rahmen: keiner / …", neben Icon und
   Schrift.
3. **Der Satz selbst.** Entweder selbst gezeichnet oder aus dem Bestand; es gibt
   bereits einen 16×52-Bestand (`Bildersammlung`).

## Was vorher zu klaeren ist

- **Wo der Text dann steht — und der Auftraggeber hat es bereits geloest:**
  *„Damit sollten wir gut zurechtkommen, wenn wir 8×8-Grafiken und
  <12px-Schriften verwenden. Das einzig Spezielle ist, dass das Icon ein
  bisschen nach rechts ruecken muesste. Der Rest ist Standard."*

  Ein Rahmen ist damit **ein Einzug**, kein neuer Satzspiegel: Alles wird in das
  um die Rahmenstaerke verkleinerte Feld gerechnet, statt in die volle Anzeige.
  `Meldungsbau` hat die Stellen schon — `flaecheX`, `flaecheBreite`,
  `iconY(kante:)`, `iconBreite(kante:)`; sie bekommen den Einzug hereingereicht,
  statt von 0 und 52 auszugehen.

  Gilt bei 8×8-Icons und Schriften unter 12 Pixeln. **Was bei groesseren
  geschieht, gehoert entschieden** — sperren, warnen, oder den Rahmen
  ausschliessen.
- **Animierte Rahmen** treffen Firmwarebeobachtung 3: Die Uhr setzt
  GIF-Verfahren 1 („nur den geaenderten Ausschnitt") nicht um. Ein Laufrahmen
  um stehenden Text braeuchte also je Einzelbild das **ganze** Feld — und das
  ist die Nutzlastgrenze, die niemand kennt (§4.2a).
- **Herkunft.** Ulanzis 23 Werke (Kategorie „Pixel Art 16×52") sind **keine**
  Rahmen und haben namentliche Urheber — als Grundschatz waere das eine
  Lizenzfrage. Selbst gezeichnete Rahmen haben das Problem nicht.
