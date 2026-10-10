# Features per clock

Binding: what the app offers for each clock model, and what it bases that on.
The decisions made in the core are held by
`Tests/TC002CoreTests/FunktionslisteTests.swift` (table and test point at each
other; whoever changes a row changes both). The interface measurements are in
`docs/en/awtrix-ng-protocol.md`; observations to re-check after a firmware
change are in `docs/en/firmware-observations.md`.

## The rule

| Case | Interface |
|---|---|
| The clock can **never** do it (hardware or firmware, reported or measured) | **hidden** |
| The clock **cannot right now** (no address, clock unreachable, sensor in control, no state read yet) | **disabled, with the reason** shown |
| The clock has **reported nothing** (capabilities never queried, switch missing in `audio`) | **allowed**; the pre-send check and the clock reject what is wrong |
| Several target clocks, only some can | disabled only if **none** can; otherwise allowed, and the message names the clocks where it is dropped |

Where the code departs from this rule, see "Deviations".

## Legend

- Source: 🔬 measured (with date), 📄 vendor docs, ❓ not measured.
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
| Clock font (the clock sets the text itself) | yes | yes | 📄 | no capability; switch always present, controls for font, size, bold, border, spacing, alignment greyed while on | Mac/iPad, iPhone |
| Font size does not fit the height | – | 16 px does not fit 8 rows: largest fitting size of the same font, note under the preview | 🔬 9 Oct 2026 | display size of the target clock (`Meldungsbau`, `Pixelgroessen`) | all (automatic) |
| Icon 8×8 | yes | yes | 🔬 9 Oct 2026 | target clock size | all |
| Icon 16×16 | yes | replaced by its 8×8 version if there is one | 🔬 9 Oct 2026 | `Iconbestaende.passend(_:fuer:)` by display size | all (automatic, note) |
| Finished image (painted, collection) | 52 × 16 only | 32 × 8 only | 🔬 9 Oct 2026 | wrong size: `NGFehler.massPasstNicht`, message says so | Mac/iPad (paint, collection), iPhone (collection), CLI `bild` |
| Layouts (boxes with content) | yes | no (`422 unknown field`) | 🔬 9 Oct 2026 | `capabilities.layout` (`Geraetefaehigkeiten.layoutUnterstuetzt`); `false` makes `Kastenlayout.pruefen` throw `LayoutFehler.nichtUnterstuetzt`, `nil` (never queried) lets it through | CLI `layout` only; no picker in the UI (the help says so) |
| Still/animated GIF, delivery HTTP/MQTT | yes | yes | 🔬 9 Oct 2026 | `Pixelweg.zustellweg` (8192 bytes MQTT) | all |
| Background, effect, overlay, palette | the clock's lists | the clock's lists (19 effects, 16 palette effects, 6 overlays, 8 palettes) | 🔬 10 Oct 2026 | `capabilities.effects/overlays/palettes`; the picker shows the clock's list, an empty list means no picker, `Darstellung.pruefen(gegen:)` | Mac/iPad, iPhone (appearance), CLI `effekte` |
| Clock overlay (remote control) | yes | yes (6) | 🔬 10 Oct 2026 | `capabilities.overlays` not empty | Mac/iPad, iPhone, CLI |
| Transitions, clock faces (settings) | `transitions`, `clockFaces` (5) | 22 `transitions`; `clockFaces` absent, so no clock faces | 🔬 10 Oct 2026 | `capabilities.transitions/clockFaces`; if missing, the built-in clock faces apply | Mac/iPad, iPhone (clock settings), CLI |
| Notification (one-off above the loop) | yes | yes | 🔬 | no capability | all |

### Sound

A sound kind is allowed if the clock's `audio.<switch>` is `true`
(`Geraetefaehigkeiten.kann`); if `audio` or the switch is missing, it is allowed.

