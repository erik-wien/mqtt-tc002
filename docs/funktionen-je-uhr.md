# Funktionen je Uhr

Verbindlich: Was die App je Uhrenmodell anbietet, und woran sie es festmacht.
Die Fähigkeiten, die der Kern entscheidet, hält `Tests/TC002CoreTests/FunktionslisteTests.swift`
fest (die Tabelle und der Test verweisen aufeinander; wer eine Zeile ändert,
ändert beide). Die Messungen zur Schnittstelle stehen in
`docs/awtrix-ng-protokoll.md`; Beobachtungen, die bei einem Firmwarewechsel
nachzuprüfen sind, in `docs/firmware-beobachtungen.md`.

## Die Regel

| Fall | Oberfläche |
|---|---|
| Die Uhr kann es **nie** (Hardware oder Firmware, gemeldet oder gemessen) | **ausblenden** |
| Die Uhr kann es **zurzeit nicht** (keine Adresse, Uhr nicht erreichbar, Sensor regelt, kein Zustand gelesen) | **sperren, mit Grund** sichtbar |
| Die Uhr hat darüber **nichts gemeldet** (Fähigkeiten nie abgefragt, Schalter fehlt in `audio`) | **erlaubt**; die Prüfung vor dem Senden und die Uhr weisen Falsches ab |
| Mehrere Zieluhren, nur ein Teil kann es | gesperrt nur, wenn **keine** kann; sonst erlaubt, und die Meldung nennt die Uhren, bei denen es entfällt |

Wo der Code von dieser Regel abweicht, steht es im Abschnitt „Abweichungen“.

## Zeichen

- Quelle: 🔬 gemessen (mit Datum), 📄 Herstellerdoku, ❓ nicht gemessen.
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
| Schrift der Uhr (Uhr setzt den Text selbst) | ja | ja | 📄 | keine Fähigkeit; Schalter immer da, Regler für Schriftwahl, Größe, Fett, Rand, Abstand, Ausrichtung dann grau | Mac/iPad, iPhone |
| Schriftgröße passt nicht in die Höhe | – | 16 px passt nicht in 8 Zeilen: größte passende Größe derselben Schrift, Hinweis unter der Vorschau | 🔬 09.10.2026 | Anzeigemaß der Zieluhr (`Meldungsbau`, `Pixelgroessen`) | alle (automatisch) |
| Icon 8×8 | ja | ja | 🔬 09.10.2026 | Maß der Zieluhr | alle |
| Icon 16×16 | ja | durch seine 8×8-Fassung ersetzt, wenn es eine gibt | 🔬 09.10.2026 | `Iconbestaende.passend(_:fuer:)` nach Anzeigemaß | alle (automatisch, Hinweis) |
| Fertiges Bild (gemalt, Sammlung) | nur 52 × 16 | nur 32 × 8 | 🔬 09.10.2026 | falsches Maß: `NGFehler.massPasstNicht`, Meldung nennt es | Mac/iPad (Malen, Sammlung), iPhone (Sammlung), CLI `bild` |
| Layouts (Kästen mit Inhalt) | ja | nein (`422 unknown field`) | 🔬 09.10.2026 | `capabilities.layout` (`Geraetefaehigkeiten.layoutUnterstuetzt`); `false` weist `Kastenlayout.pruefen` mit `LayoutFehler.nichtUnterstuetzt` ab, `nil` (nie gefragt) lässt zu | nur CLI `layout`; keine Auswahl in der Oberfläche (Hilfe nennt es) |
| Standbild/Bewegtes als GIF, Zustellweg HTTP/MQTT | ja | ja | 🔬 09.10.2026 | `Pixelweg.zustellweg` (8192 Byte MQTT) | alle |
| Hintergrund, Effekt, Overlay, Palette | Listen der Uhr | Listen der Uhr (19 Effekte, 16 Paletteneffekte, 6 Overlays, 8 Paletten) | 🔬 10.10.2026 | `capabilities.effects/overlays/palettes`; Auswahl zeigt die Liste der Uhr, leere Liste = keine Auswahl, `Darstellung.pruefen(gegen:)` | Mac/iPad, iPhone (Darstellung), CLI `effekte` |
| Overlay der Uhr (Fernbedienung) | ja | ja (6) | 🔬 10.10.2026 | `capabilities.overlays` nicht leer | Mac/iPad, iPhone, CLI |
| Übergänge, Zifferblätter (Einstellungen) | `transitions`, `clockFaces` (5) | 22 `transitions`; `clockFaces` fehlt, also keine Zifferblätter | 🔬 10.10.2026 | `capabilities.transitions/clockFaces`; fehlen sie, gelten die fest eingebauten Zifferblätter | Mac/iPad, iPhone (Uhr-Einstellungen), CLI |
| Nachricht (einmalig über der Schleife) | ja | ja | 🔬 | keine Fähigkeit | alle |

### Klang

Eine Klangart ist erlaubt, wenn `audio.<Schalter>` der Uhr `true` ist
(`Geraetefaehigkeiten.kann`); fehlt `audio` oder der Schalter, ist sie erlaubt.

