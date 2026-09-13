# mqtt-tc002

*[Deutsche Fassung](README.md)*

Send messages to the Ulanzi TC002 (Pixbar, 52×16) — over MQTT.

## What the app does

MQTT-TC002 is a macOS app that sends text, images and hand-drawn icons to one
or more Ulanzi TC002 pixel clocks. The route there goes through an MQTT broker,
not straight to the clock — the clock listens to the broker, not to the app.

## Building

`./build.sh` packages up `build/MQTT-TC002.app`. If you would rather work in
Xcode, open `Package.swift` directly. There are no external package
dependencies; macOS 14 or newer is required.

## The five areas

- **Connection** — enter clocks and query them, manage broker access.
  "Query" determines the topic prefix and the MAC directly from the clock;
  nothing is entered by hand here.
- **Send** — assemble text and optionally an icon into a named display and
  send it off. Five blocks show the clock's fixed slots, with their content
  where the app knows it. The preview comes from the same raster as the
  message that is sent. There are two ways to choose from: **as pixels**,
  rasterized by the app itself, with umlauts and any font — if the text does
  not fit, it runs through by itself as scrolling text; or **as text**, set
  by the device, which scrolls with its own font for that, but does not know
  umlauts.
- **Draw** — a free 52×16 canvas, which turns into rectangles instead of
  single pixels when sent.
- **Icons** — draw your own 8×8 images or fetch them via a LaMetric number.
- **Displays** — switch or delete what the app has already created on the
  active clock, plus the clock's page cycling. The app keeps this list
  separately per clock: deleting always happens only on the active one, and
  whatever went to other clocks via "to all" stays there until it is deleted
  there.

How these areas are operated in detail is in the help inside the program
(⌘?); what the clock itself can do and what its protocol looks like is in
[`docs/tc002-protokoll.md`](docs/tc002-protokoll.md). What a device running the
AWTRIX NG firmware can do and what its protocol looks like is alongside it in
[`docs/en/awtrix-ng-protocol.md`](docs/en/awtrix-ng-protocol.md).

## Fonts and spacing

Three pixel fonts are included — **Micro 5**, **Silkscreen** and **Tiny5**,
all under the SIL Open Font License. They are designed on a pixel grid, not as
screen fonts with curves, and therefore sit exactly on the dots of the display
at their design size. There are no odd in-between sizes for them: there the
strokes land between two pixels, and without antialiasing — which the display
does not have — a threshold decides arbitrarily. That is why the picker offers
only the clean sizes.

On top of that there are a few fonts from the system, for everyone who likes
it more ordinary.

The **margin** setting determines how many rows stay free with "top" and
"bottom". It is needed because flush looks different from font to font: some
bring space above the cap height, others do not.

The **spacing** setting is not kerning in the usual sense: the app rasterizes
every character individually, measures where its ink starts and stops, and
places the characters next to each other so that exactly as many empty columns
stand between them as are set. So the value is literally a number of pixel
columns. The advance widths of the font are discarded in the process — they
are meant for print sizes and, on sixteen pixels, produce letter pairs that
are sometimes too tight and sometimes too loose.

## Why text as pixels works

The built-in font of the clock does not know umlauts and barely any
punctuation. The app gets around that by not sending text as a string, but
rasterizing it itself with CoreText and transmitting it as `draw` rectangles —
that way "ä", "ö", "ü" and "ß" work anyway, and the preview shows exactly the
image that is also sent, because both come from the same pixel field.

## Icons

All icons live in one place:
`~/Library/Application Support/MQTT-TC002/Icons` — not in the app bundle,
because there they would be gone with the next build, and under
`/Applications` the folder is not writable anyway. They get there in three
ways: a **starter set** of around thirty 8×8 icons is taken over from the app
package once, on the very first launch; after that they are perfectly ordinary
icons of your own — deletable and overwritable. More are created in the 8×8
editor under "Icons" or can be fetched by their number from
developer.lametric.com. Anyone who has tidied up too thoroughly gets missing
starter-set icons back with "Restore starter set"; what is already there stays
untouched.

## On the command line

A command-line tool ships inside the app bundle and uses the same setup as the
app — broker, password and clocks come from its settings. Setting up still
happens only in the app. Link it once:

```bash
mkdir -p ~/.local/bin
ln -sf /Applications/MQTT-TC002.app/Contents/MacOS/mqtttc002 ~/.local/bin/mqtttc002
```

