# Funktionen je Uhr

Verbindlich: Was die App je Uhrenmodell anbietet, und woran sie es festmacht.
Die Fähigkeiten, die der Kern entscheidet, hält `Tests/TC002CoreTests/FunktionslisteTests.swift`
fest (die Tabelle und der Test verweisen aufeinander; wer eine Zeile ändert,
ändert beide). Die Messungen zur Schnittstelle stehen in
`docs/awtrix-ng-protokoll.md`; Beobachtungen, die bei einem Firmwarewechsel
nachzuprüfen sind, in `docs/firmware-beobachtungen.md`.

## Die Regel

Erik, 10. Oktober 2026: „Ausgrauen soll nur verwendet werden, wenn ein Feature
deaktiviert wurde, das ich aktivieren kann (z. B. Schrift der Uhr ein|aus).
Etwas, das an der Uhr nie funktionieren wird, wird einfach nicht angezeigt.“

| Fall | Oberfläche |
|---|---|
| Die Uhr kann es **nie** (Hardware oder Firmware: Fähigkeit `false` oder Schlüssel fehlt in der Antwort) | **nicht angezeigt**: keine graue Zeile, kein Hinweis |
| Es ist nur **abgeschaltet, und der Nutzer kann die Ursache selbst ändern** (Schalter wie „Schrift der Uhr“, Lichtsensor regelt die Helligkeit, keine Adresse eingetragen, MQTT-Funktion im HTTP-Betrieb) | **gesperrt, mit Grund** sichtbar |
| Die Uhr hat darüber **nichts gemeldet** (Fähigkeiten nie abgefragt, Schalter fehlt in `audio`) | **erlaubt**; die Prüfung vor dem Senden und die Uhr weisen Falsches ab |
| Mehrere Zieluhren, nur ein Teil kann es | bleibt, und die Meldung nennt die Uhren, bei denen es entfällt („… zeigt die Nachricht ohne Ton“); kann es **keine**, wird es nicht angezeigt |

Zwei gewollte Ausnahmen von „unbekannt → erlaubt“: der Schalter „Automatisch“
(Helligkeit) und die Gruppe „MQTT-Verschlüsselung“ erscheinen erst, wenn die
Fähigkeiten gelesen sind und den Sensor bzw. `mqttTls` melden. Grund: Eine
wirkungslose Einstellung wird nicht geschrieben (§7.4), und die Gruppe führt
sonst auf eine Seite, die es bei der Mehrzahl der Uhren nie gibt.

Einstellungen der Uhr (Seiten „Auf der Uhr“): Eine Zeile erscheint nur, wenn die
Antwort der Uhr ihren Schlüssel enthält (`Geraeteeinstellungen.hat(pfad:)`); eine
Gruppe ohne sichtbare Zeile entfällt (`Uhrgruppe.sichtbar`).

## Zeichen

- Quelle: 🔬 gemessen (mit Datum), 📄 Herstellerdoku (die Zeilen der TC001: der
  ESP32-Zweig, <https://blueforcer.github.io/awtrix-ng/esp32/>; die der TC002:
  der Zweig `/tc002/`), ❓ nicht gemessen.
- Modelle: **TC002** = 52 × 16, `platform.id` `tc002`; **TC001** = 32 × 8,
  `platform.id` `esp32`. Beide mit AWTRIX NG 1.2.2.
- Oberfläche: **Mac/iPad** = Desktop-Oberfläche (Fernbedienung = Bereich „Uhr“,
  Seitenleiste, Inspektor), **iPhone** = Blatt „Steuerung“ und Sendeansicht,
  **CLI** = `mqtttc002`. „alle“ = alle drei.

## Die Tabelle

### Senden: Text, Bilder, Darstellung

