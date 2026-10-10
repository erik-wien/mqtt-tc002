# mqtt-tc002

*[Deutsche Fassung](README.md)*

**Pixel Clock Messenger** sends text, images and control commands to Ulanzi pixel
clocks running the free **AWTRIX NG** firmware — over HTTP or via an MQTT broker.

Since 14 September 2026 the app is called "Pixel Clock Messenger"; the repo, the
bundle identifier `cloud.eriks.mqtt-tc002`, the data folder `MQTT-TC002` and the
`mqtttc002` command keep their names — identity, permissions and existing
collections hang on them.

## Requirements

- **Clock:** Ulanzi **TC002** (52×16 display) or **TC001** (32×8) running AWTRIX NG.
  AWTRIX NG is the only supported firmware; the clock's factory firmware is no
  longer served. The interface, as it shows on the device, is described in
  [`docs/en/awtrix-ng-protocol.md`](docs/en/awtrix-ng-protocol.md). What each model
  supports is in [`docs/en/features-per-clock.md`](docs/en/features-per-clock.md).
- **Network:** The clock must be reachable on the same network. Over HTTP its
  address is enough; MQTT additionally needs a broker the clock listens to.
- **System:** macOS 14, iOS 17 (iPhone and iPad) or later. There are no external
  package dependencies.
- **Without a clock** you can try everything with the built-in virtual clock
  (see below).

## What the app does

- **Send:** text with icon, font, size, color, margin, spacing and alignment. The
  app rasterizes the text itself and sends the clock pixels; the preview shows
  exactly what goes out (except with "Clock font", where the clock sets the text
  in its own font). Five blocks show the clock's fixed slots. Images go
  pixel-exact as a GIF at the size of the target clock's display; moving ones as
  an animated GIF.
- **Appearance:** background color, effects, overlays (weather) and palettes, as
  the clock itself offers them.
- **Displays and messages:** A display sits in a slot and runs in the
  clock's loop, with duration and lifetime (expires by itself or stays). A
  message interrupts the loop once, can be held and dismissed, and can bring
  a sound (melody, MP3, speech).
- **Several clocks:** target selectable per send, method per clock (HTTP or MQTT).
- **Clock control:** remote control with a live picture of the display, state,
  display on/off, brightness, moodlight, indicators, overlay, restart, plus sound
  and radio; buttons and dial where the app reads them along.
- **Clock settings:** the settings stored on the clock, in groups, plus the TLS
  certificate for MQTT.
- **Editor (Mac, iPad):** paint icons (8×8, 16×16) and whole displays, with
  animation; icons can be fetched by LaMetric number.
- **Shortcuts (iPhone, iPad)** and **command line (Mac)**.
- **Sync** of your own collections via iCloud; German and English.

How to use all this is in the in-app help (⌘?).

## Building

`./build.sh` assembles `erzeugt/mac/MQTT-TC002.app`. If you prefer Xcode, open
`Package.swift`.

The iOS version is generated from `project.yml`; the project itself is not
checked in:

```bash
xcodegen generate
open MQTT-TC002-iOS.xcodeproj
```

A green build says nothing about whether fonts, icons, the app icon,
translations and the `LICENSE` ended up in the bundle — `scripts/buendel-pruefen.sh`
checks that.

## On the command line

The Mac bundle carries a tool that uses the same setup as the app — clocks,
method and broker come from its settings; setting up happens only in the app.
Link it once:

```bash
mkdir -p ~/.local/bin
ln -sf /Applications/MQTT-TC002.app/Contents/MacOS/mqtttc002 ~/.local/bin/mqtttc002
```

```bash
mqtttc002 "Coffee is ready"
mqtttc002 senden "Mail" --icon post --farbe "#FFAA00" --dauer 10
mqtttc002 senden Attention --an Kitchen --zentriert --unten
mqtttc002 nachricht "Door open" --name door   # one-off message over the loop
mqtttc002 zurueckziehen door
mqtttc002 layout boxes.json                   # boxes with one content each
mqtttc002 bildschirm                          # the clock's display as text
mqtttc002 helligkeit 120 ; mqtttc002 moodlight --farbe "#FF8800"
mqtttc002 ton spielen --sprache "Hello"       # sound, melody, radio
mqtttc002 uhren                               # what is set up
mqtttc002 hilfe                               # all commands and options
```

(The command names are German; `mqtttc002 -AppleLanguages '(en)' hilfe` prints
the help in English.)

Over MQTT the tool waits for the clock's answer: if it rejects, the reason goes
to the error output and the call ends with 1. `--trocken` shows what would be
sent. On the first run macOS asks once whether the tool may use the app's
Keychain entry.

## Trying it without a clock

In Settings under "Advanced" there is the switch **"Virtual clock"**. It starts a
small HTTP service on `127.0.0.1:8752` that speaks the AWTRIX NG interface and
shows the displays in a window with a device frame. "Add as clock" puts it in the
clock list; from then on querying, sending, deleting and the history work as
with a device. It listens on your own computer only and speaks HTTP, not MQTT.

## Languages

The app comes in German and English and follows the system language. German is
the development language: the German wording is in the source and is also the
key. `python3 scripts/texte-sammeln.py --pruefen` reports every visible text
without a translation. A further language is a folder
`Resources/Sprachen/<code>.lproj` with a `Localizable.strings`.

## Tests

`swift test` runs without network and without a real device: HTTP calls run
against a `URLProtocol` stand-in, sending over MQTT against a `NachrichtSendend`
stand-in, and some tests talk to the virtual clock over a port on `127.0.0.1`.
The generated MQTT bytes are checked against a real recording from
`mosquitto_pub`.

## License

GPL-3.0, with an **additional permission** for distribution through an
application distribution service — see
[`LIZENZ-AUSNAHME.md`](LIZENZ-AUSNAHME.md). Without it the App Store would be a
licence violation, even with the source published.

No source code from [PixDeck](https://github.com/cailurus/PixDeck) is included:
it was a reference for how the device behaves, and facts about a device are not
copyrightable. The three pixel fonts (Micro 5, Silkscreen, Tiny5) are under the
SIL Open Font License.