| Feature | TC002 | TC001 | Source | How the app decides | Interface |
|---|---|---|---|---|---|
| Play a stored melody | yes | yes (buzzer) | 🔬 10 Oct 2026 | `audio.rtttl` (`Klangart.melodie`) | Mac/iPad, iPhone ("Von der Uhr"), CLI |
| Play RTTTL text | yes | yes | 🔬 10 Oct 2026 | `audio.rtttl` (`Klangart.rtttl`) | CLI `ton spielen --rtttl`, shortcut |
| Play MP3 (file on the clock) | yes | no | 🔬 10 Oct 2026 | `audio.mp3`; a file name is MP3 or melody according to the clock's lists, an unknown name is both | Mac/iPad, iPhone ("Von der Uhr": MP3 section dropped if no target can play MP3: `Klangeignung.mp3Zeigen`), CLI |
| Upload MP3 | yes | no (the clock accepts the file and never plays it) | 🔬 10 Oct 2026 | `Klangeignung.mp3Hochladbar` = `kann(.mp3)`; also disabled without an address | Mac/iPad, iPhone (remote control › sound: button and MP3 list hidden), CLI `ton mp3 hochladen` |
| Song | yes | no | 🔬 10 Oct 2026 | `audio.song` (`Klangart.lied`) | CLI `ton spielen --lied` |
| Speech (`speech`) | yes | no | 🔬 10 Oct 2026 | `audio.speech` (`Klangart.sprache`) | Mac/iPad, iPhone ("Vorlesen"), CLI `--sprache` |
| Radio, choose a station | yes | no | 🔬 10 Oct 2026 | `audio.radio`; radio rows in the remote control only then | Mac/iPad, iPhone, CLI `--sender` |
| MP3 from a web address (`url`) | yes | no | 🔬 10 Oct 2026 | `audio.url` (`Klangart.adresse`) | CLI `ton spielen --datei <address>` |
| Sound clip (`clip`), sound effect (`effect`), track (`track`) | `clip` yes, `effect` yes, `track` no | all no | 🔬 10 Oct 2026 | not offered by the app | – |
| Sound in a message (several target clocks) | – | – | – | `Klangeignung.verteilen`: the sound goes only to clocks that play it; the message goes to all | Mac/iPad, iPhone, CLI |
| Volume, "Spielt", stop | yes | yes (buzzer) | 📄 | no capability; disabled without an address or if `audio` is entirely empty | Mac/iPad, iPhone, CLI |
| Sound collection: store/sync melodies to the clock | yes | yes | 🔬 10 Oct 2026 | `kann(.melodie)` (`Klangabgleich`) | Mac/iPad, iPhone (settings › sounds), CLI `ton abgleichen` |
| Sound collection: sync MP3 | yes | skipped (`faehigkeitFehlt`) | 🔬 10 Oct 2026 | `Klangeignung.mp3Hochladbar` | as above |

### Remote control and clock settings

| Feature | TC002 | TC001 | Source | How the app decides | Interface |
|---|---|---|---|---|---|
| Display on/off, brightness | yes | yes | 🔬 10 Oct 2026 | no capability; slider disabled while nothing is read from the clock or the sensor is in control | Mac/iPad, iPhone, CLI |
| Automatic brightness (light sensor) | no (`sensors.light` `false`) | yes (`sensors.light` `true`) | 🔬 10 Oct 2026 | `Geraetefaehigkeiten.lichtsensor`; "Automatisch" switch only with a sensor, `autoBrightness` is otherwise never written (`Geraeteeinstellung.wirkt`), the slider is disabled while automatic is on | Mac/iPad, iPhone (remote control, clock settings), CLI `helligkeit auto` |
| Moodlight | yes | ❓ | 🔬 TC002 | no capability | Mac/iPad, iPhone, CLI |
| Indicators (3) | yes | ❓ | 🔬 TC002 | no capability | Mac/iPad, iPhone, CLI |
| Buttons, knob (read only via MQTT) | yes | ❓ (knob) | 📄 | operating mode `mqtt`; otherwise rows greyed with the note "nur im MQTT-Betrieb" | Mac/iPad, iPhone |
| Live image of the display | yes | ❓ | 🔬 TC002 | image at the clock's size | Mac/iPad, iPhone, CLI `bildschirm` |
| Restart | yes | yes | 📄 | no capability | Mac/iPad, iPhone, CLI |
| MQTT over TLS, upload CA | yes (`mqttTls` `true`) | no (`mqttTls` absent) | 🔬 10 Oct 2026 | `capabilities.mqttTls`; group "Verschlüsselung" only when `true` | Mac/iPad, iPhone (clock settings), CLI `tls` |
| `enlargeApps` | yes, not writable | does not exist | 🔬 9 Oct 2026 | the app rasterises every image for the display size; the setting is never written (`Geraeteeinstellung.schreibbar`) | – |
| Virtual clock | TC002 mode (default) | `NGTon.tc001` (only `audio` and `platform.id`) | 🔬 10 Oct 2026 | `NGTon.faehigkeiten`, `NGUhrzustand.lichtsensor` | Mac/iPad, iPhone (settings), tests |