| Funktion | TC002 | TC001 | Quelle | Entscheidung der App | Oberfläche |
|---|---|---|---|---|---|
| Gerasterter Text und Bilder (GIF im `icon`) | ja, 52 × 16 | ja, 32 × 8 | 🔬 09.10.2026 | `Uhr.anzeigemass` aus `display.width/height` (`Anzeigemass.fuer`); ohne Auskunft 52 × 16 | alle, immer angezeigt |
| Schrift der Uhr (Uhr setzt den Text selbst) | ja | ja | 📄 | keine Fähigkeit; Schalter immer da, Regler für Schriftwahl, Größe, Fett, Rand, Abstand, Ausrichtung dann grau (der Nutzer schaltet es selbst) | Mac/iPad, iPhone |
| Schriftgröße passt nicht in die Höhe | – | 16 px passt nicht in 8 Zeilen: größte passende Größe derselben Schrift, Hinweis unter der Vorschau | 🔬 09.10.2026 | Anzeigemaß der Zieluhr (`Meldungsbau`, `Pixelgroessen`) | alle (automatisch) |
| Icon 8×8 | ja | ja | 🔬 09.10.2026 | Maß der Zieluhr | alle |
| Icon 16×16 | ja | durch seine 8×8-Fassung ersetzt, wenn es eine gibt | 🔬 09.10.2026 | `Iconbestaende.passend(_:fuer:)` nach Anzeigemaß | alle (automatisch, Hinweis) |
| Fertiges Bild (gemalt, Sammlung) | nur 52 × 16 | nur 32 × 8 | 🔬 09.10.2026 | falsches Maß: `NGFehler.massPasstNicht`, Meldung nennt es | Mac/iPad (Malen, Sammlung), iPhone (Sammlung), CLI `bild` |
| Layouts (Kästen mit Inhalt) | ja | nein (`422 unknown field`) | 🔬 09.10.2026 | `capabilities.layout` (`Geraetefaehigkeiten.layoutUnterstuetzt`); `false` weist `Kastenlayout.pruefen` mit `LayoutFehler.nichtUnterstuetzt` ab, `nil` (nie gefragt) lässt zu | nur CLI `layout`; keine Auswahl in der Oberfläche (Hilfe nennt es) |
| Standbild/Bewegtes als GIF, Zustellweg HTTP/MQTT | ja | ja | 🔬 09.10.2026 | `Pixelweg.zustellweg` (8192 Byte MQTT) | alle |
| Hintergrund, Effekt, Overlay, Palette | Listen der Uhr | Listen der Uhr (19 Effekte, 16 Paletteneffekte, 6 Overlays, 8 Paletten) | 🔬 10.10.2026 | `capabilities.effects/overlays/palettes`; Auswahl zeigt die Liste der Uhr, leere Liste = keine Auswahl, `Darstellung.pruefen(gegen:)` | Mac/iPad, iPhone (Darstellung), CLI `effekte` |
| Overlay der Uhr (Fernbedienung) | ja | ja (6) | 🔬 10.10.2026 | `capabilities.overlays` nicht leer | Mac/iPad, iPhone, CLI |
| Übergänge, Zifferblätter (Einstellungen) | `transitions`, `clockFaces` (5) | 22 `transitions`; `clockFaces` fehlt, also keine Zifferblätter | 🔬 10.10.2026 | `capabilities.transitions/clockFaces`; die Zeile `clockFace` (samt ihren Farbzeilen) erscheint nur, wenn die Einstellungen der Uhr den Schlüssel melden | Mac/iPad, iPhone (Uhr-Einstellungen), CLI |
| Nachricht (einmalig über der Schleife) | ja | ja | 🔬 | keine Fähigkeit | alle |

### Klang

Eine Klangart ist erlaubt, wenn `audio.<Schalter>` der Uhr `true` ist
(`Geraetefaehigkeiten.kann`); fehlt `audio` oder der Schalter, ist sie erlaubt.

