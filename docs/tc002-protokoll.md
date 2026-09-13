# Die Ulanzi TC002 fernsteuern

*[English version](en/tc002-protocol.md)*

Was das Gerät kann und wie man es anspricht — über MQTT und über HTTP. Diese
Beschreibung ist von unserer App unabhängig: sie gilt genauso für `mosquitto_pub`,
Node-RED, Home Assistant oder ein eigenes Skript. Wie man dieselben Dinge **in der
App** bedient, steht in deren Hilfe (⌘?).

Jede Angabe trägt ihre Herkunft:

| Zeichen | Bedeutung |
|---|---|
| ✅ | am Gerät selbst nachgeprüft |
| 📘 | aus dem [Herstellerrepository](https://github.com/UlanziTechnology/Ulanzi-U-Clock-TC002), nicht gegengeprüft |
| ❓ | offen — Vermutung, noch nicht belegt |

**Alle Angaben beziehen sich auf die Firmware `mcuVer V1.0.17`, `appVer 1.1.1`**
(Stand 11.09.2026, ablesbar über `/getBase`, siehe §5.1). Manches, was hier als
❌ steht, ist womöglich schlicht ein Fehler und in einer späteren Fassung
behoben — namentlich, dass der `text`-Befehl nicht scrollt (§4.3) und dass ein
leerer HTTP-Rumpf nicht löscht (§5.6). Wer mit neuerer Firmware arbeitet und
etwas anders vorfindet: Die Prüfungen dazu stehen jeweils dabei und sind in
wenigen Minuten zu wiederholen.

---

## 1. Das Display

✅ **52 Pixel breit, 16 hoch.** Der Ursprung liegt **oben links**, x wächst nach
rechts, y nach unten. Farben durchgehend als `"#RRGGBB"`.

✅ **Die eingebaute Schrift kennt keine Umlaute.** Kleinbuchstaben gehen, Ziffern
gehen; von den Satzzeichen sind nur `%`, `.`, `-` und `:` vorhanden. Alles andere
fehlt ersatzlos — das Gerät zeigt an der Stelle nichts an und meldet auch nichts.
Wer „Grüße" schreiben will, muss den Text selbst in Pixel wandeln und als
`draw` schicken (siehe §4.1).

❓ Ob die Schrift **Großbuchstaben** kennt, ist nicht nachgeprüft — belegt sind
nur Kleinbuchstaben und Ziffern. Prüfung: `"content":"ABC abc"` schicken und
hinsehen.

---

## 2. Das Themen-Präfix — die häufigste Fehlerquelle

✅ **Das Präfix, unter dem das Gerät lauscht, ist nicht das, was in der App
Ulanzi Studio eingetragen ist.** Die Firmware hängt die **letzten vier Stellen der
MAC-Adresse** an, getrennt durch einen Unterstrich:

```
eingetragen:  awtrix
MAC:          aa:bb:cc:dd:a8:6b
tatsächlich:  awtrix_a86b
```

📘 Ohne Zutun steht `ulanzi` darin, das Gerät lauscht also auf `ulanzi_xxxx`.

Nirgends in der Bedienoberfläche steht dieses vollständige Präfix. **Ermitteln
lässt es sich nur über HTTP** (§5.2 und §5.1) oder daran, welche Themen das Gerät
beim Broker abonniert:

```bash
# im Broker-Protokoll erscheint beim Verbinden des Geräts:
#   Received SUBSCRIBE from awtrix
#     awtrix_a86b/# (QoS 0)
```

✅ **Ein Platzhalter im eingetragenen Präfix macht das Gerät unbrauchbar.** Steht
dort `#` oder `+`, baut die Firmware ein ungültiges CONNECT-Paket; der Broker
protokolliert `bad socket read/write: Invalid input` und weist die Verbindung ab.

> ✅ **Warum falsche Präfixe so schwer zu finden sind:** MQTT 3.1.1 hat **keinen
> Rückkanal für eine abgelehnte Veröffentlichung**. Wer auf ein Thema schreibt,
> für das sein Konto keine Rechte hat, oder auf ein Präfix, das niemand
> abonniert, bekommt trotzdem ein sauberes `PUBACK`-freies QoS-0-Ende: kein
> Fehler, keine Warnung, nichts. Erst MQTT 5 kennt dafür Begründungscodes.
> Diese Stille ist der Grund, warum die Präfix-Eigenheit oben Stunden kostet.

---

## 3. Die MQTT-Themen

Es gibt zwei, beide unterhalb des Präfixes aus §2.

### 3.1 `<präfix>/custom/<name>` — eine benannte Anzeige setzen

✅ Die Nutzlast ist das Rahmen-JSON aus §4. `<name>` wählt man frei; er ist der
Bezeichner, unter dem die Anzeige danach existiert. Dieselbe Anzeige erneut
beschicken heißt: sie ersetzen.

```bash
mosquitto_pub -h 192.168.1.10 -u konto -P kennwort \
  -t 'awtrix_a86b/custom/notiz' \
  -m '{"text":[{"content":"hallo","fontHeight":10,"x":0,"y":3,"color":"#00FF66","align":"left","valign":"top","rect":[0,0,52,16],"charSpacing":1}]}'
```

### 3.2 `<präfix>/custom/<name>` mit leerer Nutzlast — die Anzeige löschen

✅ **Genau null Bytes**, nicht `""` und nicht `{}`:

```bash
mosquitto_pub -h 192.168.1.10 -u konto -P kennwort \
  -t 'awtrix_a86b/custom/notiz' -n
```

Die Anzeige verschwindet vom Gerät und aus dem Seitenwechsel.

Über HTTP ist es umgekehrt: Dort löscht der Rumpf `{}`, und ein leerer Rumpf
tut nichts (§5.6). Wer beide Wege benutzt, verwechselt das leicht.

> ✅ **Eine stehende Anzeige blockiert.** Solange eine benannte Anzeige gezeigt
> wird, bleibt sie stehen; neue Nachrichten unter demselben Präfix wirken nicht
> sichtbar, bis die stehende Anzeige gelöscht wird. Wer nacheinander
> verschiedene Dinge zeigen will, löscht also entweder vorher oder schreibt auf
> **dieselbe** Anzeige (was sie ersetzt).

### 3.3 `<präfix>/switchDiyApp` — auf eine Anzeige umschalten

✅ Nutzlast ist der bloße Name, kein JSON:

```bash
mosquitto_pub -h 192.168.1.10 -u konto -P kennwort \
  -t 'awtrix_a86b/switchDiyApp' -m 'notiz'
```

Dieses Thema steht in **keiner** Hersteller-Doku. Belegt ist es daraus, dass das
Gerät es beim Broker abonniert, und daraus, dass Umschalten damit funktioniert.

Dasselbe geht ohne Broker: `POST /api/switchDiyApp?name=<name>` (§5.8). Der
HTTP-Weg antwortet dabei, dieser hier nicht — und über ihn ist auch belegt, dass
die Uhr wirklich auf die genannte Anzeige springt.

✅ **Eine Anzeige, die es nicht gibt, wird abgewiesen** — über HTTP mit
`{"code":404,"message":"custom app not found"}` (§5.8). Der Aufruf prüft also,
statt still nichts zu tun.

❓ Offen bleibt, wie sich **dieses** Thema in dem Fall verhält: Es antwortet
nicht.

### 3.4 `<präfix>/status` — meldet die Uhr sich selbst

✅ Die Uhr veröffentlicht hier `online`, solange sie am Broker hängt. Am
11.09.2026 im Broker beobachtet.

### 3.5 `<präfix>/customList` — welche Anzeigen die Uhr kennt

✅ **Die Uhr veröffentlicht ihre eigene Anzeigenliste.** Am 11.09.2026 im Broker
beobachtet:

```json
{"apps":[{"appName":"scrolltest"}],"count":1}
```

Das ist die Antwort auf „welche benannten Anzeigen gibt es gerade" — und zwar vom
Gerät selbst, nicht aus der Buchführung des Senders. Wer mehrere Werkzeuge
benutzt (diese App, Ulanzi Studio, PixDeck, `mosquitto_pub`), erfährt nur hier,
was wirklich auf der Uhr steht.

Dieselbe Auskunft gibt es **auch über HTTP**, auf Nachfrage statt auf gut
Glück: `GET /api/customList` (§5.7). Der Pfad `GET /customList` — ohne `/api` —
liefert nichts; das ist der ganze Unterschied und lange für einen Mangel der
Firmware gehalten worden.

✅ **Die Uhr meldet auch, was über HTTP entstanden ist.** Die Anzeige
`scrolltest` oben war über `POST /api/custom?name=scrolltest` (§5.6) angelegt
worden, ohne dass der Broker daran beteiligt war — und trotzdem steht sie in der
Liste, die die Uhr über MQTT veröffentlicht. Am 11.09.2026 so beobachtet.
`customList` ist damit wirklich der Zustand des Geräts und nicht die
Buchführung eines einzelnen Senders.

Daraus folgt zweierlei. Erstens: **Senden über HTTP und Zuhören über MQTT lässt
sich mischen.** Wer einen Broker hat, kann über HTTP schicken — dort gibt es
echte Fehlercodes statt der Stille aus §2 — und den Rückkanal trotzdem
behalten.

Zweitens: **Ein reiner HTTP-Betrieb ist möglich.** Anlegen und Löschen (§5.6),
Umschalten (§5.8) und die Anzeigenliste (§5.7) gehen ohne Broker, alle vier am
Gerät gemessen. Zwei Dinge bleiben MQTT vorbehalten: der **Inhalt** einer
Anzeige — den erfährt nur, wer die Sendung auf `custom` mitliest (§3.1) — und
die Meldung, ob die Uhr überhaupt online ist (§3.4).

Beide Themen stehen in **keiner** Hersteller-Doku.

❓ Ob die Uhr diese Themen **aufbewahrt** (`retain`) veröffentlicht, ist nicht
nachgeprüft. Es entscheidet, ob ein frisches Abonnement sofort einen Stand
bekommt oder bis zur nächsten Sendung der Uhr wartet. Prüfung:
`mosquitto_sub -v -t '<präfix>/#'` frisch starten — kommt sofort etwas, war es
aufbewahrt. (Ein Abonnent muss aufbewahrte Nachrichten ohnehin annehmen: sie
kommen mit gesetztem RETAIN-Bit, Kopfbyte `0x31` statt `0x30`.)

---

## 4. Das Rahmen-JSON

Ein Objekt mit bis zu vier Schlüsseln. **Leere Bestandteile weglassen** — das Gerät
stolpert über leere Felder.

```json
{
  "draw":  [ … ],
  "image": [ … ],
  "text":  [ … ],
  "duration": 10
}
```

### 4.1 `draw` — zeichnen

📘 Zwei Grundformen:

| Form | Bedeutung |
|---|---|
| `{"df":[x,y,breite,höhe,"#RRGGBB"]}` | gefülltes Rechteck |
| `{"dfc":[x,y,radius,"#RRGGBB"]}` | gefüllter Kreis |

✅ `df` mit Breite und Höhe `1` ist ein **einzelner Pixel** — damit lässt sich das
Display frei bemalen und, wichtiger, **Text mit Umlauten darstellen**, indem man
ihn selbst rastert und Pixel für Pixel schickt.

Ein grüner Punkt links oben und ein roter Balken darunter:

```json
{"draw":[{"df":[0,0,1,1,"#00FF66"]},{"df":[0,2,20,3,"#FF0000"]}]}
```

> **Nachrichtengröße.** Jeder Pixel einzeln wird schnell groß. Wer rastert, sollte
> waagrechte Läufe gleicher Farbe zu einem breiten `df` zusammenfassen; das
> verkleinert typische Textbilder um ein Vielfaches.

### 4.2 `image` — Bilder

✅ Ein Eintrag je Bild:

```json
{"image":[{"data":"data:image/gif;base64,R0lGODlh…","position":[0,4]}]}
```

- `data` — vollständige Daten-URI. `image/gif`, `image/jpeg` und `image/png` sind
  die gebräuchlichen Typen; die AWTRIX-Welt arbeitet fast durchgehend mit **8×8-GIF**.
- `position` — `[x, y]`, wieder oben links gerechnet.

✅ **Animierte GIFs spielt das Gerät ab**, nicht nur deren erstes Einzelbild.
Am 11.09.2026 am Gerät nachgeprüft — das Herstellerrepository sagt dasselbe.

❓ Nicht belegt: ob die Bildgröße beschränkt ist und was bei Bildern größer als
52×16 geschieht.

❓ Ebenfalls nicht belegt: ob **zwei `image`-Einträge im selben Rahmen**
nebeneinander gezeichnet werden oder der zweite den ersten ersetzt. Wer ein Icon
neben einem anderen Bild zeigen will, ist mit einem einzigen Bild, in das beides
hineingerechnet ist, auf der sicheren Seite.

### 4.2a Laufschrift als animiertes GIF — der Weg um beide Beschränkungen

✅ Am 11.09.2026 am Gerät bestätigt.

Das Gerät kennt zwei Wege, Text zu zeigen, und jeder hat eine Lücke:

| | `text` (§4.3) | `draw` selbst gerastert (§4.1) |
|---|---|---|
| Umlaute, Satzzeichen | ❌ | ✅ |
| freie Schriftart | ❌ | ✅ |
| langer Text laeuft durch | ✅ über `scrollSpeed` (§5.4) | ❌ ein `draw`-Rahmen ist starr |

**Beides zugleich geht über `image`:** Den Text in voller Breite selbst rastern,
daraus ein animiertes GIF bauen, in dem ein 52×16-Fenster Bild für Bild über den
Text wandert, und dieses GIF schicken. Das Gerät spielt es ab — der Text läuft,
und weil wir selbst gerastert haben, sind Umlaute und jede Schriftart dabei.

```
Text:    [ G r ü ß e   a u s   W i e n ]      (z. B. 120 Pixel breit)
Bild 1:  [      52-Pixel-Fenster      ]  Versatz -52
Bild 2:   [      52-Pixel-Fenster     ]  Versatz -51
…
Bild n:                  [   Fenster  ]  Versatz 120
```

Ein Einzelbild je Pixel Versatz ergibt einen weichen Lauf; jeder zweite oder
dritte Schritt spart Einzelbilder auf Kosten der Ruhe im Bild.

> ⚠️ **Die Uhr beherrscht nur das Entsorgungsverfahren 2.** Jedes Einzelbild
> eines animierten GIFs trägt eine Anweisung, was vor dem nächsten Bild mit dem
> Bildschirm geschehen soll. Verfahren **2** heißt „vorher löschen", Verfahren
> **1** heißt „stehenlassen und nur den geänderten Ausschnitt darüberzeichnen".
> Mit Verfahren 1 **fehlen auf der Uhr einzelne Pixel** — die Formen stimmen,
> aber es sind Löcher darin.
>
> Der Haken: Man wählt das Verfahren nicht selbst. `CGImageDestination` unter
> macOS leitet es daraus ab, ob die Einzelbilder durchsichtige Stellen haben.
> **Deckende Bilder ergeben Verfahren 1, durchsichtige ergeben Verfahren 2.**
> Wer ein Lauf-GIF baut, muss unbeleuchtete Pixel deshalb **durchsichtig**
> lassen statt sie schwarz zu malen — auf schwarzem Grund sieht beides gleich
> aus, für die Uhr ist es der Unterschied zwischen lesbar und löchrig.
>
> Am 11.09.2026 gemessen: dieselben 86 Einzelbilder, einmal deckend (Verfahren 1,
> löchrig), einmal durchsichtig (Verfahren 2, sauber). Nachsehen lässt sich das
> im dritten Byte jeder Grafiksteuer-Erweiterung (`0x21 0xF9`), Bits 2 bis 4.

❓ **Wo die Größengrenze liegt, ist offen.** Ein kurzer Satz geht nachweislich.
Ein langer Text braucht schnell mehrere hundert Einzelbilder, und die Nutzlast
wächst mit jedem davon — als Daten-URI zusätzlich um ein Drittel, weil Base64 so
rechnet. Wer das ausreizt, sollte sich an die Grenze herantasten, statt sie zu
erraten.

Dieser Weg steht in **keiner** Hersteller-Doku; er ergibt sich daraus, dass
`image` animierte GIFs annimmt (§4.2).

### 4.3 `text` — Text in der Gerätschrift

✅ Ein Eintrag je Textblock, alle Schlüssel belegt:

```json
{"text":[{
  "content": "12:45",
  "fontHeight": 10,
  "x": 0, "y": 3,
  "color": "#FFFFFF",
  "align": "left", "valign": "top",
  "rect": [0, 0, 52, 16],
  "charSpacing": 1
}]}
```

| Schlüssel | Bedeutung |
|---|---|
| `content` | der Text — **ohne Umlaute**, siehe §1 |
| `fontHeight` | Schrifthöhe in Pixeln |
| `x`, `y` | linke obere Ecke |
| `color` | `"#RRGGBB"` |
| `align` | waagrecht: `left`, `center`, `right` |
| `valign` | senkrecht: `top`, `middle`, `bottom` |
| `rect` | Fläche `[x, y, breite, höhe]`, in der ausgerichtet wird |
| `charSpacing` | Abstand zwischen den Zeichen in Pixeln |

> ❌ **`text` scrollt nicht.** Ein Text, der breiter ist als das Display, wird
> abgeschnitten — er läuft nicht durch, auch nicht bei `scrollSpeed` über null.
> Am 11.09.2026 mit drei Fassungen geprüft: mit `rect` und allen Feldern, ohne
> `rect`, und mit nichts als `content` und `color`. Keine davon lief.
>
> `scrollSpeed` (§5.4) gilt also offenbar nur für die Anzeigen, die das Gerät
> selbst verwaltet, nicht für eigene über `custom`.
>
> **Zwei Wege führen trotzdem zu laufendem Text:**
>
> 1. **Als animiertes GIF** (§4.2a). Eine Nachricht, danach läuft es von allein
>    weiter — auch wenn der Sender längst weg ist. Kann Umlaute. Kostet 10 bis
>    30 KB.
> 2. **Vom Sender getrieben.** Immer wieder derselbe `text`-Befehl mit
>    verändertem `x`, etwa alle 0,4 Sekunden. So macht es
>    [PixDeck](https://github.com/cailurus/PixDeck) in seinem `notice`-Modul.
>    Jede Nachricht ist winzig, aber die Bewegung hört auf, sobald der Sender
>    aufhört — und Umlaute gehen weiterhin nicht.
>
> Für eine Nachricht, die man hinschickt und vergisst, taugt der erste Weg; für
> eine ständig aktualisierte Laufschrift der zweite.

### 4.4 `duration` — Standzeit

📘 In **Sekunden**, wie lange diese Anzeige beim Blättern stehen bleibt.

❓ Offen: wie `duration` mit dem geräteweiten Seitenwechsel (§5.4,
`carouselSpeed`) zusammenwirkt — ob es ihn für diese eine Anzeige überschreibt
oder ob der kleinere der beiden Werte gewinnt.

---

## 5. Die HTTP-Schnittstelle

Das Gerät beantwortet HTTP auf Port 80. Die Hersteller-Doku führt MQTT als den
Fernsteuerungsweg, aber **HTTP trägt einen Betrieb für sich allein**: Anlegen
und Löschen (§5.6), Umschalten (§5.8) und die Anzeigenliste (§5.7) sind hier
ebenso zu haben. Umgekehrt ist HTTP der **einzige** Weg, das Themen-Präfix und
den Verbindungszustand zu erfahren, und der einzige, um Geräteeinstellungen zu
ändern.

Alle Abfragen sind `GET`, alle Befehle `POST`; nichts davon verlangt eine
Anmeldung.

### 5.1 `GET /getBase` — Gerätekennung

✅
```json
{"devSn":"TC002-TESTGERAET01","ssid":"heimnetz","ip":"192.168.1.20",
 "mac":"aabbccdda86b","mcuVer":"V1.0.17","appVer":"1.1.1"}
```

Aus `mac` kommen die vier Stellen für das Präfix (§2).

### 5.2 `GET /getMqttConfig` — was eingetragen ist

✅
```json
{"isMqtt":true,"ip":"192.168.1.10","port":"1883","mqtt_name":"awtrix",
 "mqtt_pwd":"…","mqtt_prefix":"awtrix","isHADiscoveryEnabled":false}
```

`mqtt_prefix` ist das **eingetragene**, nicht das wirksame Präfix — erst zusammen
mit `mac` aus §5.1 ergibt sich `awtrix_a86b`.

Bemerkenswert: Das Gerät gibt das MQTT-Kennwort im Klartext heraus, an jeden im
Netz, ohne Anmeldung.

### 5.3 `GET /getMqttStatus` — hängt es am Broker?

✅
```json
{"code":200,"data":{"enabled":true,"connected":true}}
```

`connected` ist die einzige verlässliche Antwort auf „warum kommt nichts an" —
sie unterscheidet „Gerät hängt nicht am Broker" von „Gerät hängt dran, aber mein
Präfix stimmt nicht".

### 5.4 `GET /getConfig` — Geräteeinstellungen

✅
```json
{"brightness":{"level":"high"},"volume":4,"carouselSpeed":0,"scrollSpeed":7}
```

| Feld | Bedeutung |
|---|---|
| `brightness.level` | Helligkeitsstufe |
| `volume` | Lautstärke des Weckers |
| `carouselSpeed` | ✅ **der Seitenwechsel.** `0` heißt: es wird nicht geblättert, die erste Anzeige bleibt stehen. Größer als null ist die Standzeit je Seite. |
| `scrollSpeed` | Lauftempo langer Texte — ❌ **nicht** für eigene Anzeigen über `custom`, siehe §4.3 |

✅ `carouselSpeed` ist die Antwort auf „warum sehe ich immer nur die erste
Meldung": ohne ihn zu setzen, blättert das Gerät nicht.

❓ `scrollSpeed` gilt nach eigener Lektüre für den `text`-Befehl (§4.3) — dort
scrollt langer Inhalt am Gerät durch. Für selbst gerasterte `draw`-Rahmen (§4.1)
gilt er **nicht**: ein `draw`-Rahmen ist ein starres Pixelraster ohne Scrollen,
gleich welchen Wert `scrollSpeed` hat. Diese Zuordnung ist begründete Annahme,
am Gerät nicht nachgeprüft — ebenso wenig der gültige Wertebereich.

### 5.5 `POST /setConfig` — Einstellungen ändern

✅ Mit dem **vollständigen** Konfigurationsobjekt angenommen und wirksam.
❓ Ob eine Teilangabe wie `{"carouselSpeed":20}` die übrigen Felder verliert oder
abgelehnt wird, ist nicht ausprobiert — die Firmware anderer Ulanzi-Geräte
verhält sich so, und der sichere Ablauf ist deshalb ohnehin: `/getConfig` lesen,
ein Feld ändern, alles zurückschicken.

```bash
K=$(curl -s http://192.168.1.20/getConfig \
    | python3 -c 'import json,sys; k=json.load(sys.stdin); k["carouselSpeed"]=20; print(json.dumps(k))')
curl -s -X POST http://192.168.1.20/setConfig -H 'Content-Type: application/json' -d "$K"
# {"code":200,"message":"Settings saved successfully"}
```

### 5.6 `POST /api/custom?name=<name>` — dasselbe ohne Broker

✅ Nimmt **dasselbe Rahmen-JSON** wie §3.1 entgegen und setzt dieselbe benannte
Anzeige — nur ohne Umweg über den Broker.

```bash
curl -s -X POST 'http://192.168.1.20/api/custom?name=notiz' \
  -H 'Content-Type: application/json' \
  -d '{"draw":[{"df":[0,0,4,4,"#00FF66"]}]}'
```

✅ **Die neue Anzeige erscheint sofort**, ohne Umschalten. Steht allerdings
schon eine andere, bleibt die stehen — dann führt nur `switchDiyApp` (§5.8)
weiter.

✅ **Löschen geht hierüber auch — mit dem Rumpf `{}`.** Am 13.09.2026 gemessen,
gegen `GET /api/customList` (§5.7) geprüft:

```bash
curl -s http://192.168.1.20/api/customList
# {"apps":["meldung2","meldung3","meldung1"],"count":3}

curl -s -X POST 'http://192.168.1.20/api/custom?name=probe' \
  -H 'Content-Type: application/json' -d '{"draw":[{"df":[0,0,8,8,"#FF0000"]}]}'
# {"code":200,"message":"ok"}   → die Liste nennt danach vier Anzeigen

curl -s -X POST 'http://192.168.1.20/api/custom?name=probe' \
  -H 'Content-Type: application/json' -d '{}'
# {"code":200,"message":"ok"}

curl -s http://192.168.1.20/api/customList
# {"apps":["meldung2","meldung3","meldung1"],"count":3}   → probe ist weg
```

> ❌ **Ein leerer Rumpf löscht nicht.** Er antwortet dasselbe
> `{"code":200,"message":"ok"}`, die Anzeige bleibt aber stehen — am 11.09.2026
> nachgeprüft. Die Falle liegt darin, dass über MQTT genau umgekehrt die **leere**
> Nutzlast löscht (§3.2) und `{}` dort nichts ausrichtet.

Diesen Weg geht [PixDeck](https://github.com/cailurus/PixDeck), und deshalb steht
im MQTT-Kapitel der Hersteller-Doku ein Programm empfohlen, das in Wahrheit über
HTTP arbeitet. Für ein Gerät im selben Netz ist das der kürzere Weg; über MQTT
geht es dagegen auch dann, wenn Sender und Uhr einander nicht direkt erreichen.

### 5.7 `GET /api/customList` — welche Anzeigen auf der Uhr stehen

✅ Nennt die benannten Anzeigen, die das Gerät gerade kennt — dieselbe Auskunft
wie das MQTT-Thema aus §3.5, nur auf Nachfrage und ohne Broker. Am 13.09.2026
gemessen:

```bash
curl -s http://192.168.1.20/api/customList
{"apps":["meldung2","meldung5","meldung3"],"count":3}
```

> ⚠️ **Der Pfad ist `/api/customList`.** `GET /customList` — ohne `/api` —
> liefert nichts.

Die Schreibweise weicht von §3.5 ab: Hier stehen bloße Zeichenketten, dort
Objekte mit `appName`. Gemeint ist dieselbe Liste.

Es sind **nur Namen**. Was auf einer Anzeige steht, verrät das Gerät auch
hierüber nicht — belegt oder frei ist damit gesichert, der Inhalt nicht.

### 5.8 `POST /api/switchDiyApp?name=<name>` — umschalten ohne Broker

✅ Der Aufruf wird angenommen, antwortet — und die Uhr springt darauf wirklich
auf die genannte Anzeige. Am 13.09.2026 gemessen:

```bash
curl -s -X POST 'http://192.168.1.20/api/switchDiyApp?name=meldung2'
{"code":200,"message":"app switch requested","data":{"name":"meldung2","index":100}}
```

Das ist das Gegenstück zum MQTT-Thema aus §3.3 — und auskunftsfreudiger: Dort
gibt es überhaupt keine Antwort, hier eine mit Namen und einer Zahl.

✅ **Die Wirkung ist gesehen, nicht bloß gemeldet.** „app switch **requested**"
ist die Wortwahl der Antwort, kein Vorbehalt. Gemessen am 13.09.2026 mit
abgeschaltetem Seitenwechsel (`carouselSpeed` `0`, §5.4), damit das Gerät nicht
von selbst weiterblättert — je Schritt am Display nachgesehen:

```bash
curl -s -X POST 'http://192.168.1.20/api/custom?name=probe' \
  -H 'Content-Type: application/json' -d '{"draw":[{"df":[0,0,52,16,"#FF0000"]}]}'
# {"code":200,"message":"ok"}
curl -s http://192.168.1.20/api/customList
# {"apps":["probe"],"count":1}            → die Uhr zeigt die rote Fläche sofort

curl -s -X POST 'http://192.168.1.20/api/custom?name=probe2' \
  -H 'Content-Type: application/json' -d '{"draw":[{"df":[0,0,52,16,"#00FF00"]}]}'
# {"code":200,"message":"ok"}
curl -s http://192.168.1.20/api/customList
# {"apps":["probe","probe2"],"count":2}   → die Uhr bleibt auf Rot

curl -s -X POST 'http://192.168.1.20/api/switchDiyApp?name=probe2'
# {"code":200,"message":"app switch requested","data":{"name":"probe2","index":111}}
#                                         → die Uhr wird grün
```

> ✅ **Eine neu angelegte Anzeige erscheint sofort**, ohne Umschalten.
>
> ✅ **Eine zweite übernimmt nicht.** Die erste bleibt stehen; wer die zweite
> sehen will, schaltet um. Für ein Nacheinander über HTTP heißt das:
> `switchDiyApp` schicken oder immer dieselbe Anzeige beschreiben (§5.6).

❓ Beides ist bei **abgeschaltetem** Seitenwechsel gemessen. Wie es sich
verhält, wenn die Uhr von selbst durch die Anzeigen blättert, ist unbelegt.

> ✅ **Eine Anzeige, die es nicht gibt, wird abgewiesen:**
> `{"code":404,"message":"custom app not found"}`. Der Endpunkt prüft den Namen
> und meldet einen echten Fehler.

> ❓ **`index` ist ungedeutet.** Beobachtet sind `100` und `111` — fest ist die
> Zahl also nicht. Was sie bedeutet, wissen wir nicht; sie ist hier
> abgeschrieben, nicht erklärt.

---

## 6. Wenn nichts erscheint

Der Reihe nach, vom Häufigsten zum Seltensten:

1. **Präfix.** `/getMqttConfig` und `/getBase` abfragen und zusammensetzen (§2).
   Beinahe immer liegt es hier.
2. **Hängt das Gerät überhaupt am Broker?** `/getMqttStatus` (§5.3).
3. **Darf das Konto auf das Thema schreiben?** Die Rechte stehen in der
   Rechtedatei des Brokers; bei Mosquitto meldet das Protokoll eine abgelehnte
   Veröffentlichung — der Sender selbst erfährt davon nichts (§2).
4. **Steht noch eine alte Anzeige?** Welche es gibt, sagt `GET /api/customList`
   (§5.7); weg damit über die leere MQTT-Nutzlast (§3.2) oder über HTTP mit dem
   Rumpf `{}` (§5.6).
5. **Blättert es nicht?** `carouselSpeed` ist `0` (§5.4).
6. **Fehlen Zeichen im Text?** Umlaute und die meisten Satzzeichen gibt es in der
   Gerätschrift nicht — als Pixel schicken (§1, §4.1).

---

## 7. Was hier noch fehlt

Ehrlich benannt, statt verschwiegen. Was davon nach einem Firmware-Update
erneut zu prüfen wäre, steht gesammelt in
[`firmware-beobachtungen.md`](firmware-beobachtungen.md).

- ❓ Wie `duration` und `carouselSpeed` zusammenwirken (§4.4).
- ❓ Wie sich das **MQTT**-Thema `switchDiyApp` bei einer nicht vorhandenen
  Anzeige verhält (§3.3) — über HTTP ist es belegt: `404 custom app not found`
  (§5.8).
- ❓ Was `index` in der Antwort von `POST /api/switchDiyApp` bedeutet.
  Beobachtet sind `100` und `111` (§5.8).
- ❓ Ob eine neu angelegte Anzeige auch bei **eingeschaltetem** Seitenwechsel
  sofort erscheint und eine zweite auch dann nicht übernimmt (§5.8).
- ❓ Ob die Gerätschrift Großbuchstaben kennt (§1).
- ❓ Ob `status` und `customList` aufbewahrt veröffentlicht werden (§3.5).
- ❓ Wie **groß** eine Nutzlast sein darf. Belegt ist, dass rund **14 KB**
  durchgehen (318 Einzelbilder, am 11.09.2026 gesendet und sauber angezeigt);
  wo die Grenze darüber liegt, hat niemand ausgereizt. Wer sie sucht, sollte
  vorher §4.2a gelesen haben — was wie eine Größengrenze aussieht, war dort in
  Wahrheit das Entsorgungsverfahren.
- ❓ Ob es **weitere** Themen unterhalb des Präfixes gibt. Das Gerät abonniert
  `<präfix>/#`, also alles. Drei sind gefunden (§3.1 bis §3.5), alle drei nur
  durch Hinsehen; welche es sonst noch auswertet, ist nicht dokumentiert.
- ❓ Ob und wie sich Wecker, Lautstärke und Helligkeit über MQTT statt über
  `/setConfig` setzen lassen.
