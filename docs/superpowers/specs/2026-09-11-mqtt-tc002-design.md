# mqtt-tc002 — Design

Native macOS-Fenster-App, die einer Ulanzi TC002 (Pixbar, 52×16 Pixel) Meldungen
schickt: Text mit Farbe, 8×8-Icons, frei gemalte Pixel. Dazu die Verwaltung der
Anzeigen auf dem Geraet und seiner Einstellungen.

Der Weg zur Uhr fuehrt ueber MQTT. Die Geraeteeinstellungen laufen ueber deren
HTTP-Schnittstelle, weil es dafuer kein MQTT-Thema gibt.

## Abgrenzung

Gebaut wird:

- Text mit Farbe an eine benannte Anzeige senden
- 8×8-Icons aus einer mitgelieferten Sammlung, erweiterbar ueber LaMetric-Nummern
- ein Pixel-Editor fuer das ganze 52×16-Feld
- Vorschau vor dem Senden
- Verwaltung der Anzeigen: anlegen, umschalten, loeschen
- Geraeteeinstellungen: Seitenwechsel, Helligkeit, Lautstaerke

Nicht gebaut wird:

- Betrieb aus der Menueleiste
- Zeitsteuerung, wiederkehrende Meldungen, Automatisierung
- mehrere Geraete gleichzeitig — eines, einstellbar
- Abonnieren von MQTT; Rueckmeldungen holt die App per HTTP
- Stichwortsuche in der LaMetric-Galerie: die Schnittstelle antwortet ohne
  Entwicklerschluessel mit 401. Holen ueber die Nummer geht ohne Anmeldung.

## Lizenz

**GPL-3.0.** Aus PixDeck (github.com/cailurus/PixDeck, GPL-3.0) wird Code
uebernommen, insbesondere fuer den Pixel-Editor und die Textvermessung. Die
Lizenzdatei liegt im Repository, die Herkunft steht in der README.

## Aufbau

Swift Package wie beim E-Book-Werkzeug, `build.sh` schnuert das Bundle.

```
Package.swift
Sources/
  TC002Core/            Bibliothek, alles ohne Oberflaeche
    MQTT.swift          CONNECT, CONNACK, PUBLISH — mehr braucht es nicht
    Frame.swift         das JSON-Modell: draw, image, text, duration
    Textraster.swift    Text mit CoreText rastern, Breite messen
    Icons.swift         Sammlung laden, Daten-URI bauen, LaMetric-Abruf
    Device.swift        HTTP: getConfig, setConfig, getMqttStatus, api/custom
    Displays.swift      benannte Anzeigen: anlegen, umschalten, loeschen
  TC002App/             ausfuehrbares Ziel, nur Oberflaeche
Tests/TC002CoreTests/
Icons/                  die 30 mitgelieferten 8×8-Icons plus names.json
build/                  Bauergebnis, ungetrackt
```

## Was ueber das Geraet feststeht

Am 11.09.2026 am laufenden Geraet ermittelt, nicht aus der Herstellerdoku:

| Sache | Wert |
|---|---|
| Praefix | eingestellt `awtrix`, tatsaechlich `awtrix_a86b` — die Firmware haengt ihre Geraetekennung an |
| Anzeigen | `<praefix>/custom/<name>` |
| Umschalten | `<praefix>/switchDiyApp`, Nutzlast ist der Name |
| Loeschen | leere Nachricht auf `<praefix>/custom/<name>` |
| Broker | 192.168.1.10:1883, unverschluesselt, kein anonymer Zugang |
| HTTP | `POST /api/custom?name=<n>`, `/getConfig`, `/setConfig`, `/getMqttStatus` |

### Das Praefix ermittelt die App selbst

Der Stolperstein des ganzen Projekts ist, dass das eingestellte Praefix nicht das
tatsaechliche ist. Die Firmware haengt die **letzten vier Stellen der MAC-Adresse**
an — `aabbccdda86b` wird zu `awtrix_a86b`. Die App muss das niemanden raten lassen:

- `/getMqttConfig` liefert `mqtt_prefix`
- `/getBase` liefert `mac`, `devSn`, `mcuVer`, `appVer`
- daraus setzt die App das Themen-Praefix zusammen und zeigt es an

Damit ist ausgeschlossen, dass Nachrichten ins Leere gehen, weil jemand das Feld
aus der Geraeteoberflaeche abgeschrieben hat.

