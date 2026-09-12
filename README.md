# mqtt-tc002

*[English version](README.en.md)*

Meldungen an die Ulanzi TC002 (Pixbar, 52×16) schicken — per MQTT.

## Was die App tut

MQTT-TC002 ist eine macOS-App, die Text, Bilder und selbst gemalte Icons an
eine oder mehrere Ulanzi-TC002-Pixeluhren schickt. Der Weg dorthin führt über
einen MQTT-Broker, nicht direkt zur Uhr — die Uhr hört auf ihn, nicht auf die
App.

## Bauen

`./build.sh` schnürt `build/MQTT-TC002.app`. Wer lieber in Xcode arbeitet,
öffnet `Package.swift` direkt. Es gibt keine externen Paketabhängigkeiten;
vorausgesetzt wird macOS 14 aufwärts.

## Die fünf Bereiche

- **Verbindung** — Uhren eintragen und abfragen, Broker-Zugang verwalten.
  „Abfragen“ ermittelt Themen-Präfix und MAC direkt von der Uhr; von Hand
  eingetragen wird hier nichts.
- **Senden** — Text und wahlweise ein Icon zu einer benannten Anzeige
  zusammensetzen und verschicken. Die Vorschau entsteht aus demselben Raster
  wie die gesendete Nachricht. Zwei Wege stehen zur Wahl: **als Pixel**, von
  der App selbst gerastert, mit Umlauten und freier Schrift — passt der Text
  nicht, läuft er von selbst als Laufschrift durch; oder **als Text**, vom
  Gerät gesetzt, das dafür mit seiner eigenen Schrift scrollt, aber keine
  Umlaute kennt.
- **Malen** — eine freie 52×16-Zeichenfläche, aus der beim Senden Rechtecke
  statt einzelner Pixel werden.
- **Icons** — eigene 8×8-Bildchen malen oder über eine LaMetric-Nummer
  nachladen.
- **Anzeigen** — was die App bei der aktiven Uhr bereits angelegt hat,
  umschalten oder löschen, dazu der Seitenwechsel der Uhr. Diese Liste führt
  die App je Uhr getrennt: gelöscht wird immer nur bei der aktiven, und was
  über „an alle“ auf andere Uhren ging, bleibt dort stehen, bis es dort
  gelöscht wird.

Wie man diese Bereiche im Einzelnen bedient, steht in der Hilfe im Programm
(⌘?); was die Uhr selbst kann und wie ihr Protokoll aussieht, steht in
[`docs/tc002-protokoll.md`](docs/tc002-protokoll.md).

## Schriften und Abstand

Drei Pixelschriften liegen bei — **Micro 5**, **Silkscreen** und **Tiny5**,
alle unter der SIL Open Font License. Sie sind auf einem Pixelraster
entworfen, nicht als Bildschirmschriften mit Kurven, und sitzen deshalb bei
ihrer Entwurfsgröße genau auf den Punkten des Displays. Krumme Zwischengrößen
gibt es bei ihnen nicht: Dort landen die Striche zwischen zwei Pixeln, und
ohne Kantenglättung — die das Display nicht kennt — entscheidet ein Schwellwert
willkürlich. Die Auswahl bietet deshalb nur die sauberen Größen an.

Dazu kommen ein paar Schriften aus dem System für alle, die es gewöhnlicher
mögen.

Die Einstellung **Rand** bestimmt, wie viele Zeilen bei „oben" und „unten" frei
bleiben. Sie ist nötig, weil bündig je nach Schrift verschieden aussieht: Manche
bringen über der Großbuchstabenhöhe Platz mit, andere nicht.

Die Einstellung **Abstand** ist keine Unterschneidung im üblichen Sinn: Die App
rastert jedes Zeichen einzeln, misst, wo seine Tinte anfängt und aufhört, und
setzt die Zeichen so aneinander, dass dazwischen genau so viele leere Spalten
stehen, wie eingestellt. Der Wert ist also wörtlich eine Anzahl Pixelspalten.
Die Vorschubbreiten der Schrift werden dabei verworfen — sie sind für
gedruckte Größen gedacht und ergeben auf sechzehn Pixeln mal zu enge, mal zu
weite Buchstabenpaare.

## Warum Text als Pixel geht

