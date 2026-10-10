# Features per clock

Binding: what the app offers for each clock model, and what it bases that on.
The decisions made in the core are held by
`Tests/TC002CoreTests/FunktionslisteTests.swift` (table and test point at each
other; whoever changes a row changes both). The interface measurements are in
`docs/en/awtrix-ng-protocol.md`; observations to re-check after a firmware
change are in `docs/en/firmware-observations.md`.

## The rule

Erik, 10 October 2026: "Greying out is to be used only when a feature has been
disabled that I can enable (e.g. clock font on|off). Something that will never
work on the clock is simply not shown."

| Case | Interface |
|---|---|
| The clock can **never** do it (hardware or firmware: capability `false` or key absent from the answer) | **not shown**: no greyed row, no note |
| It is only **switched off, and the user can change the cause himself** (a switch like "Clock font", the light sensor controls brightness, no address entered, MQTT feature in HTTP mode) | **disabled, with the reason** shown |
| The clock has **reported nothing** (capabilities never queried, switch missing in `audio`) | **allowed**; the pre-send check and the clock reject what is wrong |
| Several target clocks, only some can | stays, and the message names the clocks where it is dropped ("… shows the message without sound"); if **none** can, it is not shown |

Two deliberate exceptions to "unknown → allowed": the "Automatisch" switch
(brightness) and the group "MQTT encryption" appear only once the capabilities
are read and report the sensor or `mqttTls`. Reason: an ineffective setting is
never written (§7.4), and the group would otherwise lead to a page most clocks
never have.

Clock settings (pages "Auf der Uhr"): a row appears only if the clock's answer
contains its key (`Geraeteeinstellungen.hat(pfad:)`); a group without a visible
row disappears (`Uhrgruppe.sichtbar`).

## Legend

- Source: 🔬 measured (with date), 📄 vendor docs (TC001 rows: the ESP32 branch,
  <https://blueforcer.github.io/awtrix-ng/esp32/>; TC002 rows: the `/tc002/`
  branch), ❓ not measured.
- Models: **TC002** = 52 × 16, `platform.id` `tc002`; **TC001** = 32 × 8,
  `platform.id` `esp32`. Both on AWTRIX NG 1.2.2.
- Interface: **Mac/iPad** = desktop interface (remote control = the "Uhr"
  area, sidebar, inspector), **iPhone** = "Steuerung" sheet and send view,
  **CLI** = `mqtttc002`. "all" = all three.

## The table

### Sending: text, images, appearance

| Feature | TC002 | TC001 | Source | How the app decides | Interface |
|---|---|---|---|---|---|
| Rasterised text and images (GIF in `icon`) | yes, 52 × 16 | yes, 32 × 8 | 🔬 9 Oct 2026 | `Uhr.anzeigemass` from `display.width/height` (`Anzeigemass.fuer`); without an answer 52 × 16 | all, always shown |
| Clock font (the clock sets the text itself) | yes | yes | 📄 | no capability; switch always present, controls for font, size, bold, border, spacing, alignment greyed while on (the user switches it himself) | Mac/iPad, iPhone |
| Font size does not fit the height | – | 16 px does not fit 8 rows: largest fitting size of the same font, note under the preview | 🔬 9 Oct 2026 | display size of the target clock (`Meldungsbau`, `Pixelgroessen`) | all (automatic) |
| Icon 8×8 | yes | yes | 🔬 9 Oct 2026 | target clock size | all |
| Icon 16×16 | yes | replaced by its 8×8 version if there is one | 🔬 9 Oct 2026 | `Iconbestaende.passend(_:fuer:)` by display size | all (automatic, note) |
| Finished image (painted, collection) | 52 × 16 only | 32 × 8 only | 🔬 9 Oct 2026 | wrong size: `NGFehler.massPasstNicht`, message says so | Mac/iPad (paint, collection), iPhone (collection), CLI `bild` |
| Layouts (boxes with content) | yes | no (`422 unknown field`) | 🔬 9 Oct 2026 | `capabilities.layout` (`Geraetefaehigkeiten.layoutUnterstuetzt`); `false` makes `Kastenlayout.pruefen` throw `LayoutFehler.nichtUnterstuetzt`, `nil` (never queried) lets it through | CLI `layout` only; no picker in the UI (the help says so) |
| Still/animated GIF, delivery HTTP/MQTT | yes | yes | 🔬 9 Oct 2026 | `Pixelweg.zustellweg` (8192 bytes MQTT) | all |
| Background, effect, overlay, palette | the clock's lists | the clock's lists (19 effects, 16 palette effects, 6 overlays, 8 palettes) | 🔬 10 Oct 2026 | `capabilities.effects/overlays/palettes`; the picker shows the clock's list, an empty list means no picker, `Darstellung.pruefen(gegen:)` | Mac/iPad, iPhone (appearance), CLI `effekte` |
| Clock overlay (remote control) | yes | yes (6) | 🔬 10 Oct 2026 | `capabilities.overlays` not empty | Mac/iPad, iPhone, CLI |
| Transitions, clock faces (settings) | `transitions`, `clockFaces` (5) | 22 `transitions`; `clockFaces` absent, so no clock faces | 🔬 10 Oct 2026 | `capabilities.transitions/clockFaces`; the `clockFace` row (with its colour rows) appears only if the clock's settings report the key | Mac/iPad, iPhone (clock settings), CLI |
| Notification (one-off above the loop) | yes | yes | 🔬 | no capability | all |

