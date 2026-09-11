# Die Ulanzi TC002 fernsteuern

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

---

## 1. Das Display

✅ **52 Pixel breit, 16 hoch.** Der Ursprung liegt **oben links**, x wächst nach
rechts, y nach unten. Farben durchgehend als `"#RRGGBB"`.

✅ **Die eingebaute Schrift kennt keine Umlaute.** Kleinbuchstaben gehen, Ziffern
gehen; von den Satzzeichen sind nur `%`, `.`, `-` und `:` vorhanden. Alles andere
fehlt ersatzlos — das Gerät zeigt an der Stelle nichts an und meldet auch nichts.
Wer „Grüße" schreiben will, muss den Text selbst in Pixel wandeln und als
`draw` schicken (siehe §4.1).

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

❓ Offen: ob `switchDiyApp` auch greift, wenn die genannte Anzeige gar nicht
existiert oder nicht in der DIY-Liste des Geräts steht.

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

> ⚠️ **Es ist ein MQTT-Thema, kein HTTP-Endpunkt.** `GET /customList` liefert
> nichts. Lesen lässt es sich nur, indem man es beim Broker abonniert.

Beide Themen stehen in **keiner** Hersteller-Doku.

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

### 4.4 `duration` — Standzeit

📘 In **Sekunden**, wie lange diese Anzeige beim Blättern stehen bleibt.

❓ Offen: wie `duration` mit dem geräteweiten Seitenwechsel (§5.4,
`carouselSpeed`) zusammenwirkt — ob es ihn für diese eine Anzeige überschreibt
oder ob der kleinere der beiden Werte gewinnt.

---

## 5. Die HTTP-Schnittstelle

Das Gerät beantwortet HTTP auf Port 80. Diese Schnittstelle ist **nicht** der
Fernsteuerungsweg — dafür ist MQTT gedacht —, aber sie ist der **einzige** Weg, das
Themen-Präfix und den Verbindungszustand zu erfahren, und der einzige, um
Geräteeinstellungen zu ändern.

Alle Abfragen sind `GET` ohne Anmeldung.

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
| `scrollSpeed` | Lauftempo langer Texte |

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

Diesen Weg geht [PixDeck](https://github.com/cailurus/PixDeck), und deshalb steht
im MQTT-Kapitel der Hersteller-Doku ein Programm empfohlen, das in Wahrheit über
HTTP arbeitet. Für ein Gerät im selben Netz ist das der kürzere Weg; über MQTT
geht es dagegen auch dann, wenn Sender und Uhr einander nicht direkt erreichen.

---

## 6. Wenn nichts erscheint

Der Reihe nach, vom Häufigsten zum Seltensten:

1. **Präfix.** `/getMqttConfig` und `/getBase` abfragen und zusammensetzen (§2).
   Beinahe immer liegt es hier.
2. **Hängt das Gerät überhaupt am Broker?** `/getMqttStatus` (§5.3).
3. **Darf das Konto auf das Thema schreiben?** Die Rechte stehen in der
   Rechtedatei des Brokers; bei Mosquitto meldet das Protokoll eine abgelehnte
   Veröffentlichung — der Sender selbst erfährt davon nichts (§2).
4. **Steht noch eine alte Anzeige?** Erst mit leerer Nutzlast löschen (§3.2).
5. **Blättert es nicht?** `carouselSpeed` ist `0` (§5.4).
6. **Fehlen Zeichen im Text?** Umlaute und die meisten Satzzeichen gibt es in der
   Gerätschrift nicht — als Pixel schicken (§1, §4.1).

---

## 7. Was hier noch fehlt

Ehrlich benannt, statt verschwiegen:

- ❓ Wie `duration` und `carouselSpeed` zusammenwirken (§4.4).
- ❓ Ob `switchDiyApp` auf nicht vorhandene Anzeigen wirkt (§3.3).
- ❓ Wie **groß** eine Nutzlast sein darf. Dass animierte GIFs laufen, ist geklärt
  (§4.2); offen ist, wo die Grenze liegt. Das entscheidet, ob sich längerer Text
  als durchlaufendes GIF schicken lässt — der einzige Weg, Umlaute **und**
  Scrollen zugleich zu bekommen, denn `scrollSpeed` gilt nur für den
  Gerätetext (§5.4) und ein `draw`-Rahmen ist starr.
- ❓ Ob es weitere Themen unterhalb des Präfixes gibt. Das Gerät abonniert
  `<präfix>/#`, also alles; welche Namen es darunter auswertet, ist nicht
  dokumentiert, und `switchDiyApp` war selbst nur durch Hinsehen zu finden.
- ❓ Ob und wie sich Wecker, Lautstärke und Helligkeit über MQTT statt über
  `/setConfig` setzen lassen.
