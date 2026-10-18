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
| Mehrere Zieluhren, nur ein Teil kann es | bleibt, und der Hinweis nennt die Uhren, bei denen es entfällt („… zeigt die Nachricht ohne Ton“); kann es **keine**, wird es nicht angezeigt |

Zwei gewollte Ausnahmen von „unbekannt → erlaubt“: der Schalter „Automatisch“
(Helligkeit) und die Gruppe „MQTT-Verschlüsselung“ erscheinen erst, wenn die
Fähigkeiten gelesen sind und den Sensor bzw. `mqttTls` melden. Grund: Eine
wirkungslose Einstellung wird nicht geschrieben (§7.4), und die Gruppe führt
sonst auf eine Seite, die es bei der Mehrzahl der Uhren nie gibt.

Einstellungen der Uhr (Bereich „Uhr“, „Vorgaben der Uhr“): Eine Zeile erscheint nur, wenn die
Antwort der Uhr ihren Schlüssel enthält (`Geraeteeinstellungen.hat(pfad:)`); eine
Gruppe ohne sichtbare Zeile entfällt (`Uhrgruppe.sichtbar`).

## Zeichen

- Quelle: 🔬 gemessen (mit Datum), 📄 Herstellerdoku (die Zeilen der TC001: der
  ESP32-Zweig, <https://blueforcer.github.io/awtrix-ng/esp32/>; die der TC002:
  der Zweig `/tc002/`), ❓ nicht gemessen.
- Modelle: **TC002** = 52 × 16, `platform.id` `tc002`; **TC001** = 32 × 8,
  `platform.id` `esp32`. Beide mit AWTRIX NG 1.2.2. **ESP32 DIY** = selbstgebaute
  Uhr, 32 bis 128 × 8, `platform.id` `esp32` (eigener Abschnitt unten).
- Oberfläche: **Mac/iPad** = Desktop-Oberfläche (Fernbedienung = Bereich „Uhr“,
  Seitenleiste, Inspektor), **iPhone** = Blatt „Uhr …“ und Sendeansicht,
  **CLI** = `mqtttc002`, **Kurzbefehl** = App Intents (iPhone, iPad, Mac; `Sources/TC002Kurzbefehle`). „alle“ = Mac/iPad, iPhone und CLI; Kurzbefehle sind darin nicht enthalten und stehen, wo es sie gibt, ausdrücklich da.

## Die Tabelle

### Senden: Text, Bilder, Darstellung