## Deviations

As of this version. Not fixed, only recorded; each line measured against the
rule above.

1. **Never possible, but disabled instead of hidden.**
   - `Sources/TC002Ansichten/Tonbausteine.swift:52-53`: the sound picker offers
     "Von der Uhr" and "Vorlesen" disabled (`selectionDisabled`) even when the
     only target clock can never do it (TC001: "Vorlesen"). With several targets
     disabling is correct.
   - `Sources/TC002Ansichten/Tonbausteine.swift:62-71`: the reason lines "Von der
     Uhr: …" and "Vorlesen: …" are shown as well.
   - `Sources/TC002Ansichten/Tonbausteine.swift:111`: melodies in the list are
     disabled instead of hidden when no target clock can play melodies.
   - `Sources/TC002Ansichten/Tonbausteine.swift:219` (with `.disabled(gesperrt)`):
     the whole "Ton" section stays visible and greyed with "Diese Uhr meldet
     keinen Ton." when `audio` is entirely empty.
   - `Sources/TC002Ansichten/Klangsammlungsansicht.swift:342`: "Sichern" for a
     melody is disabled when the clock has no `rtttl`.
2. **Unknown, but hidden instead of allowed.**
   - `Sources/TC002Ansichten/Fernbedienung.swift:54` and `:208`: "Automatisch"
     is missing while capabilities are unread or `sensors` is missing from the
     answer (`lichtsensor` is then `false`).
   - `Sources/TC002Core/Geraeteeinstellungen.swift:173` (called from
     `Sources/TC002Ansichten/Uhrgruppen.swift:170`): without an answer
     `autoBrightness` has "no effect" and the row disappears. Intended (avoid
     writing an ineffective setting, §7.4), but it departs from "unknown →
     allowed".
   - `Sources/TC002Ansichten/Uhrgruppen.swift:76`: the group "Verschlüsselung" is
     missing without `mqttTls: true`, even if never queried.
3. **Not bound to capabilities although unmeasured for the TC001.**
   `Fernbedienung.swift` shows moodlight, indicators, knob, live image, and the
   settings pages "Klang" (`bootSound`, `musicSource`), transitions and clock
   faces (`Uhrgruppen.swift:46-100`) indiscriminately for both models. The TC001 reports neither `clockFaces` nor `bootSound`
   (keys absent, measured 10 Oct 2026): `Uhrgruppen.swift:55` and `:205` still shows the built-in
   clock face list, and `bootSound` (group "Klang", `Uhrgruppen.swift:67`) depends on no
   capability; both should disappear when the key is absent. Moodlight, indicators, knob
   and live image have no capability key and stay ❓.
4. **Virtual clock in TC001 mode.** `Sources/TC002Core/VirtuelleNGUhrTon.swift:100-108`
   only switches `audio` and `platform.id`; `layout`, `display` (52 × 16),
   `mqttTls`, `clockFaces`, `bootSound`, `enlargeApps` and the lists stay those of the TC002. The virtual
   TC001 therefore reports layouts and 52 × 16, which the real one does not have.

## Open questions

- Moodlight, indicators, knob and live image have no capability key; only a
  trial on the device shows whether the TC001 has them.
