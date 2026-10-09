# Remote-controlling AWTRIX NG

*[Deutsche Fassung](../awtrix-ng-protokoll.md)*

What an Ulanzi TC002 running **AWTRIX NG 1.2.2** can do and how to address it —
over MQTT and over HTTP. This description is independent of our app: it applies
just as well to `mosquitto_pub`, Node-RED, Home Assistant or a script of your
own.

Every statement carries its provenance:

| Mark | Meaning |
|---|---|
| 📄 | from the [AWTRIX NG documentation](https://blueforcer.github.io/awtrix-ng/tc002/) (TC002 branch), not cross-checked on a device |
| 🔬 | read on a device itself |
| ❓ | open — the documentation does not say, or not measured |

**The documented statements refer to the state of the TC002 branch as of
2026-10-09 (version 1.2.2)**, the measurements to a device running **AWTRIX NG
1.2.2** (`boardType tc002`, `soc armv7l`), read via HTTP `GET` on 2026-10-09.
What carries 🔬 holds, to begin with, for that one device and that one build;
what carries 📄 holds for the firmware in general. **MQTT has not yet been
measured on this device** — everything about MQTT is 📄. 🔬 statements marked
"measured on 1.1.0/TC001" come from an earlier firmware on a 32×8 device and
have not been re-confirmed.

---

## 1. The display

📄 **The TC002 has a fixed grid of 52 × 16 pixels** (832 pixels); size and panel
width are not configurable. The origin is at the top left, `x` counts columns
from 0, `y` counts rows from 0; the bottom right is (51, 15). Anything outside
is cut off silently, never wrapped and never an error.

🔬 `GET /api/v1/capabilities` reports `display`: `width 52`, `height 16`,
`configurable false`, `minWidth`/`maxWidth` 52, `minHeight`/`maxHeight` 16,
`maxPixels 832`, `ready true`, `restartRequired false`. `GET
/api/v1/display/screen` answers `width 52`, `height 16` and 832 pixel values.

### 1.1 Enlarged apps (`enlargeApps`)

📄 **Pushed apps and notifications are drawn at double size by default:** on a
grid of **26 × 8**, each pixel as a 2×2 square (bottom right (25, 7)). An app
written for an 8-row clock thus fills the panel. The global setting
`enlargeApps` (default `true`) turns that off; the app then uses the full
52×16 grid. The same happens when the icon is larger than 26×8.

📄 **Scripts and layouts always work on the full 52×16 grid.**

🔬 `enlargeApps` is `true` on the measured device (settings and
`capabilities`).

🔬 **The coordinates of `draw` apply to the 26×8 grid in enlarged apps**
(measured on 2026-10-09 via `GET /api/v1/display/screen`, with `enlargeApps:
true`): every command occupies 2×2 squares. `["pixel",0,0]` occupies columns
0…1 and rows 0…1, `["pixel",51,15]` lies outside and drops out. In a `layout`,
`draw` works on the full 52×16 instead, relative to the region's `box`. Without
`enlargeApps` the display also works on 52×16.

❓ Whether the same holds for `progress` and the charts is not measured.

### 1.2 The icon area

📄 An icon narrower than the panel occupies its width plus `iconGap` on the
left; text, bars and charts start to the right of it. At normal grid that is 8
columns of image plus 1 column of space, enlarged 16 plus 2 (text starts at
column 18). Draw commands ignore the icon and count from the left edge. A GIF
as wide as the display (52, or 26×8 enlarged) counts as the background. Details
in §5.3.

### 1.3 Fonts

📄 Standard are `small` (default) and `large`; ten matrix fonts come on top
(`matrix-light6`, `matrix-chunky6`, `matrix-chunky6x`, `matrix-light6x`,
`matrix-chunky8`, `matrix-chunky8x`, `matrix-chunky8x6`, `matrix-light8`,
`matrix-light8x`, `matrix-light8x6`). `capabilities.fonts` lists which exist;
the `font` field takes any of these names.

| Font | Capitals | Rows | Character width | Space |
|---|---|---|---|---|
| `small` | 5 px high | 1–5 | 4 px | 2 px |
| `large` | 7 px high | 0–6, descenders to row 7 | 4 px | 2 px |

🔬 `capabilities.fonts` lists per font `name`, `ascent`, `descent`,
`lineHeight`: `small` 6/1/7, `large` 6/2/9; all ten matrix fonts have
`descent 0` and `ascent` = `lineHeight` = 6 (`…6`, `…6x`) or 8 (`…8`, `…8x`,
`…8x6`).

### 1.4 Colors

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
milliseconds** carrying an `…Ms` suffix. The single exception is the read-only
`uptimeSeconds` in `GET /api/v1/device`.

---

## 2. The topic prefix

📄 The prefix `<P>` is exactly what stands in `mqttPrefix` — **unchanged, with
nothing appended**. Leave it empty and the **device uid** takes its place, that
is the twelve-character MAC address in lowercase without colons
(`<uid>/cmd/notify`). The MQTT client id is the uid as well.

📄 The device also publishes its prefix under the prefix itself:
`<P>/state/prefix` carries `<P>` as a plain string, retained.

📄 Topics outside `<P>/` are not read.

📄 `mqttPrefix` takes effect only after a restart (the "restart" column of the
system configuration, §11).

🔬 Measured on 1.1.0/TC001: the prefix may span several topic levels (a slash in
it was taken over into the device log, `GET /api/v1/logs`: `mqtt: broker
<broker>:1883, prefix <prefix>`).

🔬 Measured on 1.1.0/TC001: **A space at either end counts — and is nowhere to
be seen.** A trailing space in `mqttPrefix` was carried as part of the prefix in
the device log, and the device subscribed to `<prefix> /cmd/#` accordingly. Read
off a user interface, the prefix looks like the value without the space, and
anything published there lands on a topic no device subscribes to — NG does not
answer that at all. The firmware took the value literally.

🔬 Measured on 1.1.0/TC001: a `mqttPrefix` changed by `PATCH`/`PUT` took effect
only at the next connect; the running session kept the old prefix.

🔬 **A wildcard in the prefix prevents the MQTT client — silently.** With a `#`
in `mqttPrefix` (form `<word>/#`) the connection never came up: in the device
log repeatedly `failed (timeout, state -4)`, in `GET /api/v1/device`
`mqtt.state offline`, `error timeout`, `connects 0`. No message points at the
prefix, other credentials changed nothing. After clearing the prefix the device
connected at once (`state connected`). NG thus does not check `mqttPrefix` for
wildcards, and the consequence is a connection failure with no hint at the
cause. The docs give neither a character set nor a range (📄). ❓ Whether `+`
acts the same is not measured.

---

## 3. The MQTT topics

📄 The device connects to **one** broker. **QoS 0 everywhere** — for
publications, subscriptions and the Last Will; a message lost on the way is
lost silently. The payload of a command is **byte for byte the same** as the
body of the matching HTTP request. The topics in the examples are written with
the prefix `<P>`.

### 3.1 The connection

| Key | Type | Default | Meaning |
|---|---|---|---|
| `mqttEnabled` | bool | `false` | master switch; `true` needs a non-empty `mqttHost` (else 422) |
| `mqttHost` | string | `""` | broker |
| `mqttPort` | int | `1883` | 1–65535 |
| `mqttUser` / `mqttPass` | string | `""` | both empty = anonymous; `mqttPass` is a secret |
| `mqttTls` | bool | `false` | connect over TLS, usually port 8883 (§11.1) |
| `mqttTlsPin` | string | `""` | SHA-256 of the trusted broker certificate, 64 lowercase hex digits |
| `mqttPrefix` | string | `""` | topic prefix `<P>`; empty → uid |
| `haDiscovery` | bool | `false` | publish the Home Assistant document |
| `haPrefix` | string | `"homeassistant"` | its prefix; empty = `homeassistant` |

These keys live in the **system configuration** (`/api/v1/system`, §11), not in
the display settings.

📄 A failed connection attempt is retried after 5 s, then 10, 20, 40 and at most
every 60 s, each wait shortened by up to 20 %. A successful connection resets
the schedule. The state is in `mqtt` of `GET /api/v1/device` (§7.1).

### 3.2 Commands — only under `<P>/cmd/`

📄 Everything under `<P>/state/` and `<P>/event/` is outbound. `<P>/cmd` and
`<P>/cmd/` on their own hit nothing.

| Topic | Payload | HTTP counterpart |
|---|---|---|
| `cmd/notify` | notification JSON | `POST /api/v1/notifications` |
| `cmd/notify/dismiss` | ignored | `DELETE /api/v1/notifications/active` |
| `cmd/notify/dismiss/<name>` | ignored | `DELETE /api/v1/notifications/{name}` |
| `cmd/apps/pushed/<name>` | app JSON; **empty or `{}` deletes** | `PUT /api/v1/apps/pushed/{name}` or `DELETE /api/v1/apps/{name}` |
| `cmd/apps/switch` | bare name **or** `{"name":…,"fast":bool}` | `PUT /api/v1/apps/active` |
| `cmd/apps/next` · `cmd/apps/previous` | ignored | `POST /api/v1/apps/next` / `/previous` |
| `cmd/apps/order` | `{"order":[…],"disabled":[…]}` — `disabled` is required, `order` optional | `PUT /api/v1/apps/order` |
| `cmd/apps/<name>/enabled` | `true` or `false` | `PUT /api/v1/apps/{name}/enabled` |
| `cmd/settings` | subset of the settings | `PATCH /api/v1/settings` |
| `cmd/settings/reset` | ignored; deletes the stored settings, restarts | `POST /api/v1/settings/reset` |
| `cmd/display` | `{"power":bool?,"overlay":string\|null?}` | `PATCH /api/v1/display` |
| `cmd/display/moodlight` | mood-light JSON; **empty = off** | `PUT` / `DELETE /api/v1/display/moodlight` |
| `cmd/indicators/1` · `/2` · `/3` | `{"color","blinkMs","fadeMs"}`; empty or `{}` = reset (off) | `PUT` / `DELETE /api/v1/indicators/{id}` |
| `cmd/audio/play` | one sound object or a list (1–4), §3.2.1 | `POST /api/v1/audio/play` |
| `cmd/audio/stop` | optionally `{"group":"alert"\|"app"\|"radio"}`; empty = everything | `POST /api/v1/audio/stop` |
| `cmd/audio/stations` | `{"stations":[…]}` | `PUT /api/v1/audio/stations` |
| `cmd/device/reboot` | ignored | `POST /api/v1/device/reboot` |
| `cmd/device/sleep` | `{"durationMs":ms}`, `> 0` | `POST /api/v1/device/sleep` |
| `cmd/screen/get` | ignored | publishes `<P>/state/screen` |
| `cmd/voice/start` | ignored; starts Home Assistant Voice | none |

📄 The **factory reset is not reachable over MQTT** — only
`POST /api/v1/device/factory-reset`. A publication there does nothing and
answers nothing.

📄 The name in `cmd/apps/pushed/<name>` is the rest of the topic after
`apps/pushed/` and must satisfy `[A-Za-z0-9_-]{1,32}` (otherwise `invalidName`
in `/result`). `cmd/apps/pushed/` with an empty name hits nothing.

📄 The number in `cmd/indicators/<id>` must be a **single character** `1`, `2`
or `3`. Anything else hits no route — and is thus dropped silently, whereas the
HTTP route at the same place answers `404`.

📄 `cmd/voice/start` answers `unavailable` ("voice not ready") when Voice is
off, not connected, busy or still starting. The commands `settings/reset` and
`device/reboot` restart the device; their `/result` reply may not arrive.

📄 **Indicators:** `color` switches on; `0` or `null` switches off but keeps the
stored color. `blinkMs` and `fadeMs` 0–65535; missing ones count as 0, each
request sets blinking and fading anew.

#### 3.2.1 `audio/play`

📄 A sound has **exactly one** of the keys:

| Key | Value | Plays |
|---|---|---|
| `file` | stored name, `Script/name` or `http(s)://` address | MP3 or melody |
| `rtttl` | RTTTL text, at most 512 characters | melody from the payload |
| `song` | song text | synthesizer |
| `speech` | 1–512 bytes | spoken text (only with a voice) |
| `station` | name, list position from 0 or stream address | internet radio |
| `loop` | bool | repeats until stopped or replaced; **not** with `station` |

A bare string `"ding"` is `{"file":"ding"}`. A name without a slash is looked up
first as `/MP3/<name>.mp3`, then as `/MELODIES/<name>.txt`; with a slash only in
the script's folder. A list of 1–4 sounds plays the first one the device can
play. Errors: `422` for two keys, `.mp3`/`.txt` in the name or unreadable
melody, `404` for a missing file, `503 unavailable` without matching hardware.

📄 `audio/stop`: `alert` stops the current alert (notification sound, playback
via `audio/play`, boot sound, voice answer), `app` the script sounds, `radio`
the radio; any other value is refused.

### 3.3 Three traps that snap shut silently

📄 **A message over 8192 bytes, topic included, is dropped — no error, no
`/result` reply.** Over HTTP the limit would be 2 MiB (§8); over MQTT there is
no sign. This mostly hits notifications with images, layouts or long song text.

📄 **A topic that hits no route produces no reply at all** — no error, no
acknowledgement. **Typos are therefore invisible.** When a command seems to
vanish without a trace, the spelling of the topic is the first thing to check.

📄 A `/result` topic is never read as a command itself; subscribing to
`…/result` hears only replies.

### 3.4 The reply on `<topic>/result`

📄 Every command that **hits a route** is answered on `<cmd topic>/result`, not
retained, QoS 0:

```
awtrixNG/cmd/settings        ->  awtrixNG/cmd/settings/result
awtrixNG/cmd/apps/pushed/x   ->  awtrixNG/cmd/apps/pushed/x/result
```

Success is exactly `{"ok":true}`. A failure carries the same error body as HTTP,
wrapped in `ok:false` (`field` is absent when it would be empty):

```json
{"ok":false,"error":{"code":"validationFailed","message":"invalid value","field":"brightness"}}
```

Only these codes appear over MQTT: `invalidJson` (`invalid JSON`),
`validationFailed` (the reason or `invalid value`), `notFound` (`not found`),
`insufficientStorage` (`storage full`), `unavailable` (e.g. `no audio output`),
`internalError` (`command failed`) and `invalidName` (only
`cmd/apps/pushed/{name}`, `invalid name`). The framing codes of HTTP (§12) have
no counterpart over MQTT.

📄 **`<P>/event/error`** (not retained) carries `{"source","request","error"}`
for **every** rejected command, over MQTT as over HTTP; `source` is `mqtt` or
`http`. One subscription is enough to see all failures.

### 3.5 State and event topics

| Topic | Content | Retained | When |
|---|---|---|---|
| `<P>/state/device` | device JSON, the shape of `GET /api/v1/device` | yes | every `statsInterval` (default 10 000 ms, minimum 1 000), immediately on a change of panel power or indicator |
| `<P>/state/settings` | settings JSON | yes | on every change and on connect |
| `<P>/state/apps/active` | name of the running app, **bare string, not JSON** | yes | immediately on change and on connect |
| `<P>/state/audio` | audio JSON (`radio`, `app`, `alert`, `stations`) | yes | on a change of radio, app or alert sound, on connect |
| `<P>/state/capabilities` | capabilities JSON (effects, transitions, palettes …) | yes | once per connection |
| `<P>/state/prefix` | `<P>` itself, bare string | yes | once per connection |
| `<P>/state/buttons/left` · `/select` · `/right` · `/knob` | `"1"` / `"0"` | no | on every edge and on connect |
| `<P>/event/knob` | `{"turn":N}`, positive = clockwise | no | on turning; fast turning may bundle clicks |
| `<P>/event/error` | `{"source","request","error"}` | no | on every rejected command |
| `<P>/state/screen` | `{"width":W,"height":H,"pixels":[…]}` | no | only as a reply to `cmd/screen/get` |
| `<P>/availability` | `online` / `offline` | yes | on connect, or as the Last Will |

📄 On connect the device sends the current button state and clears retained
messages on the button topics.

📄 `statsInterval` is the **slowest** cadence of `state/device`, not the only
trigger. Successive event-driven publications are at least 250 ms apart.
`state/settings` and `state/apps/active` are purely event-driven.

📄 **There is no list of all apps over MQTT.** Reading goes exclusively through
HTTP: `GET` routes have no MQTT counterpart; the device pushes its state onto
the retained `state` topics instead.

📄 `<P>/availability` is registered as a broker-side Last Will at CONNECT
(`offline`, retained) and published as `online` immediately on a successful
connection.

📄 What the device publishes **to you** has no size limit; `state/device` and
`state/screen` go out however large they are.

### 3.6 Home Assistant

📄 With `haDiscovery` on, a single retained document is published at
`<haPrefix>/device/<uid>/config` (HA device discovery, requires Home Assistant
2024.11 or newer). **There is no second topic tree:** every component points at
the same `<P>/cmd/…` and `<P>/state/…` topics. Switching it off publishes an
empty retained payload to the same topic.

📄 Always created: matrix (light), three indicators (lights), transition effect
(select) and transition (switch), buttons for next/previous app and dismiss
notification, sensors for current app, version, IP address, MQTT prefix, Wi-Fi
strength, uptime and free memory, three button sensors, plus charging, knob
(button and turn event) and volume. Only with matching hardware: battery (level,
voltage, low), Assist, radio, app and alert volume, stop sound.

---

## 4. The HTTP interface

📄 The base is `http://<ip>` on **port 80** (also via the device's mDNS name).
The setting `webPort` is stored but **has no effect**.

### 4.1 What applies to every request

📄 **`Content-Type: application/json` is mandatory** on every request with a
JSON body. `PUT` and `PATCH` with another type are refused with `415
unsupportedMediaType` ("expected application/json") before the body is read; a
**missing** header is accepted and the body is read as JSON. A `POST` is not
checked for the type. Exceptions: `PUT /api/v1/apps/script/{name}` (Berry
source, any type) and `PUT /api/v1/apps/script-update/{name}` (any type, the
body must be JSON); file uploads have their own format.

📄 **An empty body or `{}` never deletes anything.** `PUT
/api/v1/apps/pushed/{name}`, `PUT /api/v1/display/moodlight` and `PUT
/api/v1/indicators/{id}` then answer `422 validationFailed` ("body required");
deletion is done with the matching `DELETE`. Over MQTT it is the other way
round: there an empty body deletes.

📄 **Basic auth is off from the factory** — the whole interface stands open on
the LAN. It is switched on via `authEnabled` (with a stored user name and
password) and then applies in **every** operating state, including setup mode.
It covers the interface, the web UI and the static folders; missing or wrong
credentials are `401` with `WWW-Authenticate`.

📄 **Every failing request** carries the same body:

```json
{ "error": { "code": "validationFailed", "message": "invalid value", "field": "brightness" } }
```

`code` is machine-readable and stable — check that, never `message`, which is
English prose for humans and may change. `field` is present only when a
specific input key caused the failure. The only route with a response shape of
its own is `POST /api/v1/restore`.

🔬 On the measured device an unknown route answers `404` with
`{"error":{"code":"notFound","message":"unknown route"}}`, and `POST
/api/v1/settings` answers `405` with
`{"error":{"code":"methodNotAllowed","message":"allowed: GET, PATCH"}}` — the
allowed methods are in the message. (Measured on 1.1.0/TC001 the wording was
`allowed method(s): …`; whoever parses the message has a bug.)

📄 **Method override:** a `POST` with `X-HTTP-Method-Override` (`PUT`, `PATCH`
or `DELETE`, case-insensitive) is checked as the named method, so it needs the
same `Content-Type` as a real `PATCH`. Any other value is `400
invalidMethodOverride`. The header is ignored at `/update`, `/api/v1/files`,
`/api/v1/audio/mp3` and `/api/v1/restore` and does not reach the `PUT` of the
script source.

📄 **Cross-site requests:** responses carry `Access-Control-Allow-Origin: *`, a
preflight `OPTIONS` answers `204`. Five routes refuse requests from foreign web
pages with `403 forbiddenOrigin`: `GET /api/v1/system?secrets=1`, `PUT
/api/v1/system`, `POST /api/v1/restore`, `POST /update`, `POST
/api/v1/device/factory-reset`.

📄 **Setup mode:** writing requests from foreign hosts are `403 forbidden`;
allowed are only the setup page, status reads, Wi-Fi setup, reboot and backup
restore. Log, scripts, file routes, secrets export and firmware are blocked.

### 4.2 The routes

**Device**

| Route | Purpose |
|---|---|
| `GET /api/v1/device` | state and statistics (same shape as `state/device`) |
| `GET /api/v1/version` · `GET /version` | version number as JSON or as `text/plain` |
| `POST /api/v1/device/reboot` | restart (also in setup mode) |
| `POST /api/v1/device/sleep` | deep sleep for `{"durationMs"}`; listed so in the MQTT part of the docs, not found in the route list of the HTTP page |
| `POST /api/v1/device/factory-reset` | erase everything, restart in setup mode |

**Settings**

| Route | Purpose |
|---|---|
| `GET /api/v1/settings` | all display settings (§10) |
| `PATCH /api/v1/settings` | any subset; unknown keys refused; the reply is all settings |
| `POST /api/v1/settings/reset` | settings to default, restart |

**Display**

| Route | Purpose |
|---|---|
| `GET /api/v1/display` | `power`, `brightness`, `overlay`, `overlaySettings`, `moodlight` |
| `PATCH /api/v1/display` | `power` (bool), `overlay` (name or `null`/`""`), `overlaySettings` (`{speed, palette, blend}`); all or nothing, reply `{"ok":true}` |
| `PUT /api/v1/display/moodlight` | flood the panel with one color: `kelvin` 1000–40000 (wins over `color`), `color`, `brightness` 0–255 (not checked: 300 becomes 44, 256 becomes 0); missing fields keep their value, the first time white at 120 |
| `DELETE /api/v1/display/moodlight` | off; always `200` |
| `GET /api/v1/display/screen` | the frame buffer: `width`, `height`, `pixels` |

**Apps**

| Route | Purpose |
|---|---|
| `GET /api/v1/apps` | the inventory in order, §7.2 |
| `PUT /api/v1/apps/active` | switch: `{"name","fast"}` (`fast` default `false`); a body not starting with `{` is taken as the name itself — broken JSON thus as a name and therefore `404`, not `400`; `503 serviceBusy` if an on-demand script cannot start |
| `POST /api/v1/apps/next` · `/previous` | page forward and back |
| `PUT /api/v1/apps/order` | `{"order":[…],"disabled":[…]}`; `disabled` is the complete list of the switched-off apps, `order` only together with it; duplicates in `order` run several times per round; `507 applied, not saved yet` means active until restart, not saved |
| `PUT /api/v1/apps/{name}/enabled` | body `true`/`false`; a switched-off app keeps its place; any other body `422` |
| `PUT /api/v1/apps/pushed/{name}` | create or replace an app (object or array) |
| `DELETE /api/v1/apps/{name}` | delete an app; without effect on built-in apps (`Time`, `Status`) but `200` |
| `GET` / `PATCH /api/v1/apps/builtin/{name}/config` | settings of a built-in app |

**Scripts (Berry)**

| Route | Purpose |
|---|---|
| `GET` / `PUT /api/v1/apps/script/{name}` | read source (`text/plain`) or install (even with errors) |
| `PUT /api/v1/apps/script-update/{name}` | replace only if the old source matches `expected_source` (`409 scriptChanged`) |
| `GET` / `PATCH /api/v1/apps/{name}/config` | settings of a script (`PATCH` restarts it) |
| `GET` / `PATCH /api/v1/apps/{name}/data` | stored data (`null` removes a key) |
| `GET /api/v1/oauth` · `GET`/`POST`/`DELETE /api/v1/oauth/{name}` · `POST …/start` · `POST …/code` | sign-in of scripts at services |
| `GET` / `POST /api/v1/apps/script/{name}/sounds` · `DELETE …/sounds[/{sound}]` | MP3s of a script (with SHA-256) |
| `GET /api/v1/scripts/shared` | what scripts have published to each other |

**Notifications and indicators**

| Route | Purpose |
|---|---|
| `POST /api/v1/notifications` | a one-time message over the loop |
| `DELETE /api/v1/notifications/active` | remove the visible one; always `200`, even when none is showing; the next one in the queue appears immediately |
| `DELETE /api/v1/notifications/{name}` | remove the named one, also while waiting (`404` if none has that name); `active` is reserved as a name |
| `PUT /api/v1/indicators/{id}` | `{"color","blinkMs","fadeMs"}`; `id` 1–3 from top to bottom, else `404` ("id must be 1..3") |
| `DELETE /api/v1/indicators/{id}` | reset and switch off; always `200` |

**Sound**

| Route | Purpose |
|---|---|
| `GET /api/v1/audio` | playback state (`radio`, `app`, `alert`) and station list |
| `POST /api/v1/audio/play` · `/stop` | play (§3.2.1), stop (`{"group"}`) |
| `POST /api/v1/audio/clip` | play a recorded WAV or MP3 file once, not stored; raw body up to 2 MiB |
| `GET` / `PUT` / `DELETE /api/v1/audio/melodies[/{name}]` | melodies; `PUT {"rtttl":…}` → `201` new, `200` replaced |
| `GET` / `POST` / `DELETE /api/v1/audio/mp3[/{name}]` · `POST …/mp3/rename` | MP3 files (`multipart` field `file`), rename with `{"from","to"}` |
| `GET` / `PUT /api/v1/audio/stations` | read the station list or replace it whole (`{"stations":[…]}` or a bare array, at most 32) |

**Capabilities, system, files**

| Route | Purpose |
|---|---|
| `GET /api/v1/capabilities` | the name lists and limits of this build — to be queried instead of hard-coding names (§7.4) |
| `GET /api/v1/system` | system configuration (§11); with `?secrets=1` the secrets too |
| `PUT /api/v1/system` | partial merge, everything checked |
| `GET /api/v1/system/wifi-scan` | Wi-Fi scan, asynchronous: `202` while scanning, then `200` with results |
| `GET /api/v1/logs` | device log, `?after=N` to continue |
| `GET /api/v1/mqtt/tls` · `PUT`/`DELETE /api/v1/mqtt/tls/ca` | how the broker is trusted; upload your own CA (`{"certificate":PEM}`, at most 65536 bytes) or delete it |
| `GET` / `POST /api/v1/voice` | Home Assistant Voice (`POST` needs the header `X-Awtrix-Voice: 1` and a matching Origin) |
| `GET` / `POST` / `DELETE /api/v1/gamepad[…]` | pair and forget Bluetooth gamepads, remote control from a phone |
| `GET` / `POST` / `DELETE /api/v1/files` | file store: `GET ?dir=` (default `/ICONS`), `POST` upload to `ICONS`, `MELODIES`, `PALETTES`, `MP3`, `DELETE ?path=` |
| `POST /api/v1/icons/rename` | rename an icon (`{"from","to"}`, same extension) |
| `GET`/`PUT`/`DELETE /api/v1/icons/origins` | origin links of the icons to the Hub |
| `POST /update` | install firmware (`.awup`, `multipart` field `firmware`) |
| `POST /api/v1/restore` | restore a backup (`.zip`, also in setup mode) |
| `GET /`, `/index.html`, `/fullscreen` | web UI (`fullscreen` shows only the display) |
| `GET /ICONS/*`, `/MELODIES/*`, `/PALETTES/*`, `/MP3/*`, `/SCRIPTS/*`, `/apploop.json` | static files, **`GET` only** |

📄 Deleting via `DELETE /api/v1/files` is restricted to `/ICONS`, `/MELODIES`,
`/PALETTES` and `/MP3`; `DELETE` there needs a real `DELETE` method (no
override).

🔬 Measured, plain `GET`s: `/api/v1/version` → `{"version":"1.2.2"}`;
`/api/v1/files` → `{"files":[],"usedBytes":2579,"totalBytes":6908435}`;
`/api/v1/icons/origins` → `{"icons":[]}`; `/api/v1/audio/stations` →
`{"stations":[{"name","url"}]}`; `/api/v1/mqtt/tls` →
`{"ca":"public","pending":null}`; `/api/v1/scripts/shared` → `[]`;
`/api/v1/audio/melodies` → `{"melodies":[],"usedBytes":…,"totalBytes":…}`;
`/api/v1/audio/mp3` → `{"files":[],"scripts":[],"usedBytes":…,"totalBytes":…}`.

---

## 5. The payload of an app

📄 The same shape applies to `PUT /api/v1/apps/pushed/{name}` and `POST
/api/v1/notifications` — and thus also to `cmd/apps/pushed/<name>` and
`cmd/notify`. **Every top-level key not listed below is an error** (`422
validationFailed`, `field` = the key). A payload is applied in full or not at
all.

📄 **The name of an app comes from the path, never from the body.** It must
satisfy `[A-Za-z0-9_-]{1,32}` and is checked before the payload is read; a
wrong or reserved name is `400 invalidName`.

📄 An app lives **in RAM** until it is replaced, deleted, withdrawn by
`lifetimeMs` or the device restarts; afterwards the sender has to push it again.
A new app joins the end of the loop; to show it at once, follow with `PUT
/api/v1/apps/active`. Replacing keeps the place in the loop, and with unchanged
text the scrolling does not start over.

📄 **Wrong types for number, bool, `text`, `icon`, `effect`, `overlay` and
`name` are no error:** the value is ignored and the default stays
(`"durationMs":"5000"` gives `200` and the standard time).

### 5.1 Text

| Key | Type | Range | Default | Meaning |
|---|---|---|---|---|
| `text` | string \| array | — | `""` | the text, or an array of colored parts |
| `textCase` | string | `inherit` · `upper` · `asTyped` | `inherit` | capitalization; `inherit` follows the global setting `uppercase` |
| `font` | string | `small` · `large` · a name from `capabilities.fonts` | `small` | the font (§1.3) |
| `textColor` | color \| `"palette"` | — | global `textColor` (`#FFFFFF`) | text color, or paint from the app's palette |
| `textBlinkMs` | int | ms, 0 = off | `0` | blink period: first half of each period black, second half colored |
| `textFadeMs` | int | ms, 0 = off | `0` | sinusoidal fade in and out per period |
| `textAlign` | string | `start` · `center` · `end` | `center` | alignment of still text; only when the text does not move |
| `scroll` | object \| string | see 5.2 | inherited | text motion; a bare string sets only `mode` |
| `textOffsetX` | int | px | `0` | shift; for moving text it shifts every anchor point |
| `textInFront` | bool | — | `false` | drawing order only |

📄 **The baseline is fixed;** there is no vertical control for the `text` key
(for free placement: `draw` or a layout, §9). `textInFront` sets only the order:
`true` paints the decoration (draw commands, progress bar, charts) first and the
text over it, the default `false` the other way round.

📄 Still text is centered in the space to the right of the icon column (or on
the whole panel when there is no icon); text never runs over the icon. Moving
text ignores `textAlign`. `textOffsetX` works in both cases.

📄 `text` is UTF-8. **All fonts have the same character set:** accents of
Western and Central European languages, Vietnamese, Greek, Cyrillic, IPA
letters, `°`, `€` and other currency signs, plus Chinese and Korean characters
for dates and weekdays (best in `large` and the 8-pixel fonts). A character
without a glyph — an emoji — becomes **exactly one `?`** per character. Changing
the font therefore never turns a letter into `?`. Capitalization (`uppercase`,
`textCase: upper`) reaches beyond ASCII and keeps accents. A number or bool as
`text` is ignored.

🔬 On the measured device the global setting `uppercase` is `true`.

📄 **Colored parts:** instead of a string, `text` takes an array of `{"text":
string, "color": color}`. The parts are drawn left to right, each advancing by
its own width. A missing or non-string `text` becomes `""`; a part without
`color` is white. With an array of parts the top-level `textColor` is ignored —
unless it is `"palette"`, which paints the whole run from the palette and
ignores the part colors.

📄 **Which coloring wins**, checked in this order:

| Rank | Condition | Result |
|---|---|---|
| 1 | `textColor: "palette"` with a `palette` set | gradient across the text; `textBlinkMs`/`textFadeMs` **are ignored** |
| 2 | `textFadeMs > 0` | soft pulsing of the resolved color |
| 3 | `textBlinkMs > 0` | blinking of the resolved color |
| 4 | — | `textColor`, else the global `textColor` |

### 5.2 Scrolling

📄 Text moves **only if it does not fit** (or `whenFits: "scroll"`). In enlarged
apps about six characters fit (about four beside an icon), with `enlargeApps` off
about thirteen.

📄 `scroll` takes an object of seven independent fields; missing ones come from
the global setting `scroll` (§10). An invalid value is `422` with `field` like
`scroll.speed`.

| Field | Type | Range | Default | Meaning |
|---|---|---|---|---|
| `mode` | string | `static` · `wrap` · `loop` · `bounce` | `wrap` | kind of motion |
| `direction` | string | `left` · `right` | `left` | direction of travel; `right` mirrors all kinds |
| `entry` | string | `inline` · `offscreen` | `inline` | start at rest on the panel or run in from outside (without the initial pause) |
| `whenFits` | string | `static` · `scroll` | `static` | whether text that fits anyway moves nonetheless |
| `speed` | int | ≥ 0 | `100` | percent of the base speed |
| `gap` | int | ≥ 0 | `8` | `loop` only — pixels between the repetitions |
| `holdMs` | int | ≥ 0 | `1000` | pause before starting and at each turning point of `bounce` |

📄 The base speed is about **21 pixels per second**; `speed` is the percentage
of that (200 twice as fast, 50 half as fast). From about 200 the text begins to
blur.

| `mode` | Motion |
|---|---|
| `static` | none; the text stands at its alignment, overhang is cut off on the right |
| `wrap` | runs from the start anchor until fully out, then jumps back |
| `loop` | continuous; a fresh copy pushes in `gap` pixels behind the last, the picture is never empty |
| `bounce` | swings between the rest position and the stop at the other edge, pause at both turning points |

📄 `repeat` is **top level**, not in `scroll` (there `422`).

### 5.3 Icon

| Key | Type | Range | Default | Meaning |
|---|---|---|---|---|
| `icon` | string | id, data URL or `http(s)://` address | `""` | the image |
| `iconMode` | string | `fixed` · `pushOnce` · `push` | `fixed` | whether moving text pushes the icon out |
| `iconOffsetX` | int | px | `0` | shift, X only; the reserved column stays |
| `iconGap` | int | 0–128, whole | `1` | space between icon and text (else `422`, `field` = `iconGap`) |
| `icons` | array | up to 4 objects | `[]` | additional, freely placed icons |

📄 **The three forms of `icon`:**

- **Id**, at most 64 characters: first `/ICONS/<id>.gif`, then
  `/ICONS/<id>.jpg`; if both exist the GIF wins. Case matters. An id without a
  file shows no icon, the text centers across the whole panel.
- **Data URL** `data:image/gif;base64,…` or `data:image/jpeg;base64,…`. A
  mismatching content is not shown, **PNG data URLs are refused**. Plain base64
  without a prefix, or an id over 64 characters, is `422`.
- **Web address** `http://` or `https://`, at most 2048 characters, without
  spaces; PNG too, the format is detected from the content. The image fills a
  square of 16×16, cropped from the middle, and stays empty until loaded. Once
  loaded it stays in memory (limits §8), redirects are followed, HTTPS
  certificates are checked (self-signed ones fail); failures are retried after
  30 s, 2 min, then every 10 min.

📄 **Sizes:** a JPEG always occupies 8×8 — a larger one is not refused, only its
top-left corner is shown. A GIF keeps its own size up to the display size
(enlarged 26×8, otherwise 52×16). Files and data URLs are JPEG or GIF only, no
PNG, no BMP; the web UI converts PNG/JPG to GIF before storing, the API refuses
PNG with `415`, even renamed.

📄 An icon narrower than the panel **reserves its width plus `iconGap`** (§1.2),
which indents text, bars and the line chart. A GIF of the full display width
counts as the **background** instead: it replaces `backgroundColor` and any
`effect` and indents nothing. A missing or unreadable icon falls back to the
layout without icon.

📄 GIFs loop forever, the loop count of the file is ignored; each has its own
frame times (0 becomes 100 ms) and its own colors. Transparent pixels show what
the previous frame drew there; in the first frame they are black.

🔬 **A GIF as a data URL in the `icon` of a layout region** is accepted up to
7508 Base64 characters and rejected from 8796 (`422 validationFailed` "invalid
icon", `field` `layout.regions[0].icon`; measured 09.10.2026, NG 1.2.2, TC002,
over HTTP). **As the `icon` of the display directly** (without `layout`) a 52×16
GIF up to 58,761 bytes (78,348 Base64 characters) is accepted and one of 87 KB
rejected (`field` `icon`). An icon larger than 26×8 switches the display to the
full grid (§1.1): the GIF lands pixel-exact in 52×16 (a 1-pixel column across
all 16 rows and the corner pixel (0,0) are right, no stray colors) and plays
animated with the frame times of the file.

📄 `iconMode`: `fixed` leaves the icon in place and lets the text run past it;
`pushOnce` lets the text push it out **once**, after which it stays gone and the
text starts at x=0; `push` brings it back on every run.

📄 **`icons[]`:** per element `icon` (required, non-empty, id or data URL), `x`
and `y` (−65535…65535, default 0); whatever lies outside is cut off. More than 4
elements, a bad coordinate, a missing `icon` or an unknown key is `422` (`field`
e.g. `icons[1].x`). `"icons": []` removes the extra icons of a pushed app.

### 5.4 Dwell time

| Key | Type | Default | Meaning |
|---|---|---|---|
| `durationMs` | long | `0` | how long it is shown; 0 or less takes the global `appDurationMs` (7000). Ignored for `hold` notifications |
| `lifetimeMs` | long | `0` | **apps only** — expire by themselves after this time; 0 = never. Notifications accept the key and ignore it |
| `lifetimeExpiry` | string | `remove` | `remove` deletes the app; `mark` keeps it with a 1-px frame in dark red (`#6E0700`) |
| `repeat` | int | `0` | how often moving text passes across the picture; ignored when the text does not move or `durationMs` is set (notification: then at least as long as `durationMs`) |

### 5.5 Background, charts, progress, effect, palette, overlay

| Key | Type | Range | Default | Meaning |
|---|---|---|---|---|
| `backgroundColor` | color | — | absent → black | solid fill; ignored when `effect` is set |
| `barChart` | array of int | at most 16 | `[]` | bar chart; excess entries drop, non-numbers count as 0 |
| `lineChart` | array of int | at most 16 | `[]` | line chart; needs at least 2 values |
| `chartAutoscale` | bool | — | `true` | `true`: from minimum to maximum, top at least 1, bottom at most 0; `false`: fixed 0–8, values clipped |
| `chartColor` | color \| `"palette"` | — | the text color | bars and line |
| `progress` | int | percent, below 0 = off | `-1` | fill level, above 100 counts as 100; bottom row only |
| `progressColor` | color \| `"palette"` | — | `#00FF00` | filled part |
| `progressTrackColor` | color | — | `#FFFFFF` | unfilled part, always a plain color |
| `effect` | string | case-insensitive | `""` | moving background effect; unknown → `422`, `field` = `effect` |
| `effectSpeed` | float | 0.1–10.0 | `1.0` | speed of effect and overlay; 0 or negative becomes 0.1, above 10 becomes 10 |
| `palette` | string \| array \| null | name or 1–16 stops | absent | `null` or `""` removes it; unknown → `422`, `field` = `palette` |
| `paletteBlend` | bool | — | `true` | blend between the entries; `false` gives hard bands |
| `paletteSpan` | int | px, 0 = stretch | `0` | pixels per full run when painting text |
| `paletteSpeed` | float | 0.0–10.0, 0 = still | `0` | runs per second when painting text |
| `overlay` | string | case-insensitive | `""` | weather overlay over everything; empty takes the global one; the app's own wins |
| `layout` | object | §9 | absent | regions instead of the visual keys |

📄 Bars are at least 1 px wide with a 1 px gap and grow from the zero line;
negative values hang below it.

📄 **Palettes:** a name is looked up first in `/PALETTES/<name>.txt`, then among
the built-in ones (`Cloud`, `Lava`, `Ocean`, `Forest`, `Stripe`, `Party`, `Heat`,
`Rainbow`); a file overrides the built-in one of the same name. Array forms:
1–16 plain colors, spread evenly, or objects `{"color": color, "pos": 0–100}`
with both keys — not mixed. An empty or longer array is refused. Painted from the
palette are `textColor` (column by column), `chartColor` (per bar by its value)
and `progressColor` (by position); effects and overlays use it too.

📄 Effects (19): `Plasma`, `TheaterChase`, `Fade`, `MovingLine`, `BrickBreaker`,
`PingPong`, `Radar`, `Checkerboard`, `Fireworks`, `PlasmaCloud`, `Ripple`,
`Snake`, `Pacifica`, `Matrix`, `SwirlIn`, `SwirlOut`, `LookingEyes`,
`TwinklingStars`, `ColorWaves`; all but `PingPong`, `Matrix` and `LookingEyes`
use the palette. Overlays (6): `rain`, `snow`, `drizzle`, `storm`, `thunder`,
`frost`. Transitions (22, for `transitionEffect`): `Random`, `Slide`, `Dim`,
`Zoom`, `Rotate`, `Pixelate`, `Curtain`, `Ripple`, `Blink`, `Reload`, `Fade`,
`Cover`, `Uncover`, `Split`, `Blinds`, `Blocks`, `Flash`, `Diamond`, `Wave`,
`Rain`, `Melt`, `Interlace`.

🔬 `GET /api/v1/capabilities` lists exactly these on the measured device: 19
effects, 16 palette effects, 22 transitions, 6 overlays, 8 palettes.

### 5.6 Notifications only

📄 These keys are accepted **only** by `POST /api/v1/notifications`; in a pushed
app they are `422 validationFailed`:

| Key | Type | Default | Meaning |
|---|---|---|---|
| `name` | string | `""` | label for removing it later via the URL; `active` is reserved |
| `hold` | bool | `false` | stays until removed; ignores `durationMs`; halts the queue |
| `stack` | bool | `true` | queue behind the existing ones; `false` replaces the visible one (restart of scrolling, icon, sound), waiting ones stay |
| `wakeup` | bool | `false` | show even when the panel is switched off; dark again afterwards |
| `sound` | string \| object \| array | — | sound when it appears, at alert volume |

📄 `sound`: `"ding"` (`/MP3/ding.mp3`, else melody `/MELODIES/ding.txt`),
`{"file":"Folder/name"}`, `{"rtttl":"…"}`, `{"speech":"…"}` or a list of 1–4 of
those (the first playable). `""` and `null` are no sound; `"loop":true` in the
object repeats until the notification leaves. `station` is not allowed. A
malformed sound is `422` (`field` = `sound`, `sound.<key>`, `sound[1].file`), a
sound that is not stored or cannot be played is **no** error — the notification
appears silently.

📄 The visible notification ends with its time, even mid-run (unless `repeat` or
`hold`); a press of the middle button removes it. Removing a waiting one does not
touch the visible one.

### 5.7 Arrays as payload

📄 An **array** sent to `PUT /api/v1/apps/pushed/{name}` creates numbered apps
`<name>0`, `<name>1`, … — one per object element, none called `<name>`; elements
that are not objects are skipped without using up a number. `DELETE
/api/v1/apps/{name}` deletes the exact name **and** the numbered apps created
that way; one you stored yourself under `<name>1` is an app of its own and
stays. An array counts whole or not at all: if one element breaks a rule or the
stack does not fit under the ceiling, the whole request is refused and not a
single app is created or changed.

📄 An array sent to `POST /api/v1/notifications` may hold **at most one**
element; more is `422 validationFailed`, and nothing is queued.

### 5.8 How the errors are named

| Situation | Response |
|---|---|
| body is not valid JSON | `400 invalidJson` |
| body over 2 MiB (HTTP) | `413 payloadTooLarge` |
| unknown top-level key | `422 validationFailed`, `field` = the key |
| unreadable color, wherever it stands | `422 validationFailed`, `field` = the key |
| a word key with a word outside its list | `422 validationFailed`, `field` = the key |
| unknown `effect` or `overlay` name | `422 validationFailed`, `field` = `effect` / `overlay` |
| invalid `palette` name or form | `422 validationFailed`, `field` = `palette` |
| invalid `scroll` field | `422 validationFailed`, `field` = `scroll.<key>` |
| `iconGap` not a whole number 0–128 | `422 validationFailed`, `field` = `iconGap` |
| bad `icons[]` entry | `422 validationFailed`, `field` = `icons[<i>].<key>` |
| malformed `sound` | `422 validationFailed`, `field` = `sound` / `sound.<key>` |
| unknown draw command, not an array, wrong argument count, non-numeric coordinate, `pixels` with an odd number of coordinates | `422 validationFailed`, `field` = `draw[<i>]` |
| notification key in an app | `422 validationFailed`, `field` = the key |
| keys beside `layout` that do not fit | `422`, `field` = the key ("not allowed with layout") |

---

## 6. The draw commands

📄 `draw` is an **array of arrays**, each with the command name first. Drawing
happens in the order of the array. There are nine commands:

| Command | Arguments |
|---|---|
| `["pixel", x, y, color]` | one pixel |
| `["pixels", color, x1, y1, x2, y2, …]` | many pixels in one color (even number of coordinates) |
| `["line", x1, y1, x2, y2, color]` | both end points included |
| `["rect", x, y, w, h, color]` | outline, 1 px |
| `["rectFill", x, y, w, h, color]` | filled |
| `["circle", cx, cy, r, color]` | center and radius |
| `["circleFill", cx, cy, r, color]` | filled |
| `["text", x, y, "HI", color]` | text in the app's `font` |
| `["bitmap", x, y, w, h, data]` | image; exactly these six arguments |

📄 The trailing color may be **omitted**; the command then takes the app's text
color. `pixels` carries its color **first**, where `null` means the same.
Pixels outside drop out and are never wrapped. A `w` or `h` of zero or less draws
nothing, as does a negative radius; a radius `0` draws the center point. A
`bitmap` that is too short leaves the remaining cells undrawn, surplus entries
are ignored.

📄 `bitmap` data come in two interchangeable forms: as an **array of w × h
colors**, row by row, in any color form from §1.4 — or as a **base64 string of
w × h × 3 raw RGB888 bytes**. The base64 form is far shorter for large images.

📄 The `text` of the draw commands is UTF-8, set in the app's `font` and never
moves; it is **unaffected** by `textCase`, `palette`, `textBlinkMs`,
`textFadeMs`, `textAlign` and `uppercase`. With `small`, `y` is the top row of
capitals; `y = 1` lines up with the rows of the `text` key.

📄 The number of commands is limited only by the 2 MiB (HTTP) or 8192 bytes
(MQTT).

```bash
curl -X PUT http://<ip>/api/v1/apps/pushed/art \
  -H 'Content-Type: application/json' \
  -d '{"draw":[
        ["rect",0,0,26,8,"#202020"],
        ["circleFill",4,4,2,"#F00"],
        ["text",9,1,"HI"]
      ]}'
```

📄 **The order in which a picture comes about** (later layers cover earlier
ones):

1. **Background** — the effect if `effect` resolves, else `backgroundColor` or
   black.
2. **Text and decoration** — with `textInFront` the decoration first, then the
   text; otherwise the other way round. The decoration is always `draw` →
   `progress` → `barChart` → `lineChart`.
3. **Expiry mark** — the dark-red frame of an expired app with
   `lifetimeExpiry: "mark"`.
4. **Icon** — vertically centered, with `iconOffsetX` plus the shift from
   `iconMode`.
5. **Extra icons** — `icons[]` in array order.
6. **Overlay** — the app's own, else the global one.

---

## 7. What the device tells about itself

### 7.1 `GET /api/v1/device` and `<P>/state/device`

🔬 On the measured device:

```json
{"version":"1.2.2","uid":"<uid>","boardType":"tc002","soc":"armv7l",
 "updateImage":"awtrix-ng-tc002.awup","ipAddress":"<ip>","macAddress":"<mac>",
 "hostname":"<hostname>","wifiRssi":-26,"uptimeSeconds":4421,
 "freeHeapBytes":13553664,"minFreeHeapBytes":13488128,
 "scriptingRunning":true,"scriptHeapPool":"system","scriptHeapBudgetBytes":4194304,
 "resetReason":"software","fps":42,"brightness":128,
 "batteryPercent":73,"batteryVoltage":4.03,"lowBattery":false,
 "matrixPower":true,"currentApp":"Time",
 "indicators":[{"on":false,"color":"#000000","blinkMs":0,"fadeMs":0}, …],
 "messageCount":0,
 "wifi":{"enabled":true,"state":"connected","host":"<ssid>","endpoint":"<ip>",
         "attempts":0,"retryInMs":0,"connects":1,"error":null,"lastError":null},
 "mqtt":{"enabled":true,"state":"offline","host":"<broker>","endpoint":"<broker>:1883",
         "attempts":85,"retryInMs":35431,"connects":0,"error":"timeout","lastError":"timeout"},
 "mirror":{"sharing":false,"viewers":0,"source":"","state":"off"},
 "usbPower":false,"update":{"state":"idle","release":"","error":""}}
```

Identifiers, addresses and names are replaced; the numeric values stand as the
device reported them.

🔬 Compared with 1.1.0/TC001, `lightLevel`, `ldrRaw`, `temperature`, `humidity`
and `batteryPinMillivolts` are missing (no light sensor, no probes); new are
`macAddress`, `updateImage`, `mirror`, `usbPower` and `update`.

📄 Meaning: `uid` twelve lowercase hex digits; `soc` e.g. `armv7l`;
`resetReason` `poweron`, `software`, `panic` or `watchdog`; `brightness` 0–255
(the value in use right now); `messageCount` the MQTT command messages received
since start; `indicators` exactly three entries with `on`, `color`
(`#RRGGBB`), `blinkMs`, `fadeMs` (0–65535). The battery keys (`batteryVoltage`,
`batteryPercent`, `lowBattery`) are absent altogether as long as the device
reports no battery; `lowBattery` is `true` below `lowBatteryThreshold` and
always `false` at threshold 0. `usbPower` appears once the device reports its
power supply. `update.state`: `idle`, `applying`, `boot-pending`, `confirmed`,
`failed`. `mirror.state`: `off`, `offline`, `resolving`, `notFound`, `waiting`,
`idle`, `filtered`, `sizeMismatch`, `noMemory`, `showing`.

📄 `wifi` and `mqtt` have the same keys: `enabled`, `state` (`disabled`,
`offline`, `connecting`, `connected`), `host`, `endpoint`, `attempts` (failed
attempts in a row), `retryInMs`, `connects` (successes since start), `error`
(`null` while connected) and `lastError`. Possible values of `error` for `wifi`:
`hostNotFound`, `badCredentials`, `timeout`, `lost`; for `mqtt`: `noWifi`,
`hostNotFound`, `refused`, `badCredentials`, `rejected`, `timeout`, `lost`.

🔬 On the measured device `mqtt.state` was `offline` with `attempts` 85 and
`error` `timeout`; the device log repeatedly said `failed (timeout, state -4)`.
The cause is a wildcard in the prefix (§2).

### 7.2 `GET /api/v1/apps`

🔬 Per app `name`, `enabled`, `inLoop`, `slot`, `present`, `origin` and
`config`:

```json
[{"name":"Time","enabled":true,"inLoop":true,"slot":null,"present":true,"origin":"builtin","config":true},
 {"name":"Status","enabled":true,"inLoop":true,"slot":null,"present":true,"origin":"builtin","config":false}]
```

📄 `origin` is one of `builtin`, `pushed`, `script`, `module` (or `null` when not
present). The ordered apps come first in their order, then everything else.
Without an order the loop runs: built-in apps, pushed ones in order of arrival,
scripts. Keys that do not apply are absent: `icon` (pushed apps with an icon),
`import` (modules), `skipped`, `headless`, `ondemand`, `error` (`null` or
`{message, line?, hook?}`) and `meta` (scripts), `config` (apps with settings).
The order survives restarts only for apps named in an order call; switched-off
pushed apps stay off after being sent again.

❓ Why `slot` is `null` for both measured apps although `inLoop true` is
reported is not explained (the docs say `slot` is "integer or `null`").

### 7.3 `GET /api/v1/display/screen` and `<P>/state/screen`

📄 `pixels` is a flat array of packed RGB integers (`0xRRGGBB` as a decimal
number), `width × height` entries, row by row from the top left — **the colors
the apps drew**; brightness and color correction do not change them.

🔬 On the measured device `{"width":52,"height":16,"pixels":[…]}` with 832
values.

Over MQTT the topic is **not retained** and is published only as a reply to
`cmd/screen/get`.

### 7.4 `GET /api/v1/capabilities`

🔬 On the measured device: `effects`, `paletteEffects`, `transitions`,
`overlays`, `palettes` (names, §5.5); `audio` with the switches `mp3`, `rtttl`,
`song`, `speech`, `radio`, `url`, `effect`, `clip` (all `true`) and `track`
(`false`); `microphone`, `scriptUpdates`, `ble`, `gamepad`, `gamepadRemote`,
`oauth`, `crypto`, `tcp`, `voice`, `mqttTls`, `bootSound`, `enlargeApps` (all
`true`); `gpio` `null` (pins not changeable); `platform.id` `tc002`;
`sensors.light` `false`; `display` (§1); `fonts` (§1.3); `clockFaces` (`sheet`,
`ring`, `flap`, `month`, `big`); `layout` `true` and `layouts` with `version 1`
and `limits` (§9.5).

### 7.5 `GET /api/v1/display`, `/audio` and more

🔬 `GET /api/v1/display`:
`{"power":true,"brightness":128,"overlay":null,"overlaySettings":{"speed":1,"palette":null,"blend":true},"moodlight":null}`.
`GET /api/v1/audio`: `radio` (`playing`, `station`, `title`, `error`,
`underruns`, `decodeUs`, `starvedMs`, `bufferBytes`), `app` and `alert`
(`playing`, `name`, `error`), and `stations` (each `name`, `url`).

📄 `moodlight` is `{color, brightness}` or `null`. `GET /api/v1/logs` returns the
running device log; `GET /api/v1/files` the file store with `usedBytes` and
`totalBytes` (excluding the reserved minimum free space).

---

## 8. The limits

📄 Everything the device enforces, and what it answers at the edge:

| Limit | Value | At the edge |
|---|---|---|
| body over HTTP (JSON or upload) | **2 MiB** | `413 payloadTooLarge`, nothing is applied |
| MQTT command message, topic included | **8192 bytes** | **dropped: no error, no `/result` reply** |
| nesting in the JSON | 16 levels | `400 invalidJson` |
| names of apps and scripts | 1–32 characters from `A–Z`, `a–z`, `0–9`, `_`, `-` | `400 invalidName` |
| firmware package (`.awup`) | 8 MiB | `413 payloadTooLarge` |
| bodies over 64 KiB | received one at a time | a second large body mid-reception: `503 serviceBusy`, `Retry-After: 2` |
| apps in the device at once | **50** (new names only) | `507 insufficientStorage`, nothing is stored; replacing always succeeds |
| array as payload | all or nothing | if the new names exceed 50 in total: `507`, nothing created |
| notification queue | 32, the visible one counted | stacked: `507`; `stack: false` replaces the visible one and is never refused |
| notifications per request | 1 | `422 validationFailed` |
| points in `barChart` / `lineChart` | 16 | the 17th and all further ones drop, it is drawn anyway |
| extra icons (`icons`) | 4 per app, in addition to `icon` | `422`, the whole request refused |
| display size | **52 × 16** = 832 pixels, fixed | — |
| GIF | must fit the width and height of the display | shrink larger ones first; a too-large GIF is not shown |
| 🔬 GIF as data URL, `icon` of a layout region | about 8 KB Base64 (7508 characters accepted, 8796 rejected) | `422 validationFailed` "invalid icon", `field` `layout.regions[0].icon` |
| 🔬 GIF as data URL, `icon` of the display | at least 58,761 bytes of GIF accepted, 87 KB rejected | `field` `icon` |
| icon from a web address: address | 2048 characters, `http(s)`, no spaces | `422`, `field` = `icon` |
| icon from a web address: file size · load time | 1 MB · 15 s | image not shown, the log names the server |
| icon from a web address: JPEG | up to 8192 × 8192; progressive 1920 × 1280 (4:2:0), 1600 × 1200 (4:2:2), 1000 × 1000 (4:4:4) | image not shown |
| icon from a web address: PNG · GIF | 4 million pixels, not interlaced · 8 KB | image not shown |
| images in memory | 64 images and 128 KB | the oldest is evicted and reloaded when needed |
| simultaneous downloads | 1, up to 8 waiting | the others wait |
| file store | the free space; **1 MiB** stays reserved for settings, Wi-Fi setup and updates | `507 insufficientStorage`, no half file is left behind |
| melody (source) · name | 512 characters · 1–24 characters | `422 validationFailed` |
| MP3 name | 1–32 characters | `400 invalidName`; MP3 and melody names are unique together (`409 nameTaken`) |
| sounds in a list | 1–4 | `422 validationFailed` |
| speech text | 1–512 bytes | `422 validationFailed` |
| MP3 from an address (`file`) | 4 MB, only with enough free memory | nothing plays, `alert.error`/`app.error` names the reason |
| song text | 16384 bytes (over MQTT 8192 including JSON and escaping); 16 tracks, 32 instruments, 8192 notes, 1024 bars, 8 notes per chord, echo 2 s | `422` |
| radio stations | 32; name 1–24 characters, address at most 255 characters with `http(s)` | `422`, the whole list refused, the row named |
| Berry scripts | shared memory: a quarter of the memory free at start, at most 4 MiB (`scriptHeapBudgetBytes`); further limits in the manufacturer docs, not listed here | new install refused, running scripts keep running |
| certificate (`PUT /api/v1/mqtt/tls/ca`) | 65536 bytes | `422`/`507` |

📄 **Not limited are:** requests per second — neither over HTTP nor over MQTT is
anything throttled; and what the device publishes — `state/device` and
`state/screen` go out however large they are. The number of draw commands is
limited only by the body limit.

🔬 Measured on 1.1.0/TC001 with this app's frame builder, **in each case the
whole MQTT message** (topic and JSON): text of 1 000 characters 1 096 bytes, of
7 900 characters 7 996 bytes; umlauts count two bytes in the JSON.

🔬 On the measured device `GET /api/v1/files` reports `"usedBytes":2579,
"totalBytes":6908435`.

---

## 9. Layouts

📄 A **layout** divides the display into boxes, each showing exactly one content
(text, icon, chart, progress bar or drawing). It stands as the block `layout` in
the payload of a pushed app or notification (or is drawn by a script) and is not
stored as a file on the device. `capabilities.layout` is `true` (🔬).

### 9.1 Grid and boxes

📄 **Layouts work on the full 52 × 16 grid**, never on the enlarged one (§1.1).
A box is `[x, y, width, height]` from the top-left corner: whole display
`[0, 0, 52, 16]`, top half `[0, 0, 52, 8]`, bottom half `[0, 8, 52, 8]`. **A box
must lie completely inside the display**, otherwise `422` ("outside the
display") and nothing changes. Content sits in the middle of its box unless
`align` and `valign` say otherwise; what does not fit is cut off — except text,
which scrolls. Fonts and images keep their size.

### 9.2 Structure

📄 At layout level there are:

| Key | Meaning |
|---|---|
| `version` | `1` |
| `regions` | the regions, in drawing order (later ones cover earlier ones) |
| `backgroundColor` | fills the display first; default black |
| `effect` | background effect; **not** together with `backgroundColor` |
| `effectSpeed` | 0.1–10 |
| `overlay` | overlay above all regions; without it the device shows its own |
| `palette`, `paletteBlend`, `paletteSpan`, `paletteSpeed` | apply to effect, overlay and regions that use `"palette"` without a palette of their own |

📄 Each **region** has `id` (freely chosen, unique within the layout, at most 64
bytes) and `box` and **exactly one** of the keys `text`, `icon`, `chart`,
`progress`, `draw`. `align` (horizontal) and `valign` (vertical) take `start`,
`center`, `end`; both default to `center`.

### 9.3 Contents

| Content | Value | Further keys of the region |
|---|---|---|
| `text` | string or array of parts (each with optional `color`) | `font` (default `small`), `color`, `palette`, `textColor` (name of a pushed app for `color`), `align`, `valign`, `scroll`, `repeat`, `textCase`, `textBlinkMs`, `textFadeMs` |
| `icon` | id, data URL or web address that fills the region | `align`, `valign` |
| `chart` | `{values, type, min, max}` — `values` up to 128 integers, `type` `line` or `bar`, `min` and `max` only together and with `min < max`; without both the chart scales itself and includes zero | — |
| `progress` | 0–100, fills from the left | `color`, `palette`, `trackColor` (empty part, default `#202020`) |
| `draw` | the same commands as the `draw` key (§6), counted from the top-left corner of the box; whatever lies outside the box is cut off | `color`, `font` |

📄 `palette` takes a name, a list of colors or `{color, pos}` stops. `color` or
`textColor` set to `"palette"` takes the colors from the palette of the region or
layout. `paletteBlend`, `paletteSpan`, `paletteSpeed` need a `palette` next to
them.

📄 A **text** region scrolls unless it sets `"scroll":"static"`, even if the text
fits. `scroll` takes a mode (`"loop"`) or the object from §5.2; `speed` and
`holdMs` up to 1 000 000, `gap` up to 32 767; `speed: 0` never finishes. Without
`scroll` the global settings apply. `align` places text only while it stands
still.

### 9.4 What combines and what does not

📄 Beside `layout`, `durationMs`, `repeat`, `lifetimeMs`, `lifetimeExpiry` still
apply, and for notifications `name`, `hold`, `stack`, `wakeup`, `sound`. **Not
combinable** with `layout` are `text`, `icon`, `draw`, `effect`, `scroll` and the
remaining drawing keys of the payload (colors, palettes, effects, overlays,
charts, progress belong in the layout or the region): `422` with `field` = the
key ("not allowed with layout"). A region may set its own `repeat`; `0` means the
app does not wait for it, and still text never holds the app.

### 9.5 Updating and limits

📄 **A change is made by sending the whole layout again;** the docs describe no
partial update of single fields. Regions are matched by `id`, order does not
matter; moving text of unchanged regions keeps its position, a region whose
text, font, box or scroll options change starts from the beginning. Any error
refuses the entire update; the previous content stays. Also refused are an
unknown font, effect or palette, an icon that cannot be loaded, and too much
content.

📄 Limits per layout (also under `layouts.limits` in `capabilities`):

| Limit | Value |
|---|---|
| regions | 16 |
| moving texts | 8 |
| icons | 4 |
| chart values per chart | 128 |
| text in total | 8192 bytes |
| prepared content, shared by pushed apps, waiting notifications and script handles | 256 KiB (`preparedBytes` 262144) |
| script handles | 4 per script, 8 in total |

When memory is full the request is refused and the display stays unchanged. On
replacement the device briefly needs room for the old and the new layout.

🔬 `capabilities.layouts.limits` reports on the measured device `regions 16`,
`scrollers 8`, `assets 4`, `chartPoints 128`, `textBytes 8192`,
`preparedBytes 262144`, `scriptHandles 8`, `scriptHandlesPerScript 4`.

```json
{"layout":{"version":1,"regions":[
  {"id":"icon","box":[0,4,8,8],"icon":"sun"},
  {"id":"temp","box":[9,0,43,16],"text":"21.5°C"}]}}
```

```json
{"durationMs":10000,"layout":{"version":1,"regions":[
  {"id":"title","box":[0,0,52,8],"text":"TEMPERATURE","font":"matrix-light6"},
  {"id":"value","box":[0,8,52,8],"text":"22.4°C","font":"matrix-chunky8x6","color":"#00AAFF"}]}}
```

---

## 10. The settings

📄 `GET /api/v1/settings` returns all display settings, each always present;
`PATCH` takes a subset, checks everything before writing and refuses unknown
keys. The same keys are in `<P>/state/settings`.

🔬 The measured reply has 46 keys; the values below are the documented defaults,
and where the device's state differs, that is noted.

| Group | Key | Type · range · default |
|---|---|---|
| Brightness | `brightness` | int 0–255, default 120 (measured 128); raw value, not a percentage |
| | `autoBrightness` | bool, `false` — **no effect** (no light sensor) |
| Color | `saturation` | int 0–100, 100 |
| | `gamma` | number > 0, 1.9 |
| | `colorCorrection`, `colorTint` | color or `null`, `null`; multiply every pixel, the second after the first |
| Global text | `textColor` | color, `#FFFFFF`, never `null` |
| | `uppercase` | bool, `true` |
| | `scroll` | object as §5.2, default `wrap`/`left`/`inline`/`static`/100/8/1000 |
| | `enlargeApps` | bool, `true` (§1.1) |
| Loop | `autoTransition` | bool, `true` |
| | `appDurationMs` | int ≥ 0, 7000 |
| | `transitionEffect` | name (case-insensitive), `"Rain"`; names in `capabilities.transitions` |
| | `transitionDirection` | `normal` · `reverse`, `normal` |
| | `transitionDurationMs` | int 0–2147483647, 1000 |
| Clock app | `clockFace` | `sheet` · `ring` · `flap` · `month` · `big`, `sheet` |
| | `timeColor` | color or `null` |
| | `calendarHeaderColor` · `calendarTextColor` · `calendarBodyColor` | color, `#FF0000` · `#000000` · `#FFFFFF` |
| | `calendarAnimation` | bool, `true` |
| | `timeMode` | int 0–6, 1 — **no effect** |
| Time text | `time24h` · `timeLeadingZero` · `timeShowSeconds` · `timeShowAmPm` | bool, `true` · `true` · `false` · `false` |
| | `timeSeparatorMode` | `steady` · `blink` · `pulse`, `pulse` |
| Date text | `dateOrder` | `dayMonthYear` · `monthDayYear` · `yearMonthDay`, `dayMonthYear` |
| | `dateSeparator` | `dot` · `slash` · `dash`, `dot` |
| | `dateYearMode` | `none` · `twoDigit` · `fourDigit`, `twoDigit` |
| | `dateShowWeekday` · `dateMonthNames` | bool, `false` |
| | `dateColor` | color or `null` |
| Weekday bar | `weekdayBar` | object: `show` (`true`), `startOnMonday` (`true`), `weekendDays` (`["sunday","saturday"]`), `activeColor` `#FFFFFF`, `inactiveColor` `#666666`, `weekendActiveColor` `#FFFFFF`, `weekendInactiveColor` `#666666` (colors never `null`) |
| | `dateWeekdayBar` | object of the same shape — **no effect** |
| Sensor apps | `useCelsius`, `temperatureColor`, `humidityColor`, `batteryColor` | accepted, **no effect** |
| Sound | `volume` | int 0–100, master volume 90 (measured 100) |
| | `radioVolume` · `appVolume` · `alertVolume` | int 0–100, 80 · 100 · 100; each group plays at master volume × share |
| | `bootSound` | bool, `true` |
| | `musicSource` | `auto` · `playback` · `microphone`, `auto` |
| Buttons | `blockNavigation` | bool, `false` |

---

## 11. The system configuration

📄 `GET /api/v1/system` reads, `PUT` merges in a subset (everything checked
before anything is written). Secrets (`wifiPass`, `mqttPass`, `authPass`) come
only with `?secrets=1`; an empty value on write keeps the stored secret.
"Restart" means: takes effect only after `POST /api/v1/device/reboot`. In setup
mode only `wifiSsid`, `wifiPass` and `hostname` are writable.

| Group | Key | Type · range · default | Restart |
|---|---|---|---|
| Wi-Fi | `wifiSsid` | string, `""`; cannot be emptied by `PUT` (`422`) | yes |
| | `wifiPass` | string, secret | yes |
| | `wifiConnectTimeout` | long 5000–120000 ms, 15000 | yes |
| | `wifiRoamRssi` | int −90…0 dBm, 0 = off | yes |
| Network | `netStatic` · `ip` · `gateway` · `subnet` · `dns1` · `dns2` | bool `false`; strings, dotted form; `ip` may carry `/0`–`/32`; fixed only with `netStatic` and `ip` set; `subnet` then required | no |
| MQTT | `mqttEnabled` · `mqttHost` · `mqttPort` · `mqttUser` · `mqttPass` · `mqttTls` · `mqttPrefix` | §3.1 | yes |
| | `mqttTlsPin` | 64 lowercase hex digits or `""`, else `422` ("expected 64 lowercase hex digits") | no, applies at the next connection attempt |
| Home Assistant | `haDiscovery` · `haPrefix` | §3.1 | no, applies at once |
| Time | `ntpServer` | string, `pool.ntp.org` | no |
| | `tz` | POSIX TZ, `CET-1CEST,M3.5.0,M10.5.0/3`, not validated | no |
| | `tzName` | IANA name, label of the web UI only | no |
| Identity | `hostname` | string 1–32, empty → `awtrixng-` + last 6 characters of the uid | yes |
| Access | `authEnabled` | bool; `true` needs `authUser` and `authPass` (`422`) | no |
| | `authUser` · `authPass` | string; `authPass` is a secret | no |
| | `webPort` | stored, **no effect** (port 80) | — |
| Battery | `lowBatteryThreshold` | uint8 0–100, 0 = off | no |
| Buttons | `swapButtons` | bool, `false`; swaps left and right, never the middle | no |
| | `buttonCallback` | URL, `""`; receives an HTTP `POST` on every press, release and turn; `http://` only | no |
| Mirroring | `mirrorShare` · `mirrorShareApps` · `mirrorShareNotifications` · `mirrorFrom` · `mirrorFromApps` · `mirrorFromNotifications` | bool `false`; name list `"*"`; bool `true`; source `""`; `"*"`; `true`. UDP port 4212 open while `mirrorShare` is on or `mirrorFrom` is set; no login | no |
| Misc | `statsInterval` | long 1000–600000 ms, 10000 (else `422`) | yes |
| | `debugMode` · `scriptingEnabled` | bool, `false` · `true` | no · yes |
| no effect | `tempOffset`, `humOffset`, `batteryDividerRatio`, `tempDecimals`, `dfplayer`, `artnet`, `minBrightness`, `maxBrightness`, `ldrFactor`, `ldrGamma`, `ldrOnGround`, `brightnessSmoothing` | accepted and stored | — |

📄 There are no panel or pin keys: keys for them are ignored like unknown ones;
`capabilities.gpio` is `null`.

🔬 `GET /api/v1/system` lists 48 keys on the measured device, including all the
MQTT, network, mirror and button keys named above; `mqttTls false`,
`mqttTlsPin ""`, `statsInterval 10000`, `webPort 80`, `lowBatteryThreshold 15`,
`scriptingEnabled true`. `wifiPass`, `mqttPass` and `authPass` are not listed in
it.

### 11.1 MQTT over TLS

📄 `mqttTls: true` connects encrypted (usually port 8883). Trusted is a
certificate of a public CA that carries the name `mqttHost`, or the one fixed by
`mqttTlsPin`; an uploaded broker CA replaces both. `GET /api/v1/mqtt/tls` shows
how the broker is trusted, including the SHA-256 fingerprint; `PUT
/api/v1/mqtt/tls/ca` with `{"certificate":"<PEM>"}` (at most 65536 bytes, else
`422`) uploads a CA of your own, `DELETE` removes it and answers with the state.
Both routes are `404` when the capability is missing (`capabilities.mqttTls`).

🔬 `GET /api/v1/mqtt/tls` answers `{"ca":"public","pending":null}` on the
measured device.

❓ Which values `ca` takes besides `public` and what `pending` means is not
stated.

---

## 12. Error codes

📄 `code` is stable; `message` is English prose. The status column applies to
HTTP.

| Code | Status | Meaning |
|---|---|---|
| `invalidJson` | 400 | body is not valid JSON (on some routes also empty) |
| `invalidName` | 400 | name invalid or reserved (`field` `name`, for renames `from`/`to`) |
| `invalidPath` | 400 | path outside the allowed folders or containing `..` |
| `invalidMethodOverride` | 400 | `X-HTTP-Method-Override` misused |
| `invalidPlayer` | 400 | gamepad player not 1 or 2 |
| `invalidOrigin` | 400 | a field of an icon origin link is missing or invalid |
| `badRequest` | 400 | upload without file, too many files or interrupted |
| `invalidPackage` · `wrongTarget` | 400 | firmware package damaged or for another device |
| `unauthorized` | 401 | login on, credentials missing or wrong |
| `forbidden` | 403 | route not allowed in setup mode |
| `forbiddenOrigin` | 403 | request from a foreign web page |
| `notFound` | 404 | unknown route, or app, sound, file, notification not there |
| `methodNotAllowed` | 405 | the path exists, but not for this method (`allowed: <list>`) |
| `scriptChanged` · `notNewer` · `gamepadsFull` · `updateBusy` · `nameTaken` | 409 | script differs from `expected_source` · package not newer · both gamepad slots taken · update running · name already taken |
| `payloadTooLarge` | 413 | body over the limit |
| `insufficientMemory` | 413 | not enough free memory for a firmware package |
| `unsupportedMediaType` | 415 | `Content-Type` not JSON on `PUT`/`PATCH`, or the file does not suit the folder |
| `validationFailed` | 422 | JSON valid, a value is not; usually with `field`; nothing is applied |
| `internalError` · `storageError` | 500 | action failed · icon links not readable/storable |
| `notSupported` | 501 | device takes no network updates |
| `scanUnavailable` · `unavailable` · `serviceBusy` | 503 | Wi-Fi scan impossible while the setup hotspot is open · capability missing or sound not playable · briefly busy (`Retry-After: 2`) |
| `insufficientStorage` | 507 | store or queue full, or not storable (`applied, not saved yet` for order and station list) |

---

## 13. What changed against 1.1.0

📄 For senders written against 1.1.0 (in each case according to the docs, not
checked on a device):

| Subject | 1.1.0 (TC001) | 1.2.2 (TC002) |
|---|---|---|
| Grid | 32×8, panel width 32–128 configurable | 52×16 fixed; enlarged apps work on 26×8 |
| HTTP body limit | 8192 bytes | 2 MiB (MQTT still 8192 bytes, now with topic) |
| Notification sound | `sound`, `soundRtttl` | `sound` as name, object or list; `soundRtttl` no longer listed |
| `audio/play` | keys `sound`, `mp3`, `melody`, `track`, `rtttl`, `station`, `index`, `url` | `file`, `rtttl`, `song`, `speech`, `station`, `loop`; list up to 4 |
| `audio/stop` | `{"scope":"sounds"\|"stream"\|"all"}` | `{"group":"alert"\|"app"\|"radio"}` |
| Icon | id, or base64 in the text from 65 characters | id, data URL with prefix, or web address; bare base64 is `422` |
| Text | `textCenter` | `textAlign` (`start`/`center`/`end`) |
| Fonts | `small`, `large` | plus ten matrix fonts |
| Message on a wrong method | `allowed method(s): …` | `allowed: …` (🔬) |
| New | — | layouts, `iconGap`, `icons[]`, `cmd/voice/start`, `event/knob`, `event/error`, `cmd/apps/<name>/enabled`, `mqttTls`, `state/buttons/knob` |

---

## 14. What is not stated

- ❓ **Whether `+` in `mqttPrefix` acts like `#`** (§2) and whether the firmware
  objects to spaces or further characters in it.
- ❓ **Everything about MQTT on the device:** topics, `/result` replies,
  `event/error`, `state/*`, Last Will and retention are known from the docs only,
  not measured — the client did not connect during the measurement (wildcard in the prefix).
- ❓ **The grid of the charts and the progress bar in enlarged apps** (26×8 or
  52×16; measured for `draw`, §1.1) and the height of the bar.
- ❓ **The unit of `iconGap`** in enlarged apps (columns of the 26×8 grid or of
  the display).
- ❓ **Whether `POST /api/v1/device/sleep` exists over HTTP:** the MQTT part lists
  it as the HTTP counterpart, the route list of the HTTP page does not name it.
- ❓ **The values of `ca` and the meaning of `pending`** in `GET
  /api/v1/mqtt/tls` (§11.1).
- ❓ **Why `slot` in `GET /api/v1/apps` is `null` for running built-in apps**
  (§7.2).
- ❓ **An MQTT route that outputs the list of apps.** There is none; the inventory
  is explicitly available only via `GET /api/v1/apps`.
- ❓ **Whether the behaviors measured in §2 on 1.1.0** (a space at the edge of
  the prefix counts; a prefix change takes effect only on a new connection)
  **carry over to 1.2.2/TC002.** The docs require a restart for `mqttPrefix`.