| Funktion | TC002 | TC001 | Quelle | Entscheidung der App | Oberfläche |
|---|---|---|---|---|---|
| Gerasterter Text und Bilder (GIF im `icon`) | ja, 52 × 16 | ja, 32 × 8 | 🔬 09.10.2026 | `Uhr.anzeigemass` aus `display.width/height` (`Anzeigemass.fuer`); ohne Auskunft 52 × 16 | alle, immer angezeigt |
| Schrift der Uhr (Uhr setzt den Text selbst) | ja | ja | 📄 | keine Fähigkeit; Schalter immer da, Regler für Schriftwahl, Größe, Fett, Rand, Abstand, Ausrichtung dann grau (der Nutzer schaltet es selbst) | Mac/iPad, iPhone (im Menü der Schriftart), CLI `--schrift-der-uhr` (weist die dann wirkungslosen Angaben ab) |
| Schriftgröße passt nicht in die Höhe | – | 16 px passt nicht in 8 Zeilen: größte passende Größe derselben Schrift (Maß: Tinte von „ÄÖÜH“, `TinteImFeldTests`), Hinweis unter der Vorschau | 🔬 09.10.2026 | Anzeigemaß der Zieluhr (`Meldungsbau`, `Pixelgroessen`) | alle (automatisch) |
| Icon 8×8 | ja | ja | 🔬 09.10.2026 | Maß der Zieluhr | alle |
| Icon 16×16 | ja | durch seine 8×8-Fassung ersetzt, wenn es eine gibt | 🔬 09.10.2026 | `Iconbestaende.passend(_:fuer:)` nach Anzeigemaß | alle (automatisch, Hinweis), Kurzbefehle „Anzeige schicken“ und „Nachricht senden“ (Hinweis im Ergebnis, `Iconbestaende.hinweise`) |
| Abstand Icon–Text und Zuschnitt | ja | ja | 📄 Quelltext 1.2.2 (Einheit von `iconGap`), am Gerät noch nicht gemessen | Das Icon wird immer auf seine Tinte zugeschnitten (links und rechts, Schwarz zählt nicht, bei Bewegtem der gemeinsame Kasten); der Text beginnt `Uhr.iconAbstand` Pixel dahinter (Vorgabe 1, 0 bis 16). Pixelweg: genau so; mittiger Text setzt den Block aus Icon, Abstand und Text in die Mitte. Schrift der Uhr: zugeschnittenes Icon und `iconGap` in Spalten der Seite (TC002 vergrößert: aufgerundet halbiert; sonst Pixel), nur gesendet, wenn ≠ 1; mittiger Text steht im Rest neben dem Icon. Ein Icon ohne Tinte zählt wie keins (`Iconplatz`). Soll ein Icon nicht zugeschnitten werden (z. B. weil der freie Rand gewollt ist), füllt man den Hintergrund des Icons mit #000001 statt mit Schwarz oder Transparenz: Das sieht auf der Uhr schwarz aus, zählt aber als Farbe und hält den Rand. | Mac/iPad, iPhone: Seite der Uhr „Abstand Icon–Text“; gilt für Senden, Nachrichten, Kurzbefehle, CLI (kein Feld im Senden-Dialog) |
| Icon mitscrollen: Fest · Einmal mitscrollen · Mitscrollen | ja | ja | 📄 `iconMode` | `Iconmodus`; „Einmal“ (`pushOnce`) nur mit Schrift der Uhr — im Pixelweg ist die Stellung grau (der Nutzer schaltet „Schrift der Uhr“ selbst ein) und gilt dort als „Mitscrollen“ (`Iconmodus.wirksam`); wie bisher nur bei laufendem Text | Mac/iPad (Inspektor), iPhone (Blatt „Icons“), CLI `--icon-mitscrollen` und `--icon-modus fest\|einmal\|mit`, Kurzbefehle (Auswahl „Icon mitscrollen“; der frühere Schalter läuft weiter) |
| Zusatzicons (bis zu 4) | ja | ja | 📄 Quelltext 1.2.2 (`RenderPipeline`, `PageZoom`), am Gerät noch nicht gemessen | keine Fähigkeit in `capabilities`, darum überall angezeigt und nie ausgegraut (auch nicht bei ausgeschalteter „Schrift der Uhr“ oder wenn der Text passt). `Zusatzicons`: Stelle in Anzeigepixeln (von links 0–127, von oben 0–15), Icons nicht zugeschnitten, Wahl wie beim Icon (8×8 und 16×16 nach Maß der Uhr, `Iconbestaende.passend`). Schrift der Uhr: `icons[]` mit Spalten der Seite = `Zusatzicons.seitenwert` (auf der vergrößerten TC002 Anzeigepixel ÷ 2, abgerundet; sonst Pixel); ein 16×16 darunter schaltet die Vergrößerung der ganzen Anzeige ab (`Geraeteschrift.vergroessert`). Pixelweg: eingebacken in Anzeigepixeln nach Text und Icon, spätere decken frühere, bewegte Icons auf gemeinsamer Zeitleiste (`Zusatzicons.zeitleiste`) | Mac/iPad (Inspektor, Abschnitt Icon), iPhone (Blatt „Icons“); Kurzbefehle und Werkzeug kennen sie nicht; gemerkt im Slotgedächtnis (`Slotstand.zusatzicons`) |
| Icon in Kurzbefehlen wählen | ja | ja | – | `IconEntity`/`IconAbfrage` über `Kurzbefehlswerte.iconvorschlaege`, Suche nach Name oder Nummer (`Kurzbefehlswerte.icons(passend:in:)`), Kennung `Icon.kennung` | Kurzbefehle „Anzeige schicken“ und „Nachricht senden“ (Auswahl statt getippter Nummer) |
| Fertiges Bild (gemalt, Sammlung) | nur 52 × 16 | nur 32 × 8 | 🔬 09.10.2026 | falsches Maß: `NGFehler.massPasstNicht`, die Fehlermeldung nennt es | Mac/iPad (Malen, Sammlung), iPhone (Sammlung), CLI `bild`, Kurzbefehl „Bild schicken“ (52 × 16, eine TC001 weist es ab) |
| Layouts (Kästen mit Inhalt) | ja | nein (`422 unknown field`) | 🔬 09.10.2026 | `capabilities.layout` (`Geraetefaehigkeiten.layoutUnterstuetzt`); `false` weist `Kastenlayout.pruefen` mit `LayoutFehler.nichtUnterstuetzt` ab, `nil` (nie gefragt) lässt zu | nur CLI `layout`; keine Auswahl in der Oberfläche (Hilfe nennt es) |
| Standbild/Bewegtes als GIF, Zustellweg HTTP/MQTT | ja | ja | 🔬 09.10.2026 | `Pixelweg.zustellweg` (8192 Byte MQTT) | alle |
| Hintergrund, Effekt, Overlay, Palette | Listen der Uhr | Listen der Uhr (19 Effekte, 16 Paletteneffekte, 6 Overlays, 8 Paletten) | 🔬 10.10.2026 | `capabilities.effects/overlays/palettes`; Auswahl zeigt die Vereinigung der Listen aller Zieluhren (`Darstellungsangebot`; ein Name genügt, wenn ihn eine Uhr kennt), fehlende Listen holt der Reiter beim Öffnen selbst, ein Hinweis nennt Uhren, die den gewählten Namen abweisen, `Darstellung.pruefen(gegen:)` | Mac/iPad, iPhone (Darstellung), CLI `effekte`; Kurzbefehle „Anzeige schicken“ und „Nachricht senden“ senden bewusst ohne Darstellung (`Meldungsoptionen.ausAblage` liest sie nicht) |
| Overlay der Uhr (Fernbedienung) | ja | ja (6) | 🔬 10.10.2026 | `capabilities.overlays` nicht leer; `AnzeigenSteuerung.overlay` prüft den Namen gegen die Liste | Mac/iPad, iPhone, CLI `overlay`, Kurzbefehl „Overlay der Uhr setzen“ (Name wie in der Liste der Uhr, ein unbekannter wird abgewiesen) |
| Übergänge, Zifferblätter (Einstellungen) | `transitions`, `clockFaces` (5) | 22 `transitions`; `clockFaces` fehlt, also keine Zifferblätter | 🔬 10.10.2026 | `capabilities.transitions/clockFaces`; die Zeile `clockFace` (samt ihren Farbzeilen) erscheint nur, wenn die Einstellungen der Uhr den Schlüssel melden | Mac/iPad, iPhone (Bereich „Uhr“), CLI |
| Nachricht (einmalig über der Schleife) | ja | ja | 🔬 | keine Fähigkeit | alle, Kurzbefehl „Nachricht senden“ |

