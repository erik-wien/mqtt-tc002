# Die fünf Slot-Blöcke — Entwurf

Stand 12.09.2026, abends. Entstanden im Gespräch, nachdem die Mac-Sendeansicht
die Ordnung des iPhones bekommen hat und ihre Mitte leer wurde.

## Worum es geht

Die Uhr hat fünf feste Plätze für eigene Anzeigen, in der Oberfläche „Slot"
genannt, auf dem Gerät `meldung1` bis `meldung5`. Heute wählt man den Slot über
eine Ziffernreihe ①–⑤ und weiß dabei nicht, was darauf liegt.

Gewünscht ist ein Nachrichtenfenster: oben das Gerät, **in der Mitte die fünf
Slots mit ihrem Inhalt**, unten die Eingabe. Antippen eines Blocks wählt den
Slot. Man sieht, was man überschreibt.

## Was die Uhr verrät, und was nicht

Das ist der Kern des Entwurfs, gemessen und in der Gerätereferenz belegt (§3.5):

- `customList` meldet **Namen**, sonst nichts — `{"apps":[{"appName":"…"}]}`.
  Damit weiß die App, welche Slots belegt sind. Verlässlich, für jeden
  Absender, auch für über HTTP angelegte Anzeigen.
- Die Liste ändert sich nur, wenn ein Name dazukommt oder verschwindet. Sind
  alle fünf Slots einmal belegt, ändert sie sich **nie wieder** — auch nicht,
  wenn jemand Slot 3 überschreibt.
- Den **Inhalt** eines Slots verrät die Uhr nicht. Nicht die Pixel, nicht die
  Farbe, nicht die Schrift.

Daraus folgt: Inhalt kann die App nur kennen, wenn sie die Sendung gesehen hat.

## Woher der Inhalt kommt: der Reader

Die App abonniert zusätzlich zu `customList` und `status` das Thema
`<präfix>/custom/#`. Was auf ein Thema veröffentlicht wird, bekommen **alle**
Abonnenten — die App sieht damit jede Sendung an die Uhr, gleich ob sie von ihr
selbst, vom Kommandozeilenwerkzeug, von einem Kurzbefehl, von `mosquitto_pub`
oder von einem zweiten Menschen kommt. Mitsamt Nutzlast.

Die Nutzlast ist unser eigenes Format (`Rahmen.alsJSON()`), die App kann daraus
die Pixel des Blocks rekonstruieren. Bei einem Lauf-GIF das erste Einzelbild;
ob der Block das GIF abspielt, ist Geschmack und wird später entschieden.

Grenzen, ehrlich benannt:

- **Live-Strom, kein Gedächtnis.** Ohne RETAIN sieht die App nur, was
  veröffentlicht wird, während sie verbunden ist. War das Telefon im Büro,
  ist alles verpasst, was inzwischen kam.
- **Über HTTP angelegte Anzeigen** berühren den Broker nicht — sie bleiben
  ohne Inhalt.
- Der Strom sagt, **was angezeigt wird**, nicht **wie es entstanden ist**. Aus
  Pixeln lässt sich keine Schriftart zurückrechnen.

## Drei Zustände je Block

| Zustand | Woher | Was der Block zeigt |
|---|---|---|
| **frei** | Name fehlt in `customList` | leerer Block, gedämpft |
| **belegt, Inhalt bekannt** | Name da **und** Nutzlast gesehen | die Pixel, klein |
| **belegt, Inhalt unbekannt** | Name da, Nutzlast nie gesehen | „belegt" ohne Inhalt, mit Hinweis warum |

Der dritte Zustand ist keine Schwäche, sondern die Auskunft. Ein Block, der
Grün behauptet, obwohl niemand mehr weiß, ob es stimmt, wäre genau die
Zuversicht, gegen die dieses Programm gebaut ist.

Dazu bleibt die vorhandene Unterscheidung aus dem Verlauf erhalten: **Tatsache**
(von der Uhr gemeldet) gegen **Erinnerung** (eigene Buchführung).

## RETAIN — die eine Entscheidung, die am Gerät fällt

Unser Sender veröffentlicht mit Kopfbyte `0x30`, RETAIN nicht gesetzt. Mit
`0x31` hielte der Broker die letzte Nutzlast je Thema fest, und jeder neue
Abonnent — das Telefon nach dem Büro — bekäme sofort alle fünf Slots. MQTT wäre
damit der Zustand der Uhr, nicht nur ein Strom.