Die eingebaute Schrift der Uhr kennt keine Umlaute und kaum Satzzeichen. Die
App umgeht das, indem sie Text nicht als Zeichenkette schickt, sondern selbst
mit CoreText rastert und als `draw`-Rechtecke überträgt — damit gehen „ä“,
„ö“, „ü“ und „ß“ trotzdem, und die Vorschau zeigt exakt das Bild, das auch
gesendet wird, weil beide aus demselben Pixelfeld stammen.

## Icons

Alle Icons liegen an einer Stelle:
`~/Library/Application Support/MQTT-TC002/Icons` — nicht im App-Bündel, denn
dort wären sie beim nächsten Bau weg, und unter `/Applications` ist der
Ordner ohnehin nicht beschreibbar. Dorthin kommen sie auf drei Wegen: Ein
**Grundschatz** von rund dreißig 8×8-Icons wird beim allerersten Start
einmalig aus dem App-Paket übernommen, danach sind es ganz normale eigene
Icons — löschbar und überschreibbar. Weitere entstehen im 8×8-Editor unter
„Icons“ oder lassen sich über ihre Nummer von developer.lametric.com
nachladen. Wer zu gründlich aufgeräumt hat, holt fehlende Grundschatz-Icons
mit „Grundschatz wiederherstellen“ zurück; Vorhandenes bleibt dabei
unangetastet.

## Auf der Kommandozeile

Im App-Bündel reist ein Werkzeug mit, das dieselbe Einrichtung benutzt wie die
App — Broker, Kennwort und Uhren kommen aus deren Einstellungen, eingerichtet
wird weiterhin nur in der App. Einmal verlinken:

```bash
ln -s /Applications/MQTT-TC002.app/Contents/MacOS/mqtttc002 /usr/local/bin/mqtttc002
```

```bash
mqtttc002 "Kaffee fertig"
mqtttc002 senden "Post da" --icon 1673 --farbe "#FFAA00" --dauer 10
mqtttc002 senden Achtung --an Küche --zentriert --unten
mqtttc002 uhren            # was eingerichtet ist, * sind die Ziele
mqtttc002 icons            # Nummer und Name
mqtttc002 loeschen cli     # die Anzeige wieder von der Uhr nehmen
mqtttc002 hilfe            # alle Optionen
```

Zu lange Texte laufen von selbst als GIF durch, genau wie in der App.
`--trocken` zeigt Thema, Nutzlast und Größe, ohne zu senden — und nebenbei, ob
ein Broker-Kennwort gefunden wurde. Beim ersten Lauf fragt macOS einmal, ob das
Werkzeug an den Schlüsselbundeintrag der App darf.

## Tests

`swift test` läuft ohne Netz und ohne echtes Gerät: HTTP-Aufrufe an die Uhr
laufen gegen einen `URLProtocol`-Doppelgänger, das Senden über MQTT gegen
einen `NachrichtSendend`-Doppelgänger. Die erzeugten MQTT-Bytes selbst sind
gegen eine echte Aufzeichnung von `mosquitto_pub` geprüft. Die echte Uhr und
der Broker im Haus sind in Tests tabu.

## Lizenz

GPL-3.0. Die Herkunft ist [PixDeck](https://github.com/cailurus/PixDeck),
siehe „Quellen“ unten.

## Quellen

- **Offizielles Repository des Herstellers:**
  https://github.com/UlanziTechnology/Ulanzi-U-Clock-TC002
  Bestaetigt die Praefixbildung `<eingestellt>_<letzte vier MAC-Stellen>` (Vorgabe
  `ulanzi`), nennt `text`, `image`, `draw` und `duration`, und fuehrt neben `df`
  (Rechteck) auch `dfc` (gefuellter Kreis: `{"dfc":[x,y,radius,"#RRGGBB"]}`) auf.
  Animierte GIFs sind laut dieser Quelle in `image` unterstuetzt.
- **Nicht** dokumentiert sind dort: das Steuerthema `<praefix>/switchDiyApp` und das
  Loeschen einer Anzeige durch eine leere Nutzlast. Beides haben wir am 11.09.2026 am
  Geraet ermittelt — `switchDiyApp` aus den SUBSCRIBE-Zeilen des Brokers.
- **PixDeck** (https://github.com/cailurus/PixDeck, GPL-3.0): Quelle der Erkenntnis, dass
  dasselbe JSON auch per HTTP an `/api/custom?name=<n>` geht.