### Klang

Eine Klangart ist erlaubt, wenn `audio.<Schalter>` der Uhr `true` ist
(`Geraetefaehigkeiten.kann`); fehlt `audio` oder der Schalter, ist sie erlaubt.

| Funktion | TC002 | TC001 | Quelle | Entscheidung der App | Oberfläche |
|---|---|---|---|---|---|
| Gespeicherte Melodie spielen | ja | ja (Summer) | 🔬 10.10.2026 | `audio.rtttl` (`Klangart.melodie`) | Mac/iPad, iPhone („Von der Uhr“; Namenliste = Vereinigung der Zieluhren, die Melodien können, beim Öffnen des Blatts selbst geholt, ein Name, den eine Zieluhr nicht führt, gilt dort als nicht abspielbar), CLI, Kurzbefehl „Nachricht senden“ (Feld „Klang“) |
| RTTTL-Text spielen | ja | ja | 🔬 10.10.2026 | `audio.rtttl` (`Klangart.rtttl`) | CLI `ton spielen --rtttl` |
| MP3 spielen (Datei auf der Uhr) | ja | nein | 🔬 10.10.2026 | `audio.mp3`; Dateiname ist MP3 oder Melodie nach den Listen der Uhr, unbekannter Name = beides | Mac/iPad, iPhone („Von der Uhr“: MP3-Abschnitt entfällt, wenn keine Zieluhr MP3 kann: `Klangeignung.mp3Zeigen`), CLI, Kurzbefehl „Nachricht senden“ (Feld „Klang“) |
| MP3 hochladen | ja | nein (Uhr nimmt die Datei an, spielt sie nie) | 🔬 10.10.2026 | `Klangeignung.mp3Hochladbar` = `kann(.mp3)`; gesperrt auch ohne Adresse | Mac/iPad, iPhone (Bereich „Uhr“ › Ton: Knopf und MP3-Liste ausgeblendet), CLI `ton mp3 hochladen` |
| Lied (`song`) | ja | nein | 🔬 10.10.2026 | `audio.song` (`Klangart.lied`) | CLI `ton spielen --lied` |
| Vorlesen (`speech`) | ja | nein | 🔬 10.10.2026 | `audio.speech` (`Klangart.sprache`) | Mac/iPad, iPhone („Vorlesen“ nicht angeboten, wenn keine Zieluhr es kann), CLI `--sprache`, Kurzbefehl „Nachricht senden“ („Vorlesen“; eine Uhr, die es nicht kann, zeigt die Nachricht ohne Ton) |
| Radio, Sender wählen | ja | nein | 🔬 10.10.2026 | `audio.radio`; Radiozeilen in der Fernbedienung und die Einstellung Radiolautstärke nur dann | Mac/iPad, iPhone, CLI `--sender` |
| MP3 von Webadresse (`url`) | ja | nein | 🔬 10.10.2026 | `audio.url` (`Klangart.adresse`) | CLI `ton spielen --datei <Adresse>` |
| Klang-Clip (`clip`), Klangeffekt (`effect`), Spur (`track`) | `clip` ja, `effect` ja, `track` nein | alle nein | 🔬 10.10.2026 | von der App nicht angeboten | – |
| Klang in einer Nachricht (mehrere Zieluhren) | – | – | – | `Klangeignung.verteilen`: der Klang geht nur an Uhren, die ihn spielen; die Nachricht geht an alle | Mac/iPad, iPhone, CLI, Kurzbefehl „Nachricht senden“ (der Dialog nennt die Uhren ohne Klang) |
| Lautstärke, „Spielt“, Stopp | ja | ja (Summer) | 📄 | keine Fähigkeit; gesperrt ohne Adresse (der Nutzer trägt sie ein); Abschnitt „Ton“ der Fernbedienung nicht angezeigt, wenn `audio` ganz leer | Mac/iPad, iPhone, CLI |
| Klangsammlung: Melodie auf die Uhr sichern/abgleichen | ja | ja | 🔬 10.10.2026 | `kann(.melodie)` (`Klangabgleich`); „Sichern“ in der Sammlung hängt an keiner Uhr, nur „Probehören“ braucht die gezeigte Uhr und entfällt, wenn sie `rtttl` nie kann | Mac/iPad, iPhone (Bereich „Klänge“, Titelmenü „Klänge …“), CLI `ton abgleichen` |
| Klangsammlung: MP3 abgleichen | ja | übersprungen (`faehigkeitFehlt`) | 🔬 10.10.2026 | `Klangeignung.mp3Hochladbar` | wie oben |