```bash
mqtttc002 "Coffee is ready"
mqtttc002 send "Mail arrived" --icon 1673 --color "#FFAA00" --duration 10
mqtttc002 send Attention --to Kitchen --center --bottom
mqtttc002 clocks           # what is set up, * marks the targets
mqtttc002 icons            # number and name
mqtttc002 delete cli       # take the display off the clock again
mqtttc002 help             # every option
```

Every subcommand and option has a German spelling as well, because the app is
German: `senden`, `loeschen`, `umschalten`, `uhren`, `--an`, `--farbe`,
`--dauer`. Both work, in either language.

Text that is too long scrolls by itself as a GIF, exactly as in the app.
`--dry-run` shows topic, payload and size without sending, and says whether a
broker password was found. On the first run, macOS asks once whether the tool
may read the app's Keychain entry.

## Languages

The app comes in German and English and follows the system language. To switch
just this app, use System Settings → General → Language & Region under
"Applications". To try it once:

```bash
/Applications/MQTT-TC002.app/Contents/MacOS/TC002App -AppleLanguages '(en)'
mqtttc002 -AppleLanguages '(en)' help
```

German is the development language: the German wording sits in the source and is
also the lookup key, so a missing translation falls back to the German sentence.
`python3 scripts/texte-sammeln.py --pruefen` reports every visible text without a
translation. Another language is a folder `Resources/Sprachen/<code>.lproj` with a
`Localizable.strings` in it.

## On the iPhone

An iOS version (`MQTT-TC002-iOS.xcodeproj`, iOS 17 and up) shares its core and
state layer with the Mac app. It can set up and query clocks ("Settings"),
send text with an icon and formatting ("Send", the app's root view), and show
what is currently on the active clock plus its log ("History") — both reached
through menu items in the title bar instead of a tab bar of their own.
Deliberately missing: editing icons and the free-form canvas ("Draw"). Both
stay on the desktop.

At the foot of the settings sit "Help" and "About MQTT-TC002", both as sheets:
iOS offers no system-provided place for "About", and the established one is
the end of the app's own settings. The help is not the same as on the Mac —
what depends on the device (the five slots, the three block states, the
silence of MQTT 3.1.1, the three pixel fonts, prefix and broker) lives as
shared text in `TC002Ansichten/HilfeInhalt.swift`, while whatever operates a
particular button lives in each interface's own help. The About sheet shows
the version, the GPL-3.0 with its license text, and the acknowledgements; the
`LICENSE` rides along into the bundle via `project.yml`, as it does on the Mac
via `build.sh`.

Built with

```bash
xcodegen generate
open MQTT-TC002-iOS.xcodeproj
```

then pick a target in Xcode and run. `xcodegen` generates the project from
`project.yml`; the project itself is not checked in. A successful build says
nothing about whether fonts, icons, the app icon, translations, and the
`LICENSE` actually ended up in the bundle — `scripts/buendel-pruefen.sh`
checks that.

## Tests

`swift test` runs without network and without a real device: HTTP calls to the
clock run against a `URLProtocol` stand-in, sending over MQTT against a
`NachrichtSendend` stand-in. The generated MQTT bytes themselves are checked
against a real recording from `mosquitto_pub`. The real clock and the broker in
the house are off limits in tests.

## License

GPL-3.0. The origin is [PixDeck](https://github.com/cailurus/PixDeck), see
"Sources" below.

## Sources

- **Official repository of the manufacturer:**
  https://github.com/UlanziTechnology/Ulanzi-U-Clock-TC002
  Confirms that the prefix is formed as `<eingestellt>_<letzte vier MAC-Stellen>`
  (default `ulanzi`), names `text`, `image`, `draw` and `duration`, and lists,
  besides `df` (rectangle), also `dfc` (filled circle:
  `{"dfc":[x,y,radius,"#RRGGBB"]}`). According to this source, animated GIFs
  are supported in `image`.
- **Not** documented there: the control topic `<praefix>/switchDiyApp` and
  deleting a display by way of an empty payload. We determined both on the
  device on 11 September 2026 — `switchDiyApp` from the SUBSCRIBE lines of the
  broker.
- **PixDeck** (https://github.com/cailurus/PixDeck, GPL-3.0): source of the
  insight that the same JSON also goes over HTTP to `/api/custom?name=<n>`.