| Funktion | TC002 | TC001 | Quelle | Entscheidung der App | Oberfläche |
|---|---|---|---|---|---|
| Gespeicherte Melodie spielen | ja | ja (Summer) | 🔬 10.10.2026 | `audio.rtttl` (`Klangart.melodie`) | Mac/iPad, iPhone („Von der Uhr“; ohne Fähigkeit keine Melodien in der Namenliste), CLI |
| RTTTL-Text spielen | ja | ja | 🔬 10.10.2026 | `audio.rtttl` (`Klangart.rtttl`) | CLI `ton spielen --rtttl`, Kurzbefehl |
| MP3 spielen (Datei auf der Uhr) | ja | nein | 🔬 10.10.2026 | `audio.mp3`; Dateiname ist MP3 oder Melodie nach den Listen der Uhr, unbekannter Name = beides | Mac/iPad, iPhone („Von der Uhr“: MP3-Abschnitt entfällt, wenn keine Zieluhr MP3 kann: `Klangeignung.mp3Zeigen`), CLI |
| MP3 hochladen | ja | nein (Uhr nimmt die Datei an, spielt sie nie) | 🔬 10.10.2026 | `Klangeignung.mp3Hochladbar` = `kann(.mp3)`; gesperrt auch ohne Adresse | Mac/iPad, iPhone (Fernbedienung › Ton: Knopf und MP3-Liste ausgeblendet), CLI `ton mp3 hochladen` |
| Lied (`song`) | ja | nein | 🔬 10.10.2026 | `audio.song` (`Klangart.lied`) | CLI `ton spielen --lied` |
| Vorlesen (`speech`) | ja | nein | 🔬 10.10.2026 | `audio.speech` (`Klangart.sprache`) | Mac/iPad, iPhone („Vorlesen“ nicht angeboten, wenn keine Zieluhr es kann), CLI `--sprache` |
| Radio, Sender wählen | ja | nein | 🔬 10.10.2026 | `audio.radio`; Radiozeilen in der Fernbedienung nur dann | Mac/iPad, iPhone, CLI `--sender` |
| MP3 von Webadresse (`url`) | ja | nein | 🔬 10.10.2026 | `audio.url` (`Klangart.adresse`) | CLI `ton spielen --datei <Adresse>` |
| Klang-Clip (`clip`), Klangeffekt (`effect`), Spur (`track`) | `clip` ja, `effect` ja, `track` nein | alle nein | 🔬 10.10.2026 | von der App nicht angeboten | – |
| Klang in einer Nachricht (mehrere Zieluhren) | – | – | – | `Klangeignung.verteilen`: der Klang geht nur an Uhren, die ihn spielen; die Nachricht geht an alle | Mac/iPad, iPhone, CLI |
| Lautstärke, „Spielt“, Stopp | ja | ja (Summer) | 📄 | keine Fähigkeit; gesperrt ohne Adresse (der Nutzer trägt sie ein); Abschnitt „Ton“ der Fernbedienung nicht angezeigt, wenn `audio` ganz leer | Mac/iPad, iPhone, CLI |
| Klangsammlung: Melodie auf die Uhr sichern/abgleichen | ja | ja | 🔬 10.10.2026 | `kann(.melodie)` (`Klangabgleich`); „Sichern“ in der Sammlung hängt an keiner Uhr, nur „Probehören“ braucht die angesehene Uhr und entfällt, wenn sie `rtttl` nie kann | Mac/iPad, iPhone (Einstellungen › Klänge), CLI `ton abgleichen` |
| Klangsammlung: MP3 abgleichen | ja | übersprungen (`faehigkeitFehlt`) | 🔬 10.10.2026 | `Klangeignung.mp3Hochladbar` | wie oben |

### Fernbedienung und Einstellungen der Uhr

