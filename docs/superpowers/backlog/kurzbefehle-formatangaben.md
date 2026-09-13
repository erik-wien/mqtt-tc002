# Kurzbefehle: Formatangaben als Parameter

**Anlass:** Ein Kurzbefehl des Auftraggebers („Nachricht an MQTT-Uhr senden",
13.09.2026) sammelt sechs Angaben — Nachricht, Icon, senkrechte und waagrechte
Ausrichtung, Schriftart, Farbe, Slot — und legt vier davon in ein Woerterbuch,
**das niemand liest**. `MeldungSendenIntent` nimmt sie nicht an.

## Was der Intent heute kennt

`text`, `uhr`, `iconNummer`, `dauer`, `platz` (`Sources/TC002iOS/Kurzbefehle.swift:16`).

## Was fehlt

Schriftart, Groesse, Farbe, Ausrichtung waagrecht und senkrecht, Fett,
Grossbuchstaben, Rand, Abstand, Tempo, Weg (Pixel/Text).

## Zwei Bedingungen, die den Zuschnitt bestimmen

1. **Auswahllisten, kein freier Text.** Wer „Silkscren" tippt, darf nicht
   stillschweigend nichts bewirken. App Intents koennen das
   (`AppEnum`/`EntityQuery`) — ohne das waere der Parameter schlimmer als keiner.
2. **`Pixelgroessen` gilt auch hier.** Die abgesegneten Groessen haengen an der
   Schrift (Micro 5: 10/14/16, Silkscreen: 7–16 mit Luecken, Tiny5 ebenso).
   Ein Kurzbefehl, der eine nicht angebotene Groesse schickt, umgeht eine
   Entscheidung, die ein Mensch mit den Augen getroffen hat.

## Die Falle aus CLAUDE.md, die hier zuschnappt

App Intents fuehren ihre `parameterSummary` im Buendel als `${text} …`, **nicht**
als `\(\.$text) …`. Wer den Quelltext abschreibt, legt einen
Uebersetzungsschluessel an, den nie jemand nachschlaegt. Nachsehen in
`Metadata.appintents/extract.actionsdata` des **gebauten** Buendels.

## Nebenbefunde am Kurzbefehl selbst (gehoeren dem Auftraggeber)

- `dauer` und `platz` haengen beide am Ausgang von „Icon eingeben".
- Die Dauer wird **nach** dem Senden abgefragt.
- Die Slot-Liste geht bis 4; es gibt fuenf.
- Schritt 12 heisst intern „Dauer", fragt aber nach dem Slot.
- Die Uhradresse steht fest im Kurzbefehl (privater Bereich, aber in einem
  geteilten Link).

Die meisten davon erledigen sich, sobald die Parameter da sind und das
Woerterbuch entfaellt.