### Firmware

Die TC002 traegt **zwei** Firmwares, eine im Mikrocontroller (`mcuVer`) und eine
im SoC (`appVer`), mit eigener Aktualisierung von Ulanzi. Alternative Firmware
wie AWTRIX 3 ist auf dieser Hardware kein Thema — sie setzt einen ESP32 voraus,
auf dem alles laeuft. Geprueft am Geraet: V1.0.17 und 1.1.1.

Ein Platzhalter im Praefix macht die Anmeldung unmoeglich: die Uhr meldet beim
Verbinden einen letzten Willen auf dieses Thema an, und ein `#` ist in einem
Thema, auf das gesendet wird, verboten. Der Broker verwirft das Paket, im
Protokoll steht `Invalid input`, ein `CONNECT` erscheint nie.

## Das Frame-JSON

Drei Bestandteile, frei kombinierbar:

```json
{
  "draw":  [{"df": [x, y, breite, hoehe, "#RRGGBB"]}],
  "image": [{"data": "data:image/gif;base64,…", "position": [0, 0]}],
  "text":  [{"content": "TEXT", "fontHeight": 10, "x": 10, "y": 3,
             "color": "#FFFFFF", "align": "left", "valign": "top",
             "rect": [0, 0, 52, 16], "charSpacing": 1}],
  "duration": 5
}
```

`df` ist ein gefuelltes Rechteck; mit Breite und Hoehe 1 ist es ein einzelner
Pixel. `duration` steuert die Standzeit im Durchlauf, nicht das Ablaufen — eine
Anzeige bleibt, bis sie ueberschrieben oder geloescht wird.

Zwei Eigenheiten des Geraets: es **scrollt nicht selbst**, Laufschrift muss Bild
fuer Bild geschickt werden; und sein Font kennt **keine Umlaute** und an Satzzeichen
nur `%`, `.`, `-` und `:` — am Geraet durchprobiert. Kleinbuchstaben gehen dagegen.

## Schrift wird selbst gerastert

Deshalb benutzt die App den `text`-Teil des Geraets **nicht** als Normalfall.
Stattdessen rastert sie den Text selbst mit CoreText in das 52×16-Feld, fasst
jede Zeile zu waagrechten Laeufen zusammen und schickt sie als `df`-Rechtecke.

Das loest drei Probleme auf einmal: die Vorschau ist **exakt**, weil Vorschau und
Sendung aus demselben Raster stammen; Umlaute und Satzzeichen funktionieren
unabhaengig vom Geraetefont, der beides nicht kann; und die Schriftart ist frei
waehlbar.

Am laufenden Geraet belegt: „Grüße!" in Menlo 11 ergibt 40 Pixel Breite, 62
Rechtecke, 1,7 KB Nutzlast — mit Umlauten, die der Geraetefont nicht kann.

Der Weg ueber den geraeteeigenen `text` bleibt als Wahlmoeglichkeit erhalten: er
erzeugt viel kleinere Nachrichten und ist sinnvoll, wenn Groesse zaehlt.

Ein Fallstrick, der beim Bau schon einmal zugeschlagen hat: Quartz zeichnet mit
dem Ursprung unten links, der Bildspeicher beginnt aber oben links. Wer hier
spiegelt, bekommt die Schrift auf dem Kopf.

## Der MQTT-Client

Ein Socket, drei Schritte: `CONNECT` senden, **`CONNACK` lesen**, `PUBLISH` mit
Guetegrad 0, schliessen. Kein Abonnieren, keine Sitzung ueber den Aufruf hinaus.

Das `CONNACK` ist der Grund, warum die App ueberhaupt Fehler melden kann: sein
Rueckgabecode unterscheidet falsches Kennwort (4) von fehlender Berechtigung (5)
und wird in einen deutschen Satz uebersetzt. Die Ablehnung einer einzelnen
Veroeffentlichung bleibt bei Version 3.1.1 stumm — das ist Protokoll, und die
App sagt das dem Nutzer an der Stelle, an der es ihn betrifft.

Jeder Aufruf hat eine Frist. Bleibt das `CONNACK` aus, endet er mit einer
Meldung statt zu haengen.

## Die Oberflaeche

Vier Bereiche in einem Fenster, ueber eine Seitenleiste erreichbar.

**Senden.** Name der Anzeige, Textfeld, Farbwahl, Icon-Auswahl, darunter die
Vorschau, daneben der Senden-Knopf. Das ist der Normalfall und startet ausgewaehlt.