| Funktion | TC002 | TC001 | Quelle | Entscheidung der App | Oberfläche |
|---|---|---|---|---|---|
| Display an/aus, Helligkeit | ja | ja | 🔬 10.10.2026 | keine Fähigkeit; Regler gesperrt, solange von der Uhr nichts gelesen ist oder der Sensor regelt | Mac/iPad, iPhone, CLI |
| Helligkeit automatisch (Lichtsensor) | nein (`sensors.light` `false`) | ja (`sensors.light` `true`) | 🔬 10.10.2026 | `Geraetefaehigkeiten.lichtsensor`; Schalter „Automatisch“ nur mit Sensor, `autoBrightness` wird sonst nie geschrieben (`Geraeteeinstellung.wirkt`), bei Automatik ist der Regler gesperrt | Mac/iPad, iPhone (Fernbedienung, Uhr-Einstellungen), CLI `helligkeit auto` |
| Moodlight | ja | ja | 🔬 TC002, 📄 ESP32-Zweig (`PUT`/`DELETE /api/v1/display/moodlight`) | keine Fähigkeit | Mac/iPad, iPhone, CLI |
| Anzeiger (3 Indikatoren) | ja | ja | 🔬 TC002, 📄 ESP32-Zweig (`PUT`/`DELETE /api/v1/indicators/{1..3}`) | keine Fähigkeit | Mac/iPad, iPhone, CLI |
| Tasten (nur MQTT mitlesen) | ja | ja (drei Tasten) | 📄 | Betriebsart `mqtt`; sonst Zeilen grau mit Hinweis „nur im MQTT-Betrieb“ (der Nutzer stellt die Betriebsart um) | Mac/iPad, iPhone |
| Drehknopf (Zeile und Knopfdruck) | ja | nein (nur drei Tasten) | 📄 ESP32-Zweig (Übersicht der TC001) | `Geraetefaehigkeiten.hatDrehknopf` = `platform.id` nicht `esp32`; ohne Auskunft angezeigt | Mac/iPad, iPhone |
| Live-Bild des Displays | ja | ja | 🔬 TC002, 📄 ESP32-Zweig (`GET /api/v1/display/screen`) | Bild im Maß der Uhr | Mac/iPad, iPhone, CLI `bildschirm` |
| Neustart | ja | ja | 📄 | keine Fähigkeit | Mac/iPad, iPhone, CLI |
| MQTT über TLS, CA hochladen | ja (`mqttTls` `true`) | nein (`mqttTls` fehlt) | 🔬 10.10.2026 | `capabilities.mqttTls`; Gruppe „Verschlüsselung“ nur bei `true` | Mac/iPad, iPhone (Uhr-Einstellungen), CLI `tls` |
| `enlargeApps` | ja, nicht schreibbar | gibt es nicht | 🔬 09.10.2026 | App rechnet alle Bilder für das Anzeigemaß; Einstellung wird nie geschrieben (`Geraeteeinstellung.schreibbar`) | – |
| Virtuelle Uhr | TC002-Modus (Vorgabe) | `NGTon.tc001`: gemessener Schlüsselsatz (kein `layout`, `layouts`, `mqttTls`, `clockFaces`, `bootSound`, `enlargeApps`; Anzeige 32 × 8; Einstellungen ohne `clockFace`, `bootSound`, `enlargeApps`) | 🔬 10.10.2026 | `NGTon.istTC001`, `VirtuelleNGUhr.faehigkeitenantwort/einstellungenantwort` | Mac/iPad, iPhone (Einstellungen), Tests |

## Abweichungen

Gewollt bleibt:

1. Die zwei Ausnahmen von „unbekannt → erlaubt“ (siehe Regel): „Automatisch“ und
   „MQTT-Verschlüsselung“ erscheinen erst nach der Abfrage.
2. Die virtuelle Uhr zeichnet im TC001-Modus weiter auf dem Raster 52 × 16
   (`/display/screen`, `draw`); nur ihre Auskünfte (`capabilities`, Einstellungen)
   sind die der TC001. Sie nimmt außerdem weiter ein `layout` an, das die echte
   TC001 mit `422` abweist.

## Offene Fragen

- Die Zeilen der TC001 stützen sich teils auf den ESP32-Zweig der Herstellerdoku
  (📄), nicht auf eine Messung am Gerät: Moodlight, Anzeiger, Live-Bild,
  fehlender Drehknopf.
