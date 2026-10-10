# AWTRIX NG fernsteuern

*[English version](en/awtrix-ng-protocol.md)*

Was eine Ulanzi TC002 oder TC001 mit der Firmware **AWTRIX NG 1.2.2** kann und
wie man sie anspricht — über MQTT und über HTTP. Diese Beschreibung ist von unserer App
unabhängig: sie gilt genauso für `mosquitto_pub`, Node-RED, Home Assistant oder
ein eigenes Skript.

Jede Angabe trägt ihre Herkunft:

| Zeichen | Bedeutung |
|---|---|
| 📄 | aus der [AWTRIX-NG-Dokumentation](https://blueforcer.github.io/awtrix-ng/tc002/) (TC002-Zweig), nicht am Gerät gegengeprüft |
| 🔬 | an einem Gerät selbst gelesen |
| ❓ | offen — steht in der Doku nicht, oder nicht gemessen |

**Die Doku-Angaben beziehen sich auf den Stand des TC002-Zweigs vom
09.10.2026 (Fassung 1.2.2)**, die Messungen auf **zwei Geräte**, beide mit
**AWTRIX NG 1.2.2**, per HTTP gemessen am 09.10.2026:

| Gerät | Anzeige | Plattform |
|---|---|---|
| Ulanzi **TC002** | 52 × 16 | Linux (`boardType tc002`, `soc armv7l`) |
| Ulanzi **TC001** | 32 × 8 | ESP32 |

Was hier 🔬 trägt, gilt zunächst für das genannte Gerät und diesen einen Bau —
steht keines dabei, ist es die TC002; was 📄 trägt, für die Firmware im
Allgemeinen. Die Fähigkeiten der beiden unterscheiden sich (`layout`,
`enlargeApps`; siehe §1.1, §5.3, §9). **MQTT ist an diesem Gerät noch nicht
gemessen** — alles zu MQTT ist 📄. 🔬-Angaben „gemessen an 1.1.0/TC001“ stammen
von einer früheren Firmware auf einem 32×8-Gerät und sind nicht neu bestätigt.

---

## 1. Das Display

📄 **Die TC002 hat ein festes Raster von 52 × 16 Pixeln** (832 Pixel); Größe und
Panelbreite sind nicht einstellbar. Der Ursprung liegt oben links, `x` zählt
Spalten ab 0, `y` Zeilen ab 0; unten rechts ist (51, 15). Was außerhalb liegt,
wird still abgeschnitten, nie umgebrochen und nie ein Fehler.

🔬 `GET /api/v1/capabilities` meldet `display`: `width 52`, `height 16`,
`configurable false`, `minWidth`/`maxWidth` 52, `minHeight`/`maxHeight` 16,
`maxPixels 832`, `ready true`, `restartRequired false`. `GET
/api/v1/display/screen` antwortet `width 52`, `height 16` und 832 Pixelwerte.

### 1.1 Vergrößerte Apps (`enlargeApps`)

📄 **Gepushte Anzeigen und Benachrichtigungen werden standardmäßig doppelt
groß gezeichnet:** auf einem Raster von **26 × 8**, jedes Pixel als Quadrat 2×2
(unten rechts (25, 7)). Eine für eine 8-zeilige Uhr geschriebene Anzeige füllt so
das Panel. Die globale Einstellung `enlargeApps` (Vorgabe `true`) schaltet das
ab; die Anzeige nimmt dann das volle 52×16-Raster. Dasselbe passiert, wenn das
Icon größer als 26×8 ist.

📄 **Skripte und Layouts rechnen immer auf dem vollen 52×16-Raster.**

🔬 `enlargeApps` steht am gemessenen Gerät auf `true` (Einstellungen und
`capabilities`).

🔬 **TC001 (ESP32, 32 × 8), 09.10.2026:** Hier gibt es kein `enlargeApps`; `draw`
und `bitmap` direkt in der Anzeige rechnen auf den vollen 32 × 8 Pixeln,
pixelgenau.

🔬 **Die Koordinaten von `draw` gelten bei vergrößerten Apps auf dem
26×8-Raster** (gemessen am 09.10.2026 über `GET /api/v1/display/screen`, mit
`enlargeApps: true`): Jeder Befehl belegt Quadrate 2×2. `["pixel",0,0]` belegt
die Spalten 0…1 und die Zeilen 0…1, `["pixel",51,15]` liegt außerhalb und fällt
weg. In einem `layout` rechnet `draw` dagegen auf dem vollen 52×16, relativ zur
`box` der Region. Ohne `enlargeApps` rechnet auch die Anzeige auf 52×16.

❓ Ob dasselbe für `progress` und die Diagramme gilt, ist nicht gemessen.

### 1.2 Der Icon-Bereich

📄 Ein Icon, das schmaler ist als das Panel, belegt links seine Breite plus
`iconGap`; Text, Balken und Diagramme beginnen rechts davon. Beim normalen Raster
sind das 8 Spalten Bild plus 1 Spalte Luft, vergrößert 16 plus 2 (der Text
beginnt bei Spalte 18). Zeichenbefehle ignorieren das Icon und zählen vom linken
Rand. Ein GIF in voller Anzeigebreite (52 bzw. vergrößert 26×8) gilt als
Hintergrund. Einzelheiten §5.3.

### 1.3 Schriften

📄 Standard sind `small` (Vorgabe) und `large`; dazu kommen zehn Matrixschriften
(`matrix-light6`, `matrix-chunky6`, `matrix-chunky6x`, `matrix-light6x`,
`matrix-chunky8`, `matrix-chunky8x`, `matrix-chunky8x6`, `matrix-light8`,
`matrix-light8x`, `matrix-light8x6`). Welche es gibt, steht in
`capabilities.fonts`; das Feld `font` nimmt jeden dieser Namen.

| Schrift | Großbuchstaben | Zeilen | Zeichenbreite | Leerzeichen |
|---|---|---|---|---|
| `small` | 5 px hoch | 1–5 | 4 px | 2 px |
| `large` | 7 px hoch | 0–6, Unterlängen bis Zeile 7 | 4 px | 2 px |

🔬 `capabilities.fonts` führt je Schrift `name`, `ascent`, `descent`,
`lineHeight`: `small` 6/1/7, `large` 6/2/9; alle zehn Matrixschriften haben
`descent 0` und `ascent` = `lineHeight` = 6 (`…6`, `…6x`) bzw. 8 (`…8`, `…8x`,
`…8x6`).

### 1.4 Farben

📄 **Farben** werden in fünf Formen angenommen und in einer zurückgegeben:

| Form | Beispiel | Anmerkung |
|---|---|---|
| `"RRGGBB"` | `"FF8800"` | führendes `#` wahlweise |
| `"RGB"` | `"F80"` | Kurzform, jede Stelle verdoppelt |
| `[r, g, b]` | `[255, 136, 0]` | je Kanal auf 0–255 begrenzt |
| `["HSV", h, s, v]` | `["HSV", 32, 100, 100]` | `h` auf 0–359 umgebrochen, `s`/`v` auf 0–100 |
| gepackte Ganzzahl | `16746496` | `0xRRGGBB` |

Gelesen wird immer `"#RRGGBB"` in Großbuchstaben. Jeder Kanal ist ganzzahlig;
ein Bruchwert wird abgewiesen. `null` bedeutet **erben oder aus**, nicht
schwarz.

📄 **Schlüssel sind durchgehend camelCase**, **Dauern ganzzahlige
Millisekunden** mit `…Ms` am Namen. Die einzige Ausnahme ist das nur lesbare
`uptimeSeconds` in `GET /api/v1/device`.

---

## 2. Das Themen-Präfix

📄 Das Präfix `<P>` ist genau das, was in `mqttPrefix` steht — **unverändert,
ohne Anhang**. Bleibt es leer, tritt die **Geräte-uid** an seine Stelle, also
die zwölfstellige MAC-Adresse in Kleinbuchstaben ohne Doppelpunkte
(`<uid>/cmd/notify`). Die MQTT-Client-Kennung ist ebenfalls die uid.

📄 Zusätzlich veröffentlicht das Gerät sein Präfix unter dem Präfix selbst:
`<P>/state/prefix` trägt `<P>` als blanke Zeichenkette, aufbewahrt.

📄 Themen außerhalb von `<P>/` werden nicht gelesen.

📄 `mqttPrefix` wirkt erst nach einem Neustart (Spalte „Neustart“ der
Systemkonfiguration, §11).

🔬 Gemessen an 1.1.0/TC001: Das Präfix darf mehrere Themenebenen enthalten
(ein Schrägstrich darin wurde so ins Geräteprotokoll übernommen, `GET
/api/v1/logs`: `mqtt: broker <Broker>:1883, prefix <Präfix>`).

🔬 Gemessen an 1.1.0/TC001: **Ein Leerzeichen am Rand zählt mit — und ist
nirgends zu sehen.** Ein abschließendes Leerzeichen im `mqttPrefix` führte das
Geräteprotokoll als Teil des Präfixes mit, und das Gerät abonnierte entsprechend
`<Präfix> /cmd/#`. Wer das Präfix in einer Oberfläche abliest, sieht den Wert
ohne Leerzeichen und schreibt auf ein Thema, das kein Gerät abonniert — NG
antwortet darauf gar nicht. Die Firmware nahm den Wert wörtlich.

🔬 Gemessen an 1.1.0/TC001: Ein per `PATCH`/`PUT` geändertes `mqttPrefix` griff
erst beim nächsten Verbindungsaufbau; die laufende Sitzung führte das alte
Präfix weiter.

🔬 **Ein Platzhalter im Präfix verhindert den MQTT-Client — still.** Stand in
`mqttPrefix` ein `#` (Form `<wort>/#`), kam die Verbindung nie zustande: im
Geräteprotokoll wiederholt `failed (timeout, state -4)`, in `GET
/api/v1/device` `mqtt.state offline`, `error timeout`, `connects 0`. Keine
Meldung zeigt auf das Präfix, andere Zugangsdaten änderten nichts. Nach dem
Leeren des Präfixes verband sich das Gerät sofort (`state connected`). NG prüft
`mqttPrefix` also nicht auf Platzhalter, und die Folge ist ein Verbindungsfehler
ohne Hinweis auf die Ursache. Die Doku nennt weder Zeichenvorrat noch Bereich
(📄). ❓ Ob `+` ebenso wirkt, ist nicht gemessen.

---

## 3. Die MQTT-Themen

📄 Das Gerät verbindet sich mit **einem** Broker. **QoS 0 überall** — für
Veröffentlichungen, Abonnements und das Last Will; eine unterwegs verlorene
Nachricht ist still verloren. Die Nutzlast eines Kommandos ist **byteweise
dieselbe** wie der Rumpf der entsprechenden HTTP-Anfrage. Die Themen in den
Beispielen sind mit dem Präfix `<P>` geschrieben.

### 3.1 Die Verbindung

| Schlüssel | Typ | Vorgabe | Bedeutung |
|---|---|---|---|
| `mqttEnabled` | bool | `false` | Hauptschalter; `true` braucht ein nicht leeres `mqttHost` (sonst 422) |
| `mqttHost` | string | `""` | Broker |
| `mqttPort` | int | `1883` | 1–65535 |
| `mqttUser` / `mqttPass` | string | `""` | beide leer = anonym; `mqttPass` ist ein Geheimnis |
| `mqttTls` | bool | `false` | Verbindung über TLS, üblich Port 8883 (§11.1) |
| `mqttTlsPin` | string | `""` | SHA-256 des vertrauten Brokerzertifikats, 64 Hexziffern in Kleinbuchstaben |
| `mqttPrefix` | string | `""` | Themen-Präfix `<P>`; leer → uid |
| `haDiscovery` | bool | `false` | Home-Assistant-Dokument veröffentlichen |
| `haPrefix` | string | `"homeassistant"` | dessen Präfix; leer = `homeassistant` |

Diese Schlüssel stehen in der **Systemkonfiguration** (`/api/v1/system`, §11),
nicht in den Anzeigeeinstellungen.

📄 Ein gescheiterter Verbindungsversuch wird nach 5 s wiederholt, dann 10, 20,
40 und höchstens alle 60 s, jede Wartezeit um bis zu 20 % verkürzt. Eine
geglückte Verbindung setzt den Plan zurück. Den Stand zeigt `mqtt` in `GET
/api/v1/device` (§7.1).

### 3.2 Kommandos — nur unter `<P>/cmd/`

📄 Alles unter `<P>/state/` und `<P>/event/` ist ausgehend. `<P>/cmd` und
`<P>/cmd/` für sich treffen nichts.

| Thema | Nutzlast | HTTP-Gegenstück |
|---|---|---|
| `cmd/notify` | Benachrichtigungs-JSON | `POST /api/v1/notifications` |
| `cmd/notify/dismiss` | wird ignoriert | `DELETE /api/v1/notifications/active` |
| `cmd/notify/dismiss/<name>` | wird ignoriert | `DELETE /api/v1/notifications/{name}` |
| `cmd/apps/pushed/<name>` | Anzeigen-JSON; **leer oder `{}` löscht** | `PUT /api/v1/apps/pushed/{name}` bzw. `DELETE /api/v1/apps/{name}` |
| `cmd/apps/switch` | blanker Name **oder** `{"name":…,"fast":bool}` | `PUT /api/v1/apps/active` |
| `cmd/apps/next` · `cmd/apps/previous` | wird ignoriert | `POST /api/v1/apps/next` bzw. `/previous` |
| `cmd/apps/order` | `{"order":[…],"disabled":[…]}` — `disabled` ist Pflicht, `order` wahlweise | `PUT /api/v1/apps/order` |
| `cmd/apps/<name>/enabled` | `true` oder `false` | `PUT /api/v1/apps/{name}/enabled` |
| `cmd/settings` | Teilmenge der Einstellungen | `PATCH /api/v1/settings` |
| `cmd/settings/reset` | wird ignoriert; löscht die gespeicherten Einstellungen, Neustart | `POST /api/v1/settings/reset` |
| `cmd/display` | `{"power":bool?,"overlay":string\|null?}` | `PATCH /api/v1/display` |
| `cmd/display/moodlight` | Moodlight-JSON; **leer = aus** | `PUT` / `DELETE /api/v1/display/moodlight` |
| `cmd/indicators/1` · `/2` · `/3` | `{"color","blinkMs","fadeMs"}`; leer oder `{}` = zurücksetzen (aus) | `PUT` / `DELETE /api/v1/indicators/{id}` |
| `cmd/audio/play` | ein Klangobjekt oder eine Liste (1–4), §3.2.1 | `POST /api/v1/audio/play` |
| `cmd/audio/stop` | wahlweise `{"group":"alert"\|"app"\|"radio"}`; leer = alles | `POST /api/v1/audio/stop` |
| `cmd/audio/stations` | `{"stations":[…]}` | `PUT /api/v1/audio/stations` |
| `cmd/device/reboot` | wird ignoriert | `POST /api/v1/device/reboot` |
| `cmd/device/sleep` | `{"durationMs":ms}`, `> 0` | `POST /api/v1/device/sleep` |
| `cmd/screen/get` | wird ignoriert | veröffentlicht `<P>/state/screen` |
| `cmd/voice/start` | wird ignoriert; startet Home Assistant Voice | keines |

📄 Der **Werkszustand ist nicht über MQTT erreichbar** — nur
`POST /api/v1/device/factory-reset`. Eine Veröffentlichung dorthin tut nichts
und antwortet nichts.

📄 Der Name in `cmd/apps/pushed/<name>` ist der Rest des Themas hinter
`apps/pushed/` und muss `[A-Za-z0-9_-]{1,32}` erfüllen (sonst `invalidName` im
`/result`). `cmd/apps/pushed/` mit leerem Namen trifft nichts.

📄 Die Kennziffer in `cmd/indicators/<id>` muss ein **einzelnes Zeichen** `1`,
`2` oder `3` sein. Alles andere trifft keine Route — und wird damit still
verworfen, während die HTTP-Route an derselben Stelle `404` antwortet.

📄 `cmd/voice/start` antwortet `unavailable` („voice not ready“), wenn Voice
aus, nicht verbunden, beschäftigt oder noch im Start ist. Die Kommandos
`settings/reset` und `device/reboot` starten neu; ihre `/result`-Antwort kann
ausbleiben.

📄 **Indikatoren:** `color` schaltet ein; `0` oder `null` schaltet aus, behält
aber die gespeicherte Farbe. `blinkMs` und `fadeMs` 0–65535; fehlende gelten als
0, jede Anfrage setzt Blinken und Blenden neu.

#### 3.2.1 `audio/play`

📄 Ein Klang hat **genau einen** der Schlüssel:

| Schlüssel | Wert | Spielt |
|---|---|---|
| `file` | gespeicherter Name, `Skript/name` oder `http(s)://`-Adresse | MP3 oder Melodie |
| `rtttl` | RTTTL-Text, höchstens 512 Zeichen | Melodie aus der Nutzlast |
| `song` | Song-Text | Synthesizer |
| `speech` | 1–512 Byte | gesprochener Text (nur mit Stimme) |
| `station` | Name, Listenposition ab 0 oder Stream-Adresse | Internetradio |
| `loop` | bool | wiederholt bis Stopp oder Ersatz; **nicht** mit `station` |

Eine blanke Zeichenkette `"ding"` ist `{"file":"ding"}`. Ein Name ohne
Schrägstrich wird zuerst als `/MP3/<name>.mp3`, dann als
`/MELODIES/<name>.txt` gesucht; mit Schrägstrich nur im Ordner des Skripts.
Eine Liste mit 1–4 Klängen spielt den ersten, den das Gerät spielen kann.
Fehler: `422` bei zwei Schlüsseln, `.mp3`/`.txt` im Namen oder unlesbarer
Melodie, `404` für fehlende Datei, `503 unavailable` ohne passende Hardware.

📄 `audio/stop`: `alert` hält den laufenden Alarm an (Benachrichtigungsklang,
Wiedergabe über `audio/play`, Startklang, Voice-Antwort), `app` die Skriptklänge,
`radio` das Radio; jeder andere Wert ist abgewiesen.

### 3.3 Drei Fallen, die still zuschnappen

📄 **Eine Nachricht über 8192 Byte, Thema eingerechnet, wird verworfen — kein
Fehler, keine `/result`-Antwort.** Über HTTP wäre die Grenze 2 MiB (§8); über
MQTT gibt es kein Anzeichen. Das trifft vor allem Benachrichtigungen mit
Bildern, Layouts oder langem Song-Text.

📄 **Ein Thema, das keine Route trifft, erzeugt gar keine Antwort** — keinen
Fehler, keine Bestätigung. **Tippfehler sind damit unsichtbar.** Wenn ein
Kommando spurlos zu verschwinden scheint, ist die Schreibweise des Themas das
erste, was zu prüfen ist.

📄 Ein `/result`-Thema wird nie selbst als Kommando gelesen; wer `…/result`
abonniert, hört nur Antworten.

### 3.4 Die Antwort auf `<Thema>/result`

📄 Jedes Kommando, das **eine Route trifft**, wird auf `<cmd-Thema>/result`
beantwortet, nicht aufbewahrt, QoS 0:

```
awtrixNG/cmd/settings        ->  awtrixNG/cmd/settings/result
awtrixNG/cmd/apps/pushed/x   ->  awtrixNG/cmd/apps/pushed/x/result
```

Erfolg ist genau `{"ok":true}`. Ein Fehlschlag trägt denselben Fehlerrumpf wie
HTTP, in `ok:false` gewickelt (`field` fehlt, wenn es leer wäre):

```json
{"ok":false,"error":{"code":"validationFailed","message":"invalid value","field":"brightness"}}
```

Über MQTT erscheinen nur diese Codes: `invalidJson` (`invalid JSON`),
`validationFailed` (der Grund oder `invalid value`), `notFound` (`not found`),
`insufficientStorage` (`storage full`), `unavailable` (z. B. `no audio output`),
`internalError` (`command failed`) und `invalidName` (nur
`cmd/apps/pushed/{name}`, `invalid name`). Die Rahmencodes von HTTP (§12) haben
über MQTT kein Gegenstück.

📄 **`<P>/event/error`** (nicht aufbewahrt) trägt `{"source","request","error"}`
für **jedes** abgewiesene Kommando, über MQTT wie über HTTP; `source` ist
`mqtt` oder `http`. Ein Abonnement genügt, um alle Fehlschläge zu sehen.

### 3.5 Zustands- und Ereignisthemen

| Thema | Inhalt | Aufbewahrt | Wann |
|---|---|---|---|
| `<P>/state/device` | Geräte-JSON, Form von `GET /api/v1/device` | ja | alle `statsInterval` (Vorgabe 10 000 ms, mindestens 1 000), sofort bei Wechsel von Panelstrom oder Indikator |
| `<P>/state/settings` | Einstellungs-JSON | ja | bei jeder Änderung und beim Verbinden |
| `<P>/state/apps/active` | Name der laufenden App, **blanke Zeichenkette, kein JSON** | ja | sofort bei Wechsel und beim Verbinden |
| `<P>/state/audio` | Audio-JSON (`radio`, `app`, `alert`, `stations`) | ja | bei Wechsel von Radio, App- oder Alarmklang, beim Verbinden |
| `<P>/state/capabilities` | Fähigkeiten-JSON (Effekte, Übergänge, Paletten …) | ja | einmal je Verbindung |
| `<P>/state/prefix` | `<P>` selbst, blanke Zeichenkette | ja | einmal je Verbindung |
| `<P>/state/buttons/left` · `/select` · `/right` · `/knob` | `"1"` / `"0"` | nein | bei jeder Flanke und beim Verbinden |
| `<P>/event/knob` | `{"turn":N}`, positiv = im Uhrzeigersinn | nein | beim Drehen; schnelles Drehen kann Rasten bündeln |
| `<P>/event/error` | `{"source","request","error"}` | nein | bei jedem abgewiesenen Kommando |
| `<P>/state/screen` | `{"width":W,"height":H,"pixels":[…]}` | nein | nur als Antwort auf `cmd/screen/get` |
| `<P>/availability` | `online` / `offline` | ja | beim Verbinden bzw. als Last Will |

📄 Beim Verbinden sendet das Gerät den aktuellen Tastenstand und räumt
aufbewahrte Nachrichten auf den Tastenthemen weg.

📄 `statsInterval` ist die **langsamste** Taktung von `state/device`, nicht die
einzige Auslösung. Aufeinanderfolgende ereignisgetriebene Veröffentlichungen
liegen mindestens 250 ms auseinander. `state/settings` und `state/apps/active`
sind rein ereignisgetrieben.

📄 **Eine Liste aller Anzeigen gibt es über MQTT nicht.** Lesen läuft
ausschließlich über HTTP: `GET`-Routen haben kein MQTT-Gegenstück, das Gerät
schiebt statt dessen seinen Zustand auf die aufbewahrten `state`-Themen.

📄 `<P>/availability` ist als brokerseitiges Last Will bei CONNECT angemeldet
(`offline`, aufbewahrt) und wird bei geglückter Verbindung sofort als `online`
veröffentlicht.

📄 Was das Gerät **an dich** veröffentlicht, hat keine Größengrenze;
`state/device` und `state/screen` gehen heraus, so groß sie sind.

### 3.6 Home Assistant

📄 Bei eingeschaltetem `haDiscovery` wird ein einzelnes aufbewahrtes Dokument
unter `<haPrefix>/device/<uid>/config` veröffentlicht (HA-Geräte-Discovery,
verlangt Home Assistant 2024.11 oder neuer). **Es gibt keinen zweiten
Themenbaum:** Jede Komponente zeigt auf dieselben `<P>/cmd/…`- und
`<P>/state/…`-Themen. Ausschalten veröffentlicht eine leere aufbewahrte
Nutzlast auf dasselbe Thema.

📄 Immer angelegt: Matrix (Licht), drei Indikatoren (Lichter), Übergangseffekt
(Auswahl) und Übergang (Schalter), Tasten für nächste/vorige App und
Benachrichtigung schließen, Sensoren für aktuelle App, Fassung, IP-Adresse,
MQTT-Präfix, WLAN-Stärke, Laufzeit und freien Speicher, drei Tastensensoren,
dazu Laden, Knopf (Taste und Drehereignis) und Lautstärke. Nur mit passender
Hardware: Batterie (Stand, Spannung, schwach), Assist, Radio-, App- und
Alarmlautstärke, Klang stoppen.

---

## 4. Die HTTP-Schnittstelle

📄 Basis ist `http://<ip>` auf **Port 80** (auch über den mDNS-Namen des
Geräts). Die Einstellung `webPort` wird gespeichert, **wirkt aber nicht**.

### 4.1 Was jede Anfrage betrifft

📄 **`Content-Type: application/json` ist Pflicht** bei jeder Anfrage mit
JSON-Rumpf. `PUT` und `PATCH` mit einem anderen Typ werden vor dem Lesen des
Rumpfes mit `415 unsupportedMediaType` abgewiesen („expected
application/json“); ein **fehlender** Kopf wird angenommen und der Rumpf als JSON
gelesen. Ein `POST` wird nicht auf den Typ geprüft. Ausnahmen:
`PUT /api/v1/apps/script/{name}` (Berry-Quelltext, jeder Typ) und
`PUT /api/v1/apps/script-update/{name}` (jeder Typ, Rumpf muss JSON sein);
Dateiaufnahmen haben ihr eigenes Format.

📄 **Ein leerer Rumpf oder `{}` löscht nie etwas.** `PUT
/api/v1/apps/pushed/{name}`, `PUT /api/v1/display/moodlight` und `PUT
/api/v1/indicators/{id}` antworten dann `422 validationFailed` („body
required“); gelöscht wird mit dem passenden `DELETE`. Über MQTT ist es
umgekehrt: dort löscht ein leerer Rumpf.

📄 **Basic-Auth ist ab Werk aus** — die gesamte Schnittstelle steht im LAN
offen. Eingeschaltet wird sie über `authEnabled` (mit hinterlegtem Namen und
Kennwort) und gilt dann in **jedem** Betriebszustand, auch im
Einrichtungsbetrieb. Sie umfasst die Schnittstelle, die Web-Oberfläche und die
statischen Verzeichnisse; fehlende oder falsche Zugangsdaten sind `401` mit
`WWW-Authenticate`.

📄 **Jede fehlschlagende Anfrage** trägt denselben Rumpf:

```json
{ "error": { "code": "validationFailed", "message": "invalid value", "field": "brightness" } }
```

`code` ist maschinenlesbar und stabil — darauf ist zu prüfen, nie auf
`message`, das englische Prosa für Menschen ist und sich ändern darf. `field`
steht nur da, wenn ein bestimmter Eingabeschlüssel den Fehlschlag verursacht
hat. Die einzige Route mit eigener Antwortform ist `POST /api/v1/restore`.

🔬 Am gemessenen Gerät antwortet eine unbekannte Route mit `404` und
`{"error":{"code":"notFound","message":"unknown route"}}`, und `POST
/api/v1/settings` mit `405` und
`{"error":{"code":"methodNotAllowed","message":"allowed: GET, PATCH"}}` — die
erlaubten Methoden stehen in der Meldung. (Gemessen an 1.1.0/TC001 lautete der
Wortlaut `allowed method(s): …`; wer die Meldung parst, hat einen Fehler.)

📄 **Methodenüberschreibung:** Ein `POST` mit `X-HTTP-Method-Override` (`PUT`,
`PATCH` oder `DELETE`, Groß-/Kleinschreibung gleich) wird als die genannte
Methode geprüft, braucht also denselben `Content-Type` wie ein echtes `PATCH`.
Jeder andere Wert ist `400 invalidMethodOverride`. Der Kopf wird bei `/update`,
`/api/v1/files`, `/api/v1/audio/mp3` und `/api/v1/restore` ignoriert und erreicht
nicht das `PUT` des Skriptquelltextes.

📄 **Seitenübergreifende Anfragen:** Antworten tragen
`Access-Control-Allow-Origin: *`, ein Vorabflug `OPTIONS` antwortet `204`. Fünf
Routen verweigern Anfragen von fremden Webseiten mit `403 forbiddenOrigin`:
`GET /api/v1/system?secrets=1`, `PUT /api/v1/system`, `POST /api/v1/restore`,
`POST /update`, `POST /api/v1/device/factory-reset`.

📄 **Einrichtungsbetrieb:** Schreibende Anfragen von fremden Rechnern sind
`403 forbidden`; erlaubt sind nur die Einrichtungsseite, Statuslesen, WLAN-
Einrichtung, Neustart und Sicherungsrückspielung. Protokoll, Skripte,
Dateirouten, Geheimnisexport und Firmware sind gesperrt.

### 4.2 Die Routen

**Gerät**

| Route | Wozu |
|---|---|
| `GET /api/v1/device` | Zustand und Statistik (dieselbe Form wie `state/device`) |
| `GET /api/v1/version` · `GET /version` | Fassungsnummer als JSON bzw. als `text/plain` |
| `POST /api/v1/device/reboot` | Neustart (auch im Einrichtungsbetrieb) |
| `POST /api/v1/device/sleep` | Tiefschlaf für `{"durationMs"}`; so im MQTT-Teil der Doku geführt, in der Routenliste der HTTP-Seite nicht gefunden |
| `POST /api/v1/device/factory-reset` | alles löschen, Neustart im Einrichtungsbetrieb |

**Einstellungen**

| Route | Wozu |
|---|---|
| `GET /api/v1/settings` | alle Anzeigeeinstellungen (§10) |
| `PATCH /api/v1/settings` | beliebige Teilmenge; unbekannte Schlüssel abgewiesen; Antwort sind alle Einstellungen |
| `POST /api/v1/settings/reset` | Einstellungen auf Vorgabe, Neustart |

**Anzeige**

| Route | Wozu |
|---|---|
| `GET /api/v1/display` | `power`, `brightness`, `overlay`, `overlaySettings`, `moodlight` |
| `PATCH /api/v1/display` | `power` (bool), `overlay` (Name oder `null`/`""`), `overlaySettings` (`{speed, palette, blend}`); alles oder nichts, Antwort `{"ok":true}` |
| `PUT /api/v1/display/moodlight` | Panel einfarbig fluten: `kelvin` 1000–40000 (gewinnt über `color`), `color`, `brightness` 0–255 (nicht geprüft: 300 wird zu 44, 256 zu 0); fehlende Felder behalten ihren Wert, erstes Mal weiß bei 120 |
| `DELETE /api/v1/display/moodlight` | aus; immer `200` |
| `GET /api/v1/display/screen` | der Bildspeicher: `width`, `height`, `pixels` |

**Apps**

| Route | Wozu |
|---|---|
| `GET /api/v1/apps` | das Inventar in Reihenfolge, §7.2 |
| `PUT /api/v1/apps/active` | umschalten: `{"name","fast"}` (`fast` Vorgabe `false`); ein Rumpf, der nicht mit `{` beginnt, gilt als der Name selbst — kaputtes JSON also als Name und damit `404`, nicht `400`; `503 serviceBusy`, wenn ein Skript auf Abruf nicht starten kann |
| `POST /api/v1/apps/next` · `/previous` | vor- und zurückblättern |
| `PUT /api/v1/apps/order` | `{"order":[…],"disabled":[…]}`; `disabled` ist die vollständige Liste der Abgeschalteten, `order` nur zusammen damit; Doppelte in `order` laufen mehrfach je Runde; `507 applied, not saved yet` heißt: bis zum Neustart aktiv, nicht gespeichert |
| `PUT /api/v1/apps/{name}/enabled` | Rumpf `true`/`false`; eine abgeschaltete App behält ihren Platz; jeder andere Rumpf `422`; 🔬 unbekannter Name: ok, legt nichts an; `true` räumt einen Geistereintrag (`present:false`) weg, §7.2 |
| `PUT /api/v1/apps/pushed/{name}` | Anzeige anlegen oder ersetzen (Objekt oder Feld) |
| `DELETE /api/v1/apps/{name}` | Anzeige löschen; bei eingebauten Apps (`Time`, `Status`) wirkungslos, aber `200` |
| `GET` / `PATCH /api/v1/apps/builtin/{name}/config` | Einstellungen einer eingebauten App |

**Skripte (Berry)**

| Route | Wozu |
|---|---|
| `GET` / `PUT /api/v1/apps/script/{name}` | Quelltext lesen (`text/plain`) bzw. installieren (auch mit Fehlern) |
| `PUT /api/v1/apps/script-update/{name}` | ersetzen nur, wenn der alte Quelltext zu `expected_source` passt (`409 scriptChanged`) |
| `GET` / `PATCH /api/v1/apps/{name}/config` | Einstellungen eines Skripts (`PATCH` startet es neu) |
| `GET` / `PATCH /api/v1/apps/{name}/data` | gespeicherte Daten (`null` entfernt einen Schlüssel) |
| `GET /api/v1/oauth` · `GET`/`POST`/`DELETE /api/v1/oauth/{name}` · `POST …/start` · `POST …/code` | Anmeldung von Skripten bei Diensten |
| `GET` / `POST /api/v1/apps/script/{name}/sounds` · `DELETE …/sounds[/{sound}]` | MP3 eines Skripts (mit SHA-256) |
| `GET /api/v1/scripts/shared` | was Skripte einander veröffentlicht haben |

**Benachrichtigungen und Indikatoren**

| Route | Wozu |
|---|---|
| `POST /api/v1/notifications` | einmalige Meldung über der Schleife |
| `DELETE /api/v1/notifications/active` | die sichtbare wegnehmen; immer `200`, auch wenn keine zu sehen ist; die nächste der Warteschlange erscheint sofort |
| `DELETE /api/v1/notifications/{name}` | die benannte wegnehmen, auch wartend (`404`, wenn keine so heißt); `active` ist als Name reserviert |
| `PUT /api/v1/indicators/{id}` | `{"color","blinkMs","fadeMs"}`; `id` 1–3 von oben nach unten, sonst `404` („id must be 1..3“) |
| `DELETE /api/v1/indicators/{id}` | zurücksetzen und ausschalten; immer `200` |

**Klang**

| Route | Wozu |
|---|---|
| `GET /api/v1/audio` | Wiedergabezustand (`radio`, `app`, `alert`) und Senderliste |
| `POST /api/v1/audio/play` · `/stop` | abspielen (§3.2.1), anhalten (`{"group"}`) |
| `POST /api/v1/audio/clip` | eine aufgenommene WAV- oder MP3-Datei einmal abspielen, nicht gespeichert; roher Rumpf bis 2 MiB |
| `GET` / `PUT` / `DELETE /api/v1/audio/melodies[/{name}]` | Melodien; `PUT {"rtttl":…}` → `201` neu, `200` ersetzt |
| `GET` / `POST` / `DELETE /api/v1/audio/mp3[/{name}]` · `POST …/mp3/rename` | MP3-Dateien (`multipart`-Feld `file`), umbenennen mit `{"from","to"}` |
| `GET` / `PUT /api/v1/audio/stations` | Senderliste lesen bzw. ganz ersetzen (`{"stations":[…]}` oder blankes Feld, höchstens 32) |

**Fähigkeiten, System, Dateien**

| Route | Wozu |
|---|---|
| `GET /api/v1/capabilities` | die Namenslisten und Grenzen dieses Baus — abzufragen, statt Namen fest einzutragen (§7.4) |
| `GET /api/v1/system` | Systemkonfiguration (§11); mit `?secrets=1` auch die Geheimnisse |
| `PUT /api/v1/system` | teilweises Zusammenführen, alles geprüft |
| `GET /api/v1/system/wifi-scan` | WLAN-Suche, asynchron: `202` während der Suche, dann `200` mit Ergebnissen |
| `GET /api/v1/logs` | Geräteprotokoll, `?after=N` für Fortsetzung |
| `GET /api/v1/mqtt/tls` · `PUT`/`DELETE /api/v1/mqtt/tls/ca` | Vertrauensstand des Brokers; eigene CA hochladen (`{"certificate":PEM}`, höchstens 65536 Byte) bzw. löschen |
| `GET` / `POST /api/v1/voice` | Home Assistant Voice (`POST` braucht Kopf `X-Awtrix-Voice: 1` und passenden Origin) |
| `GET` / `POST` / `DELETE /api/v1/gamepad[…]` | Bluetooth-Gamepads koppeln, vergessen, Fernsteuerung vom Telefon |
| `GET` / `POST` / `DELETE /api/v1/files` | Dateiablage: `GET ?dir=` (Vorgabe `/ICONS`), `POST` Aufnahme in `ICONS`, `MELODIES`, `PALETTES`, `MP3`, `DELETE ?path=` |
| `POST /api/v1/icons/rename` | Icon umbenennen (`{"from","to"}`, gleiche Endung) |
| `GET`/`PUT`/`DELETE /api/v1/icons/origins` | Herkunftsverweise der Icons zum Hub |
| `POST /update` | Firmware einspielen (`.awup`, `multipart`-Feld `firmware`) |
| `POST /api/v1/restore` | eine Sicherung einspielen (`.zip`, auch im Einrichtungsbetrieb) |
| `GET /`, `/index.html`, `/fullscreen` | Web-Oberfläche (`fullscreen` zeigt nur das Display) |
| `GET /ICONS/*`, `/MELODIES/*`, `/PALETTES/*`, `/MP3/*`, `/SCRIPTS/*`, `/apploop.json` | statische Dateien, **nur `GET`** |

📄 Löschen über `DELETE /api/v1/files` ist auf `/ICONS`, `/MELODIES`,
`/PALETTES` und `/MP3` beschränkt; `DELETE` dort braucht eine echte
`DELETE`-Methode (keine Überschreibung).

🔬 Gemessen, `GET` ohne Besonderheiten: `/api/v1/version` →
`{"version":"1.2.2"}`; `/api/v1/files` → `{"files":[],"usedBytes":2579,
"totalBytes":6908435}`; `/api/v1/icons/origins` → `{"icons":[]}`;
`/api/v1/audio/stations` → `{"stations":[{"name","url"}]}`;
`/api/v1/mqtt/tls` → `{"ca":"public","pending":null}`;
`/api/v1/scripts/shared` → `[]`; `/api/v1/audio/melodies` →
`{"melodies":[],"usedBytes":…,"totalBytes":…}`; `/api/v1/audio/mp3` →
`{"files":[],"scripts":[],"usedBytes":…,"totalBytes":…}`.

---

## 5. Die Nutzlast einer Anzeige

📄 Dieselbe Form gilt für `PUT /api/v1/apps/pushed/{name}` und
`POST /api/v1/notifications` — und damit auch für `cmd/apps/pushed/<name>` und
`cmd/notify`. **Jeder oberste Schlüssel, der unten nicht steht, ist ein Fehler**
(`422 validationFailed`, `field` = der Schlüssel). Eine Nutzlast wird ganz
angewandt oder gar nicht.

📄 **Der Name einer Anzeige kommt aus dem Pfad, nie aus dem Rumpf.** Er muss
`[A-Za-z0-9_-]{1,32}` erfüllen und wird geprüft, bevor die Nutzlast gelesen
wird; ein falscher oder reservierter Name ist `400 invalidName`.

📄 Eine Anzeige liegt **im RAM**, bis sie ersetzt, gelöscht, von `lifetimeMs`
eingezogen wird oder das Gerät neu startet; danach muss der Absender sie neu
schicken. Eine neue Anzeige reiht sich ans Ende der Schleife ein; zum sofortigen
Zeigen folgt `PUT /api/v1/apps/active`. Ersetzen behält den Platz in der Schleife,
und bei unverändertem Text läuft die Laufschrift nicht neu an.

📄 **Falsche Typen bei Zahl, bool, `text`, `icon`, `effect`, `overlay` und
`name` sind kein Fehler:** Der Wert wird übergangen und die Vorgabe bleibt
(`"durationMs":"5000"` ergibt `200` und die Standardzeit).

### 5.1 Text

| Schlüssel | Typ | Bereich | Vorgabe | Bedeutung |
|---|---|---|---|---|
| `text` | string \| Feld | — | `""` | der Text, oder ein Feld eingefärbter Teile |
| `textCase` | string | `inherit` · `upper` · `asTyped` | `inherit` | Schreibweise; `inherit` folgt der globalen Einstellung `uppercase` |
| `font` | string | `small` · `large` · ein Name aus `capabilities.fonts` | `small` | die Schrift (§1.3) |
| `textColor` | Farbe \| `"palette"` | — | globales `textColor` (`#FFFFFF`) | Textfarbe, oder aus der Palette der Anzeige malen |
| `textBlinkMs` | int | ms, 0 = aus | `0` | Blinkdauer: erste Hälfte jeder Periode schwarz, zweite gefärbt |
| `textFadeMs` | int | ms, 0 = aus | `0` | sinusförmige Auf- und Abblendung je Periode |
| `textAlign` | string | `start` · `center` · `end` | `center` | Ausrichtung ruhenden Textes; nur wenn der Text nicht läuft |
| `scroll` | Objekt \| string | siehe 5.2 | geerbt | Textbewegung; eine blanke Zeichenkette setzt nur `mode` |
| `textOffsetX` | int | px | `0` | Verschiebung; bei laufendem Text verschiebt sie jeden Ankerpunkt |
| `textInFront` | bool | — | `false` | nur Zeichenreihenfolge |

📄 **Die Grundlinie ist fest;** eine senkrechte Steuerung des `text`-Schlüssels
gibt es nicht (für freie Platzierung: `draw` oder ein Layout, §9).
`textInFront` setzt nur die Reihenfolge: `true` malt erst die Dekoration
(Zeichenbefehle, Fortschrittsbalken, Diagramme) und den Text darüber, die
Vorgabe `false` umgekehrt.

📄 Ruhender Text steht mittig in dem Raum rechts der Icon-Spalte (oder auf dem
ganzen Panel, wenn kein Icon da ist); über das Icon läuft Text nie. Laufender
Text ignoriert `textAlign`. `textOffsetX` wirkt in beiden Fällen.

📄 `text` ist UTF-8. **Alle Schriften haben denselben Zeichenvorrat:** Akzente
west- und mitteleuropäischer Sprachen, Vietnamesisch, Griechisch, Kyrillisch,
IPA-Zeichen, `°`, `€` und andere Währungszeichen, dazu chinesische und
koreanische Zeichen für Datum und Wochentag (am besten in `large` und den
8-Pixel-Schriften). Ein Zeichen ohne Abbildung — ein Emoji — wird zu **genau
einem `?`** je Zeichen. Ein Schriftwechsel macht also nie aus einem Buchstaben
ein `?`. Die Großschreibung (`uppercase`, `textCase: upper`) geht über ASCII
hinaus und behält Akzente. Eine Zahl oder ein bool als `text` wird übergangen.

🔬 Am gemessenen Gerät steht die globale Einstellung `uppercase` auf `true`.

📄 **Eingefärbte Teile:** Statt einer Zeichenkette nimmt `text` ein Feld von
`{"text": string, "color": Farbe}`. Die Teile werden von links nach rechts
gezeichnet, jedes um seine eigene Breite vorrückend. Fehlt `text` oder ist es
keine Zeichenkette, wird es `""`; ein Teil ohne `color` ist weiß. Bei einem
Teilefeld wird das oberste `textColor` übergangen — außer es steht auf
`"palette"`, was den ganzen Lauf aus der Palette malt und die Teilfarben
übergeht.

📄 **Welche Farbgebung gewinnt**, in dieser Reihenfolge geprüft:

| Rang | Bedingung | Ergebnis |
|---|---|---|
| 1 | `textColor: "palette"` bei gesetzter `palette` | Verlauf über den Text; `textBlinkMs`/`textFadeMs` **werden übergangen** |
| 2 | `textFadeMs > 0` | weiches Pulsen der aufgelösten Farbe |
| 3 | `textBlinkMs > 0` | Blinken der aufgelösten Farbe |
| 4 | — | `textColor`, sonst das globale `textColor` |

### 5.2 Laufschrift

📄 Text läuft **nur, wenn er nicht passt** (oder `whenFits: "scroll"`). Bei
vergrößerten Apps passen rund sechs Zeichen (neben einem Icon rund vier), mit
`enlargeApps` aus rund dreizehn.

📄 `scroll` nimmt ein Objekt aus sieben unabhängigen Feldern; fehlende kommen
aus der globalen Einstellung `scroll` (§10). Ein ungültiger Wert ist `422` mit
`field` wie `scroll.speed`.

| Feld | Typ | Bereich | Vorgabe | Bedeutung |
|---|---|---|---|---|
| `mode` | string | `static` · `wrap` · `loop` · `bounce` | `wrap` | Bewegungsart |
| `direction` | string | `left` · `right` | `left` | Laufrichtung; `right` spiegelt alle Arten |
| `entry` | string | `inline` · `offscreen` | `inline` | ruhend auf dem Panel beginnen oder von außen einlaufen (ohne Anfangspause) |
| `whenFits` | string | `static` · `scroll` | `static` | ob Text, der ohnehin passt, sich trotzdem bewegt |
| `speed` | int | ≥ 0 | `100` | Prozent der Grundgeschwindigkeit |
| `gap` | int | ≥ 0 | `8` | nur `loop` — Pixel zwischen den Wiederholungen |
| `holdMs` | int | ≥ 0 | `1000` | Pause vor dem Anlaufen und an jedem Wendepunkt von `bounce` |

📄 Die Grundgeschwindigkeit sind rund **21 Pixel je Sekunde**; `speed` ist der
Prozentsatz davon (200 doppelt so schnell, 50 halb so schnell). Ab etwa 200
beginnt der Text zu verschwimmen.

| `mode` | Bewegung |
|---|---|
| `static` | keine; der Text steht an seiner Ausrichtung, Überhang wird rechts abgeschnitten |
| `wrap` | läuft vom Startanker, bis er ganz hinausgelaufen ist, dann Sprung zurück |
| `loop` | fortlaufend; eine frische Kopie schiebt sich `gap` Pixel hinter der letzten nach, das Bild ist nie leer |
| `bounce` | pendelt zwischen Ruhelage und Anschlag am anderen Rand, Pause an beiden Wendepunkten |

📄 `repeat` steht **auf oberster Ebene**, nicht in `scroll` (dort `422`).

### 5.3 Icon

| Schlüssel | Typ | Bereich | Vorgabe | Bedeutung |
|---|---|---|---|---|
| `icon` | string | Kennung, Data-URL oder `http(s)://`-Adresse | `""` | das Bild |
| `iconMode` | string | `fixed` · `pushOnce` · `push` | `fixed` | ob laufender Text das Icon hinausschiebt |
| `iconOffsetX` | int | px | `0` | Verschiebung, nur X; die reservierte Spalte bleibt |
| `iconGap` | int | 0–128, ganzzahlig | `1` | Abstand zwischen Icon und Text (sonst `422`, `field` = `iconGap`) |
| `icons` | Feld | bis 4 Objekte | `[]` | zusätzliche, frei platzierte Icons |

📄 **Die drei Formen von `icon`:**

- **Kennung**, höchstens 64 Zeichen: zuerst `/ICONS/<id>.gif`, dann
  `/ICONS/<id>.jpg`; bei beiden gewinnt das GIF. Groß-/Kleinschreibung zählt. Eine
  Kennung ohne Datei zeigt kein Icon, der Text zentriert über das ganze Panel.
- **Data-URL** `data:image/gif;base64,…` oder `data:image/jpeg;base64,…`. Ein
  nicht passender Inhalt wird nicht gezeigt, **PNG-Data-URLs sind abgewiesen**.
  Reines Base64 ohne Vorsatz oder eine Kennung über 64 Zeichen ist `422`.
- **Webadresse** `http://` oder `https://`, höchstens 2048 Zeichen, ohne
  Leerzeichen; auch PNG, das Format wird am Inhalt erkannt. Das Bild füllt ein
  Quadrat von 16×16, aus der Mitte beschnitten, und bleibt leer, bis es
  geladen ist. Einmal geladen bleibt es im Speicher (Grenzen §8), Weiterleitungen
  werden verfolgt, HTTPS-Zertifikate geprüft (selbstsignierte scheitern);
  Fehlschläge werden nach 30 s, 2 min, dann alle 10 min wiederholt.

📄 **Größen:** Ein JPEG belegt immer 8×8 — ein größeres wird nicht abgewiesen,
gezeigt wird nur seine linke obere Ecke. Ein GIF behält seine eigene Größe bis
zur Anzeigegröße (vergrößert 26×8, sonst 52×16). Dateien und Data-URLs nur JPEG
oder GIF, kein PNG, kein BMP; die Web-Oberfläche wandelt PNG/JPG vor dem Ablegen
in GIF, die API weist PNG mit `415` ab, auch umbenannt.

📄 Ein Icon, das schmaler ist als das Panel, **reserviert seine Breite plus
`iconGap`** (§1.2), die Text, Balken und Liniendiagramm einrückt. Ein GIF in
voller Anzeigebreite gilt statt dessen als **Hintergrund**: es ersetzt
`backgroundColor` und jeden `effect` und rückt nichts ein. Ein fehlendes oder
nicht lesbares Icon fällt auf die Anordnung ohne Icon zurück.

📄 GIFs laufen endlos, die Schleifenzahl der Datei zählt nicht; jedes hat seine
eigenen Bildzeiten (0 wird 100 ms) und seine eigenen Farben. Durchsichtige
Pixel zeigen, was das vorige Bild dort gezeichnet hat; im ersten Bild sind sie
schwarz.

🔬 **Ein GIF als Data-URL im `icon` einer Layout-Region** wird bis 7508 Zeichen
Base64 angenommen und ab 8796 abgewiesen (`422 validationFailed` „invalid
icon“, `field` `layout.regions[0].icon`; gemessen 09.10.2026, NG 1.2.2, TC002,
über HTTP). **Als `icon` der Anzeige direkt** (ohne `layout`) wird ein 52×16-GIF
bis 58 761 Byte (78 348 Zeichen Base64) angenommen und eines von 87 KB
abgewiesen (`field` `icon`). Ein Icon größer als 26×8 schaltet die Anzeige auf
das volle Raster (§1.1): Das GIF landet pixelgenau in 52×16 (eine 1-Pixel-Spalte
über alle 16 Zeilen und das Eckpixel (0,0) stimmen, keine Fremdfarben) und läuft
animiert mit den Bildzeiten der Datei.

🔬 **Pixelgenaue Bilder auf beiden Geräten (09.10.2026, NG 1.2.2, per HTTP):**
Ein GIF als Data-URL im `icon` der Anzeige, **in voller Anzeigegröße**, landet
pixelgenau (Eckpixel exakt) — auf der **TC001 in 32 × 8**, auf der **TC002 in
52 × 16**, dort animiert, sobald es mehrere Bilder hat. Ein einbildriges GIF ist
ein Standbild. Die anderen Wege taugen nicht für beide:

| Weg | TC001 (ESP32, 32 × 8) | TC002 (52 × 16) |
|---|---|---|
| `layout` mit `draw`/`bitmap` | `422 validationFailed` „unknown field“, `field` `layout`: der ESP32 hat keine Layouts (`capabilities.layout` fehlt) | pixelgenau |
| `draw`/`bitmap` direkt in der Anzeige | pixelgenau (kein `enlargeApps`) | 2 × 2 vergrößert, nur 26 × 8 (§1.1) |
| GIF als Data-URL im `icon` der Anzeige, volle Größe | **pixelgenau** | **pixelgenau**, animiert |

Ein GIF, das nicht größer ist als 26 × 8, schaltet die TC002 nicht auf das volle
Raster und wird dort vergrößert gezeichnet; das GIF muss darum genau das
Anzeigemaß der Uhr haben. Über MQTT antwortet die TC001 auf ein `layout` mit
`ok:false` auf `<Thema>/result` (§3.4); ohne Mitlesen dieses Themas bleibt die
Abweisung unsichtbar.

📄 `iconMode`: `fixed` lässt das Icon stehen und den Text daran vorbeilaufen;
`pushOnce` lässt den Text es **einmal** hinausschieben, danach bleibt es weg und
der Text beginnt bei x=0; `push` holt es in jedem Laufdurchgang zurück.

📄 **`icons[]`:** je Element `icon` (Pflicht, nicht leer, Kennung oder Data-URL),
`x` und `y` (−65535…65535, Vorgabe 0); was außerhalb liegt, wird abgeschnitten.
Mehr als 4 Elemente, eine schlechte Koordinate, ein fehlendes `icon` oder ein
unbekannter Schlüssel ist `422` (`field` z. B. `icons[1].x`). `"icons": []`
entfernt die Zusatzicons einer gepushten Anzeige.

### 5.4 Standzeit

| Schlüssel | Typ | Vorgabe | Bedeutung |
|---|---|---|---|
| `durationMs` | long | `0` | wie lange gezeigt wird; 0 oder weniger nimmt das globale `appDurationMs` (7000). Bei `hold`-Benachrichtigungen ignoriert |
| `lifetimeMs` | long | `0` | **nur Anzeigen** — nach dieser Zeit von selbst verfallen; 0 = nie. Benachrichtigungen nehmen den Schlüssel an und ignorieren ihn |
| `lifetimeExpiry` | string | `remove` | `remove` löscht die Anzeige; `mark` behält sie mit einem 1-px-Rahmen in Dunkelrot (`#6E0700`) |
| `repeat` | int | `0` | wie oft laufender Text über das Bild zieht; ignoriert, wenn der Text nicht läuft oder `durationMs` gesetzt ist (Benachrichtigung: dann mindestens so lange wie `durationMs`) |

### 5.5 Hintergrund, Diagramme, Fortschritt, Effekt, Palette, Overlay

| Schlüssel | Typ | Bereich | Vorgabe | Bedeutung |
|---|---|---|---|---|
| `backgroundColor` | Farbe | — | fehlt → schwarz | einfarbige Füllung; bei gesetztem `effect` übergangen |
| `barChart` | Feld von int | höchstens 16 | `[]` | Balkendiagramm; Überzählige fallen weg, Nichtzahlen zählen als 0 |
| `lineChart` | Feld von int | höchstens 16 | `[]` | Liniendiagramm; braucht mindestens 2 Werte |
| `chartAutoscale` | bool | — | `true` | `true`: von Minimum bis Maximum, oben mindestens 1, unten höchstens 0; `false`: fest 0–8, Werte abgeschnitten |
| `chartColor` | Farbe \| `"palette"` | — | die Textfarbe | Balken und Linie |
| `progress` | int | Prozent, unter 0 = aus | `-1` | Füllstand, über 100 zählt als 100; nur in der untersten Zeile |
| `progressColor` | Farbe \| `"palette"` | — | `#00FF00` | gefüllter Teil |
| `progressTrackColor` | Farbe | — | `#FFFFFF` | ungefüllter Teil, immer eine einfache Farbe |
| `effect` | string | Groß-/Kleinschreibung egal | `""` | bewegter Hintergrundeffekt; unbekannt → `422`, `field` = `effect` |
| `effectSpeed` | float | 0.1–10.0 | `1.0` | Tempo von Effekt und Overlay; 0 oder negativ wird 0.1, über 10 wird 10 |
| `palette` | string \| Feld \| null | Name oder 1–16 Stützstellen | fehlt | `null` oder `""` entfernt sie; unbekannt → `422`, `field` = `palette` |
| `paletteBlend` | bool | — | `true` | zwischen den Einträgen überblenden; `false` gibt harte Bänder |
| `paletteSpan` | int | px, 0 = dehnen | `0` | Pixel je vollem Durchlauf beim Malen von Text |
| `paletteSpeed` | float | 0.0–10.0, 0 = stillstehend | `0` | Durchläufe je Sekunde beim Malen von Text |
| `overlay` | string | Groß-/Kleinschreibung egal | `""` | Wetter-Overlay über allem; leer nimmt das globale; das der Anzeige gewinnt |
| `layout` | Objekt | §9 | fehlt | Regionen statt der visuellen Schlüssel |

📄 Balken sind mindestens 1 px breit mit 1 px Lücke und wachsen von der Nulllinie;
negative Werte hängen darunter.

📄 **Paletten:** Ein Name wird zuerst in `/PALETTES/<name>.txt`, dann unter den
eingebauten gesucht (`Cloud`, `Lava`, `Ocean`, `Forest`, `Stripe`, `Party`,
`Heat`, `Rainbow`); eine Datei überstimmt die gleichnamige eingebaute.
Feldformen: 1–16 einfache Farben, gleichmäßig verteilt, oder Objekte
`{"color": Farbe, "pos": 0–100}` mit beiden Schlüsseln — nicht gemischt. Ein
leeres oder längeres Feld ist abgewiesen. Aus der Palette gemalt werden
`textColor` (spaltenweise), `chartColor` (je Balken nach seinem Wert) und
`progressColor` (nach der Position); Effekte und Overlays nutzen sie ebenfalls.

📄 Effekte (19): `Plasma`, `TheaterChase`, `Fade`, `MovingLine`, `BrickBreaker`,
`PingPong`, `Radar`, `Checkerboard`, `Fireworks`, `PlasmaCloud`, `Ripple`,
`Snake`, `Pacifica`, `Matrix`, `SwirlIn`, `SwirlOut`, `LookingEyes`,
`TwinklingStars`, `ColorWaves`; die Palette nutzen alle außer `PingPong`,
`Matrix` und `LookingEyes`. Overlays (6): `rain`, `snow`, `drizzle`, `storm`,
`thunder`, `frost`. Übergänge (22, für `transitionEffect`): `Random`, `Slide`,
`Dim`, `Zoom`, `Rotate`, `Pixelate`, `Curtain`, `Ripple`, `Blink`, `Reload`,
`Fade`, `Cover`, `Uncover`, `Split`, `Blinds`, `Blocks`, `Flash`, `Diamond`,
`Wave`, `Rain`, `Melt`, `Interlace`.

🔬 `GET /api/v1/capabilities` führt am gemessenen Gerät genau diese Listen:
19 Effekte, 16 Paletteneffekte, 22 Übergänge, 6 Overlays, 8 Paletten.

📄 **Mit einem Bild in Anzeigegröße** (§5.3, der Pixelweg der App) gilt: Das GIF
ist der Hintergrund und ersetzt `backgroundColor` und `effect`; ein `overlay`
liegt darüber. Diagramme und Fortschritt gehören darum zu einer Anzeige **ohne**
gerasterten Inhalt: Die App kennt je Anzeige entweder Text/Bild oder
Diagramm/Fortschritt, jeweils mit freiwilligem Hintergrund, Effekt, Overlay und
Palette, und weist `backgroundColor`/`effect` neben einem gerasterten Bild vor
dem Senden ab. Die Namen von Effekt, Overlay und Palette prüft sie gegen die
Listen von `capabilities`, die sie je Uhr bei der Abfrage holt.

### 5.6 Nur für Benachrichtigungen

📄 Diese Schlüssel nimmt **allein** `POST /api/v1/notifications` an; in einer
gepushten Anzeige sind sie `422 validationFailed`:

| Schlüssel | Typ | Vorgabe | Bedeutung |
|---|---|---|---|
| `name` | string | `""` | Bezeichnung zum späteren Wegnehmen über die URL; `active` ist reserviert |
| `hold` | bool | `false` | bleibt, bis sie weggenommen wird; ignoriert `durationMs`; hält die Warteschlange an |
| `stack` | bool | `true` | hinter den bestehenden anstellen; `false` ersetzt die sichtbare (Neustart von Laufschrift, Icon, Klang), wartende bleiben |
| `wakeup` | bool | `false` | auch bei abgeschaltetem Panel zeigen; danach wieder dunkel |
| `sound` | string \| Objekt \| Feld | — | Klang beim Erscheinen, mit Alarmlautstärke |

📄 `sound`: `"ding"` (`/MP3/ding.mp3`, sonst Melodie `/MELODIES/ding.txt`),
`{"file":"Ordner/name"}`, `{"rtttl":"…"}`, `{"speech":"…"}` oder eine Liste von
1–4 davon (der erste spielbare). `""` und `null` sind kein Klang; `"loop":true`
im Objekt wiederholt, bis die Benachrichtigung geht. `station` ist nicht
erlaubt. Ein falsch gebauter Klang ist `422` (`field` = `sound`, `sound.<key>`,
`sound[1].file`), ein nicht gespeicherter oder nicht spielbarer **kein** Fehler —
die Benachrichtigung erscheint stumm.

📄 Die sichtbare Benachrichtigung endet mit ihrer Zeit, auch mitten im Lauf
(außer `repeat` oder `hold`); ein Druck auf die mittlere Taste nimmt sie weg.
Das Wegnehmen einer wartenden berührt die sichtbare nicht.

### 5.7 Felder als Nutzlast

📄 Ein **Feld** an `PUT /api/v1/apps/pushed/{name}` legt durchnummerierte
Anzeigen `<name>0`, `<name>1`, … an — eine je Objekt-Element, keine namens
`<name>`; Elemente, die keine Objekte sind, werden übersprungen, ohne eine
Nummer zu verbrauchen. `DELETE /api/v1/apps/{name}` löscht den genauen Namen
**und** die so entstandenen nummerierten Anzeigen; eine, die man selbst unter
`<name>1` abgelegt hat, ist eine eigene Anzeige und bleibt. Ein Feld gilt ganz
oder gar nicht: Verstößt ein Element gegen eine Regel oder passt der Stapel nicht
unter die Obergrenze, wird die ganze Anfrage abgewiesen und keine einzige
Anzeige angelegt oder geändert.

📄 Ein Feld an `POST /api/v1/notifications` darf **höchstens ein** Element
halten; mehr ist `422 validationFailed`, und nichts wird eingereiht.

### 5.8 Wie die Fehler benannt sind

| Lage | Antwort |
|---|---|
| Rumpf ist kein gültiges JSON | `400 invalidJson` |
| Rumpf über 2 MiB (HTTP) | `413 payloadTooLarge` |
| unbekannter oberster Schlüssel | `422 validationFailed`, `field` = der Schlüssel |
| unlesbare Farbe, an welcher Stelle auch immer | `422 validationFailed`, `field` = der Schlüssel |
| ein Wortschlüssel mit einem Wort außerhalb seiner Liste | `422 validationFailed`, `field` = der Schlüssel |
| unbekannter `effect`- oder `overlay`-Name | `422 validationFailed`, `field` = `effect` / `overlay` |
| ungültiger `palette`-Name oder -Form | `422 validationFailed`, `field` = `palette` |
| ungültiges `scroll`-Feld | `422 validationFailed`, `field` = `scroll.<key>` |
| `iconGap` nicht ganzzahlig 0–128 | `422 validationFailed`, `field` = `iconGap` |
| schlechter `icons[]`-Eintrag | `422 validationFailed`, `field` = `icons[<i>].<key>` |
| falsch gebauter `sound` | `422 validationFailed`, `field` = `sound` / `sound.<key>` |
| unbekannter Zeichenbefehl, kein Feld, falsche Argumentzahl, nicht numerische Koordinate, `pixels` mit ungerader Koordinatenzahl | `422 validationFailed`, `field` = `draw[<i>]` |
| Schlüssel für Benachrichtigungen in einer Anzeige | `422 validationFailed`, `field` = der Schlüssel |
| Schlüssel neben `layout`, die nicht dazu passen | `422`, `field` = der Schlüssel („not allowed with layout“) |

---

## 6. Die Zeichenbefehle

📄 `draw` ist ein **Feld von Feldern**, jedes mit dem Namen des Befehls zuerst.
Gezeichnet wird in der Reihenfolge des Feldes. Es gibt neun Befehle:

| Befehl | Argumente |
|---|---|
| `["pixel", x, y, farbe]` | ein Pixel |
| `["pixels", farbe, x1, y1, x2, y2, …]` | viele Pixel in einer Farbe (gerade Koordinatenzahl) |
| `["line", x1, y1, x2, y2, farbe]` | beide Endpunkte eingeschlossen |
| `["rect", x, y, w, h, farbe]` | Umriss, 1 px |
| `["rectFill", x, y, w, h, farbe]` | gefüllt |
| `["circle", cx, cy, r, farbe]` | Mittelpunkt und Radius |
| `["circleFill", cx, cy, r, farbe]` | gefüllt |
| `["text", x, y, "HI", farbe]` | Text in der `font` der Anzeige |
| `["bitmap", x, y, w, h, daten]` | Bild; genau diese sechs Argumente |

📄 Die abschließende Farbe darf **fehlen**; der Befehl nimmt dann die Textfarbe
der Anzeige. `pixels` trägt seine Farbe **zuerst**, wo `null` dasselbe bedeutet.
Pixel außerhalb fallen weg und werden nie umgebrochen. Ein `w` oder `h` von null
oder weniger zeichnet nichts, ebenso ein negativer Radius; ein Radius `0`
zeichnet den Mittelpunkt. Ein zu kurzes `bitmap` lässt die restlichen Zellen
ungezeichnet, überzählige Einträge werden übergangen.

📄 `bitmap`-Daten kommen in zwei austauschbaren Formen: als **Feld von w × h
Farben**, zeilenweise, in jeder Farbform aus §1.4 — oder als
**Base64-Zeichenkette von w × h × 3 rohen RGB888-Bytes**. Die Base64-Form ist bei
großen Bildern weit kürzer.

📄 Das `text` der Zeichenbefehle ist UTF-8, wird in der `font` der Anzeige
gesetzt und läuft nie; es ist **unbeeinflusst** von `textCase`, `palette`,
`textBlinkMs`, `textFadeMs`, `textAlign` und `uppercase`. Bei `small` ist `y`
die oberste Zeile der Großbuchstaben; `y = 1` fluchtet mit den Zeilen des
`text`-Schlüssels.

📄 Die Zahl der Befehle ist allein durch die 2 MiB (HTTP) bzw. 8192 Byte (MQTT)
begrenzt.

```bash
curl -X PUT http://<ip>/api/v1/apps/pushed/art \
  -H 'Content-Type: application/json' \
  -d '{"draw":[
        ["rect",0,0,26,8,"#202020"],
        ["circleFill",4,4,2,"#F00"],
        ["text",9,1,"HI"]
      ]}'
```

📄 **Die Reihenfolge, in der ein Bild entsteht** (spätere Schichten decken frühere):

1. **Hintergrund** — der Effekt, wenn `effect` auflöst, sonst `backgroundColor`
   oder Schwarz.
2. **Text und Dekoration** — bei `textInFront` erst die Dekoration, dann der
   Text; sonst umgekehrt. Die Dekoration ist immer `draw` → `progress` →
   `barChart` → `lineChart`.
3. **Verfallsmarke** — der dunkelrote Rahmen einer verfallenen Anzeige mit
   `lifetimeExpiry: "mark"`.
4. **Icon** — senkrecht zentriert, bei `iconOffsetX` zuzüglich der Verschiebung
   aus `iconMode`.
5. **Zusatzicons** — `icons[]` in Feldreihenfolge.
6. **Overlay** — das der Anzeige, sonst das globale.

---

## 7. Was das Gerät über sich selbst herausgibt

### 7.1 `GET /api/v1/device` und `<P>/state/device`

🔬 Am gemessenen Gerät:

```json
{"version":"1.2.2","uid":"<uid>","boardType":"tc002","soc":"armv7l",
 "updateImage":"awtrix-ng-tc002.awup","ipAddress":"<ip>","macAddress":"<mac>",
 "hostname":"<hostname>","wifiRssi":-26,"uptimeSeconds":4421,
 "freeHeapBytes":13553664,"minFreeHeapBytes":13488128,
 "scriptingRunning":true,"scriptHeapPool":"system","scriptHeapBudgetBytes":4194304,
 "resetReason":"software","fps":42,"brightness":128,
 "batteryPercent":73,"batteryVoltage":4.03,"lowBattery":false,
 "matrixPower":true,"currentApp":"Time",
 "indicators":[{"on":false,"color":"#000000","blinkMs":0,"fadeMs":0}, …],
 "messageCount":0,
 "wifi":{"enabled":true,"state":"connected","host":"<ssid>","endpoint":"<ip>",
         "attempts":0,"retryInMs":0,"connects":1,"error":null,"lastError":null},
 "mqtt":{"enabled":true,"state":"offline","host":"<Broker>","endpoint":"<Broker>:1883",
         "attempts":85,"retryInMs":35431,"connects":0,"error":"timeout","lastError":"timeout"},
 "mirror":{"sharing":false,"viewers":0,"source":"","state":"off"},
 "usbPower":false,"update":{"state":"idle","release":"","error":""}}
```

Kennungen, Adressen und Namen sind ersetzt; die Zahlenwerte stehen so, wie das
Gerät sie gemeldet hat.

🔬 Gegenüber 1.1.0/TC001 fehlen `lightLevel`, `ldrRaw`, `temperature`,
`humidity` und `batteryPinMillivolts` (kein Lichtsensor, keine Messfühler);
neu sind `macAddress`, `updateImage`, `mirror`, `usbPower` und `update`.

📄 Bedeutung: `uid` zwölf Hexziffern klein; `soc` z. B. `armv7l`;
`resetReason` `poweron`, `software`, `panic` oder `watchdog`; `brightness`
0–255 (der gerade benutzte Wert); `messageCount` die seit dem Start
empfangenen MQTT-Kommandos; `indicators` genau drei Einträge mit `on`, `color`
(`#RRGGBB`), `blinkMs`, `fadeMs` (0–65535). Die Batterieschlüssel
(`batteryVoltage`, `batteryPercent`, `lowBattery`) fehlen ganz, solange das Gerät
keine Batterie meldet; `lowBattery` ist `true` unter `lowBatteryThreshold` und
bei Schwelle 0 immer `false`. `usbPower` erscheint, sobald das Gerät seine
Stromversorgung meldet. `update.state`: `idle`, `applying`, `boot-pending`,
`confirmed`, `failed`. `mirror.state`: `off`, `offline`, `resolving`,
`notFound`, `waiting`, `idle`, `filtered`, `sizeMismatch`, `noMemory`, `showing`.

📄 `wifi` und `mqtt` haben dieselben Schlüssel: `enabled`, `state`
(`disabled`, `offline`, `connecting`, `connected`), `host`, `endpoint`,
`attempts` (Fehlversuche in Folge), `retryInMs`, `connects` (Erfolge seit dem
Start), `error` (`null`, solange verbunden) und `lastError`. Mögliche Werte von
`error` bei `wifi`: `hostNotFound`, `badCredentials`, `timeout`, `lost`; bei
`mqtt`: `noWifi`, `hostNotFound`, `refused`, `badCredentials`, `rejected`,
`timeout`, `lost`.

🔬 Am gemessenen Gerät war `mqtt.state` `offline` mit `attempts` 85 und `error`
`timeout`; im Geräteprotokoll stand wiederholt `failed (timeout, state -4)`. Die
Ursache ist ein Platzhalter im Präfix (§2).

### 7.2 `GET /api/v1/apps`

🔬 Je App `name`, `enabled`, `inLoop`, `slot`, `present`, `origin` und `config`:

```json
[{"name":"Time","enabled":true,"inLoop":true,"slot":null,"present":true,"origin":"builtin","config":true},
 {"name":"Status","enabled":true,"inLoop":true,"slot":null,"present":true,"origin":"builtin","config":false}]
```

📄 `origin` ist eines von `builtin`, `pushed`, `script`, `module` (oder `null`,
wenn nicht vorhanden). Zuerst stehen die angeordneten Apps in ihrer Reihenfolge,
dann alles übrige. Ohne Anordnung läuft die Schleife: eingebaute Apps, gepushte
in der Reihenfolge ihres Eintreffens, Skripte. Schlüssel, die nicht zutreffen,
fehlen: `icon` (gepushte mit Icon), `import` (Module), `skipped`, `headless`,
`ondemand`, `error` (`null` oder `{message, line?, hook?}`) und `meta` (Skripte),
`config` (Apps mit Einstellungen). Die Anordnung gilt über Neustarts nur für
Apps, die in einem Anordnungsaufruf genannt wurden; abgeschaltete gepushte Apps
bleiben nach erneutem Senden aus.

🔬 **Ausgeschaltete gepushte App (09.10.2026, NG 1.2.2, TC002, per HTTP):**
`enabled:false` und `inLoop:false` bei `present:true`. `PUT /api/v1/apps/pushed/{name}`
auf einen ausgeschalteten Namen **ersetzt den Inhalt, die App bleibt
ausgeschaltet**. `DELETE /api/v1/apps/{name}` löscht den Inhalt, der Name bleibt
aber als Geistereintrag im Inventar (`enabled:false`, `inLoop:false`,
`present:false`); eine spätere Sendung unter demselben Namen ist **weiterhin
ausgeschaltet** und liefe unsichtbar. `PUT /api/v1/apps/{name}/enabled` mit
`true` räumt den Geistereintrag weg. Auf einen unbekannten Namen antwortet
`enabled` ok und legt nichts an. Folge für Clients: „belegt“ ist `present:true`;
wer eine ausgeschaltete Anzeige löscht, setzt danach `enabled true`.

❓ Warum `slot` bei beiden gemessenen Apps `null` ist, obwohl `inLoop true`
dasteht, ist nicht erklärt (die Doku nennt `slot` „Ganzzahl oder `null`“).

### 7.3 `GET /api/v1/display/screen` und `<P>/state/screen`

📄 `pixels` ist ein flaches Feld gepackter RGB-Ganzzahlen (`0xRRGGBB` als
Dezimalzahl), `width × height` Einträge, zeilenweise von oben links — **die
Farben, die die Apps gezeichnet haben**; Helligkeit und Farbkorrektur ändern sie
nicht.

🔬 Am gemessenen Gerät `{"width":52,"height":16,"pixels":[…]}` mit 832 Werten.

Über MQTT ist das Thema **nicht aufbewahrt** und wird nur als Antwort auf
`cmd/screen/get` veröffentlicht.

### 7.4 `GET /api/v1/capabilities`

🔬 Am gemessenen Gerät: `effects`, `paletteEffects`, `transitions`, `overlays`,
`palettes` (Namen, §5.5); `audio` mit den Schaltern `mp3`, `rtttl`, `song`,
`speech`, `radio`, `url`, `effect`, `clip` (alle `true`) und `track` (`false`);
`microphone`, `scriptUpdates`, `ble`, `gamepad`, `gamepadRemote`, `oauth`,
`crypto`, `tcp`, `voice`, `mqttTls`, `bootSound`, `enlargeApps` (alle `true`);
`gpio` `null` (Pins nicht änderbar); `platform.id` `tc002`; `sensors.light`
`false`; `display` (§1); `fonts` (§1.3); `clockFaces`
(`sheet`, `ring`, `flap`, `month`, `big`); `layout` `true` und `layouts` mit
`version 1` und `limits` (§9.5).

### 7.5 `GET /api/v1/display`, `/audio` und weitere

🔬 `GET /api/v1/display`:
`{"power":true,"brightness":128,"overlay":null,"overlaySettings":{"speed":1,"palette":null,"blend":true},"moodlight":null}`.
`GET /api/v1/audio`: `radio` (`playing`, `station`, `title`, `error`,
`underruns`, `decodeUs`, `starvedMs`, `bufferBytes`), `app` und `alert`
(`playing`, `name`, `error`) sowie `stations` (je `name`, `url`).

📄 `moodlight` ist `{color, brightness}` oder `null`. `GET /api/v1/logs`
liefert das fortlaufende Geräteprotokoll; `GET /api/v1/files` die Dateiablage
mit `usedBytes` und `totalBytes` (ohne die reservierte Mindestfreifläche).

---

## 8. Die Grenzen

📄 Alles, was das Gerät erzwingt, und was es am Rand antwortet:

| Grenze | Wert | Am Rand |
|---|---|---|
| Rumpf über HTTP (JSON oder Aufnahme) | **2 MiB** | `413 payloadTooLarge`, nichts wird angewandt |
| MQTT-Kommandonachricht, Thema eingerechnet | **8192 Byte** | **verworfen: kein Fehler, keine `/result`-Antwort** |
| Verschachtelung im JSON | 16 Ebenen | `400 invalidJson` |
| Namen von Anzeigen und Skripten | 1–32 Zeichen aus `A–Z`, `a–z`, `0–9`, `_`, `-` | `400 invalidName` |
| Firmwarepaket (`.awup`) | 8 MiB | `413 payloadTooLarge` |
| Rümpfe über 64 KiB | werden nacheinander angenommen | ein zweiter großer Rumpf mitten im Empfang: `503 serviceBusy`, `Retry-After: 2` |
| Anzeigen gleichzeitig im Gerät | **50** (nur neue Namen) | `507 insufficientStorage`, nichts wird abgelegt; Ersetzen gelingt immer |
| Feld als Nutzlast | alles oder nichts | übersteigen die neuen Namen 50 insgesamt: `507`, nichts angelegt |
| Warteschlange der Benachrichtigungen | 32, die sichtbare mitgezählt | gestapelt: `507`; `stack: false` ersetzt die sichtbare und wird nie abgewiesen |
| Benachrichtigungen je Anfrage | 1 | `422 validationFailed` |
| Punkte in `barChart` / `lineChart` | 16 | der 17. und alle weiteren fallen weg, gezeichnet wird trotzdem |
| Zusatzicons (`icons`) | 4 je Anzeige, zusätzlich zu `icon` | `422`, die ganze Anfrage abgewiesen |
| Anzeigegröße | TC002 **52 × 16** = 832 Pixel, fest; 🔬 TC001 **32 × 8** | — |
| GIF | muss in Breite und Höhe der Anzeige passen | größere vorher verkleinern; ein zu großes GIF wird nicht gezeigt |
| 🔬 GIF als Data-URL, `icon` einer Layout-Region | rund 8 KB Base64 (7508 Zeichen angenommen, 8796 abgewiesen) | `422 validationFailed` „invalid icon“, `field` `layout.regions[0].icon` |
| 🔬 GIF als Data-URL, `icon` der Anzeige | mindestens 58 761 Byte GIF (angenommen), 87 KB abgewiesen | `field` `icon` |
| Icon aus Webadresse: Adresse | 2048 Zeichen, `http(s)`, ohne Leerzeichen | `422`, `field` = `icon` |
| Icon aus Webadresse: Dateigröße · Ladezeit | 1 MB · 15 s | Bild wird nicht gezeigt, das Protokoll nennt den Server |
| Icon aus Webadresse: JPEG | bis 8192 × 8192; progressiv 1920 × 1280 (4:2:0), 1600 × 1200 (4:2:2), 1000 × 1000 (4:4:4) | Bild wird nicht gezeigt |
| Icon aus Webadresse: PNG · GIF | 4 Mio. Pixel, nicht verschachtelt · 8 KB | Bild wird nicht gezeigt |
| Bilder im Speicher | 64 Bilder und 128 KB | das älteste fliegt raus und wird bei Bedarf neu geladen |
| gleichzeitige Ladevorgänge | 1, bis zu 8 wartend | die übrigen warten |
| Dateiablage | der freie Platz; **1 MiB** bleiben für Einstellungen, WLAN-Einrichtung und Updates reserviert | `507 insufficientStorage`, keine halbe Datei bleibt zurück |
| Melodie (Quelltext) · Name | 512 Zeichen · 1–24 Zeichen | `422 validationFailed` |
| MP3-Name | 1–32 Zeichen | `400 invalidName`; MP3- und Melodienamen sind gemeinsam eindeutig (`409 nameTaken`) |
| Klänge in einer Liste | 1–4 | `422 validationFailed` |
| Sprechtext | 1–512 Byte | `422 validationFailed` |
| MP3 von Adresse (`file`) | 4 MB, nur bei genug freiem Speicher | es spielt nichts, `alert.error`/`app.error` nennt den Grund |
| Song-Text | 16384 Byte (über MQTT 8192 mit JSON und Maskierung); 16 Spuren, 32 Instrumente, 8192 Noten, 1024 Takte, 8 Töne je Akkord, Echo 2 s | `422` |
| Radiosender | 32; Name 1–24 Zeichen, Adresse höchstens 255 Zeichen mit `http(s)` | `422`, die ganze Liste abgewiesen, die Zeile benannt |
| Berry-Skripte | Speicher gemeinsam: ein Viertel des beim Start freien Speichers, höchstens 4 MiB (`scriptHeapBudgetBytes`); weitere Grenzen in der Herstellerdoku, hier nicht aufgeführt | Neuinstallation abgelehnt, laufende Skripte laufen weiter |
| Zertifikat (`PUT /api/v1/mqtt/tls/ca`) | 65536 Byte | `422`/`507` |

📄 **Nicht begrenzt sind:** Anfragen je Sekunde — weder über HTTP noch über
MQTT wird gedrosselt; und was das Gerät veröffentlicht — `state/device` und
`state/screen` gehen heraus, so groß sie sind. Die Zahl der Zeichenbefehle ist
nur durch die Rumpfgrenze beschränkt.

🔬 Gemessen an 1.1.0/TC001 mit dem Rahmenbau dieser App, **jeweils die ganze
MQTT-Nachricht** (Thema und JSON): Text von 1 000 Zeichen 1 096 Byte, von 7 900
Zeichen 7 996 Byte; Umlaute zählen im JSON zwei Byte.

🔬 Am gemessenen Gerät meldet `GET /api/v1/files` `"usedBytes":2579,
"totalBytes":6908435`.

---

## 9. Layouts

📄 Ein **Layout** teilt das Display in Kästen, jeder zeigt genau einen Inhalt
(Text, Icon, Diagramm, Fortschrittsbalken oder Zeichnung). Es steht als Block
`layout` in der Nutzlast einer gepushten Anzeige oder Benachrichtigung (oder wird
von einem Skript gezeichnet) und wird nicht als Datei im Gerät abgelegt.
`capabilities.layout` ist `true` (🔬, TC002).

🔬 **Auf dem ESP32 (TC001) gibt es keine Layouts** (09.10.2026, NG 1.2.2):
`capabilities.layout` fehlt, und ein `layout` in der Nutzlast weist das Gerät mit
`422 validationFailed`, `message` „unknown field“, `field` `layout` ab. Wer beide
Geräte bedient, nimmt für Gerastertes das GIF im `icon` der Anzeige (§5.3).

### 9.1 Raster und Kästen

📄 **Layouts rechnen auf dem vollen 52 × 16-Raster**, nie auf dem
vergrößerten (§1.1). Ein Kasten ist `[x, y, Breite, Höhe]` ab der linken oberen
Ecke: ganzes Display `[0, 0, 52, 16]`, obere Hälfte `[0, 0, 52, 8]`, untere
`[0, 8, 52, 8]`. **Ein Kasten muss vollständig im Display liegen**, sonst `422`
(„outside the display“) und nichts ändert sich. Inhalt sitzt mittig im Kasten,
solange `align` und `valign` nichts anderes sagen; was nicht passt, wird
abgeschnitten — außer Text, der läuft. Schriften und Bilder behalten ihre
Größe.

### 9.2 Aufbau

📄 Auf Layout-Ebene stehen:

| Schlüssel | Bedeutung |
|---|---|
| `version` | `1` |
| `regions` | die Regionen, in Zeichenreihenfolge (spätere decken frühere) |
| `backgroundColor` | füllt das Display zuerst; Vorgabe schwarz |
| `effect` | Hintergrundeffekt; **nicht** zusammen mit `backgroundColor` |
| `effectSpeed` | 0.1–10 |
| `overlay` | Overlay über allen Regionen; ohne es zeigt das Gerät sein eigenes |
| `palette`, `paletteBlend`, `paletteSpan`, `paletteSpeed` | gelten für Effekt, Overlay und Regionen, die `"palette"` ohne eigene Palette nutzen |

📄 Jede **Region** hat `id` (frei gewählt, einmalig im Layout, höchstens 64
Byte) und `box` sowie **genau einen** der Schlüssel `text`, `icon`, `chart`,
`progress`, `draw`. `align` (waagrecht) und `valign` (senkrecht) nehmen
`start`, `center`, `end`; beide Vorgabe `center`.

### 9.3 Inhalte

| Inhalt | Wert | Weitere Schlüssel der Region |
|---|---|---|
| `text` | Zeichenkette oder Feld von Teilen (je mit optionalem `color`) | `font` (Vorgabe `small`), `color`, `palette`, `textColor` (Name einer gepushten Anzeige für `color`), `align`, `valign`, `scroll`, `repeat`, `textCase`, `textBlinkMs`, `textFadeMs` |
| `icon` | Kennung, Data-URL oder Webadresse, die die Region füllt | `align`, `valign` |
| `chart` | `{values, type, min, max}` — `values` bis 128 ganze Zahlen, `type` `line` oder `bar`, `min` und `max` nur zusammen und mit `min < max`; ohne beide skaliert das Diagramm selbst und schließt die Null ein | — |
| `progress` | 0–100, füllt von links | `color`, `palette`, `trackColor` (leerer Teil, Vorgabe `#202020`) |
| `draw` | dieselben Befehle wie der Schlüssel `draw` (§6), von der linken oberen Ecke des Kastens aus gezählt; was außerhalb des Kastens liegt, wird abgeschnitten | `color`, `font` |

📄 `palette` nimmt einen Namen, eine Liste von Farben oder `{color, pos}`-Stützen.
`color` oder `textColor` auf `"palette"` nimmt die Farben aus der Palette der
Region bzw. des Layouts. `paletteBlend`, `paletteSpan`, `paletteSpeed` brauchen
eine danebenstehende `palette`.

📄 Eine **Text**region läuft, solange sie nicht `"scroll":"static"` setzt, auch
wenn der Text passt. `scroll` nimmt einen Modus (`"loop"`) oder das Objekt aus
§5.2; `speed` und `holdMs` bis 1 000 000, `gap` bis 32 767; `speed: 0` endet
nie. Ohne `scroll` gelten die globalen Einstellungen. `align` setzt Text nur,
solange er steht.

### 9.4 Was zusammen geht und was nicht

📄 Neben `layout` gelten weiter `durationMs`, `repeat`, `lifetimeMs`,
`lifetimeExpiry` und bei Benachrichtigungen `name`, `hold`, `stack`, `wakeup`,
`sound`. **Nicht kombinierbar** mit `layout` sind `text`, `icon`, `draw`,
`effect`, `scroll` und die übrigen Zeichenschlüssel der Nutzlast (Farben,
Paletten, Effekte, Overlays, Diagramme, Fortschritt gehören ins Layout bzw. in
die Region): `422` mit `field` = dem Schlüssel („not allowed with layout“).
Eine Region kann ein eigenes `repeat` setzen; `0` heißt, die Anzeige wartet nicht
auf sie, und ruhender Text hält die Anzeige nie fest.

### 9.5 Aktualisieren und Grenzen

📄 **Geändert wird, indem man das ganze Layout noch einmal schickt;** eine
Teilaktualisierung einzelner Felder beschreibt die Doku nicht. Regionen werden
über `id` zugeordnet, die Reihenfolge spielt keine Rolle; laufender Text
unveränderter Regionen behält seine Stelle, eine Region, deren Text, Schrift,
Kasten oder Laufoptionen sich ändern, beginnt von vorn. Jeder Fehler weist das
gesamte Update ab; der bisherige Inhalt bleibt. Abgewiesen wird auch bei
unbekannter Schrift, unbekanntem Effekt oder unbekannter Palette, einem Icon,
das sich nicht laden lässt, und zu viel Inhalt.

📄 Grenzen je Layout (auch unter `layouts.limits` in `capabilities`):

| Grenze | Wert |
|---|---|
| Regionen | 16 |
| laufende Texte | 8 |
| Icons | 4 |
| Diagrammwerte je Diagramm | 128 |
| Text gesamt | 8192 Byte |
| aufbereiteter Inhalt, gemeinsam für gepushte Anzeigen, wartende Benachrichtigungen und Skriptgriffe | 256 KiB (`preparedBytes` 262144) |
| Skriptgriffe | 4 je Skript, 8 insgesamt |

Ist der Speicher voll, wird die Anfrage abgewiesen und das Display bleibt
unverändert. Beim Austausch braucht das Gerät kurz Platz für altes und neues
Layout.

🔬 `capabilities.layouts.limits` meldet am gemessenen Gerät `regions 16`,
`scrollers 8`, `assets 4`, `chartPoints 128`, `textBytes 8192`,
`preparedBytes 262144`, `scriptHandles 8`, `scriptHandlesPerScript 4`.

```json
{"layout":{"version":1,"regions":[
  {"id":"icon","box":[0,4,8,8],"icon":"sun"},
  {"id":"temp","box":[9,0,43,16],"text":"21.5°C"}]}}
```

```json
{"durationMs":10000,"layout":{"version":1,"regions":[
  {"id":"title","box":[0,0,52,8],"text":"TEMPERATURE","font":"matrix-light6"},
  {"id":"value","box":[0,8,52,8],"text":"22.4°C","font":"matrix-chunky8x6","color":"#00AAFF"}]}}
```

### 9.6 Wie diese App Layouts sendet

📄 Die App kennt ein Layout als `Kastenlayout` (`TC002Core`) mit genau den Schlüsseln
oben und sendet es als Anzeige unter einem Platznamen oder als Benachrichtigung —
über denselben Weg wie jede andere Nutzlast (MQTT mit Auswertung von `/result`,
über 8192 Byte samt Thema über HTTP an dieselbe Uhr, §8). Vorher prüft sie Regionen
(16), laufende Texte (8), Icons (4), Diagrammwerte (128), Text gesamt (8192 Byte),
Kennungen (einmalig, 1–64 Byte), Kästen im Anzeigemaß der Uhr und das Zusammenpassen
von Feldern und Inhalt. Die Grenzen kommen aus `capabilities.layouts.limits`; **ob** die
Uhr Layouts kann, entscheidet allein `capabilities.layout` (fehlt es, wie bei der
TC001, weist die App das Layout ab). Ohne Auskunft (Uhr nie abgefragt, MQTT ohne
Adresse) sendet sie, und die Uhr weist ab.

📄 Das Display liest `mqtttc002 bildschirm` (HTTP: `GET /api/v1/display/screen`; MQTT:
`cmd/screen/get`, Antwort auf `state/screen`, vorher abonniert, weil das Thema nicht
aufbewahrt ist) und gibt es als Text aus. Die Layoutdatei von `mqtttc002 layout` ist
der Block `layout` oder die Nutzlast `{"layout":…,"durationMs":…}`:

```json
{"durationMs":10000,"layout":{"version":1,"regions":[
  {"id":"titel","box":[0,0,52,8],"text":"HALLO","color":"#00AAFF","scroll":{"mode":"static"}},
  {"id":"balken","box":[0,8,26,4],"progress":50,"color":"#00FF00","trackColor":"#202020"},
  {"id":"marke","box":[30,8,22,8],"draw":[["rectFill",0,0,22,8,"#FF0000"],["pixel",0,0,"#0000FF"]]}]}}
```

❓ Annahmen der App, nicht an der Uhr gemessen:

- Eine Region mit `scroll: {"mode":"static"}` zählt nicht zu den laufenden Texten (§9.3: „läuft, solange sie nicht `static` setzt“); eine ohne `scroll` zählt.
- Ein Icon als Data-URL darf in der App bis 7508 Zeichen Base64 haben, das größte gemessene, angenommene (§5.3); dazwischen und darüber bis 8796 ist nichts gemessen.
- Ein Diagramm braucht mindestens einen Wert; `min` und `max` stehen nur zusammen (§9.3).
- Ein Layout ohne Regionen und ein fehlendes `version` sendet die App nie (das erste, weil es nichts zeigt); ob die Uhr beides abweist, ist offen.
- `textCenter` neben `layout` zählt wie jeder Zeichenschlüssel als „not allowed with layout“.
- Die virtuelle Uhr zeichnet Text mit der Pixelschrift der App (die Uhr hat eine eigene), laufenden Text an seinem Startanker links, Diagramme und Kreise nach einem eigenen Verfahren; Effekt und Overlay stellt sie nicht dar. Ihre Feldnamen bei Fehlern folgen der einen Messung (`layout.regions[0].icon`), der Rest ist abgeleitet.

---

## 10. Die Einstellungen

📄 `GET /api/v1/settings` liefert alle Anzeigeeinstellungen, jede immer
vorhanden; `PATCH` nimmt eine Teilmenge, prüft alles vor dem Schreiben und
weist unbekannte Schlüssel ab. Dieselben Schlüssel stehen in `<P>/state/settings`.

🔬 Die gemessene Antwort hat 46 Schlüssel; die Werte unten sind der Stand des
Geräts, wo er von der dokumentierten Vorgabe abweicht, ist das vermerkt.

| Gruppe | Schlüssel | Typ · Bereich · Vorgabe |
|---|---|---|
| Helligkeit | `brightness` | int 0–255, Vorgabe 120 (gemessen 128); roher Wert, kein Prozentsatz |
| | `autoBrightness` | bool, `false` — **ohne Wirkung** (kein Lichtsensor) |
| Farbe | `saturation` | int 0–100, 100 |
| | `gamma` | Zahl > 0, 1.9 |
| | `colorCorrection`, `colorTint` | Farbe oder `null`, `null`; multiplizieren jedes Pixel, die zweite nach der ersten |
| Globaler Text | `textColor` | Farbe, `#FFFFFF`, nie `null` |
| | `uppercase` | bool, `true` |
| | `scroll` | Objekt wie §5.2, Vorgabe `wrap`/`left`/`inline`/`static`/100/8/1000 |
| | `enlargeApps` | bool, `true` (§1.1) |
| Schleife | `autoTransition` | bool, `true` |
| | `appDurationMs` | int ≥ 0, 7000 |
| | `transitionEffect` | Name (Groß-/Kleinschreibung egal), `"Rain"`; Namen in `capabilities.transitions` |
| | `transitionDirection` | `normal` · `reverse`, `normal` |
| | `transitionDurationMs` | int 0–2147483647, 1000 |
| Uhr-App | `clockFace` | `sheet` · `ring` · `flap` · `month` · `big`, `sheet` |
| | `timeColor` | Farbe oder `null` |
| | `calendarHeaderColor` · `calendarTextColor` · `calendarBodyColor` | Farbe, `#FF0000` · `#000000` · `#FFFFFF` |
| | `calendarAnimation` | bool, `true` |
| | `timeMode` | int 0–6, 1 — **ohne Wirkung** |
| Uhrzeittext | `time24h` · `timeLeadingZero` · `timeShowSeconds` · `timeShowAmPm` | bool, `true` · `true` · `false` · `false` |
| | `timeSeparatorMode` | `steady` · `blink` · `pulse`, `pulse` |
| Datumstext | `dateOrder` | `dayMonthYear` · `monthDayYear` · `yearMonthDay`, `dayMonthYear` |
| | `dateSeparator` | `dot` · `slash` · `dash`, `dot` |
| | `dateYearMode` | `none` · `twoDigit` · `fourDigit`, `twoDigit` |
| | `dateShowWeekday` · `dateMonthNames` | bool, `false` |
| | `dateColor` | Farbe oder `null` |
| Wochentagsleiste | `weekdayBar` | Objekt: `show` (`true`), `startOnMonday` (`true`), `weekendDays` (`["sunday","saturday"]`), `activeColor` `#FFFFFF`, `inactiveColor` `#666666`, `weekendActiveColor` `#FFFFFF`, `weekendInactiveColor` `#666666` (Farben nie `null`) |
| | `dateWeekdayBar` | Objekt gleicher Form — **ohne Wirkung** |
| Fühler-Apps | `useCelsius`, `temperatureColor`, `humidityColor`, `batteryColor` | angenommen, **ohne Wirkung** |
| Klang | `volume` | int 0–100, Hauptlautstärke 90 (gemessen 100) |
| | `radioVolume` · `appVolume` · `alertVolume` | int 0–100, 80 · 100 · 100; jede Gruppe spielt mit Hauptlautstärke × Anteil |
| | `bootSound` | bool, `true` |
| | `musicSource` | `auto` · `playback` · `microphone`, `auto` |
| Tasten | `blockNavigation` | bool, `false` |

---

## 11. Die Systemkonfiguration

📄 `GET /api/v1/system` liest, `PUT` mischt eine Teilmenge ein (alles geprüft,
bevor geschrieben wird). Geheimnisse (`wifiPass`, `mqttPass`, `authPass`) kommen
nur mit `?secrets=1`; ein leerer Wert beim Schreiben behält das gespeicherte
Geheimnis. „Neustart“ heißt: wirkt erst nach `POST /api/v1/device/reboot`. Im
Einrichtungsbetrieb sind nur `wifiSsid`, `wifiPass` und `hostname` schreibbar.

| Gruppe | Schlüssel | Typ · Bereich · Vorgabe | Neustart |
|---|---|---|---|
| WLAN | `wifiSsid` | string, `""`; per `PUT` nicht leerbar (`422`) | ja |
| | `wifiPass` | string, Geheimnis | ja |
| | `wifiConnectTimeout` | long 5000–120000 ms, 15000 | ja |
| | `wifiRoamRssi` | int −90…0 dBm, 0 = aus | ja |
| Netz | `netStatic` · `ip` · `gateway` · `subnet` · `dns1` · `dns2` | bool `false`; Strings, Dezimalpunktform; `ip` darf `/0`–`/32` tragen; fest nur bei `netStatic` und gesetzter `ip`; `subnet` Pflicht dann | nein |
| MQTT | `mqttEnabled` · `mqttHost` · `mqttPort` · `mqttUser` · `mqttPass` · `mqttTls` · `mqttPrefix` | §3.1 | ja |
| | `mqttTlsPin` | 64 Hexziffern klein oder `""`, sonst `422` („expected 64 lowercase hex digits“) | nein, greift beim nächsten Verbindungsversuch |
| Home Assistant | `haDiscovery` · `haPrefix` | §3.1 | nein, wirkt sofort |
| Zeit | `ntpServer` | string, `pool.ntp.org` | nein |
| | `tz` | POSIX-TZ, `CET-1CEST,M3.5.0,M10.5.0/3`, nicht geprüft | nein |
| | `tzName` | IANA-Name, nur Anzeige der Web-Oberfläche | nein |
| Kennung | `hostname` | string 1–32, leer → `awtrixng-` + letzte 6 Zeichen der uid | ja |
| Zugang | `authEnabled` | bool; `true` braucht `authUser` und `authPass` (`422`) | nein |
| | `authUser` · `authPass` | string; `authPass` Geheimnis | nein |
| | `webPort` | gespeichert, **ohne Wirkung** (Port 80) | — |
| Batterie | `lowBatteryThreshold` | uint8 0–100, 0 = aus | nein |
| Tasten | `swapButtons` | bool, `false`; vertauscht links und rechts, nie die Mitte | nein |
| | `buttonCallback` | URL, `""`; erhält ein HTTP-`POST` bei jedem Druck, Loslassen und Drehen; nur `http://` | nein |
| Spiegeln | `mirrorShare` · `mirrorShareApps` · `mirrorShareNotifications` · `mirrorFrom` · `mirrorFromApps` · `mirrorFromNotifications` | bool `false`; Namensliste `"*"`; bool `true`; Quelle `""`; `"*"`; `true`. UDP-Port 4212 offen, solange `mirrorShare` an oder `mirrorFrom` gesetzt ist; ohne Anmeldung | nein |
| Sonstiges | `statsInterval` | long 1000–600000 ms, 10000 (sonst `422`) | ja |
| | `debugMode` · `scriptingEnabled` | bool, `false` · `true` | nein · ja |
| ohne Wirkung | `tempOffset`, `humOffset`, `batteryDividerRatio`, `tempDecimals`, `dfplayer`, `artnet`, `minBrightness`, `maxBrightness`, `ldrFactor`, `ldrGamma`, `ldrOnGround`, `brightnessSmoothing` | angenommen und gespeichert | — |

📄 Panel und Pins gibt es nicht: Schlüssel dafür werden wie unbekannte
ignoriert; `capabilities.gpio` ist `null`.

🔬 `GET /api/v1/system` führt am gemessenen Gerät 48 Schlüssel, darunter alle
oben genannten MQTT-, Netz-, Spiegel- und Tastenschlüssel; `mqttTls false`,
`mqttTlsPin ""`, `statsInterval 10000`, `webPort 80`, `lowBatteryThreshold 15`,
`scriptingEnabled true`. `wifiPass`, `mqttPass` und `authPass` sind darin nicht
aufgeführt.

### 11.1 MQTT über TLS

📄 `mqttTls: true` verbindet verschlüsselt (üblich Port 8883). Vertraut wird
einem Zertifikat einer öffentlichen CA, das den Namen `mqttHost` trägt, oder dem
über `mqttTlsPin` festgelegten; eine hochgeladene Broker-CA ersetzt beides.
`GET /api/v1/mqtt/tls` zeigt, wie dem Broker vertraut wird, einschließlich des
SHA-256-Fingerabdrucks; `PUT /api/v1/mqtt/tls/ca` mit `{"certificate":"<PEM>"}`
(höchstens 65536 Byte, sonst `422`) lädt eine eigene CA hoch, `DELETE` entfernt
sie und antwortet mit dem Stand. Beide Routen sind `404`, wenn die Fähigkeit
fehlt (`capabilities.mqttTls`).

🔬 `GET /api/v1/mqtt/tls` antwortet am gemessenen Gerät
`{"ca":"public","pending":null}`.

❓ Welche Werte `ca` außer `public` annimmt und was `pending` bedeutet, steht
nicht da.

---

## 12. Fehlercodes

📄 `code` ist stabil; `message` ist englische Prosa. Die Statusspalte gilt für
HTTP.

| Code | Status | Bedeutung |
|---|---|---|
| `invalidJson` | 400 | Rumpf ist kein gültiges JSON (bei manchen Routen auch leer) |
| `invalidName` | 400 | Name ungültig oder reserviert (`field` `name`, bei Umbenennen `from`/`to`) |
| `invalidPath` | 400 | Pfad außerhalb der erlaubten Ordner oder mit `..` |
| `invalidMethodOverride` | 400 | `X-HTTP-Method-Override` falsch benutzt |
| `invalidPlayer` | 400 | Gamepad-Spieler nicht 1 oder 2 |
| `invalidOrigin` | 400 | Feld eines Icon-Herkunftsverweises fehlt oder ist ungültig |
| `badRequest` | 400 | Aufnahme ohne Datei, zu viele Dateien oder abgebrochen |
| `invalidPackage` · `wrongTarget` | 400 | Firmwarepaket beschädigt bzw. für ein anderes Gerät |
| `unauthorized` | 401 | Anmeldung an, Zugangsdaten fehlen oder falsch |
| `forbidden` | 403 | Route im Einrichtungsbetrieb nicht erlaubt |
| `forbiddenOrigin` | 403 | Anfrage von einer fremden Webseite |
| `notFound` | 404 | unbekannte Route oder App, Klang, Datei, Benachrichtigung nicht da |
| `methodNotAllowed` | 405 | Pfad gibt es, aber nicht für diese Methode (`allowed: <Liste>`) |
| `scriptChanged` · `notNewer` · `gamepadsFull` · `updateBusy` · `nameTaken` | 409 | Skript weicht von `expected_source` ab · Paket nicht neuer · beide Gamepad-Plätze belegt · Update läuft · Name schon vergeben |
| `payloadTooLarge` | 413 | Rumpf über der Grenze |
| `insufficientMemory` | 413 | zu wenig freier Speicher für ein Firmwarepaket |
| `unsupportedMediaType` | 415 | `Content-Type` kein JSON bei `PUT`/`PATCH` oder Datei passt nicht zum Ordner |
| `validationFailed` | 422 | JSON gültig, ein Wert nicht; meist mit `field`; nichts wird angewandt |
| `internalError` · `storageError` | 500 | Aktion misslungen · Icon-Verweise nicht les-/speicherbar |
| `notSupported` | 501 | Gerät nimmt keine Netzwerk-Updates |
| `scanUnavailable` · `unavailable` · `serviceBusy` | 503 | WLAN-Suche bei offenem Einrichtungs-Hotspot nicht möglich · Fähigkeit fehlt oder Klang nicht spielbar · kurz beschäftigt (`Retry-After: 2`) |
| `insufficientStorage` | 507 | Speicher oder Warteschlange voll, oder nicht speicherbar (`applied, not saved yet` bei Reihenfolge und Senderliste) |

---

## 13. Was sich gegenüber 1.1.0 geändert hat

📄 Für Absender, die für 1.1.0 geschrieben wurden (jeweils nach der Doku, nicht
am Gerät geprüft):

| Gegenstand | 1.1.0 (TC001) | 1.2.2 (TC002) |
|---|---|---|
| Raster | 32×8, Panelbreite 32–128 einstellbar | 52×16 fest; vergrößerte Apps rechnen auf 26×8 |
| HTTP-Rumpfgrenze | 8192 Byte | 2 MiB (MQTT weiter 8192 Byte, nun mit Thema) |
| Benachrichtigungsklang | `sound`, `soundRtttl` | `sound` als Name, Objekt oder Liste; `soundRtttl` nicht mehr geführt |
| `audio/play` | Schlüssel `sound`, `mp3`, `melody`, `track`, `rtttl`, `station`, `index`, `url` | `file`, `rtttl`, `song`, `speech`, `station`, `loop`; Liste bis 4 |
| `audio/stop` | `{"scope":"sounds"\|"stream"\|"all"}` | `{"group":"alert"\|"app"\|"radio"}` |
| Icon | Kennung oder Base64 im Text ab 65 Zeichen | Kennung, Data-URL mit Vorsatz oder Webadresse; blankes Base64 ist `422` |
| Text | `textCenter` | `textAlign` (`start`/`center`/`end`); `textCenter` wird weiter angenommen (🔬 10.10.2026) |
| Schriften | `small`, `large` | dazu zehn Matrixschriften |
| Fehlermeldung bei falscher Methode | `allowed method(s): …` | `allowed: …` (🔬) |
| Neu | — | Layouts, `iconGap`, `icons[]`, `cmd/voice/start`, `event/knob`, `event/error`, `cmd/apps/<name>/enabled`, `mqttTls`, `state/buttons/knob` |

---

## 14. Was nicht dasteht

- ❓ **Diagramme und Fortschritt neben einem GIF in Anzeigegröße:** ob sie über
  dem GIF (als Hintergrund) gezeichnet werden. Ebenso, ob `chartColor` und
  `progressColor` mit `"palette"` ohne gesetzte `palette` eine Farbe malen, ob ein
  `lineChart` mit weniger als zwei Werten abgewiesen oder nur nicht gezeichnet
  wird und ob ein `barChart`/`lineChart`, das kein Feld ist, `422` ergibt.
- ❓ **Ob Paletten, die nur als Datei `/PALETTES/<name>.txt` vorliegen, in
  `capabilities.palettes` stehen** (§5.5).
- ❓ **Ob `+` im `mqttPrefix` wie `#` wirkt** (§2) und ob die Firmware Leerzeichen
  oder weitere Zeichen darin beanstandet.
- ❓ **Alles zu MQTT am Gerät:** Themen, `/result`-Antworten, `event/error`,
  `state/*`, Last Will und Aufbewahrung sind nur aus der Doku bekannt, nicht
  gemessen — der Client verband sich bei der Messung wegen des Platzhalters im Präfix nicht.
- ❓ **Das Raster der Diagramme und des Fortschrittsbalkens bei vergrößerten
  Apps** (26×8 oder 52×16; für `draw` gemessen, §1.1) und die Höhe des Balkens.
- ❓ **Die Einheit von `iconGap`** bei vergrößerten Apps (Spalten des 26×8-Rasters
  oder des Displays).
- ❓ **Ob `POST /api/v1/device/sleep` über HTTP existiert:** Der MQTT-Teil führt
  es als HTTP-Gegenstück, die Routenliste der HTTP-Seite nennt es nicht.
- ❓ **Die Werte von `ca` und der Sinn von `pending`** in `GET /api/v1/mqtt/tls`
  (§11.1).
- ❓ **Warum `slot` in `GET /api/v1/apps` bei laufenden eingebauten Apps `null`
  ist** (§7.2).
- ❓ **Eine MQTT-Route, die die Liste der Anzeigen ausgibt.** Es gibt keine; das
  Inventar ist ausdrücklich nur über `GET /api/v1/apps` zu haben.
- ❓ **Ob sich die in §2 gemessenen Verhaltensweisen von 1.1.0** (Leerzeichen am
  Rand des Präfixes zählt mit; Präfixwechsel greift erst bei neuer Verbindung)
  **auf 1.2.2/TC002 übertragen.** Die Doku verlangt für `mqttPrefix` einen
  Neustart.
- 🔬 **Gemessen 10.10.2026 (TC002, NG 1.2.2):** `GET /api/v1/display/screen`
  liefert bei ausgeschaltetem Panel lauter Schwarz und bei laufendem Moodlight
  überall dessen Farbe. `weekendDays` steht englisch und klein in der Antwort
  (`["sunday","saturday"]`).
- ❓ **Steuerung (Moodlight, Einstellungen, Ereignisse):** ob `kelvin` außerhalb
  von 1000–40000 abgewiesen wird (nur `brightness` ist als ungeprüft
  vermerkt), welche Umrechnung Kelvin → RGB gilt und in welcher Schreibweise
  `GET /api/v1/display` die Farbe des Moodlights nennt; ob `PATCH /api/v1/settings` ein verschachteltes Objekt (`scroll`,
  `weekdayBar`) mit dem gespeicherten zusammenführt oder ersetzt (die App
  schickt darum das ganze Objekt); die
  Form von `error` in `<P>/event/error` (Wort oder Fehlerrumpf); ob `select` die
  mittlere Taste und `knob` der Druck auf den Drehknopf ist; eine Obergrenze
  für `turn` in `<P>/event/knob` (die App verwirft Beträge über 1000).
- ❓ **TLS-Zertifikat:** was `PUT /api/v1/mqtt/tls/ca` antwortet, ob ein Rumpf
  ohne PEM-Block `422` ist (die App prüft den Kopf `-----BEGIN CERTIFICATE-----`
  selbst) und unter welchem Schlüssel der SHA-256-Fingerabdruck in `GET
  /api/v1/mqtt/tls` steht.
