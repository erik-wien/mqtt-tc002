# mqtt-tc002

*[English version](README.en.md)*

**Pixel Clock Messenger** schickt Text, Bilder und Steuerbefehle an Ulanzi-Pixeluhren
mit der freien Firmware **AWTRIX NG** — per HTTP oder über einen MQTT-Broker.

Die App heißt seit dem 14.09.2026 „Pixel Clock Messenger“; das Repo, die
Bündelkennung `cloud.eriks.mqtt-tc002`, der Datenordner `MQTT-TC002` und der
Befehl `mqtttc002` behalten ihren Namen — daran hängen Identität, Freigaben und
vorhandene Bestände.

## Voraussetzungen

- **Uhr:** Ulanzi **TC002** (Display 52×16) oder **TC001** (32×8) mit AWTRIX NG.
  AWTRIX NG ist die einzige unterstützte Firmware; die Werksfirmware der Uhr
  wird nicht mehr bedient. Die Beschreibung der Schnittstelle, wie sie sich am
  Gerät zeigt, steht in [`docs/awtrix-ng-protokoll.md`](docs/awtrix-ng-protokoll.md). Was je Modell
  geht, steht in [`docs/funktionen-je-uhr.md`](docs/funktionen-je-uhr.md).
- **Netz:** Die Uhr muss im selben Netz erreichbar sein. Über HTTP genügt ihre
  Adresse; für MQTT braucht es zusätzlich einen Broker, auf den die Uhr hört.
- **System:** macOS 14, iOS 17 (iPhone und iPad) oder neuer. Es gibt keine externen
  Paketabhängigkeiten.
- **Ohne Uhr** lässt sich alles in der App mit der eingebauten virtuellen Uhr
  ausprobieren (siehe unten).

## Was die App kann

- **Senden:** Text mit Icon (auf die Tinte zugeschnitten, Abstand Icon–Text je Uhr, Icon fest, einmal oder mit mitscrollend, bis zu vier Zusatzicons an beliebiger Stelle), Schrift, Größe, Farbe, Rand, Abstand und Ausrichtung.
  Soll ein Icon nicht zugeschnitten werden (z. B. weil der freie Rand gewollt ist), füllt man den Hintergrund des Icons mit #000001 statt mit Schwarz oder Transparenz: Das sieht auf der Uhr schwarz aus, zählt aber als Farbe und hält den Rand.
  Die App rastert den Text selbst und schickt der Uhr Pixel; die Vorschau zeigt
  genau das, was hinausgeht (außer bei „Schrift der Uhr“, wo die Uhr den Text
  mit ihrer eigenen Schrift setzt). Fünf Blöcke zeigen die festen Plätze der Uhr.
  Bilder gehen pixelgenau als GIF in dem Maß, das das Display der Zieluhr hat;
  Bewegtes als animiertes GIF.
- **Favoriten:** „+ Favorit“ hebt alle Einstellungen von „Senden“ unter einem Titel auf; ein Klick (Mac, iPad: Seitenleiste, iPhone: Titelmenü) sendet sie sofort an die gespeicherten Uhren. Bearbeiten, Duplizieren, Umbenennen, Löschen; mit iCloud-Abgleich auf allen Geräten.
- **Darstellung:** Hintergrundfarbe, Effekte, Overlays (Wetter) und Paletten, die
  die Uhr selbst liefert.
- **Anzeigen und Nachrichten:** Über dem Eingabefeld wählt ein Segment „Anzeige | Nachricht“.
  Eine Anzeige liegt auf einem Platz und läuft in der Schleife der Uhr, mit Dauer und
  Lebensdauer (verfällt von selbst oder bleibt). Eine Nachricht unterbricht die Schleife
  einmal und belegt keinen Platz. Unter „Steht …“ wählst du, wie lange sie steht: bis
  du sie zurückziehst (Vorgabe), eine Zahl Sekunden oder eine Zahl Durchläufe. Dazu kann
  sie einen Klang mitbringen (Melodie, MP3, Sprache), einmal oder in Schleife;
  „Nachricht zurückziehen“ nimmt sie wieder weg.
- **Mehrere Uhren:** Die Empfänger sind wählbar je Anzeige, die Betriebsart je Uhr
  (HTTP oder MQTT); die gezeigte Uhr bestimmt Vorschau, Blöcke und Verlauf.
- **Bereich „Uhr“:** alles, was auf der Uhr eingestellt wird, an einer Stelle:
  Live-Bild des Displays, Zustand, Display an/aus, Helligkeit, Overlay jetzt auf der
  Uhr, Moodlight, Anzeiger, Ton und Radio, Neustart, Sicherung in eine Zip-Datei und Zurückspielen, Firmware-Update (Paket von GitHub, nur auf Druck und nach Bestätigung), Tasten und Drehknopf (wo die App
  sie mitliest) — dazu „Vorgaben der Uhr“, die auf der Uhr gespeicherten Einstellungen
  in Gruppen (Anzeigedauer, Schleife, Zeit & Datum …), und das TLS-Zertifikat für
  MQTT. Am iPhone öffnet „Uhr …“ im Titelmenü diesen Bereich als Blatt.
- **Klänge:** eine eigene Sammlung von Melodien und MP3-Dateien, an der die Uhren
  abgeglichen werden (Bereich „Klänge“ neben „Icons“; am iPhone „Klänge …“ im Titelmenü).