### Bereich „Uhr“: Fernbedienung und Vorgaben der Uhr

| Funktion | TC002 | TC001 | Quelle | Entscheidung der App | Oberfläche |
|---|---|---|---|---|---|
| Display an/aus, Helligkeit | ja | ja | 🔬 10.10.2026 | keine Fähigkeit; Regler gesperrt, solange von der Uhr nichts gelesen ist oder der Sensor regelt | Mac/iPad, iPhone, CLI, Kurzbefehle „Display der Uhr schalten“ und „Helligkeit der Uhr einstellen“ (Prozent; regelt der Sensor, sagt der Dialog, dass der Wert erst bei ausgeschalteter Automatik gilt) |
| Helligkeit automatisch (Lichtsensor) | nein (`sensors.light` `false`) | ja (`sensors.light` `true`) | 🔬 10.10.2026 | `Geraetefaehigkeiten.lichtsensor`; Schalter „Automatisch“ nur mit Sensor, `autoBrightness` wird sonst nie geschrieben (`Geraeteeinstellung.wirkt`), bei Automatik ist der Regler gesperrt | Mac/iPad, iPhone (Bereich „Uhr“), CLI `helligkeit auto`, Kurzbefehl „Helligkeit der Uhr einstellen“ › „Automatisch“ (eine Uhr ohne Sensor weist ab: `SteuerungsFehler.wirkungslos`, mit dem Namen der Uhr; nicht zusammen mit einem Wert: `Helligkeitswunsch`) |
| Moodlight | ja | ja | 🔬 TC002, 📄 ESP32-Zweig (`PUT`/`DELETE /api/v1/display/moodlight`) | keine Fähigkeit | Mac/iPad, iPhone, CLI, Kurzbefehl „Moodlight der Uhr einstellen“ (Farbe oder Weißton, nie beides: `Kurzbefehlswerte.moodlight`) |
| Anzeiger (3 Indikatoren) | ja | ja | 🔬 TC002, 📄 ESP32-Zweig (`PUT`/`DELETE /api/v1/indicators/{1..3}`) | keine Fähigkeit | Mac/iPad, iPhone, CLI, Kurzbefehl „Anzeiger der Uhr einstellen“ |
| Tasten (nur MQTT mitlesen) | ja | ja (drei Tasten) | 📄 | Betriebsart `mqtt`; sonst Zeilen grau mit Hinweis „nur im MQTT-Betrieb“ (der Nutzer stellt die Betriebsart um) | Mac/iPad, iPhone |
| Drehknopf (Zeile und Knopfdruck) | ja | nein (nur drei Tasten) | 📄 ESP32-Zweig (Übersicht der TC001) | `Geraetefaehigkeiten.hatDrehknopf` = `platform.id` nicht `esp32`; ohne Auskunft angezeigt | Mac/iPad, iPhone |
| Live-Bild des Displays | ja | ja | 🔬 TC002, 📄 ESP32-Zweig (`GET /api/v1/display/screen`) | Bild im Maß der Uhr | Mac/iPad, iPhone, CLI `bildschirm` |
| Batterie (Ladestand) | TC002 ja (77 %) | TC001 ja (3,9 V, 63 %); selbstgebaute Platine ohne Zelle meldet 0 %, 0,25 V | 🔬 11.10.2026 | `Geraetezustand.hatBatterie`: Spannung unter 2,0 V = keine Batterie, Zeile nicht angezeigt; ohne gemeldete Spannung angezeigt (`SteuerungTests.testBatterieNurMitBatterieAnzeigen`) | Mac/iPad, iPhone (Fernbedienung), CLI `zustand` |
| Neustart | ja | ja | 📄 | keine Fähigkeit | Mac/iPad, iPhone, CLI, Kurzbefehl „Uhr neu starten“ (fragt vorher nach) |
| Sicherung der Uhr (Zip der Weboberfläche) sichern und zurückspielen | ja | ja | 📄 `backup.js`, `reference/http` (Backup restore) | keine Fähigkeit geprüft; gesperrt ohne Adresse (der Nutzer trägt sie ein), nur HTTP | Mac/iPad, iPhone (Fernbedienung › Gerät); `VirtuelleNGUhr` und `GeraetesicherungTests` prüfen den ganzen Weg, am echten Gerät nicht gemessen |
| Firmware-Update (Release von GitHub, `POST /update`) | ja (`awtrix-ng-tc002.awup`, nur neuere Fassung) | ja (ESP32-Abbild; Versionsprüfung der Uhr ❓ nicht dokumentiert) | 📄 Quelltext des Herstellers (nicht am Gerät gemessen) | `updateImage` aus `GET /api/v1/device` nennt das Paket (`Firmwarelage`): fehlt es oder ist der Name unbekannt (Firmware vor 1.2.2), erscheinen die Zeilen nicht; gesperrt ohne Adresse (der Nutzer trägt sie ein), nur HTTP; unbekannt (nie abgefragt) = erlaubt. „Aktualisieren …“ erscheint nur, wenn das neueste Release neuer ist und eine Datei dieses Namens hat | Mac/iPad, iPhone (Fernbedienung › Gerät); gesucht wird nur auf Druck, aktualisiert nur nach Bestätigung; `VirtuelleNGUhr`, `GeraetFirmwareTests`, `FirmwareupdateZustandTests` prüfen den ganzen Weg |
| MQTT über TLS, CA hochladen | ja (`mqttTls` `true`) | nein (`mqttTls` fehlt) | 🔬 10.10.2026 | `capabilities.mqttTls`; Gruppe „Verschlüsselung“ nur bei `true` | Mac/iPad, iPhone (Bereich „Uhr“), CLI `tls` |
| `enlargeApps` | ja, nicht schreibbar | gibt es nicht | 🔬 09.10.2026 | App rechnet alle Bilder für das Anzeigemaß; Einstellung wird nie geschrieben (`Geraeteeinstellung.schreibbar`) | – |
| Virtuelle Uhr | TC002-Modus (Vorgabe) | `NGTon.tc001`: gemessener Schlüsselsatz (kein `layout`, `layouts`, `mqttTls`, `clockFaces`, `bootSound`, `enlargeApps`; Anzeige 32 × 8; Einstellungen ohne `clockFace`, `bootSound`, `enlargeApps`) | 🔬 10.10.2026 | `NGTon.istTC001`, `VirtuelleNGUhr.faehigkeitenantwort/einstellungenantwort` | Mac/iPad, iPhone (Einstellungen › Allgemein), Tests |

