# Remote-controlling AWTRIX NG

*[Deutsche Fassung](../awtrix-ng-protokoll.md)*

What a device running the **AWTRIX NG** firmware can do and how to address it —
over MQTT and over HTTP. This description is independent of our app: it applies
just as well to `mosquitto_pub`, Node-RED, Home Assistant or a script of your
own.

Every statement carries its provenance:

| Mark | Meaning |
|---|---|
| 📄 | from the [AWTRIX NG documentation](https://blueforcer.github.io/awtrix-ng/), not cross-checked on a device |
| 🔬 | read on a device itself |
| ❓ | open — the documentation does not say |

**The documented statements refer to the state of the `main` branch as of
2026-09-13**, the measurements to a device running **AWTRIX NG 1.1.0**
(`boardType awtrixng`, `soc esp32`), read on 2026-09-13 via
`GET /api/v1/device`. What carries 🔬 holds, to begin with, for that one device
and that one build; what carries 📄 holds for the firmware in general.

---

## 1. The display

📄 **The height is fixed at 8 pixels** and not configurable. The width comes
from `panelWidth × panels` and **must come to between 32 and 128**; the default
is `32 × 1`. A value outside that range is refused with `422 validationFailed`
on `panelWidth`.

🔬 The measured device is set to `panelWidth 32`, `panels 1`;
`GET /api/v1/display/screen` accordingly answers `"width":32,"height":8` with
256 pixel values.

📄 The origin is at the top left. The canvas for icons is **always 32×8**,
regardless of the panel width.

📄 **Colors** are accepted in five forms and returned in one:

| Form | Example | Note |
|---|---|---|
| `"RRGGBB"` | `"FF8800"` | leading `#` optional |
| `"RGB"` | `"F80"` | shorthand, each digit doubled |
| `[r, g, b]` | `[255, 136, 0]` | each channel clamped to 0–255 |
| `["HSV", h, s, v]` | `["HSV", 32, 100, 100]` | `h` wrapped into 0–359, `s`/`v` clamped to 0–100 |
| packed integer | `16746496` | `0xRRGGBB` |

Reading back is always uppercase `"#RRGGBB"`. Every channel is an integer; a
fractional value is rejected. `null` means **inherit or off**, not black.

📄 **Keys are `camelCase`** throughout, and **durations are integer
milliseconds** carrying an `...Ms` suffix. The single exception is the
read-only `uptimeSeconds` in `GET /api/v1/device`.

---

## 2. The topic prefix

📄 The prefix `<P>` is exactly what stands in `mqttPrefix` — **unchanged, with
nothing appended**. Leave it empty and the **device uid** takes its place, that
is the twelve-character MAC address (`a4cf12ab34cd/cmd/notify`). The MQTT
client id is the uid as well.

🔬 On the measured device `GET /api/v1/system` reports
`"mqttPrefix":"wlmonitor/board"`, and the device log (`GET /api/v1/logs`)
carries the same string: `mqtt: broker akadbrain.local:1883, prefix
wlmonitor/board`. A prefix may therefore span several topic levels.

📄 The device also publishes its prefix under the prefix itself:
`<P>/state/prefix` carries `<P>` as a plain string, retained.

❓ Whether `mqttPrefix` is checked for the MQTT wildcards (`#`, `+`) **is not
stated**: the key table gives `mqttPrefix` neither a character set nor a range.

📄 Topics outside `<P>/` are not read.

---

## 3. The MQTT topics

📄 The device connects to **one** broker. **QoS 0 everywhere** — publishes,
subscriptions and the last will; a message lost in transit is lost silently.
A command payload is **byte-identical** to the body of the corresponding HTTP
request.

### 3.1 The connection

| Key | Type | Default | Meaning |
|---|---|---|---|
| `mqttEnabled` | bool | `false` | master switch; `true` runs the client (requires a non-empty `mqttHost`) |
| `mqttHost` | string | `""` | broker |
| `mqttPort` | int | `1883` | 1–65535 |
| `mqttUser` / `mqttPass` | string | `""` | both empty = anonymous |
| `mqttPrefix` | string | `""` | topic prefix `<P>`; empty → uid |
| `haDiscovery` | bool | `false` | publish the Home Assistant document |
| `haPrefix` | string | `"homeassistant"` | its prefix |

These keys live in the **device configuration** (`/api/v1/system`), not in the
display settings.

📄 A failed connection attempt is retried after 5 s, then 10, 20, 40, and at
most every 60 s, each delay shortened by up to 20% of jitter. A successful
connection resets the schedule.

### 3.2 Commands — only under `<P>/cmd/`

📄 Everything under `<P>/state/` is outbound-only. `<P>/cmd` and `<P>/cmd/` on
their own match nothing.

| Topic | Payload | HTTP equivalent |
|---|---|---|
| `cmd/notify` | notification JSON | `POST /api/v1/notifications` |
| `cmd/notify/dismiss` | ignored | `DELETE /api/v1/notifications/active` |
| `cmd/notify/dismiss/<name>` | ignored | `DELETE /api/v1/notifications/{name}` |
| `cmd/apps/pushed/<name>` | pushed-app JSON; **empty or `{}` deletes** | `PUT /api/v1/apps/pushed/{name}` / `DELETE /api/v1/apps/{name}` |
| `cmd/apps/switch` | bare app name **or** `{"name":…,"fast":bool}` | `PUT /api/v1/apps/active` |
| `cmd/apps/next` · `cmd/apps/previous` | ignored | `POST /api/v1/apps/next` / `/previous` |
| `cmd/apps/order` | `{"order":[…],"disabled":[…]}` — `disabled` required, `order` optional | `PUT /api/v1/apps/order` |
| `cmd/settings` | partial settings JSON | `PATCH /api/v1/settings` |
| `cmd/settings/reset` | ignored | `POST /api/v1/settings/reset` |
| `cmd/display` | `{"power":bool?,"overlay":"rain"\|null?}` | `PATCH /api/v1/display` |
| `cmd/display/moodlight` | moodlight JSON; **empty = off** | `PUT` / `DELETE /api/v1/display/moodlight` |
| `cmd/indicators/1` · `/2` · `/3` | `{"color","blinkMs","fadeMs"}`; empty or `{}` = off | `PUT` / `DELETE /api/v1/indicators/{id}` |
| `cmd/audio/play` | exactly **one** of `sound`, `mp3`, `melody`, `track`, `rtttl`, `station`, `index`, `url` | `POST /api/v1/audio/play` |
| `cmd/audio/stop` | optional `{"scope":"sounds"\|"stream"\|"all"}` | `POST /api/v1/audio/stop` |
| `cmd/audio/stations` | `{"stations":[…]}` | `PUT /api/v1/audio/stations` |
| `cmd/device/reboot` | ignored | `POST /api/v1/device/reboot` |
| `cmd/device/sleep` | `{"durationMs":ms}`, `> 0` | `POST /api/v1/device/sleep` |
| `cmd/screen/get` | ignored | publishes `<P>/state/screen` |

📄 The **factory reset is not reachable over MQTT** — only
`POST /api/v1/device/factory-reset`. Publishing to
`<P>/cmd/device/factory-reset` does nothing and answers nothing.

📄 The name in `cmd/apps/pushed/<name>` is the remainder of the topic after
`apps/pushed/` and must match `[A-Za-z0-9_-]{1,32}`. `cmd/apps/pushed/` with an
empty name matches nothing.

📄 The id in `cmd/indicators/<id>` must be a **single character** `1`, `2` or
`3`. Anything else matches no route and is therefore dropped silently, while
the HTTP route at the same place answers `404` with
`indicator id must be 1..3`.

### 3.3 Two traps that close silently

📄 **A payload over 8192 bytes is dropped before it is parsed — no error, no
`/result` reply.** Over HTTP the same thing would be a `413 payloadTooLarge`;
over MQTT there is no sign of it at all. A large notification is the realistic
way to hit this.

📄 **A topic that matches no route produces no reply whatsoever** — no error,
no acknowledgement. **Typos are therefore invisible.** If a command seems to
vanish without a trace, check the spelling of the topic first.

### 3.4 The reply on `<topic>/result`

📄 Every command that **matches a route** is answered on `<cmd topic>/result`,
non-retained, QoS 0:

```
awtrixNG/cmd/settings        ->  awtrixNG/cmd/settings/result
awtrixNG/cmd/apps/pushed/x   ->  awtrixNG/cmd/apps/pushed/x/result
```

Success is exactly `{"ok":true}`. A failure carries the same error body as
HTTP, wrapped in `ok:false` (`field` is omitted when it would be empty):

```json
{"ok":false,"error":{"code":"validationFailed","message":"invalid value","field":"brightness"}}
```

The `code` values match HTTP exactly; two messages are less specific
(`notFound` collapses to a bare `not found`, and `invalidJson` says `payload`
where HTTP says `request body`). The framing codes HTTP uses
(`methodNotAllowed`, `unauthorized`, `unsupportedMediaType`, …) have no MQTT
equivalent. A `/result` topic is never itself read as a command, so replies do
not loop.

### 3.5 State topics

| Topic | Content | Retained | When |
|---|---|---|---|
| `<P>/state/device` | device JSON, the shape of `GET /api/v1/device` | yes | every `statsInterval` (default 10 000 ms, floored at 1 000), and at once when matrix power or an indicator changes |
| `<P>/state/settings` | settings JSON | yes | on every settings change, and on connect |
| `<P>/state/apps/active` | name of the running app, **plain string, not JSON** | yes | immediately on change, and on connect |
| `<P>/state/audio` | audio JSON | yes | on play, stop, track change and error, and on connect |
| `<P>/state/capabilities` | `{"effects","paletteEffects","transitions","overlays","palettes","radio","gpio"}` | yes | once per connect |
| `<P>/state/prefix` | `<P>` itself, plain string | yes | once per connect |
| `<P>/state/buttons/left` · `/select` · `/right` | `"1"` / `"0"` | yes | on every button edge, and on connect |
| `<P>/state/screen` | `{"width":W,"height":H,"pixels":[…]}` | **no** | only as the reply to `cmd/screen/get` |
| `<P>/availability` | `online` / `offline` | yes | on connect, and as the last will |

📄 `statsInterval` is the **slowest** rate at which `state/device` publishes,
not the only trigger. Consecutive change-driven publishes are spaced at least
250 ms apart. Brightness is not a trigger. `state/settings` and
`state/apps/active` are purely event-driven.

📄 **There is no MQTT topic listing the apps.** Reads are served over HTTP
only: `GET` routes have no MQTT equivalent, and the device instead pushes its
state onto the retained `state` topics.

📄 `<P>/availability` is registered as the broker-side last will at CONNECT
(`offline`, retained) and published as `online` immediately on a successful
connect.

📄 What the device publishes **to you** has no size limit; `state/device` and
`state/screen` go out at whatever size they are.

### 3.6 Home Assistant

📄 With `haDiscovery` on, a single retained document is published under
`<haPrefix>/device/<uid>/config` (HA device discovery, requiring Home Assistant
2024.11 or newer). **There is no second topic tree:** every component points at
the same `<P>/cmd/…` and `<P>/state/…` topics. Turning it off publishes an
empty retained payload to the same topic.

---

## 4. The HTTP interface

📄 The base is `http://<ip>:<webPort>`; `webPort` is device configuration
(default 80, a value `<= 0` falls back to 80). In access-point (provisioning)
mode the server always listens on port 80.

### 4.1 What applies to every request

📄 **`Content-Type: application/json` is mandatory** on every request carrying
a JSON body. `PUT` and `PATCH` declaring any other type are refused with
`415 unsupportedMediaType` before the body is read; a `POST` is not type-checked
at all — its body simply arrives empty and the request fails as
`400 invalidJson`. Both failures come from the same omission. The one exemption
is `PUT /api/v1/apps/script/{name}`, which carries Berry source and accepts any
type.

📄 **Basic auth is off by default** — the whole interface is open on the LAN.
It turns on with `authEnabled` (which requires a stored username and password)
and is then enforced in **every** mode, provisioning included. It covers the
API, the web UI at `/` and the static directories.

📄 **Every failing request** carries the same body:

```json
{ "error": { "code": "validationFailed", "message": "invalid value", "field": "brightness" } }
```

`code` is machine-readable and stable — match on it, never on `message`, which
is English prose for humans. `field` is present only when a specific input key
caused the failure. The one route answering in its own shape is
`POST /api/v1/restore`.

🔬 On the measured device an unknown route answers
`{"error":{"code":"notFound","message":"unknown route"}}` and a wrong method
answers `405` with
`{"error":{"code":"methodNotAllowed","message":"allowed method(s): DELETE"}}` —
the permitted methods are named in the message.

📄 A `POST` carrying `X-HTTP-Method-Override` is checked as the method it names,
and therefore needs the same `Content-Type` as a real `PATCH`.

### 4.2 The routes

| Route | Purpose |
|---|---|
| `GET /api/v1/device` | state and statistics (the same shape as `state/device`) |
| `GET /api/v1/version` · `GET /version` | the version as JSON, or as `text/plain` |
| `POST /api/v1/device/reboot` | reboot |
| `POST /api/v1/device/sleep` | deep-sleep for `{"durationMs"}`, then boot normally |
| `POST /api/v1/device/factory-reset` | clear settings and device configuration, format the filesystem |
| `GET /api/v1/settings` | all 40 display settings, every one always present |
| `PATCH /api/v1/settings` | any subset; everything is checked before anything is written |
| `POST /api/v1/settings/reset` | clear the settings and reboot; the device configuration stays |
| `GET /api/v1/display` · `PATCH` | matrix power, brightness, overlay, moodlight |
| `PUT` / `DELETE /api/v1/display/moodlight` | flood the panel with one color, or turn it off |
| `GET /api/v1/display/screen` | the current framebuffer |
| `GET /api/v1/apps` | the full inventory: the arranged apps first, in their order, then everything else |
| `PUT /api/v1/apps/active` | switch |
| `POST /api/v1/apps/next` · `/previous` | page forward and back |
| `PUT /api/v1/apps/order` | which apps are on, and the order of the ones that draw |
| `PUT /api/v1/apps/pushed/{name}` | create or replace a pushed app |
| `DELETE /api/v1/apps/{name}` | delete an app, whatever kind it is |
| `GET` / `PUT /api/v1/apps/script/{name}` | read Berry source (as `text/plain`) or install it |
| `GET` / `PATCH /api/v1/apps/{name}/config` | the settings a script offers |
| `GET /api/v1/scripts/shared` | what the installed scripts have published to each other |
| `POST /api/v1/notifications` | interrupt the rotation with a one-shot message |
| `DELETE /api/v1/notifications/active` | dismiss the notification currently on screen |
| `DELETE /api/v1/notifications/{name}` | dismiss the named one, wherever it sits in the queue |
| `PUT` / `DELETE /api/v1/indicators/{id}` | the three edge indicators |
| `GET /api/v1/audio` | playback status and the station list in one read |
| `GET` / `PUT` / `DELETE /api/v1/audio/melodies[/{name}]` | melodies |
| `GET` / `POST` / `DELETE /api/v1/audio/mp3[/{name}]` | MP3 files |
| `POST /api/v1/audio/play` · `/stop` | play, stop |
| `PUT /api/v1/audio/stations` | replace the whole station list |
| `GET /api/v1/capabilities` | the name lists of this build — fetch these rather than hardcoding names |
| `GET /api/v1/system` | 64 of the 67 configuration fields; the JSON key is the field name for every one |
| `PUT /api/v1/system` | partial merge, everything checked, the GPIO map validated as a whole |
| `GET /api/v1/system/wifi-scan` | Wi-Fi scan, asynchronous — poll it |
| `GET /api/v1/logs` | the incremental device log behind the web console |
| `GET` / `POST` / `DELETE /api/v1/files` | the file store |
| `POST /update` | firmware upload (`multipart/form-data`) |
| `POST /api/v1/restore` | restore a backup (`.zip`, store-only) |
| `GET /` | the embedded web UI, gzipped |
| `GET /ICONS/*`, `/MELODIES/*`, `/PALETTES/*`, `/MP3/*`, `/SCRIPTS/*`, `/apploop.json` | static files from LittleFS, **`GET` only** |

📄 Deletion via `DELETE /api/v1/files` is confined to `/ICONS`, `/MELODIES`,
`/PALETTES` and `/MP3`.

---

## 5. The payload of a display

📄 The same shape serves `PUT /api/v1/apps/pushed/{name}` and
`POST /api/v1/notifications` — and therefore `cmd/apps/pushed/<name>` and
`cmd/notify` as well.

📄 **An app's name comes from the path, never from the body.** It must match
`[A-Za-z0-9_-]{1,32}` and is checked before the payload is parsed; a malformed
one is `400 invalidName`. Any method other than `PUT` on
`/api/v1/apps/pushed/{name}` is `405 methodNotAllowed`.

📄 A pushed app lives **in RAM** until it is replaced, deleted, expired by
`lifetimeMs`, or the device restarts. Nothing is written to flash for it.

📄 **An empty body or the literal `{}` on `PUT` is not a delete**: it answers
`422` and points at `DELETE /api/v1/apps/{name}`. Over MQTT it is the other way
round — there exactly that deletes.

### 5.1 Text

| Key | Type | Range | Default | Meaning |
|---|---|---|---|---|
| `text` | string \| array | — | `""` | the page text, or an array of colored fragments |
| `textCase` | string | `inherit` · `upper` · `asTyped` | `inherit` | casing; `inherit` follows the global `uppercase` setting |
| `font` | string | `small` · `large` | `small` | which panel font to draw with. `large` is seven rows tall and reaches the top row |
| `textColor` | color \| `"palette"` | — | global `textColor` (`#FFFFFF`) | text color, or paint from the app's palette |
| `textBlinkMs` | int | ms, 0 = off | `0` | blink period |
| `textFadeMs` | int | ms, 0 = off | `0` | sinusoidal fade period |
| `textCenter` | bool | — | `true` | center text that fits; `false` left-aligns |
| `scroll` | object \| string | see 5.2 | inherited | text motion |
| `textOffsetX` | int | px | `0` | X shift applied after positioning |
| `textInFront` | bool | — | `false` | draw order only |

📄 **The baseline sits fixed on row 6**; there is no vertical control.
`textInFront` sets z-order only: `true` paints the decorations (draw commands,
progress bar, charts) first and the text on top, the default `false` the other
way round.

📄 `textCenter` takes effect only while the text is **not** animating — with
`scroll.mode: "static"`, or when it fits and `scroll.whenFits` is `static`. The
text is then centered in the space to the right of the icon column (or across
the whole panel when there is no icon), and never overlaps the icon.
`textOffsetX` is added to the final x in the static case and participates in
**every** scroll anchor.

📄 `text` is folded from UTF-8 into the matrix font's codepage: **Latin-1
accents, Latin Extended-A, `€` and Cyrillic all have their own glyphs.** A
character with no mapping — an emoji, an unsupported script — renders as
**exactly one `?`**, one per dropped character, not one per byte. A number or
bool passed as `text` is silently ignored, leaving the text empty. **There is
no lowercase mode.**

🔬 On the measured device the global `uppercase` setting is `true`.

📄 **Colored fragments:** instead of a string, `text` takes an array of
`{"text": string, "color": color}`. Fragments draw left-to-right, each
advancing by its own rendered width; there is no cap on their count. A missing
or non-string `text` yields `""`; a fragment without a `color` is white. With a
fragment array the top-level `textColor` is ignored — unless it is `"palette"`,
which paints the whole run from the palette and ignores the fragment colors.
`textBlinkMs`, `textFadeMs`, `textCase` and `uppercase` apply either way.

📄 **Which color wins**, checked in this order:

| Priority | Condition | Result |
|---|---|---|
| 1 | `textColor: "palette"` with a `palette` set | ramp across the text; `textBlinkMs`/`textFadeMs` **ignored** |
| 2 | `textFadeMs > 0` | smooth pulsing fade of the resolved color |
| 3 | `textBlinkMs > 0` | blink of the resolved color |
| 4 | — | `textColor`, else the global `textColor` |

### 5.2 Scrolling

📄 `scroll` takes an object of seven independent fields:

| Field | Type | Range | Default | Meaning |
|---|---|---|---|---|
| `mode` | string | `static` · `wrap` · `loop` · `bounce` | `wrap` | motion behaviour |
| `direction` | string | `left` · `right` | `left` | travel direction |
| `entry` | string | `inline` · `offscreen` | `inline` | start at rest on the panel, or scroll in from outside |
| `whenFits` | string | `static` · `scroll` | `static` | whether text that already fits still animates |
| `speed` | int | ≥ 0 | `100` | percent of the base rate |
| `gap` | int | ≥ 0 | `8` | `loop` only — pixels between repetitions |
| `holdMs` | int | ≥ 0 | `1000` | pause before the text starts moving, and at each `bounce` turn |

| `mode` | Motion | Cycle counted | Hold |
|---|---|---|---|
| `static` | none; the text is drawn at its aligned position and overflow is clipped | never | — |
| `wrap` | runs from the start anchor until it has fully exited, then jumps back | per exit | at the start anchor, on every cycle |
| `loop` | continuous; a fresh copy always slides in `gap` pixels behind the last, so the screen is never empty | per fold | initial only |
| `bounce` | sweeps between resting beside the icon (or the left edge) and sitting flush against the far edge | per round trip | at **both** turning points |

### 5.3 Icon

| Key | Type | Default | Meaning |
|---|---|---|---|
| `icon` | string | `""` | icon ID, or inline base64 once it is longer than 64 characters |
| `iconMode` | string | `fixed` | `fixed` · `pushOnce` · `push` |
| `iconOffsetX` | int | `0` | X shift only |

📄 **The mode is chosen purely by length:**

- **64 characters or fewer** — an icon ID resolved against the filesystem:
  animated `/ICONS/<id>.gif` is tried first, then static `/ICONS/<id>.jpg`;
- **more than 64 characters** — inline base64, decoded and sniffed: a `GIF8`
  magic makes it an animated GIF, otherwise it is decoded as JPEG.

📄 Only **JPEG and GIF**, no PNG, no BMP. Icons are drawn at rows 0–7. A JPEG
always occupies an 8×8 square — a larger one is not rejected, but only its
top-left 8×8 corner is shown. A GIF keeps its own width, up to the full 32×8.

📄 An icon narrower than the panel **reserves a 9px column** (8px icon, 1px
gap) that indents text, bars and the line chart. A GIF spanning the full 32px
is treated as a **background** instead: drawn at x=0 beneath the text, it
indents nothing and replaces `backgroundColor` and any `effect`. An icon that
is missing or fails to decode falls back to the icon-less layout rather than
leaving a black column.

📄 Transparent GIF pixels render as black on the **first** frame of an
animation; within an animation they keep what the previous frame drew there.

📄 `iconMode`: `fixed` leaves the icon in place and lets the text scroll past
it; `pushOnce` lets scrolling text shove it off to the left **once**, after
which it stays gone and the text restarts at x=0; `push` brings it back on
every scroll cycle. The shift travels 0 → −9px. `iconOffsetX` does not change
the reserved column, so it slides the icon *under* the text.

### 5.4 Timing

| Key | Type | Default | Meaning |
|---|---|---|---|
| `durationMs` | long | `0` | how long to show; 0 or less uses the global `appDurationMs` (7000). Honoured by pushed apps and notifications alike |
| `lifetimeMs` | long | `0` | **pushed apps only** — auto-expire after this long; 0 = forever |
| `lifetimeExpiry` | string | `remove` | `remove` · `mark` — what happens when the lifetime runs out |
| `repeat` | int | `0` | how many times scrolling text runs across the screen |

### 5.5 Background, charts, progress, effect, palette, overlay

| Key | Type | Range | Default | Meaning |
|---|---|---|---|---|
| `backgroundColor` | color | — | absent → black | solid canvas fill |
| `barChart` | array of int | max 16 | `[]` | bar chart values |
| `lineChart` | array of int | max 16 | `[]` | line chart values |
| `chartAutoscale` | bool | — | `true` | scale to the data max, else fix the max at 8 |
| `chartColor` | color | — | the resolved text color | bars and line |
| `progress` | int | percent, below 0 = off | `-1` | fill percentage |
| `progressColor` | color | — | `#00FF00` | filled portion |
| `progressTrackColor` | color | — | `#FFFFFF` | unfilled portion |
| `effect` | string | case-insensitive | `""` | animated background effect |
| `effectSpeed` | float | 0.1–10.0 | `1.0` | pace of the effect and of this app's overlay |
| `palette` | string \| array \| null | max 16 stops | absent | built-in or user palette name, or a list of color stops |
| `paletteBlend` | bool | — | `true` | interpolate between the 16 entries; `false` gives hard bands |
| `paletteSpan` | int | px, 0 = stretch | `0` | pixels per full pass when painting text |
| `paletteSpeed` | float | 0.0–10.0, 0 = still | `0` | palette passes per second when painting text |
| `overlay` | string | case-insensitive | `""` | weather overlay drawn on top of everything |

📄 What the palette paints: `textColor` (sampled by pixel column across the
text), `chartColor` (by each bar's value) and `progressColor` (by position
along the bar).

### 5.6 Notification-only keys

📄 These keys are accepted **only** by `POST /api/v1/notifications`; in a
pushed app they are `422 validationFailed`:

| Key | Type | Default | Meaning |
|---|---|---|---|
| `name` | string | `""` | label for dismissing it later; matched exactly, use URL-safe characters |
| `hold` | bool | `false` | never auto-expire; stay until dismissed |
| `stack` | bool | `true` | queue behind existing notifications, else replace the current one |
| `wakeup` | bool | `false` | render even while the matrix is powered off |
| `sound` | string \| int | `""` | a name: a stored MP3, else a melody, else a DFPlayer track |
| `soundRtttl` | string | `""` | inline RTTTL melody |

### 5.7 Arrays as payload

📄 A top-level **array** sent to `PUT /api/v1/apps/pushed/{name}` creates
indexed apps `<name>0`, `<name>1`, … — one per object element; non-object
elements are skipped without consuming an index. `DELETE /api/v1/apps/{name}`
erases the exact name **and** the numbered apps that array push created; one
you pushed to `<name>1` yourself is a separate app and stays. An array is
all-or-nothing: if any element trips a rule, or the batch will not fit under
the resident cap, the whole request is rejected and none of its apps are
created or updated.

📄 An array sent to `POST /api/v1/notifications` may hold **at most one**
element; more is `422 validationFailed` and nothing is queued.

### 5.8 How the errors are named

| Condition | Response |
|---|---|
| body is not valid JSON | `400 invalidJson` |
| body over 8192 bytes | `413 payloadTooLarge` |
| unknown top-level key | `422 validationFailed`, `field` = the key |
| malformed color, any position | `422 validationFailed`, `field` = the key |
| a mode key given a word that is not in its list | `422 validationFailed`, `field` = the key |
| unknown `effect` or `overlay` name | `422 validationFailed`, `field` = `effect` / `overlay` |
| unknown draw command name | `422 validationFailed`, `field` = `draw[<i>]` |
| draw element that is not an array | `422 validationFailed`, `field` = `draw[<i>]` |
| wrong argument count for a draw command | `422 validationFailed`, `field` = `draw[<i>]` |
| non-numeric coordinate, size or radius | `422 validationFailed`, `field` = `draw[<i>]` |
| `pixels` with an odd coordinate tail | `422 validationFailed`, `field` = `draw[<i>]` |

---

## 6. The draw commands

📄 `draw` is an **array of arrays**, each with the command name first. They are
drawn in array order.

| Command | Arguments |
|---|---|
| `["pixel", x, y, color]` | one pixel |
| `["pixels", color, x1, y1, x2, y2, …]` | many pixels in one color |
| `["line", x1, y1, x2, y2, color]` | both endpoints included |
| `["rect", x, y, w, h, color]` | outline, 1px, spans `x` … `x+w-1` |
| `["rectFill", x, y, w, h, color]` | filled |
| `["circle", cx, cy, r, color]` | center and radius |
| `["circleFill", cx, cy, r, color]` | filled |
| `["text", x, y, "HI", color]` | baseline sits at `y + 5` |
| `["bitmap", x, y, w, h, data]` | `data` is base64 RGB888 or an array of colors |

📄 The trailing color may be **left out**; the command then uses the app's text
color. `pixels` takes its color **first**, where `null` means the same.
Off-canvas pixels are dropped, never wrapped. A `w` or `h` of zero or less
draws nothing, as does a negative radius; a radius of `0` draws the center
pixel. A short `bitmap` leaves the remaining cells undrawn; extra entries are
ignored.

📄 `bitmap` data comes in two interchangeable forms: an array of **w × h
colors**, row-major, in any of the color forms from §1 — or a **base64 string
of w × h × 3 raw RGB888 bytes**. The base64 form is far smaller for a large
image.

📄 The `text` of the draw commands is UTF-8 like the page's own and is drawn in
the page's `font`, but is **unaffected** by `textCase`, `palette`,
`textBlinkMs`, `textFadeMs`, `textCenter` and the global `uppercase` setting.

📄 The number of commands is bounded only by the 8192-byte body.

```bash
curl -X PUT http://<awtrix-ip>/api/v1/apps/pushed/art \
  -H 'Content-Type: application/json' \
  -d '{"draw":[
        ["rect",0,0,32,8,"#202020"],
        ["circleFill",4,4,2,"#F00"],
        ["text",9,1,"HI"]
      ]}'
```

📄 **The order in which a frame is painted:**

1. **Background** — the effect if `effect` resolves, otherwise a clear to
   `backgroundColor` or black.
2. **Text and decorations** — with `textInFront`, decorations then text;
   otherwise text then decorations. Decorations are always `draw` → `progress`
   → `barChart` → `lineChart`.
3. **Icon** — rows 0–7, at `iconOffsetX` plus any `iconMode` shift.
4. **Overlay** — the per-app overlay if set, else the global one.
5. **Stale marker** — a dark-red frame if an app with
   `lifetimeExpiry: "mark"` has expired. Drawn before the icon and overlay, so
   those paint over it.

---

## 7. What the device reports about itself

### 7.1 `GET /api/v1/device` and `<P>/state/device`

🔬 On the measured device:

```json
{"version":"1.1.0","uid":"9015065613e8","boardType":"awtrixng","soc":"esp32",
 "ipAddress":"10.10.11.162","hostname":"awtrix-2","wifiRssi":-75,
 "uptimeSeconds":167,"freeHeapBytes":84160,"minFreeHeapBytes":16016,
 "largestFreeBlockBytes":77812,"scriptingRunning":true,
 "scriptHeapPool":"internal","scriptHeapBudgetBytes":98304,
 "resetReason":"poweron","fps":42,"brightness":84,"lightLevel":61.7,
 "ldrRaw":2527,"batteryPercent":74,"batteryVoltage":3.97,
 "batteryPinMillivolts":2219,"lowBattery":false,"temperature":18.6,
 "humidity":42.8,"matrixPower":true,"currentApp":"Time",
 "indicators":[{"on":false,"color":"#000000","blinkMs":0,"fadeMs":0}, …],
 "messageCount":0,
 "wifi":{"enabled":true,"state":"connected","host":"lazybird", …},
 "mqtt":{"enabled":true,"state":"offline","host":"akadbrain.local",
         "endpoint":"10.10.11.237:1883","attempts":6,"retryInMs":3871,
         "connects":0,"error":"badCredentials","lastError":"badCredentials"}}
```

📄 Whether the device is connected to the broker, and why not, is reported
under `mqtt` in this answer.

### 7.2 `GET /api/v1/apps`

🔬 Per app `name`, `enabled`, `inLoop`, `slot`, `present` and `origin`:

```json
[{"name":"Time","enabled":true,"inLoop":true,"slot":0,"present":true,"origin":"builtin"},
 {"name":"Battery","enabled":true,"inLoop":true,"slot":1,"present":true,"origin":"builtin"},
 {"name":"Date","enabled":false,"inLoop":false,"slot":null,"present":true,"origin":"builtin"}]
```

📄 `origin` is one of `builtin`, `pushed`, `script`, `module`. The arranged apps
come first, in their order, then everything else.

### 7.3 `GET /api/v1/display/screen` and `<P>/state/screen`

📄 `pixels` is a flat array of packed RGB integers (`0xRRGGBB` as unsigned
decimal), `width × height` entries — **the actual pixels of the framebuffer**,
not the payload that produced them.

🔬 On the measured device `{"width":32,"height":8,"pixels":[…]}` with 256
values.

Over MQTT the topic is **not retained** and is published only as the reply to
`cmd/screen/get`.

### 7.4 The remaining reads

📄 `GET /api/v1/settings` — 40 display settings, every one always present.
`GET /api/v1/system` — 64 of the 67 configuration fields, among them
`panelWidth`, `panels`, `mqttPrefix`, `hostname` and the pin map.
`GET /api/v1/capabilities` — the names of this build's effects, palette
effects, transitions, overlays and palettes, plus the GPIO map; fetch these
rather than hardcoding names.
`GET /api/v1/logs` — the incremental device log.
`GET /api/v1/files` — the file store with `usedBytes` and `totalBytes`.
`GET /api/v1/audio` — playback status and the station list.

🔬 On the measured device `GET /api/v1/capabilities` names 19 effects, 22
transitions, 6 overlays and the eight built-in palettes (`Cloud`, `Lava`,
`Ocean`, `Forest`, `Stripe`, `Party`, `Heat`, `Rainbow`).

---

## 8. The limits

📄 Every cap the firmware enforces, and what it answers at the edge:

| Limit | Value | At the edge |
|---|---|---|
| JSON request body over HTTP | **8192 bytes** | `413 payloadTooLarge`, nothing is applied |
| MQTT command payload | **8192 bytes** | **dropped before it is parsed: no error, no `/result` reply** |
| JSON nesting | 16 levels | deeper makes the body invalid — `400 invalidJson` |
| App and script names | 1–32 characters of `A–Z`, `a–z`, `0–9`, `_`, `-` | `400 invalidName` |
| Pushed apps resident | **50** | `507 insufficientStorage`, nothing is stored |
| Notification queue | 32, counting the one on screen | a stacked push: `507`; `stack: false` replaces the one on screen and is never rejected |
| Notifications per request | 1 | `422 validationFailed` |
| `barChart` / `lineChart` points | 16 | the 17th and later are dropped, the chart still draws |
| **Panel width** | `panelWidth × panels`, default `32 × 1`, must come to **32–128** | `422 validationFailed` on `panelWidth` |
| **Panel height** | **8 pixels** | fixed; not configurable |
| Icon canvas | **32×8**, regardless of the panel width | a GIF whose **first** frame is larger does not play at all; if a later frame is larger, decoding stops there and the frames decoded before it loop |
| File storage | the free space: **512 KB** on a 4 MB board, 4.5 MB on 8 MB, 12.5 MB on 16 MB | `500 internalError`; no truncated file is left behind |
| Script source | `scriptMaxBytes`, default 16384, range 1024–32768 | `413 payloadTooLarge`, never truncated |
| Scripts installed | `scriptLimit`, default 16, range 0–32 | `507` |
| Melody, station, MP3 | melody source 512 characters, 32 stations, names 1–24 or 1–32 characters | `422 validationFailed` |

📄 The **50** counts **new** names only: replacing an app that already exists
always works, whatever the count says.

📄 **Not limited:** requests per second — neither HTTP nor MQTT rate-limits
you; and what the device publishes — `state/device` and `state/screen` go out
at whatever size they are.

🔬 On the measured device `GET /api/v1/files` reports `"usedBytes":102400,
"totalBytes":524288`, and `GET /api/v1/system` carries `scriptMaxBytes: 16384`
and `scriptLimit: 16`.

---

## 9. What the documentation does not say

- ❓ **Whether `mqttPrefix` is checked for the MQTT wildcards `#` and `+`.** The
  key table gives `mqttPrefix` neither a character set nor a range, and testing
  it would mean changing the setting.
- ❓ **The height of the `small` font.** Of `large` it is said to be seven rows
  tall and to reach the top row; for `small` no height is given. There are no
  fonts beyond these two names.
- ❓ **An MQTT route listing the apps.** There is none; the inventory is
  explicitly available over `GET /api/v1/apps` only.
