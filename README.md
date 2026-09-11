# mqtt-tc002

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
  wie die gesendete Nachricht.
- **Malen** — eine freie 52×16-Zeichenfläche, aus der beim Senden Rechtecke
  statt einzelner Pixel werden.
- **Icons** — eigene 8×8-Bildchen malen oder über eine LaMetric-Nummer
  nachladen.
- **Anzeigen** — was die App bei der aktiven Uhr bereits angelegt hat,
  umschalten oder löschen, dazu der Seitenwechsel der Uhr.

Wie man diese Bereiche im Einzelnen bedient, steht in der Hilfe im Programm
(⌘?); was die Uhr selbst kann und wie ihr Protokoll aussieht, steht in
[`docs/tc002-protokoll.md`](docs/tc002-protokoll.md).

## Warum Text als Pixel geht

Die eingebaute Schrift der Uhr kennt keine Umlaute und kaum Satzzeichen. Die
App umgeht das, indem sie Text nicht als Zeichenkette schickt, sondern selbst
mit CoreText rastert und als `draw`-Rechtecke überträgt — damit gehen „ä“,
„ö“, „ü“ und „ß“ trotzdem, und die Vorschau zeigt exakt das Bild, das auch
gesendet wird, weil beide aus demselben Pixelfeld stammen.

## Icons

Drei Quellen stehen unter „Senden“ zur Wahl: die mitgelieferten Icons im
App-Paket, selbst gemalte aus dem 8×8-Editor unter „Icons“, und Icons, die
sich über ihre Nummer von developer.lametric.com nachladen lassen. Eigene und
nachgeladene Icons liegen unter
`~/Library/Application Support/MQTT-TC002/Icons` — nicht im App-Bündel, denn
dort wären sie beim nächsten Bau weg, und unter `/Applications` ist der
Ordner ohnehin nicht beschreibbar.

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