## ESP32 DIY (selbstgebaute Uhr)

Eigenbau mit AWTRIX NG 1.2.2 auf ESP32 (11. Oktober 2026): `platform.id`
`esp32` und `boardType` `awtrixng` wie bei der TC001, Anzeige 32 bis 128 × 8
(`capabilities.display`: `configurable` `true`, `minWidth` 32, `maxWidth` 128,
`minHeight` 8, `maxHeight` 8), derzeit 32 × 8. `Uhr.modell` hält das Modell
(`Uhrmodell`: `tc002`, `tc001`, `esp32DIY`; `nil` = noch nicht bestimmt).

**Erkennung** (`Uhrmodell.vorschlag`, bei „Abfragen“, nur wenn noch kein Modell
steht; der Nutzer ändert es auf der Uhrseite, eine Wahl bleibt):

| Antwort der Uhr | Modell |
|---|---|
| `platform.id` `tc002` | TC002 |
| `esp32`, Batterie (`Geraetezustand.hatBatterie`) **und** `ldrRaw` über 0 | TC001 |
| jeder andere `esp32` | ESP32 DIY |
| sonst, oder Gerätezustand/`ldrRaw` fehlt | unbestimmt |

`capabilities.sensors.light` ist auf jedem ESP32 `true` und entscheidet nichts.