| Funktion | TC002 | TC001 | Quelle | Entscheidung der App | Oberfläche |
|---|---|---|---|---|---|
| Gespeicherte Melodie spielen | ja | ja (Summer) | 🔬 10.10.2026 | `audio.rtttl` (`Klangart.melodie`) | Mac/iPad, iPhone („Von der Uhr“), CLI |
| RTTTL-Text spielen | ja | ja | 🔬 10.10.2026 | `audio.rtttl` (`Klangart.rtttl`) | CLI `ton spielen --rtttl`, Kurzbefehl |
| MP3 spielen (Datei auf der Uhr) | ja | nein | 🔬 10.10.2026 | `audio.mp3`; Dateiname ist MP3 oder Melodie nach den Listen der Uhr, unbekannter Name = beides | Mac/iPad, iPhone („Von der Uhr“: MP3-Abschnitt entfällt, wenn keine Zieluhr MP3 kann: `Klangeignung.mp3Zeigen`), CLI |
| MP3 hochladen | ja | nein (Uhr nimmt die Datei an, spielt sie nie) | 🔬 10.10.2026 | `Klangeignung.mp3Hochladbar` = `kann(.mp3)`; gesperrt auch ohne Adresse | Mac/iPad, iPhone (Fernbedienung › Ton: Knopf und MP3-Liste ausgeblendet), CLI `ton mp3 hochladen` |
| Lied (`song`) | ja | nein | 🔬 10.10.2026 | `audio.song` (`Klangart.lied`) | CLI `ton spielen --lied` |
| Vorlesen (`speech`) | ja | nein | 🔬 10.10.2026 | `audio.speech` (`Klangart.sprache`) | Mac/iPad, iPhone („Vorlesen“), CLI `--sprache` |
| Radio, Sender wählen | ja | nein | 🔬 10.10.2026 | `audio.radio`; Radiozeilen in der Fernbedienung nur dann | Mac/iPad, iPhone, CLI `--sender` |
| MP3 von Webadresse (`url`) | ja | nein | 🔬 10.10.2026 | `audio.url` (`Klangart.adresse`) | CLI `ton spielen --datei <Adresse>` |
| Klang-Clip (`clip`), Klangeffekt (`effect`), Spur (`track`) | `clip` ja, `effect` ja, `track` nein | alle nein | 🔬 10.10.2026 | von der App nicht angeboten | – |
| Klang in einer Nachricht (mehrere Zieluhren) | – | – | – | `Klangeignung.verteilen`: der Klang geht nur an Uhren, die ihn spielen; die Nachricht geht an alle | Mac/iPad, iPhone, CLI |
| Lautstärke, „Spielt“, Stopp | ja | ja (Summer) | 📄 | keine Fähigkeit; gesperrt ohne Adresse oder wenn `audio` ganz leer | Mac/iPad, iPhone, CLI |
| Klangsammlung: Melodie auf die Uhr sichern/abgleichen | ja | ja | 🔬 10.10.2026 | `kann(.melodie)` (`Klangabgleich`) | Mac/iPad, iPhone (Einstellungen › Klänge), CLI `ton abgleichen` |
| Klangsammlung: MP3 abgleichen | ja | übersprungen (`faehigkeitFehlt`) | 🔬 10.10.2026 | `Klangeignung.mp3Hochladbar` | wie oben |

### Fernbedienung und Einstellungen der Uhr

| Funktion | TC002 | TC001 | Quelle | Entscheidung der App | Oberfläche |
|---|---|---|---|---|---|
| Display an/aus, Helligkeit | ja | ja | 🔬 10.10.2026 | keine Fähigkeit; Regler gesperrt, solange von der Uhr nichts gelesen ist oder der Sensor regelt | Mac/iPad, iPhone, CLI |
| Helligkeit automatisch (Lichtsensor) | nein (`sensors.light` `false`) | ja (`sensors.light` `true`) | 🔬 10.10.2026 | `Geraetefaehigkeiten.lichtsensor`; Schalter „Automatisch“ nur mit Sensor, `autoBrightness` wird sonst nie geschrieben (`Geraeteeinstellung.wirkt`), bei Automatik ist der Regler gesperrt | Mac/iPad, iPhone (Fernbedienung, Uhr-Einstellungen), CLI `helligkeit auto` |
| Moodlight | ja | ❓ | 🔬 TC002 | keine Fähigkeit | Mac/iPad, iPhone, CLI |
| Anzeiger (3 Indikatoren) | ja | ❓ | 🔬 TC002 | keine Fähigkeit | Mac/iPad, iPhone, CLI |
| Tasten, Drehknopf (nur MQTT mitlesen) | ja | ❓ (Drehknopf) | 📄 | Betriebsart `mqtt`; sonst Zeilen grau mit Hinweis „nur im MQTT-Betrieb“ | Mac/iPad, iPhone |
| Live-Bild des Displays | ja | ❓ | 🔬 TC002 | Bild im Maß der Uhr | Mac/iPad, iPhone, CLI `bildschirm` |
| Neustart | ja | ja | 📄 | keine Fähigkeit | Mac/iPad, iPhone, CLI |
| MQTT über TLS, CA hochladen | ja (`mqttTls` `true`) | nein (`mqttTls` fehlt) | 🔬 10.10.2026 | `capabilities.mqttTls`; Gruppe „Verschlüsselung“ nur bei `true` | Mac/iPad, iPhone (Uhr-Einstellungen), CLI `tls` |
| `enlargeApps` | ja, nicht schreibbar | gibt es nicht | 🔬 09.10.2026 | App rechnet alle Bilder für das Anzeigemaß; Einstellung wird nie geschrieben (`Geraeteeinstellung.schreibbar`) | – |
| Virtuelle Uhr | TC002-Modus (Vorgabe) | `NGTon.tc001` (nur `audio` und `platform.id`) | 🔬 10.10.2026 | `NGTon.faehigkeiten`, `NGUhrzustand.lichtsensor` | Mac/iPad, iPhone (Einstellungen), Tests |

