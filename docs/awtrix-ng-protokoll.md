# AWTRIX NG fernsteuern

*[English version](en/awtrix-ng-protocol.md)*

Was ein Gerät mit der Firmware **AWTRIX NG** kann und wie man es anspricht — über
MQTT und über HTTP. Diese Beschreibung ist von unserer App unabhängig: sie gilt
genauso für `mosquitto_pub`, Node-RED, Home Assistant oder ein eigenes Skript.

Jede Angabe trägt ihre Herkunft:

| Zeichen | Bedeutung |
|---|---|
| 📄 | aus der [AWTRIX-NG-Dokumentation](https://blueforcer.github.io/awtrix-ng/), nicht am Gerät gegengeprüft |
| 🔬 | an einem Gerät selbst gelesen |
| ❓ | offen — steht in der Doku nicht |

**Die Doku-Angaben beziehen sich auf den Stand des Zweigs `main` vom
13.09.2026**, die Messungen auf ein Gerät mit **AWTRIX NG 1.1.0** (`boardType
awtrixng`, `soc esp32`), gelesen am 13.09.2026 über `GET /api/v1/device`. Was
hier 🔬 trägt, gilt zunächst für dieses eine Gerät und diesen einen Bau; was 📄
trägt, für die Firmware im Allgemeinen.

---

## 1. Das Display

📄 **Die Höhe ist fest 8 Pixel** und nicht einstellbar. Die Breite ergibt sich
aus `panelWidth × panels` und **muss zwischen 32 und 128** liegen; die Vorgabe
ist `32 × 1`. Ein Wert außerhalb des Bereichs wird mit `422 validationFailed`
auf `panelWidth` abgewiesen.

🔬 Das gemessene Gerät steht auf `panelWidth 32`, `panels 1`; `GET
/api/v1/display/screen` antwortet entsprechend mit `"width":32,"height":8` und
256 Pixelwerten.

📄 Der Ursprung liegt oben links. Die Leinwand für Icons ist **immer 32×8**,
unabhängig von der Panelbreite.

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
die zwölfstellige MAC-Adresse (`a4cf12ab34cd/cmd/notify`). Die MQTT-Client-
Kennung ist ebenfalls die uid.

🔬 Am gemessenen Gerät stand in `GET /api/v1/system` ein `mqttPrefix` mit einem
Schrägstrich darin, und das Geräteprotokoll (`GET /api/v1/logs`) führte dieselbe
Zeichenkette in der Form `mqtt: broker <Broker>:1883, prefix <Präfix>`. Das
Präfix darf also mehrere Themenebenen enthalten.

📄 Zusätzlich veröffentlicht das Gerät sein Präfix unter dem Präfix selbst:
`<P>/state/prefix` trägt `<P>` als blanke Zeichenkette, aufbewahrt.

❓ Ob `mqttPrefix` auf MQTT-Platzhalter (`#`, `+`) geprüft wird, **steht nicht
da**: Die Schlüsseltabelle nennt für `mqttPrefix` weder Zeichenvorrat noch
Bereich.

🔬 **Ein Leerzeichen am Rand zählt mit — und ist nirgends zu sehen.** Am
14.09.2026 stand auf einem Gerät `mqttPrefix` mit einem abschließenden
Leerzeichen; das Geräteprotokoll führte es als `prefix awtrix ` mit, und das
Gerät abonnierte entsprechend `awtrix /cmd/#`. Wer das Präfix in einer
Oberfläche abliest, sieht `awtrix` und schreibt auf ein Thema, das kein Gerät
abonniert — NG antwortet darauf gar nicht. Die Firmware nimmt den Wert also
wörtlich, auch am Rand.

🔬 **Ein geändertes `mqttPrefix` greift erst beim nächsten Verbindungsaufbau.**
Nach dem `PATCH` blieb `connects: 1` stehen, und die laufende Sitzung führte
weiter das alte Präfix; erst nach einem Neustart stand das neue im
Geräteprotokoll. Wer es ändert, muss die Verbindung neu aufbauen lassen.

📄 Themen außerhalb von `<P>/` werden nicht gelesen.

---

## 3. Die MQTT-Themen

📄 Das Gerät verbindet sich mit **einem** Broker. **QoS 0 überall** — für
Veröffentlichungen, Abonnements und das Last Will; eine unterwegs verlorene
Nachricht ist still verloren. Die Nutzlast eines Kommandos ist **byteweise
dieselbe** wie der Rumpf der entsprechenden HTTP-Anfrage.

### 3.1 Die Verbindung

| Schlüssel | Typ | Vorgabe | Bedeutung |
|---|---|---|---|
| `mqttEnabled` | bool | `false` | Hauptschalter; `true` betreibt den Client (braucht ein nicht leeres `mqttHost`) |
| `mqttHost` | string | `""` | Broker |
| `mqttPort` | int | `1883` | 1–65535 |
| `mqttUser` / `mqttPass` | string | `""` | beide leer = anonym |
| `mqttPrefix` | string | `""` | Themen-Präfix `<P>`; leer → uid |
| `haDiscovery` | bool | `false` | Home-Assistant-Dokument veröffentlichen |
| `haPrefix` | string | `"homeassistant"` | dessen Präfix |

Diese Schlüssel stehen in der **Gerätekonfiguration** (`/api/v1/system`), nicht
in den Anzeigeeinstellungen.

📄 Ein gescheiterter Verbindungsversuch wird nach 5 s wiederholt, dann 10, 20,
40 und höchstens alle 60 s, jede Wartezeit um bis zu 20 % gestreut. Eine
geglückte Verbindung setzt den Plan zurück.

### 3.2 Kommandos — nur unter `<P>/cmd/`

📄 Alles unter `<P>/state/` ist ausgehend. `<P>/cmd` und `<P>/cmd/` für sich
treffen nichts.

| Thema | Nutzlast | HTTP-Gegenstück |
|---|---|---|
| `cmd/notify` | Benachrichtigungs-JSON | `POST /api/v1/notifications` |
| `cmd/notify/dismiss` | wird ignoriert | `DELETE /api/v1/notifications/active` |
| `cmd/notify/dismiss/<name>` | wird ignoriert | `DELETE /api/v1/notifications/{name}` |
| `cmd/apps/pushed/<name>` | Anzeigen-JSON; **leer oder `{}` löscht** | `PUT /api/v1/apps/pushed/{name}` bzw. `DELETE /api/v1/apps/{name}` |
| `cmd/apps/switch` | blanker Name **oder** `{"name":…,"fast":bool}` | `PUT /api/v1/apps/active` |
| `cmd/apps/next` · `cmd/apps/previous` | wird ignoriert | `POST /api/v1/apps/next` bzw. `/previous` |
| `cmd/apps/order` | `{"order":[…],"disabled":[…]}` — `disabled` ist Pflicht, `order` wahlweise | `PUT /api/v1/apps/order` |
| `cmd/settings` | Teilmenge der Einstellungen | `PATCH /api/v1/settings` |
| `cmd/settings/reset` | wird ignoriert | `POST /api/v1/settings/reset` |
| `cmd/display` | `{"power":bool?,"overlay":"rain"\|null?}` | `PATCH /api/v1/display` |
| `cmd/display/moodlight` | Moodlight-JSON; **leer = aus** | `PUT` / `DELETE /api/v1/display/moodlight` |
| `cmd/indicators/1` · `/2` · `/3` | `{"color","blinkMs","fadeMs"}`; leer oder `{}` = aus | `PUT` / `DELETE /api/v1/indicators/{id}` |
| `cmd/audio/play` | genau **einer** der Schlüssel `sound`, `mp3`, `melody`, `track`, `rtttl`, `station`, `index`, `url` | `POST /api/v1/audio/play` |
| `cmd/audio/stop` | wahlweise `{"scope":"sounds"\|"stream"\|"all"}` | `POST /api/v1/audio/stop` |
| `cmd/audio/stations` | `{"stations":[…]}` | `PUT /api/v1/audio/stations` |
| `cmd/device/reboot` | wird ignoriert | `POST /api/v1/device/reboot` |
| `cmd/device/sleep` | `{"durationMs":ms}`, `> 0` | `POST /api/v1/device/sleep` |
| `cmd/screen/get` | wird ignoriert | veröffentlicht `<P>/state/screen` |

📄 Der **Werkszustand ist nicht über MQTT erreichbar** — nur
`POST /api/v1/device/factory-reset`. Eine Veröffentlichung auf
`<P>/cmd/device/factory-reset` tut nichts und antwortet nichts.

📄 Der Name in `cmd/apps/pushed/<name>` ist der Rest des Themas hinter
`apps/pushed/` und muss `[A-Za-z0-9_-]{1,32}` erfüllen. `cmd/apps/pushed/` mit
leerem Namen trifft nichts.

📄 Die Kennziffer in `cmd/indicators/<id>` muss ein **einzelnes Zeichen** `1`,
`2` oder `3` sein. Alles andere trifft keine Route — und wird damit still
verworfen, während die HTTP-Route an derselben Stelle `404` mit
`indicator id must be 1..3` antwortet.

### 3.3 Zwei Fallen, die still zuschnappen

📄 **Eine Nutzlast über 8192 Byte wird verworfen, bevor sie gelesen wird — kein
Fehler, keine `/result`-Antwort.** Über HTTP wäre dasselbe ein
`413 payloadTooLarge`; über MQTT gibt es kein Anzeichen. Eine große
Benachrichtigung ist der realistische Weg, dort anzustoßen.

📄 **Ein Thema, das keine Route trifft, erzeugt gar keine Antwort** — keinen
Fehler, keine Bestätigung. **Tippfehler sind damit unsichtbar.** Wenn ein
Kommando spurlos zu verschwinden scheint, ist die Schreibweise des Themas das
erste, was zu prüfen ist.

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

Die `code`-Werte stimmen mit HTTP überein; zwei Meldungen sind weniger genau
(`notFound` fällt auf ein blankes `not found` zusammen, `invalidJson` sagt
`payload` statt `request body`). Die Rahmen-Codes von HTTP
(`methodNotAllowed`, `unauthorized`, `unsupportedMediaType` …) haben über MQTT
kein Gegenstück. Ein `/result`-Thema wird nie selbst als Kommando gelesen,
Antworten laufen also nicht im Kreis.

### 3.5 Zustandsthemen

| Thema | Inhalt | Aufbewahrt | Wann |
|---|---|---|---|
| `<P>/state/device` | Geräte-JSON, Form von `GET /api/v1/device` | ja | alle `statsInterval` (Vorgabe 10 000 ms, mindestens 1 000), sofort bei Wechsel von Panelstrom oder Indikator |
| `<P>/state/settings` | Einstellungs-JSON | ja | bei jeder Änderung und beim Verbinden |
| `<P>/state/apps/active` | Name der laufenden App, **blanke Zeichenkette, kein JSON** | ja | sofort bei Wechsel und beim Verbinden |
| `<P>/state/audio` | Audio-JSON | ja | bei Start, Stopp, Titelwechsel, Fehler, beim Verbinden |
| `<P>/state/capabilities` | `{"effects","paletteEffects","transitions","overlays","palettes","radio","gpio"}` | ja | einmal je Verbindung |
| `<P>/state/prefix` | `<P>` selbst, blanke Zeichenkette | ja | einmal je Verbindung |
| `<P>/state/buttons/left` · `/select` · `/right` | `"1"` / `"0"` | ja | bei jeder Tastenflanke und beim Verbinden |
| `<P>/state/screen` | `{"width":W,"height":H,"pixels":[…]}` | **nein** | nur als Antwort auf `cmd/screen/get` |
| `<P>/availability` | `online` / `offline` | ja | beim Verbinden bzw. als Last Will |

📄 `statsInterval` ist die **langsamste** Taktung von `state/device`, nicht die
einzige Auslösung. Aufeinanderfolgende ereignisgetriebene Veröffentlichungen
liegen mindestens 250 ms auseinander. Helligkeit löst nicht aus.
`state/settings` und `state/apps/active` sind rein ereignisgetrieben.

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

---

## 4. Die HTTP-Schnittstelle

📄 Basis ist `http://<ip>:<webPort>`; `webPort` steht in der
Gerätekonfiguration (Vorgabe 80, ein Wert `<= 0` fällt auf 80 zurück). Im
Einrichtungsbetrieb (Access Point) lauscht der Server immer auf Port 80.

### 4.1 Was jede Anfrage betrifft

📄 **`Content-Type: application/json` ist Pflicht** bei jeder Anfrage mit
JSON-Rumpf. `PUT` und `PATCH` mit einem anderen Typ werden vor dem Lesen des
Rumpfes mit `415 unsupportedMediaType` abgewiesen; ein `POST` wird gar nicht
auf den Typ geprüft — sein Rumpf kommt dann schlicht leer an und die Anfrage
scheitert als `400 invalidJson`. Beide Fehlschläge stammen aus demselben
Versäumnis. Einzige Ausnahme ist `PUT /api/v1/apps/script/{name}`, das
Berry-Quelltext trägt und jeden Typ annimmt.

📄 **Basic-Auth ist ab Werk aus** — die gesamte Schnittstelle steht im LAN
offen. Eingeschaltet wird sie über `authEnabled` (mit hinterlegtem Namen und
Kennwort) und gilt dann in **jedem** Betriebszustand, auch im Einrichtungs-
betrieb. Sie umfasst die Schnittstelle, die Web-Oberfläche unter `/` und die
statischen Verzeichnisse.

📄 **Jede fehlschlagende Anfrage** trägt denselben Rumpf:

```json
{ "error": { "code": "validationFailed", "message": "invalid value", "field": "brightness" } }
```

`code` ist maschinenlesbar und stabil — darauf ist zu prüfen, nie auf
`message`, das englische Prosa für Menschen ist. `field` steht nur da, wenn ein
bestimmter Eingabeschlüssel den Fehlschlag verursacht hat. Die einzige Route
mit eigener Antwortform ist `POST /api/v1/restore`.

🔬 Am gemessenen Gerät antwortet eine unbekannte Route mit
`{"error":{"code":"notFound","message":"unknown route"}}` und eine falsche
Methode mit `405` und
`{"error":{"code":"methodNotAllowed","message":"allowed method(s): DELETE"}}` —
die erlaubten Methoden stehen also in der Meldung.

📄 Ein `POST` mit `X-HTTP-Method-Override` wird als die genannte Methode
geprüft, braucht also denselben `Content-Type` wie ein echtes `PATCH`.

### 4.2 Die Routen

| Route | Wozu |
|---|---|
| `GET /api/v1/device` | Zustand und Statistik (dieselbe Form wie `state/device`) |
| `GET /api/v1/version` · `GET /version` | Fassungsnummer als JSON bzw. als `text/plain` |
| `POST /api/v1/device/reboot` | Neustart |
| `POST /api/v1/device/sleep` | Tiefschlaf für `{"durationMs"}`, danach normaler Start |
| `POST /api/v1/device/factory-reset` | Einstellungen und Gerätekonfiguration löschen, Dateisystem formatieren |
| `GET /api/v1/settings` | alle 40 Anzeigeeinstellungen, jede immer vorhanden |
| `PATCH /api/v1/settings` | beliebige Teilmenge; alles wird geprüft, bevor irgendetwas geschrieben wird |
| `POST /api/v1/settings/reset` | Einstellungen löschen und neu starten; die Gerätekonfiguration bleibt |
| `GET /api/v1/display` · `PATCH` | Panelstrom, Helligkeit, Overlay, Moodlight |
| `PUT` / `DELETE /api/v1/display/moodlight` | Panel einfarbig fluten bzw. aus |
| `GET /api/v1/display/screen` | der aktuelle Bildspeicher |
| `GET /api/v1/apps` | das vollständige Inventar: erst die angeordneten Apps in ihrer Reihenfolge, dann der Rest |
| `PUT /api/v1/apps/active` | umschalten |
| `POST /api/v1/apps/next` · `/previous` | vor- und zurückblättern |
| `PUT /api/v1/apps/order` | was läuft und in welcher Reihenfolge |
| `PUT /api/v1/apps/pushed/{name}` | eine Anzeige anlegen oder ersetzen |
| `DELETE /api/v1/apps/{name}` | eine Anzeige löschen, gleich welcher Gattung |
| `GET` / `PUT /api/v1/apps/script/{name}` | Berry-Quelltext lesen (als `text/plain`) bzw. installieren |
| `GET` / `PATCH /api/v1/apps/{name}/config` | die Einstellungen, die ein Skript anbietet |
| `GET /api/v1/scripts/shared` | was die installierten Skripte einander veröffentlicht haben |
| `POST /api/v1/notifications` | die Schleife mit einer einmaligen Meldung unterbrechen |
| `DELETE /api/v1/notifications/active` | die gerade sichtbare Benachrichtigung wegnehmen |
| `DELETE /api/v1/notifications/{name}` | die benannte wegnehmen, wo immer sie in der Warteschlange steht |
| `PUT` / `DELETE /api/v1/indicators/{id}` | die drei Randpunkte |
| `GET /api/v1/audio` | Wiedergabezustand und Senderliste in einem Zug |
| `GET` / `PUT` / `DELETE /api/v1/audio/melodies[/{name}]` | Melodien |
| `GET` / `POST` / `DELETE /api/v1/audio/mp3[/{name}]` | MP3-Dateien |
| `POST /api/v1/audio/play` · `/stop` | abspielen, anhalten |
| `PUT /api/v1/audio/stations` | die ganze Senderliste ersetzen |
| `GET /api/v1/capabilities` | die Namenslisten dieses Baus — abzufragen, statt Namen fest einzutragen |
| `GET /api/v1/system` | 64 der 67 Konfigurationsfelder; der JSON-Schlüssel ist jeweils der Feldname |
| `PUT /api/v1/system` | teilweises Zusammenführen, alles geprüft, die GPIO-Belegung als Ganzes |
| `GET /api/v1/system/wifi-scan` | WLAN-Suche, asynchron — abzufragen |
| `GET /api/v1/logs` | das fortlaufende Geräteprotokoll hinter der Web-Konsole |
| `GET` / `POST` / `DELETE /api/v1/files` | die Dateiablage |
| `POST /update` | Firmware einspielen (`multipart/form-data`) |
| `POST /api/v1/restore` | eine Sicherung einspielen (`.zip`, unkomprimiert) |
| `GET /` | die eingebettete Web-Oberfläche, gzip-gepackt |
| `GET /ICONS/*`, `/MELODIES/*`, `/PALETTES/*`, `/MP3/*`, `/SCRIPTS/*`, `/apploop.json` | statische Dateien aus LittleFS, **nur `GET`** |

📄 Löschen über `DELETE /api/v1/files` ist auf `/ICONS`, `/MELODIES`,
`/PALETTES` und `/MP3` beschränkt.

---

## 5. Die Nutzlast einer Anzeige

📄 Dieselbe Form gilt für `PUT /api/v1/apps/pushed/{name}` und
`POST /api/v1/notifications` — und damit auch für `cmd/apps/pushed/<name>` und
`cmd/notify`.

📄 **Der Name einer Anzeige kommt aus dem Pfad, nie aus dem Rumpf.** Er muss
`[A-Za-z0-9_-]{1,32}` erfüllen und wird geprüft, bevor die Nutzlast gelesen
wird; ein falscher Name ist `400 invalidName`. Jede andere Methode als `PUT` auf
`/api/v1/apps/pushed/{name}` ist `405 methodNotAllowed`.

📄 Eine Anzeige liegt **im RAM**, bis sie ersetzt, gelöscht, von `lifetimeMs`
eingezogen wird oder das Gerät neu startet. Für sie wird nichts in den Flash
geschrieben.

📄 **Ein leerer Rumpf oder `{}` auf `PUT` löscht nicht**, sondern antwortet
`422` und verweist auf `DELETE /api/v1/apps/{name}`. Über MQTT ist es
umgekehrt: dort löscht genau das.

### 5.1 Text

| Schlüssel | Typ | Bereich | Vorgabe | Bedeutung |
|---|---|---|---|---|
| `text` | string \| Feld | — | `""` | der Text, oder ein Feld eingefärbter Stücke |
| `textCase` | string | `inherit` · `upper` · `asTyped` | `inherit` | Schreibweise; `inherit` folgt der globalen Einstellung `uppercase` |
| `font` | string | `small` · `large` | `small` | die Panelschrift. `large` ist sieben Zeilen hoch und reicht bis zur obersten Zeile |
| `textColor` | Farbe \| `"palette"` | — | globales `textColor` (`#FFFFFF`) | Textfarbe, oder aus der Palette der Anzeige malen |
| `textBlinkMs` | int | ms, 0 = aus | `0` | Blinkdauer |
| `textFadeMs` | int | ms, 0 = aus | `0` | sinusförmige Auf- und Abblendung |
| `textCenter` | bool | — | `true` | Text, der passt, mittig setzen; `false` linksbündig |
| `scroll` | Objekt \| string | siehe 5.2 | geerbt | Textbewegung |
| `textOffsetX` | int | px | `0` | Verschiebung nach der Ausrichtung |
| `textInFront` | bool | — | `false` | nur Zeichenreihenfolge |

📄 **Die Grundlinie liegt fest auf Zeile 6**; eine senkrechte Steuerung gibt es
nicht. `textInFront` setzt nur die Reihenfolge: `true` malt erst die Dekoration
(Zeichenbefehle, Fortschrittsbalken, Diagramme) und den Text darüber, die
Vorgabe `false` umgekehrt.

📄 `textCenter` wirkt nur, solange der Text **nicht** läuft — also bei
`scroll.mode: "static"` oder wenn er passt und `scroll.whenFits` auf `static`
steht. Mittig gesetzt wird dann der Raum rechts der Icon-Spalte (oder das ganze
Panel, wenn kein Icon da ist); über das Icon läuft der Text nie.
`textOffsetX` wird im ruhenden Fall auf das fertige x addiert und geht in
**jeden** Ankerpunkt einer Laufbewegung ein.

📄 `text` wird aus UTF-8 in die Codepage der Matrixschrift gefaltet:
**Latin-1-Akzente, Latin Extended-A, `€` und Kyrillisch haben eigene Glyphen.**
Ein Zeichen ohne Abbildung — ein Emoji, eine nicht unterstützte Schrift — wird
zu **genau einem `?`**, eines je verlorenem Zeichen, nicht je Byte. Eine Zahl
oder ein bool als `text` wird stillschweigend übergangen und der Text bleibt
leer. **Einen Kleinbuchstabenmodus gibt es nicht.**

🔬 Am gemessenen Gerät steht die globale Einstellung `uppercase` auf `true`.

📄 **Eingefärbte Stücke:** Statt einer Zeichenkette nimmt `text` ein Feld von
`{"text": string, "color": Farbe}`. Die Stücke werden von links nach rechts
gezeichnet, jedes um seine eigene Breite vorrückend; eine Obergrenze ihrer Zahl
gibt es nicht. Fehlt `text` oder ist es keine Zeichenkette, wird es `""`; ein
Stück ohne `color` ist weiß. Bei einem Stückfeld wird das oberste `textColor`
übergangen — außer es steht auf `"palette"`, was den ganzen Lauf aus der
Palette malt und die Stückfarben übergeht. `textBlinkMs`, `textFadeMs`,
`textCase` und `uppercase` wirken in beiden Fällen.

📄 **Welche Farbgebung gewinnt**, in dieser Reihenfolge geprüft:

| Rang | Bedingung | Ergebnis |
|---|---|---|
| 1 | `textColor: "palette"` bei gesetzter `palette` | Verlauf über den Text; `textBlinkMs`/`textFadeMs` **werden übergangen** |
| 2 | `textFadeMs > 0` | weiches Pulsen der aufgelösten Farbe |
| 3 | `textBlinkMs > 0` | Blinken der aufgelösten Farbe |
| 4 | — | `textColor`, sonst das globale `textColor` |

### 5.2 Laufschrift

📄 `scroll` nimmt ein Objekt aus sieben unabhängigen Feldern:

| Feld | Typ | Bereich | Vorgabe | Bedeutung |
|---|---|---|---|---|
| `mode` | string | `static` · `wrap` · `loop` · `bounce` | `wrap` | Bewegungsart |
| `direction` | string | `left` · `right` | `left` | Laufrichtung |
| `entry` | string | `inline` · `offscreen` | `inline` | ruhend auf dem Panel beginnen oder von außen einlaufen |
| `whenFits` | string | `static` · `scroll` | `static` | ob Text, der ohnehin passt, sich trotzdem bewegt |
| `speed` | int | ≥ 0 | `100` | Prozent der Grundgeschwindigkeit |
| `gap` | int | ≥ 0 | `8` | nur `loop` — Pixel zwischen den Wiederholungen |
| `holdMs` | int | ≥ 0 | `1000` | Pause vor dem Anlaufen und an jedem Wendepunkt von `bounce` |

| `mode` | Bewegung | Durchlauf gezählt | Pause |
|---|---|---|---|
| `static` | keine; der Text steht an seiner Ausrichtung, Überhang wird abgeschnitten | nie | — |
| `wrap` | läuft vom Startanker, bis er ganz hinausgelaufen ist, dann Sprung zurück | je Auslauf | am Startanker, in jedem Durchlauf |
| `loop` | fortlaufend; eine frische Kopie schiebt sich `gap` Pixel hinter der letzten nach, das Bild ist nie leer | je Faltung | nur zu Beginn |
| `bounce` | pendelt zwischen der Ruhelage neben dem Icon (oder am linken Rand) und dem Anschlag am anderen Rand | je Hin und Zurück | an **beiden** Wendepunkten |

### 5.3 Icon

| Schlüssel | Typ | Vorgabe | Bedeutung |
|---|---|---|---|
| `icon` | string | `""` | Kennung, oder Base64 unmittelbar im Text, sobald es länger als 64 Zeichen ist |
| `iconMode` | string | `fixed` | `fixed` · `pushOnce` · `push` |
| `iconOffsetX` | int | `0` | Verschiebung, nur X |

📄 **Die Betriebsart entscheidet allein die Länge:**

- **höchstens 64 Zeichen** — eine Kennung, die gegen das Dateisystem aufgelöst
  wird: zuerst `/ICONS/<id>.gif`, dann `/ICONS/<id>.jpg`;
- **mehr als 64 Zeichen** — Base64 unmittelbar im Text, entschlüsselt und
  beschnuppert: eine `GIF8`-Magie macht es zum GIF, sonst wird es als JPEG
  gelesen.

📄 Nur **JPEG und GIF**, kein PNG, kein BMP. Icons werden in den Zeilen 0–7
gezeichnet. Ein JPEG belegt immer 8×8 — ein größeres wird nicht abgewiesen,
gezeigt wird nur seine linke obere Ecke. Ein GIF behält seine eigene Breite bis
zu den vollen 32×8.

📄 Ein Icon, das schmaler ist als das Panel, **reserviert eine 9-px-Spalte**
(8 px Bild, 1 px Luft), die Text, Balken und Liniendiagramm einrückt. Ein GIF
über die vollen 32 px gilt statt dessen als **Hintergrund**: bei x=0 unter dem
Text gezeichnet, rückt nichts ein und ersetzt `backgroundColor` und jeden
`effect`. Ein fehlendes oder nicht lesbares Icon fällt auf die Anordnung ohne
Icon zurück, statt eine schwarze Spalte stehen zu lassen.

📄 Durchsichtige GIF-Pixel sind im **ersten** Bild einer Bewegung schwarz;
innerhalb der Bewegung behalten sie, was das vorige Bild dort gezeichnet hat.

📄 `iconMode`: `fixed` lässt das Icon stehen und den Text daran vorbeilaufen;
`pushOnce` lässt den Text es **einmal** nach links hinausschieben, danach bleibt
es weg und der Text beginnt wieder bei x=0; `push` holt es in jedem
Laufdurchgang zurück. Die Verschiebung wandert 0 → −9 px. `iconOffsetX` ändert
die reservierte Spalte nicht, schiebt das Icon also **unter** den Text.

### 5.4 Standzeit

| Schlüssel | Typ | Vorgabe | Bedeutung |
|---|---|---|---|
| `durationMs` | long | `0` | wie lange gezeigt wird; 0 oder weniger nimmt das globale `appDurationMs` (7000). Gilt für Anzeigen wie Benachrichtigungen |
| `lifetimeMs` | long | `0` | **nur Anzeigen** — nach dieser Zeit von selbst verfallen; 0 = nie |
| `lifetimeExpiry` | string | `remove` | `remove` · `mark` — was beim Verfall geschieht |
| `repeat` | int | `0` | wie oft laufender Text über das Bild zieht |

### 5.5 Hintergrund, Diagramme, Fortschritt, Effekt, Palette, Overlay

| Schlüssel | Typ | Bereich | Vorgabe | Bedeutung |
|---|---|---|---|---|
| `backgroundColor` | Farbe | — | fehlt → schwarz | einfarbige Füllung |
| `barChart` | Feld von int | höchstens 16 | `[]` | Balkendiagramm |
| `lineChart` | Feld von int | höchstens 16 | `[]` | Liniendiagramm |
| `chartAutoscale` | bool | — | `true` | auf das Maximum der Daten skalieren, sonst fest auf 8 |
| `chartColor` | Farbe | — | die aufgelöste Textfarbe | Balken und Linie |
| `progress` | int | Prozent, unter 0 = aus | `-1` | Füllstand |
| `progressColor` | Farbe | — | `#00FF00` | gefüllter Teil |
| `progressTrackColor` | Farbe | — | `#FFFFFF` | ungefüllter Teil |
| `effect` | string | Groß-/Kleinschreibung egal | `""` | bewegter Hintergrundeffekt |
| `effectSpeed` | float | 0.1–10.0 | `1.0` | Tempo des Effekts und des Overlays dieser Anzeige |
| `palette` | string \| Feld \| null | höchstens 16 Stützstellen | fehlt | eingebaute oder eigene Palette, oder eine Liste von Farbstufen |
| `paletteBlend` | bool | — | `true` | zwischen den 16 Einträgen überblenden; `false` gibt harte Bänder |
| `paletteSpan` | int | px, 0 = dehnen | `0` | Pixel je vollem Durchlauf beim Malen von Text |
| `paletteSpeed` | float | 0.0–10.0, 0 = stillstehend | `0` | Durchläufe je Sekunde beim Malen von Text |
| `overlay` | string | Groß-/Kleinschreibung egal | `""` | Wetter-Overlay über allem |

📄 Aus der Palette gemalt werden `textColor` (spaltenweise über den Text),
`chartColor` (je Balken nach seinem Wert) und `progressColor` (nach der
Position auf dem Balken).

### 5.6 Nur für Benachrichtigungen

📄 Diese Schlüssel nimmt **allein** `POST /api/v1/notifications` an; in einer
Anzeige sind sie `422 validationFailed`:

| Schlüssel | Typ | Vorgabe | Bedeutung |
|---|---|---|---|
| `name` | string | `""` | Bezeichnung zum späteren Wegnehmen; genau verglichen, URL-taugliche Zeichen verwenden |
| `hold` | bool | `false` | nie von selbst verfallen; bleibt, bis es weggenommen wird |
| `stack` | bool | `true` | hinter den bestehenden anstellen, sonst die sichtbare ersetzen |
| `wakeup` | bool | `false` | auch bei abgeschaltetem Panel zeichnen |
| `sound` | string \| int | `""` | ein Name: ein abgelegtes MP3, sonst eine Melodie, sonst eine DFPlayer-Spur |
| `soundRtttl` | string | `""` | RTTTL-Melodie unmittelbar im Text |

### 5.7 Felder als Nutzlast

📄 Ein **Feld** an `PUT /api/v1/apps/pushed/{name}` legt durchnummerierte
Anzeigen `<name>0`, `<name>1`, … an — eine je Objekt-Element; Elemente, die
keine Objekte sind, werden übersprungen, ohne eine Nummer zu verbrauchen.
`DELETE /api/v1/apps/{name}` löscht den genauen Namen **und** die so
entstandenen nummerierten Anzeigen; eine, die man selbst unter `<name>1`
abgelegt hat, ist eine eigene Anzeige und bleibt. Ein Feld gilt ganz oder gar
nicht: Verstößt ein Element gegen eine Regel oder passt der Stapel nicht unter
die Obergrenze, wird die ganze Anfrage abgewiesen und keine einzige Anzeige
angelegt oder geändert.

📄 Ein Feld an `POST /api/v1/notifications` darf **höchstens ein** Element
halten; mehr ist `422 validationFailed`, und nichts wird eingereiht.

### 5.8 Wie die Fehler benannt sind

| Lage | Antwort |
|---|---|
| Rumpf ist kein gültiges JSON | `400 invalidJson` |
| Rumpf über 8192 Byte | `413 payloadTooLarge` |
| unbekannter oberster Schlüssel | `422 validationFailed`, `field` = der Schlüssel |
| unlesbare Farbe, an welcher Stelle auch immer | `422 validationFailed`, `field` = der Schlüssel |
| ein Modus-Schlüssel mit einem Wort außerhalb seiner Liste | `422 validationFailed`, `field` = der Schlüssel |
| unbekannter `effect`- oder `overlay`-Name | `422 validationFailed`, `field` = `effect` / `overlay` |
| unbekannter Zeichenbefehl | `422 validationFailed`, `field` = `draw[<i>]` |
| ein `draw`-Element, das kein Feld ist | `422 validationFailed`, `field` = `draw[<i>]` |
| falsche Argumentzahl eines Zeichenbefehls | `422 validationFailed`, `field` = `draw[<i>]` |
| nicht numerische Koordinate, Größe oder Radius | `422 validationFailed`, `field` = `draw[<i>]` |
| `pixels` mit einer ungeraden Koordinate am Ende | `422 validationFailed`, `field` = `draw[<i>]` |

---

## 6. Die Zeichenbefehle

📄 `draw` ist ein **Feld von Feldern**, jedes mit dem Namen des Befehls zuerst.
Gezeichnet wird in der Reihenfolge des Feldes.

| Befehl | Argumente |
|---|---|
| `["pixel", x, y, farbe]` | ein Pixel |
| `["pixels", farbe, x1, y1, x2, y2, …]` | viele Pixel in einer Farbe |
| `["line", x1, y1, x2, y2, farbe]` | beide Endpunkte eingeschlossen |
| `["rect", x, y, w, h, farbe]` | Umriss, 1 px, spannt `x` … `x+w-1` |
| `["rectFill", x, y, w, h, farbe]` | gefüllt |
| `["circle", cx, cy, r, farbe]` | Mittelpunkt und Radius |
| `["circleFill", cx, cy, r, farbe]` | gefüllt |
| `["text", x, y, "HI", farbe]` | Grundlinie bei `y + 5` |
| `["bitmap", x, y, w, h, daten]` | `daten` ist Base64-RGB888 oder ein Feld von Farben |

📄 Die abschließende Farbe darf **fehlen**; der Befehl nimmt dann die Textfarbe
der Anzeige. `pixels` trägt seine Farbe **zuerst**, wo `null` dasselbe bedeutet.
Pixel außerhalb der Leinwand fallen weg und werden nie umgebrochen. Ein `w` oder
`h` von null oder weniger zeichnet nichts, ebenso ein negativer Radius; ein
Radius `0` zeichnet den Mittelpunkt. Ein zu kurzes `bitmap` lässt die restlichen
Zellen ungezeichnet, überzählige Einträge werden übergangen.

📄 `bitmap`-Daten kommen in zwei austauschbaren Formen: als **Feld von w × h
Farben**, zeilenweise, in jeder der Farbformen aus §1 — oder als
**Base64-Zeichenkette von w × h × 3 rohen RGB888-Bytes**. Die Base64-Form ist
bei großen Bildern weit kürzer.

📄 Das `text` der Zeichenbefehle ist UTF-8 wie das der Anzeige und wird in deren
`font` gesetzt, ist aber **unbeeinflusst** von `textCase`, `palette`,
`textBlinkMs`, `textFadeMs`, `textCenter` und der globalen Einstellung
`uppercase`.

📄 Die Zahl der Befehle ist allein durch die 8192 Byte des Rumpfes begrenzt.

```bash
curl -X PUT http://<awtrix-ip>/api/v1/apps/pushed/art \
  -H 'Content-Type: application/json' \
  -d '{"draw":[
        ["rect",0,0,32,8,"#202020"],
        ["circleFill",4,4,2,"#F00"],
        ["text",9,1,"HI"]
      ]}'
```

📄 **Die Reihenfolge, in der ein Bild entsteht:**

1. **Hintergrund** — der Effekt, wenn `effect` auflöst, sonst ein Löschen auf
   `backgroundColor` oder Schwarz.
2. **Text und Dekoration** — bei `textInFront` erst die Dekoration, dann der
   Text; sonst umgekehrt. Die Dekoration ist immer `draw` → `progress` →
   `barChart` → `lineChart`.
3. **Icon** — Zeilen 0–7, bei `iconOffsetX` zuzüglich der Verschiebung aus
   `iconMode`.
4. **Overlay** — das der Anzeige, sonst das globale.
5. **Verfallsmarke** — ein dunkelroter Rahmen, wenn eine Anzeige mit
   `lifetimeExpiry: "mark"` verfallen ist. Vor Icon und Overlay gezeichnet, die
   also darüber malen.

---

## 7. Was das Gerät über sich selbst herausgibt

### 7.1 `GET /api/v1/device` und `<P>/state/device`

🔬 Am gemessenen Gerät:

```json
{"version":"1.1.0","uid":"<MAC, 12 Hex>","boardType":"awtrixng","soc":"esp32",
 "ipAddress":"<IP>","hostname":"<Hostname>","wifiRssi":-75,
 "uptimeSeconds":167,"freeHeapBytes":84160,"minFreeHeapBytes":16016,
 "largestFreeBlockBytes":77812,"scriptingRunning":true,
 "scriptHeapPool":"internal","scriptHeapBudgetBytes":98304,
 "resetReason":"poweron","fps":42,"brightness":84,"lightLevel":61.7,
 "ldrRaw":2527,"batteryPercent":74,"batteryVoltage":3.97,
 "batteryPinMillivolts":2219,"lowBattery":false,"temperature":18.6,
 "humidity":42.8,"matrixPower":true,"currentApp":"Time",
 "indicators":[{"on":false,"color":"#000000","blinkMs":0,"fadeMs":0}, …],
 "messageCount":0,
 "wifi":{"enabled":true,"state":"connected","host":"<WLAN>", …},
 "mqtt":{"enabled":true,"state":"offline","host":"<Broker>",
         "endpoint":"<Broker>:1883","attempts":6,"retryInMs":3871,
         "connects":0,"error":"badCredentials","lastError":"badCredentials"}}
```

Kennungen, Adressen und Namen sind ersetzt; die Zahlenwerte stehen so, wie das
Geraet sie gemeldet hat.

📄 Ob das Gerät am Broker hängt und warum nicht, steht unter `mqtt` in dieser
Antwort.

### 7.2 `GET /api/v1/apps`

🔬 Je App `name`, `enabled`, `inLoop`, `slot`, `present` und `origin`:

```json
[{"name":"Time","enabled":true,"inLoop":true,"slot":0,"present":true,"origin":"builtin"},
 {"name":"Battery","enabled":true,"inLoop":true,"slot":1,"present":true,"origin":"builtin"},
 {"name":"Date","enabled":false,"inLoop":false,"slot":null,"present":true,"origin":"builtin"}]
```

📄 `origin` ist eines von `builtin`, `pushed`, `script`, `module`. Zuerst stehen
die angeordneten Apps in ihrer Reihenfolge, dann alles übrige.

### 7.3 `GET /api/v1/display/screen` und `<P>/state/screen`

📄 `pixels` ist ein flaches Feld gepackter RGB-Ganzzahlen (`0xRRGGBB` als
vorzeichenlose Dezimalzahl), `width × height` Einträge — **die tatsächlichen
Pixel des Bildspeichers**, nicht die Nutzlast, die sie erzeugt hat.

🔬 Am gemessenen Gerät `{"width":32,"height":8,"pixels":[…]}` mit 256 Werten.

Über MQTT ist das Thema **nicht aufbewahrt** und wird nur als Antwort auf
`cmd/screen/get` veröffentlicht.

### 7.4 Die übrigen Auskünfte

📄 `GET /api/v1/settings` — 40 Anzeigeeinstellungen, jede immer vorhanden.
`GET /api/v1/system` — 64 der 67 Konfigurationsfelder, darunter `panelWidth`,
`panels`, `mqttPrefix`, `hostname`, die Pinbelegung.
`GET /api/v1/capabilities` — die Namen der Effekte, Paletteneffekte, Übergänge,
Overlays und Paletten dieses Baus, dazu die GPIO-Karte; abzufragen, statt Namen
fest einzutragen.
`GET /api/v1/logs` — das fortlaufende Geräteprotokoll.
`GET /api/v1/files` — die Dateiablage mit `usedBytes` und `totalBytes`.
`GET /api/v1/audio` — Wiedergabezustand und Senderliste.

🔬 `GET /api/v1/capabilities` nennt am gemessenen Gerät 19 Effekte, 22
Übergänge, 6 Overlays und die acht eingebauten Paletten (`Cloud`, `Lava`,
`Ocean`, `Forest`, `Stripe`, `Party`, `Heat`, `Rainbow`).

---

## 8. Die Grenzen

📄 Alles, was das Gerät erzwingt, und was es am Rand antwortet:

| Grenze | Wert | Am Rand |
|---|---|---|
| JSON-Rumpf über HTTP | **8192 Byte** | `413 payloadTooLarge`, nichts wird angewandt |
| MQTT-Kommandonutzlast | **8192 Byte** | **verworfen, bevor sie gelesen wird: kein Fehler, keine `/result`-Antwort** |
| Verschachtelung im JSON | 16 Ebenen | tiefer ist der Rumpf ungültig — `400 invalidJson` |
| Namen von Anzeigen und Skripten | 1–32 Zeichen aus `A–Z`, `a–z`, `0–9`, `_`, `-` | `400 invalidName` |
| Anzeigen gleichzeitig im Gerät | **50** | `507 insufficientStorage`, nichts wird abgelegt |
| Warteschlange der Benachrichtigungen | 32, die sichtbare mitgezählt | gestapelt: `507`; `stack: false` ersetzt die sichtbare und wird nie abgewiesen |
| Benachrichtigungen je Anfrage | 1 | `422 validationFailed` |
| Punkte in `barChart` / `lineChart` | 16 | der 17. und alle weiteren fallen weg, gezeichnet wird trotzdem |
| **Panelbreite** | `panelWidth × panels`, Vorgabe `32 × 1`, muss **32–128** ergeben | `422 validationFailed` auf `panelWidth` |
| **Panelhöhe** | **8 Pixel** | fest, nicht einstellbar |
| Leinwand für Icons | **32×8**, unabhängig von der Panelbreite | ein GIF, dessen **erstes** Bild größer ist, spielt gar nicht; ist ein späteres größer, endet das Entschlüsseln dort und die bis dahin gelesenen Bilder laufen in Schleife |
| Dateiablage | der freie Platz: **512 KB** auf einer 4-MB-Platine, 4,5 MB auf 8 MB, 12,5 MB auf 16 MB | `500 internalError`, keine halbe Datei bleibt zurück |
| Skriptquelle | `scriptMaxBytes`, Vorgabe 16384, Bereich 1024–32768 | `413 payloadTooLarge`, nie abgeschnitten |
| Skripte installiert | `scriptLimit`, Vorgabe 16, Bereich 0–32 | `507` |
| Melodie, Sender, MP3 | Quelltext 512 Zeichen, 32 Sender, Name 1–24 bzw. 1–32 Zeichen | `422 validationFailed` |

🔬 **Wie weit die 8192 Byte in der Praxis weg sind** (gemessen am 14.09.2026
mit dem Rahmenbau dieser App):

| Nutzlast | ganze Nachricht |
|---|---|
| Text, 1 000 Zeichen | 1 096 Byte |
| Text, 7 900 Zeichen | 7 996 Byte — **8 096 Zeichen ist die Grenze** |
| Text mit Umlauten, 5 600 Zeichen | 7 296 Byte (zwei Byte je Umlaut) |
| animiertes 32×8-Icon, 20 Bilder | 1 402 Byte |
| animiertes 32×8-Icon, 80 Bilder | 5 042 Byte — rund **130 Bilder** wären die Grenze |

Die Leinwand für Icons ist fest 32×8 (§1), größer geht also gar nicht. Für
gewöhnliche Anzeigen ist die Grenze damit unerreichbar; wer sie reißt, hat es
darauf angelegt.

📄 Die **50** zählt nur **neue** Namen: Eine vorhandene Anzeige zu ersetzen
gelingt immer, was der Zähler auch sagt.

📄 **Nicht begrenzt sind:** Anfragen je Sekunde — weder über HTTP noch über
MQTT wird gedrosselt; und was das Gerät veröffentlicht — `state/device` und
`state/screen` gehen heraus, so groß sie sind.

🔬 Am gemessenen Gerät meldet `GET /api/v1/files` `"usedBytes":102400,
"totalBytes":524288`, und `GET /api/v1/system` führt `scriptMaxBytes: 16384`
und `scriptLimit: 16`.

---

## 9. Was nicht dasteht

- ❓ **Ob `mqttPrefix` auf die MQTT-Platzhalter `#` und `+` geprüft wird.** Die
  Schlüsseltabelle nennt für `mqttPrefix` weder Zeichenvorrat noch Bereich, und
  prüfen ließe es sich nur, indem man die Einstellung ändert.
- ❓ **Die Höhe der Schrift `small`.** Von `large` heißt es, sie sei sieben
  Zeilen hoch und reiche bis zur obersten Zeile; zu `small` steht keine Höhe da.
  Weitere Schriften als diese beiden Namen gibt es nicht.
- ❓ **Eine MQTT-Route, die die Liste der Anzeigen ausgibt.** Es gibt keine;
  das Inventar ist ausdrücklich nur über `GET /api/v1/apps` zu haben.