Zwei Dinge sprechen mit:

- Die Uhr abonniert `<präfix>/#`. Bei jedem Wiederverbinden bekäme sie alle
  aufbewahrten Nutzlasten erneut und legte die Anzeigen neu an. Nach einem
  Stromausfall stünde alles wieder da — heute Nachmittag wäre das ein Gewinn
  gewesen. Ob es sonst stört, ist offen.
- Gelöscht wird bei uns durch eine leere Nutzlast. Eine leere Nutzlast mit
  RETAIN **löscht** den aufbewahrten Eintrag beim Broker. Das passt.

**Das ist ein Versuch von fünf Minuten am Schreibtisch, bevor es eingebaut
wird:** einmal mit RETAIN senden, die Uhr vom Strom nehmen, wieder anstecken,
hinsehen. Der Entwurf funktioniert auch ohne RETAIN — dann bleibt „unbekannt"
häufiger.

## Die Regler wiederherstellen

Wählt man einen Slot, sollen die Regler den Stand annehmen, mit dem er
gesendet wurde: Schrift, Größe, Fett, Großbuchstaben, Icon, Ausrichtungen,
Rand, Abstand, Farbe, Dauer, Weg, Tempo.

Das kann der Reader nicht liefern. Dafür braucht es eine **eigene Aufzeichnung
je Slot** — und die muss von **allen unseren Absendern** geschrieben werden:
App, Werkzeug und Kurzbefehle. Schreibt nur die App, zeigt ein Slot nach einem
Kurzbefehl die Regler von gestern; eine Erinnerung, die sich als Tatsache
ausgibt.

Kosten dieser Entscheidung: Das Werkzeug schreibt heute **nie** in die
Einstellungen — das war eine bewusste Regel („zwei Schreiber auf denselben
Schlüsseln wären ein Wettlauf"). Die Aufzeichnung je Slot ist deshalb **kein
Teil der Einstellungen**, sondern eine eigene Datei mit eigenem Format, die
jeder Absender nach dem Senden schreibt und die App beim Wählen liest. Das
Format ist damit ein Dateiformat mit Test, wie die `Codable`-Form von `Uhr`.

Was die Aufzeichnung **nicht** ist: die Wahrheit über den Slot. Sie gilt nur,
solange der Block „belegt, Inhalt bekannt" ist **und** die gesehene Nutzlast zu
ihr passt. Weicht die Nutzlast ab (ein fremder Absender), werden die Regler
nicht angerührt.

## Oberfläche

- Fünf Blöcke nebeneinander in der Mitte der Sendeansicht (Mac) — am iPhone an
  derselben Stelle, unter der Vorschau. Gleiche Bauart, geteiltes Ziel
  `TC002Ansichten`.
- Jeder Block: Slotnummer, Zustand sichtbar ohne Farbe allein (frei / belegt /
  unbekannt), bei bekanntem Inhalt die Pixel als kleines Raster im
  Seitenverhältnis 52:16.
- Der gewählte Block ist markiert. Antippen wählt und stellt — falls möglich —
  die Regler wieder her.
- Der Papierkorb gehört zum gewählten Block (leert diesen Slot).
- Die Ziffernreihe ①–⑤ entfällt.
- Kein Erklärtext in der Ansicht. Was „unbekannt" heißt, sagt die Hilfe; im
  Block steht das Wort, nicht die Begründung.

## Was sich nicht ändert

- `meldung1`…`meldung5` als Gerätebezeichner. Das ist Dateiformat.
- Die Rechnung der Vorschau und der Nutzlast (`Meldungsbau`).
- Der Verlauf: Er behält das Protokoll, denn dort steht mehr als nur, was wann
  geschickt wurde.

## Offene Fragen

1. RETAIN — siehe oben, am Gerät zu klären.
2. Spielt ein Block ein Lauf-GIF ab oder zeigt er das erste Bild? Vorschlag:
   erstes Bild, Bewegung nur in der großen Vorschau.
3. Wie heißt die Aufzeichnungsdatei, und wo liegt sie? Vorschlag: neben den
   Icons unter `Application Support/MQTT-TC002/`, ein JSON je Uhr.