### Sound

A sound kind is allowed if the clock's `audio.<switch>` is `true`
(`Geraetefaehigkeiten.kann`); if `audio` or the switch is missing, it is allowed.

| Feature | TC002 | TC001 | Source | How the app decides | Interface |
|---|---|---|---|---|---|
| Play a stored melody | yes | yes (buzzer) | 🔬 10 Oct 2026 | `audio.rtttl` (`Klangart.melodie`) | Mac/iPad, iPhone ("Von der Uhr"; no melodies in the name list without the capability), CLI |
| Play RTTTL text | yes | yes | 🔬 10 Oct 2026 | `audio.rtttl` (`Klangart.rtttl`) | CLI `ton spielen --rtttl`, shortcut |
| Play MP3 (file on the clock) | yes | no | 🔬 10 Oct 2026 | `audio.mp3`; a file name is MP3 or melody according to the clock's lists, an unknown name is both | Mac/iPad, iPhone ("Von der Uhr": MP3 section dropped if no target can play MP3: `Klangeignung.mp3Zeigen`), CLI |
| Upload MP3 | yes | no (the clock accepts the file and never plays it) | 🔬 10 Oct 2026 | `Klangeignung.mp3Hochladbar` = `kann(.mp3)`; also disabled without an address | Mac/iPad, iPhone (remote control › sound: button and MP3 list hidden), CLI `ton mp3 hochladen` |
| Song | yes | no | 🔬 10 Oct 2026 | `audio.song` (`Klangart.lied`) | CLI `ton spielen --lied` |
| Speech (`speech`) | yes | no | 🔬 10 Oct 2026 | `audio.speech` (`Klangart.sprache`) | Mac/iPad, iPhone ("Vorlesen" not offered if no target clock can), CLI `--sprache` |
| Radio, choose a station | yes | no | 🔬 10 Oct 2026 | `audio.radio`; radio rows in the remote control and the radio volume setting only then | Mac/iPad, iPhone, CLI `--sender` |
| MP3 from a web address (`url`) | yes | no | 🔬 10 Oct 2026 | `audio.url` (`Klangart.adresse`) | CLI `ton spielen --datei <address>` |
| Sound clip (`clip`), sound effect (`effect`), track (`track`) | `clip` yes, `effect` yes, `track` no | all no | 🔬 10 Oct 2026 | not offered by the app | – |
| Sound in a message (several target clocks) | – | – | – | `Klangeignung.verteilen`: the sound goes only to clocks that play it; the message goes to all | Mac/iPad, iPhone, CLI |
| Volume, "Spielt", stop | yes | yes (buzzer) | 📄 | no capability; disabled without an address (the user enters it); the remote control's "Ton" section is not shown if `audio` is entirely empty | Mac/iPad, iPhone, CLI |
| Sound collection: store/sync melodies to the clock | yes | yes | 🔬 10 Oct 2026 | `kann(.melodie)` (`Klangabgleich`); "Sichern" in the collection depends on no clock, only "Probehören" needs the viewed clock and is dropped if it can never play `rtttl` | Mac/iPad, iPhone (settings › sounds), CLI `ton abgleichen` |
| Sound collection: sync MP3 | yes | skipped (`faehigkeitFehlt`) | 🔬 10 Oct 2026 | `Klangeignung.mp3Hochladbar` | as above |