**Malen.** Das 52×16-Feld als anklickbares Raster, Farbpalette, Radierer,
Flaeche leeren. Ziehen malt mehrere Pixel. Gesendet wird als `draw`-Liste, wobei
zusammenhaengende Pixel gleicher Farbe zu Rechtecken zusammengefasst werden —
sonst wird die Nutzlast unnoetig gross.

**Anzeigen.** Liste dessen, was angelegt wurde, mit Umschalten und Loeschen.

**Einstellungen.** Geraet und Broker, Kennwort im Schluesselbund. Darunter die
Geraeteeinstellungen ueber HTTP: Seitenwechsel, Helligkeit, Lautstaerke.
`/setConfig` erwartet die vollstaendige Konfiguration, nicht nur das geaenderte
Feld — die App liest sie deshalb vor jedem Schreiben frisch.

## Die Vorschau, und was sie nicht kann

Das Raster zeigt `draw`-Befehle und Icons **pixelgenau**, denn beides sind echte
Pixeldaten. Text dagegen wird **angenaehert**: die Schriftart des Geraets liegt
uns nicht vor, gezeigt wird die Position und die gemessene Breite mit sechs
Pixeln je Zeichen. Der Nutzen ist nicht die Schoenheit, sondern die Warnung,
wenn der Text nicht ins Feld passt.

## Icons

Die 30 mitgelieferten Icons liegen unter `Icons/` im Repository, 8×8, GIF und
PNG. Daneben eine `names.json` mit Nummer, Name und Kategorie.

Neue holt die App ueber die LaMetric-Nummer:

- `developer.lametric.com/content/apps/icon_thumbs/<nummer>` liefert das Bild
- `developer.lametric.com/api/v1/dev/preloadicons?icon_id=<nummer>` liefert Name
  und Kategorie

Beides ohne Anmeldung. Das Bild wird als `<nummer>.gif` abgelegt, der Name in
`names.json` ergaenzt. Zum Senden wird die Datei als Daten-URI kodiert.

## Fehlerbehandlung

- Broker nicht erreichbar, Frist abgelaufen, `CONNACK` mit Fehlercode: jeweils
  ein deutscher Satz, der sagt, was zu tun ist.
- Geraet ueber HTTP nicht erreichbar: die Geraeteeinstellungen werden gesperrt,
  das Senden ueber MQTT bleibt moeglich.
- Fehlendes oder unlesbares Icon: die Sammlung laedt trotzdem, der Eintrag fehlt
  mit Hinweis.
- Kein roher Systemfehlertext in der Oberflaeche.

## Geprueft wird

Der Kern, mit XCTest:

- **MQTT-Pakete Byte fuer Byte** gegen eine Aufzeichnung von `mosquitto_pub` am
  echten Broker. Das ist der wichtigste Test des Projekts: er faengt genau die
  Fehlerklasse, die uns heute Stunden gekostet hat.
- Frame-JSON gegen erwartete Zeichenketten, inklusive der drei Bestandteile.
- Textvermessung: Breite, Umbruchentscheidung, Umlaute und Satzzeichen, die der
  Geraetefont nicht kennt.
- Zusammenfassen benachbarter Pixel zu Rechtecken: gleiche Bildwirkung, weniger
  Bytes.
- Icons: Daten-URI, fehlende Datei, Ablage einer geholten Nummer.
- Geraetekonfiguration: Lesen, ein Feld aendern, vollstaendig zurueckschreiben —
  gegen einen HTTP-Doppelgaenger, nicht gegen das echte Geraet.

Ende-zu-Ende von Hand gegen die echte Uhr, je einmal: Text, Icon mit Text,
gemaltes Bild, Loeschen, Umschalten, Seitenwechsel aendern.

## Offene Punkte

Diese drei sind nicht geklaert und werden waehrend der Umsetzung am Geraet
beantwortet, nicht vorher geraten:

1. Spielt das Geraet **animierte** GIFs ab, oder zeigt es nur das erste Bild?
   Mindestens ein mitgeliefertes Icon ist animiert.
2. Wirkt `switchDiyApp` nur, wenn die Anzeige auf dem Geraet in der DIY-Liste
   aktiviert ist? Im Versuch blieb es wirkungslos.
3. Wie verhaelt sich `duration` im Zusammenspiel mit `carouselSpeed`?