| Funktion | ESP32 DIY | Quelle | Entscheidung der App | Oberfläche |
|---|---|---|---|---|
| Anzeige | 32…128 × 8, aus `display.width/height` | 🔬 11.10.2026 | `Uhr.anzeigemass`; Zeichnung `Geraetezeichnung.diy` (Panel ohne Gehäuse, Breite folgt dem Feld) | alle |
| Batterie | nur mit Zelle (unter 2,0 V keine) | 🔬 11.10.2026 | `Geraetezustand.hatBatterie` | Fernbedienung, CLI `zustand`; Ausstattung auf der Uhrseite |
| Lichtsensor / „Automatisch“ | nur wenn `ldrRaw` über 0; `ldrRaw` 0 = kein Fotowiderstand | 🔬 11.10.2026 | `Geraetefaehigkeiten.mitAusstattung` setzt `ohneLichtmessung`; nur für den Eigenbau (ein echter Sensor in völliger Dunkelheit könnte 0 lesen), nie für die TC001 | wie TC001 |
| Temperatur, Feuchte | nur mit Fühler (`temperature`/`humidity` in `/api/v1/device`) | 🔬 11.10.2026 | die App zeigt beide nicht an; sie stehen in der Ausstattung der Uhrseite | Uhrseite |
| MP3-Player (DFPlayer) | `audio.mp3` der Uhr | 🔬 11.10.2026 | `audio.mp3` gilt (spiegelt das Abspielen); `/api/v1/system` `dfplayer` wird nicht gelesen | wie TC001 |
| Lautsprecher | **nicht erkennbar** (`audio.rtttl` ist auch ohne einen `true`) | 🔬 11.10.2026 | Schalter „Lautsprecher“ (`Uhr.lautsprecher`, nil = ein); aus = `Geraetefaehigkeiten.lautsprecher` `false`, `ton` leer, `kann(_:)` für jede Klangart `false` | Uhrseite |
| Klang ohne Lautsprecher | keiner | – | Abschnitt „Ton“ der Fernbedienung, Klangknopf der Nachricht (`AppZustand.klangMoeglich`, `Klangeignung.keinKlang`), Klangeinstellungen der Uhr, „Probehören“; nicht im Klangabgleich (App und `ton abgleichen`); CLI `ton spielen` meldet und überspringt, `nachricht --rtttl` sendet ohne Klang; mehrere Ziele: bleibt, wenn eine Uhr es kann | alle |
| Klangabgleich je Uhr | wählbar | – | `Uhr.klangAbgleich` (nil = mit); Uhren ohne Lautsprecher erscheinen nicht; `ton abgleichen` ohne `--an` liest sie, mit `--an` wird die genannte Uhr abgeglichen, ohne Lautsprecher mit Hinweis übersprungen | Mac/iPad, iPhone (Bereich „Klänge“, Titelmenü „Klänge …“), CLI |
| Layouts, Drehknopf | nein (wie TC001) | 🔬 | `capabilities.layout` fehlt, `platform.id` `esp32` | wie TC001 |

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