### Remote control and clock settings

| Feature | TC002 | TC001 | Source | How the app decides | Interface |
|---|---|---|---|---|---|
| Display on/off, brightness | yes | yes | 🔬 10 Oct 2026 | no capability; slider disabled while nothing is read from the clock or the sensor is in control | Mac/iPad, iPhone, CLI |
| Automatic brightness (light sensor) | no (`sensors.light` `false`) | yes (`sensors.light` `true`) | 🔬 10 Oct 2026 | `Geraetefaehigkeiten.lichtsensor`; "Automatisch" switch only with a sensor, `autoBrightness` is otherwise never written (`Geraeteeinstellung.wirkt`), the slider is disabled while automatic is on | Mac/iPad, iPhone (remote control, clock settings), CLI `helligkeit auto` |
| Moodlight | yes | yes | 🔬 TC002, 📄 ESP32 branch (`PUT`/`DELETE /api/v1/display/moodlight`) | no capability | Mac/iPad, iPhone, CLI |
| Indicators (3) | yes | yes | 🔬 TC002, 📄 ESP32 branch (`PUT`/`DELETE /api/v1/indicators/{1..3}`) | no capability | Mac/iPad, iPhone, CLI |
| Buttons (read only via MQTT) | yes | yes (three buttons) | 📄 | operating mode `mqtt`; otherwise rows greyed with the note "nur im MQTT-Betrieb" (the user changes the mode) | Mac/iPad, iPhone |
| Knob (row and knob press) | yes | no (three buttons only) | 📄 ESP32 branch (TC001 overview) | `Geraetefaehigkeiten.hatDrehknopf` = `platform.id` is not `esp32`; shown without an answer | Mac/iPad, iPhone |
| Live image of the display | yes | yes | 🔬 TC002, 📄 ESP32 branch (`GET /api/v1/display/screen`) | image at the clock's size | Mac/iPad, iPhone, CLI `bildschirm` |
| Restart | yes | yes | 📄 | no capability | Mac/iPad, iPhone, CLI |
| MQTT over TLS, upload CA | yes (`mqttTls` `true`) | no (`mqttTls` absent) | 🔬 10 Oct 2026 | `capabilities.mqttTls`; group "Verschlüsselung" only when `true` | Mac/iPad, iPhone (clock settings), CLI `tls` |
| `enlargeApps` | yes, not writable | does not exist | 🔬 9 Oct 2026 | the app rasterises every image for the display size; the setting is never written (`Geraeteeinstellung.schreibbar`) | – |
| Virtual clock | TC002 mode (default) | `NGTon.tc001`: the measured key set (no `layout`, `layouts`, `mqttTls`, `clockFaces`, `bootSound`, `enlargeApps`; display 32 × 8; settings without `clockFace`, `bootSound`, `enlargeApps`) | 🔬 10 Oct 2026 | `NGTon.istTC001`, `VirtuelleNGUhr.faehigkeitenantwort/einstellungenantwort` | Mac/iPad, iPhone (settings), tests |

## Deviations

Kept on purpose:

1. The two exceptions to "unknown → allowed" (see the rule): "Automatisch" and
   "MQTT encryption" appear only after the query.
2. In TC001 mode the virtual clock still draws on the 52 × 16 grid
   (`/display/screen`, `draw`); only its answers (`capabilities`, settings) are
   the TC001's. It also still accepts a `layout`, which the real TC001 rejects
   with `422`.

## Open questions

- Some TC001 rows rest on the ESP32 branch of the vendor docs (📄), not on a
  measurement on the device: moodlight, indicators, live image, the missing knob.