- **Einstellungen:** nur „Uhren“ (Name, Adresse, Betriebsart, Modell), „MQTT-Broker“ und
  „Allgemein“. Am Mac stehen sie im Einstellungsfenster (⌘,), am iPad als Bereich.
- **Editor (Mac, iPad):** Icons (8×8, 16×16) und ganze Anzeigen malen, mit
  Animation; Icons lassen sich über eine LaMetric-Nummer nachladen.
- **Kurzbefehle (iPhone, iPad, Mac)** — zwölf Aktionen zum Schicken („Anzeige schicken“,
  „Bild schicken“, „Nachricht senden“ …) und zur Fernbedienung — und **Kommandozeile (Mac)**.
- **Abgleich** der eigenen Bestände über iCloud; Deutsch und Englisch.

Wie man das bedient, steht in der Hilfe im Programm (⌘?).

## Bauen

`./build.sh` schnürt `erzeugt/mac/MQTT-TC002.app`. Wer lieber in Xcode arbeitet,
öffnet `Package.swift`.

Die iOS-Fassung wird aus `project.yml` erzeugt; das Projekt selbst ist nicht
eingecheckt:

```bash
xcodegen generate
open MQTT-TC002-iOS.xcodeproj
```

Ein grüner Bau sagt nichts darüber, ob Schriften, Icons, App-Symbol,
Übersetzungen und die `LICENSE` im Bündel gelandet sind — das prüft
`scripts/buendel-pruefen.sh`.

## Auf der Kommandozeile

Im Mac-Bündel reist ein Werkzeug mit, das dieselbe Einrichtung benutzt wie die
App — Uhren, Betriebsart und Broker kommen aus deren Einstellungen, eingerichtet
wird nur in der App. Einmal verlinken:

```bash
mkdir -p ~/.local/bin
ln -sf /Applications/MQTT-TC002.app/Contents/MacOS/mqtttc002 ~/.local/bin/mqtttc002
```

```bash
mqtttc002 "Kaffee fertig"
mqtttc002 senden "Post da" --icon post --farbe "#FFAA00" --dauer 10
mqtttc002 senden Achtung --an Küche --zentriert --unten
mqtttc002 nachricht "Tür offen" --name tuer   # einmalige Nachricht über der Schleife
mqtttc002 zurueckziehen tuer
mqtttc002 layout kaesten.json                 # Kästen mit je einem Inhalt
mqtttc002 bildschirm                          # das Display der Uhr als Text
mqtttc002 helligkeit 120 ; mqtttc002 moodlight --farbe "#FF8800"
mqtttc002 ton spielen --sprache "Hello"       # Klang, Melodie, Radio
mqtttc002 uhren                               # was eingerichtet ist
mqtttc002 hilfe                               # alle Befehle und Optionen
```

Über MQTT wartet das Werkzeug auf die Antwort der Uhr: Weist sie ab, steht der
Grund auf der Fehlerausgabe, und der Aufruf endet mit 1. `--trocken` zeigt, was
gesendet würde. Beim ersten Lauf fragt macOS einmal, ob das Werkzeug an den
Schlüsselbundeintrag der App darf.

## Ohne Uhr ausprobieren

In den Einstellungen unter „Allgemein“ steht der Schalter **„Virtuelle Uhr“**. Er
startet einen kleinen HTTP-Dienst auf `127.0.0.1:8752`, der die Schnittstelle von
AWTRIX NG spricht und die Anzeigen in einem Fenster mit Geräterahmen zeigt.
„Als Uhr eintragen“ legt sie in der Uhrenliste an, „Ansehen“ öffnet ihr Fenster; ab da sind Abfragen, Senden,
Löschen und der Verlauf wie bei einem Gerät. Sie hört nur auf dem eigenen Rechner
zu und spricht HTTP, kein MQTT.

## Sprachen

Die App gibt es auf Deutsch und Englisch und folgt der Sprache des Systems.
Deutsch ist die Entwicklungssprache: Der deutsche Wortlaut steht im Quelltext und
ist zugleich der Schlüssel. `python3 scripts/texte-sammeln.py --pruefen` meldet
jeden sichtbaren Text ohne Übersetzung. Eine weitere Sprache ist ein Ordner
`Resources/Sprachen/<code>.lproj` mit einer `Localizable.strings`.

## Tests

`swift test` läuft ohne Netz und ohne echtes Gerät: HTTP-Aufrufe laufen gegen
einen `URLProtocol`-Doppelgänger, das Senden über MQTT gegen einen
`NachrichtSendend`-Doppelgänger, und ein Teil der Tests spricht über einen
Port auf `127.0.0.1` mit der virtuellen Uhr. Die erzeugten MQTT-Bytes sind gegen
eine echte Aufzeichnung von `mosquitto_pub` geprüft.

## Lizenz

GPL-3.0, mit einer **zusätzlichen Erlaubnis** für die Verbreitung über einen
Anwendungsvertrieb — siehe [`LIZENZ-AUSNAHME.md`](LIZENZ-AUSNAHME.md). Ohne sie
wäre der App Store ein Lizenzverstoß, auch bei offenem Quelltext.

Quelltext von [PixDeck](https://github.com/cailurus/PixDeck) ist **nicht**
enthalten: Es war eine Referenz über das Verhalten des Geräts, und Tatsachen
über ein Gerät sind nicht urheberrechtlich geschützt. Die drei Pixelschriften
(Micro 5, Silkscreen, Tiny5) stehen unter der SIL Open Font License.