## Abweichungen

Stand dieser Fassung. Nicht behoben, nur festgehalten; jede Zeile gegen die Regel
oben.

1. **Nie möglich, aber gesperrt statt ausgeblendet.**
   - `Sources/TC002Ansichten/Tonbausteine.swift:52-53`: die Klangauswahl bietet
     „Von der Uhr“ und „Vorlesen“ gesperrt an (`selectionDisabled`), auch wenn
     die einzige Zieluhr es nie kann (TC001: „Vorlesen“). Bei mehreren Zielen
     ist Sperren richtig.
   - `Sources/TC002Ansichten/Tonbausteine.swift:62-71`: die Grundzeilen „Von der
     Uhr: …“ und „Vorlesen: …“ stehen dann ebenfalls da.
   - `Sources/TC002Ansichten/Tonbausteine.swift:111`: Melodien der Liste
     gesperrt statt ausgeblendet, wenn keine Zieluhr Melodien kann.
   - `Sources/TC002Ansichten/Tonbausteine.swift:219` (mit `.disabled(gesperrt)`): der ganze Abschnitt „Ton“ bleibt sichtbar und grau mit
     „Diese Uhr meldet keinen Ton.“, wenn `audio` vollständig leer ist.
   - `Sources/TC002Ansichten/Klangsammlungsansicht.swift:342`: „Sichern“ einer
     Melodie ist gesperrt, wenn die Uhr kein `rtttl` kann.
2. **Unbekannt, aber ausgeblendet statt erlaubt.**
   - `Sources/TC002Ansichten/Fernbedienung.swift:54` und `:208`: „Automatisch“
     fehlt, solange die Fähigkeiten nicht gelesen sind oder `sensors` in der
     Antwort fehlt (`lichtsensor` ist dann `false`).
   - `Sources/TC002Core/Geraeteeinstellungen.swift:173` (gerufen von
     `Sources/TC002Ansichten/Uhrgruppen.swift:170`): `autoBrightness` ist ohne
     Auskunft „wirkungslos“ und die Zeile verschwindet. Beides ist so gewollt
     (Schreiben einer wirkungslosen Einstellung vermeiden, §7.4), weicht aber
     von „unbekannt → erlaubt“ ab.
   - `Sources/TC002Ansichten/Uhrgruppen.swift:76`: die Gruppe „Verschlüsselung“
     fehlt ohne `mqttTls: true`, auch wenn nie gefragt wurde.
3. **Nicht an Fähigkeiten gebunden, obwohl für die TC001 ungemessen.**
   `Fernbedienung.swift` zeigt Moodlight, Anzeiger, Drehknopf, Live-Bild und den
   Gruppenseiten „Klang“ (`bootSound`, `musicSource`), „Übergänge“ und
   „Zifferblatt“ (Uhr-Einstellungen, `Uhrgruppen.swift:46-100`) unterschiedslos
   für beide Modelle. Die TC001 meldet weder `clockFaces` noch `bootSound` (Schlüssel fehlen,
   gemessen 10.10.2026): `Uhrgruppen.swift:55` und `:205` zeigt dennoch die fest eingebaute Zifferblattliste,
   und `bootSound` (Gruppe „Klang“, `Uhrgruppen.swift:67`) hängt an keiner Fähigkeit; beide
   sollten bei fehlendem Schlüssel verschwinden. Moodlight, Anzeiger, Drehknopf und
   Live-Bild haben keinen Fähigkeitsschlüssel und bleiben ❓.
4. **Virtuelle Uhr im TC001-Modus.** `Sources/TC002Core/VirtuelleNGUhrTon.swift:100-108`
   setzt nur `audio` und `platform.id` um; `layout`, `display` (52 × 16),
   `mqttTls`, `clockFaces`, `bootSound`, `enlargeApps` und die Listen bleiben die der TC002. Die virtuelle
   TC001 meldet also Layouts und 52 × 16, die die echte nicht hat.

## Offene Fragen

- Moodlight, Anzeiger, Drehknopf und Live-Bild haben keinen Fähigkeitsschlüssel;
  ob die TC001 sie hat, zeigt nur ein Versuch am Gerät.
