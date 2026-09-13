# Remote-controlling the Ulanzi TC002

*[Deutsche Fassung](../tc002-protokoll.md)*

What the device can do and how to address it — over MQTT and over HTTP. This
description is independent of our app: it applies just as well to `mosquitto_pub`,
Node-RED, Home Assistant or a script of your own. How to do the same things **in
the app** is described in its help (⌘?).

Every statement carries its provenance:

| Mark | Meaning |
|---|---|
| ✅ | verified on the device itself |
| 📘 | from the [vendor repository](https://github.com/UlanziTechnology/Ulanzi-U-Clock-TC002), not cross-checked |
| ❓ | open — an assumption, not yet proven |

**All statements refer to firmware `mcuVer V1.0.17`, `appVer 1.1.1`**
(as of 2026-09-11, readable via `/getBase`, see §5.1). Some of what is marked
❌ here may simply be a bug, fixed in a later version — namely that the `text`
command does not scroll (§4.3) and that an empty HTTP body does not delete
(§5.6). If you work with newer firmware and find something different: the tests
are given alongside each claim and can be repeated in a few minutes.

---

## 1. The display

✅ **52 pixels wide, 16 high.** The origin is at the **top left**, x grows to the
right, y downward. Colors throughout as `"#RRGGBB"`.

✅ **The built-in font has no umlauts.** Lowercase letters work, digits work; of
the punctuation marks only `%`, `.`, `-` and `:` are present. Everything else is
missing with no substitute — the device shows nothing at that spot and reports
nothing either. If you want to write "Grüße", you have to convert the text to
pixels yourself and send it as `draw` (see §4.1).

❓ Whether the font has **uppercase letters** is not verified — only lowercase
letters and digits are proven. Test: send `"content":"ABC abc"` and look at the
result.

---

## 2. The topic prefix — the most common source of errors

✅ **The prefix the device listens on is not what is entered in the Ulanzi Studio
app.** The firmware appends the **last four digits of the MAC address**,
separated by an underscore:

```
entered:  awtrix
MAC:      aa:bb:cc:dd:a8:6b
actual:   awtrix_a86b
```

📘 Out of the box it says `ulanzi` there, so the device listens on `ulanzi_xxxx`.

Nowhere in the user interface does this complete prefix appear. **It can only be
determined over HTTP** (§5.2 and §5.1), or from which topics the device
subscribes to at the broker:

```bash
# the broker log shows this when the device connects:
#   Received SUBSCRIBE from awtrix
#     awtrix_a86b/# (QoS 0)
```

✅ **A wildcard in the entered prefix makes the device unusable.** If it contains
`#` or `+`, the firmware builds an invalid CONNECT packet; the broker logs
`bad socket read/write: Invalid input` and rejects the connection.

> ✅ **Why wrong prefixes are so hard to find:** MQTT 3.1.1 has **no return
> channel for a rejected publish**. If you write to a topic your account has no
> rights for, or to a prefix nobody subscribes to, you still get a clean
> `PUBACK`-free QoS 0 ending: no error, no warning, nothing. Only MQTT 5 has
> reason codes for this. This silence is the reason the prefix quirk above costs
> hours.

---

## 3. The MQTT topics

There are two, both below the prefix from §2.

### 3.1 `<prefix>/custom/<name>` — set a named display

✅ The payload is the frame JSON from §4. `<name>` is freely chosen; it is the
identifier under which the display exists from then on. Sending to the same
display again means: replacing it.

```bash
mosquitto_pub -h 192.168.1.10 -u konto -P kennwort \
  -t 'awtrix_a86b/custom/notiz' \
  -m '{"text":[{"content":"hallo","fontHeight":10,"x":0,"y":3,"color":"#00FF66","align":"left","valign":"top","rect":[0,0,52,16],"charSpacing":1}]}'
```

### 3.2 `<prefix>/custom/<name>` with an empty payload — delete the display

✅ **Exactly zero bytes**, not `""` and not `{}`:

```bash
mosquitto_pub -h 192.168.1.10 -u konto -P kennwort \
  -t 'awtrix_a86b/custom/notiz' -n
```

The display disappears from the device and from the page change.

Over HTTP it is the other way round: there the body `{}` deletes, and an empty
body does nothing (§5.6). Anyone using both routes confuses this easily.

> ✅ **A standing display blocks.** As long as a named display is being shown, it
> stays up; new messages under the same prefix have no visible effect until the
> standing display is deleted. So if you want to show different things one after
> another, either delete first or write to the **same** display (which replaces
> it).

### 3.3 `<prefix>/switchDiyApp` — switch to a display

✅ The payload is the bare name, no JSON:

```bash
mosquitto_pub -h 192.168.1.10 -u konto -P kennwort \
  -t 'awtrix_a86b/switchDiyApp' -m 'notiz'
```

This topic appears in **no** vendor documentation. The evidence for it is that
the device subscribes to it at the broker, and that switching with it works.

The same works without a broker: `POST /api/switchDiyApp?name=<name>` (§5.8).
The HTTP route answers, this one does not — and over that route it is also
proven that the clock really does jump to the named display.

✅ **A display that does not exist is rejected** — over HTTP with
`{"code":404,"message":"custom app not found"}` (§5.8). So the call does check,
rather than silently doing nothing.

❓ Open: how **this** topic behaves in that case. It gives no answer.

### 3.4 `<prefix>/status` — the clock reporting in

✅ The clock publishes `online` here as long as it is connected to the broker.
Observed in the broker on 2026-09-11.

### 3.5 `<prefix>/customList` — which displays the clock knows

✅ **The clock publishes its own display list.** Observed in the broker on
2026-09-11:

```json
{"apps":[{"appName":"scrolltest"}],"count":1}
```

That is the answer to "which named displays exist right now" — and it comes from
the device itself, not from the sender's bookkeeping. If you use several tools
(this app, Ulanzi Studio, PixDeck, `mosquitto_pub`), this is the only place where
you learn what is really on the clock.

The same answer is available **over HTTP as well**, on request rather than by
luck: `GET /api/customList` (§5.7). The path `GET /customList` — without
`/api` — returns nothing; that is the whole difference, and it was long taken
for a firmware defect.

✅ **The clock also reports what was created over HTTP.** The `scrolltest`
display above had been created with `POST /api/custom?name=scrolltest` (§5.6),
with no broker involved — and it still appears in the list the clock publishes
over MQTT. Observed on 2026-09-11. So `customList` really is the state of the
device, not the bookkeeping of one particular sender.

Two things follow. First: **sending over HTTP and listening over MQTT can be
mixed.** If you have a broker, you can send over HTTP — which gives you real
error codes instead of the silence described in §2 — and still keep the feedback
channel.

Second: **HTTP-only operation is possible.** Creating and deleting (§5.6),
switching (§5.8) and the display list (§5.7) all work without a broker, all four
measured on the device. Two things remain reserved for MQTT: the **content** of
a display — only somebody listening in on the `custom` publish learns that
(§3.1) — and the report of whether the clock is online at all (§3.4).

Both topics appear in **no** vendor documentation.

❓ Whether the clock publishes these topics **retained** (`retain`) is not
verified. It decides whether a fresh subscription immediately receives a state or
waits until the clock's next publish. Test: start
`mosquitto_sub -v -t '<prefix>/#'` fresh — if something arrives immediately, it
was retained. (A subscriber has to accept retained messages anyway: they arrive
with the RETAIN bit set, header byte `0x31` instead of `0x30`.)

---

## 4. The frame JSON

An object with up to four keys. **Leave out empty components** — the device
trips over empty fields.

```json
{
  "draw":  [ … ],
  "image": [ … ],
  "text":  [ … ],
  "duration": 10
}
```

### 4.1 `draw` — drawing

📘 Two basic forms:

| Form | Meaning |
|---|---|
| `{"df":[x,y,width,height,"#RRGGBB"]}` | filled rectangle |
| `{"dfc":[x,y,radius,"#RRGGBB"]}` | filled circle |

✅ `df` with width and height `1` is a **single pixel** — with it you can paint
the display freely and, more importantly, **display text with umlauts**, by
rasterizing it yourself and sending it pixel by pixel.

A green dot at the top left and a red bar below it:

```json
{"draw":[{"df":[0,0,1,1,"#00FF66"]},{"df":[0,2,20,3,"#FF0000"]}]}
```

> **Message size.** Every pixel sent individually quickly gets large. If you
> rasterize, you should merge horizontal runs of the same color into one wide
> `df`; that shrinks typical text images by a factor of several.

### 4.2 `image` — images

✅ One entry per image:

```json
{"image":[{"data":"data:image/gif;base64,R0lGODlh…","position":[0,4]}]}
```

- `data` — a complete data URI. `image/gif`, `image/jpeg` and `image/png` are
  the common types; the AWTRIX world works almost exclusively with **8×8 GIFs**.
- `position` — `[x, y]`, again counted from the top left.

✅ **The device plays animated GIFs**, not just their first frame.
Verified on the device on 2026-09-11 — the vendor repository says the same.

❓ Not proven: whether the image size is limited and what happens with images
larger than 52×16.

❓ Likewise not proven: whether **two `image` entries in the same frame** are
drawn next to each other or the second replaces the first. If you want to show an
icon next to another image, you are on the safe side with a single image that has
both rendered into it.

### 4.2a Scrolling text as an animated GIF — the way around both limitations

✅ Confirmed on the device on 2026-09-11.

The device knows two ways to show text, and each one has a gap:

| | `text` (§4.3) | `draw`, rasterized yourself (§4.1) |
|---|---|---|
| umlauts, punctuation | ❌ | ✅ |
| free choice of font | ❌ | ✅ |
| long text scrolls through | ✅ via `scrollSpeed` (§5.4) | ❌ a `draw` frame is rigid |

**Both at once is possible via `image`:** rasterize the text yourself at full
width, build an animated GIF from it in which a 52×16 window travels over the
text frame by frame, and send that GIF. The device plays it — the text scrolls,
and because we rasterized it ourselves, umlauts and any font are included.

```
Text:    [ G r ü ß e   a u s   W i e n ]      (e.g. 120 pixels wide)
Frame 1: [      52-pixel window       ]  offset -52
Frame 2:  [      52-pixel window      ]  offset -51
…
Frame n:                 [   window   ]  offset 120
```

One frame per pixel of offset gives a smooth scroll; every second or third step
saves frames at the cost of steadiness in the image.

> ⚠️ **The clock only handles disposal method 2.** Every frame of an animated
> GIF carries an instruction about what is to happen to the screen before the
> next frame. Method **2** means "clear first", method **1** means "leave it
> standing and draw only the changed section on top". With method 1,
> **individual pixels are missing on the clock** — the shapes are right, but
> there are holes in them.
>
> The catch: you do not choose the method yourself. `CGImageDestination` on
> macOS derives it from whether the frames have transparent areas.
> **Opaque images produce method 1, transparent ones produce method 2.**
> So anyone building a scrolling GIF must leave unlit pixels **transparent**
> instead of painting them black — on a black background the two look the same,
> but for the clock it is the difference between legible and full of holes.
>
> Measured on 2026-09-11: the same 86 frames, once opaque (method 1, holey),
> once transparent (method 2, clean). You can check this in the third byte of
> each graphics control extension (`0x21 0xF9`), bits 2 to 4.

❓ **Where the size limit lies is open.** A short sentence demonstrably works.
A long text quickly needs several hundred frames, and the payload grows with each
one — as a data URI by an additional third, because that is how Base64 works.
If you push this, you should feel your way to the limit instead of guessing it.

This way appears in **no** vendor documentation; it follows from the fact that
`image` accepts animated GIFs (§4.2).

### 4.3 `text` — text in the device font

✅ One entry per text block, all keys filled in:

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

| Key | Meaning |
|---|---|
| `content` | the text — **without umlauts**, see §1 |
| `fontHeight` | font height in pixels |
| `x`, `y` | top left corner |
| `color` | `"#RRGGBB"` |
| `align` | horizontal: `left`, `center`, `right` |
| `valign` | vertical: `top`, `middle`, `bottom` |
| `rect` | the area `[x, y, width, height]` within which alignment happens |
| `charSpacing` | spacing between the characters in pixels |

> ❌ **`text` does not scroll.** Text that is wider than the display is cut off —
> it does not scroll through, not even with `scrollSpeed` above zero.
> Tested on 2026-09-11 with three variants: with `rect` and all fields, without
> `rect`, and with nothing but `content` and `color`. None of them scrolled.
>
> So `scrollSpeed` (§5.4) apparently applies only to the displays the device
> manages itself, not to your own via `custom`.
>
> **Two ways still lead to scrolling text:**
>
> 1. **As an animated GIF** (§4.2a). One message, after which it keeps scrolling
>    on its own — even when the sender is long gone. Can do umlauts. Costs 10 to
>    30 KB.
> 2. **Driven by the sender.** The same `text` command over and over with a
>    changed `x`, roughly every 0.4 seconds. That is how
>    [PixDeck](https://github.com/cailurus/PixDeck) does it in its `notice`
>    module. Each message is tiny, but the motion stops as soon as the sender
>    stops — and umlauts still do not work.
>
> For a message you send and forget, the first way will do; for a constantly
> updated scrolling text, the second.

### 4.4 `duration` — dwell time

📘 In **seconds**, how long this display stays up while paging.

❓ Open: how `duration` interacts with the device-wide page change (§5.4,
`carouselSpeed`) — whether it overrides it for this one display or whether the
smaller of the two values wins.

---

## 5. The HTTP interface

The device answers HTTP on port 80. The vendor documentation presents MQTT as
the remote-control path, but **HTTP carries an operating mode of its own**:
creating and deleting (§5.6), switching (§5.8) and the display list (§5.7) are
all available here. Conversely HTTP is the **only** way to learn the topic
prefix and the connection state, and the only way to change device settings.

All queries are `GET`, all commands `POST`; none of it requires authentication.

### 5.1 `GET /getBase` — device identification

✅
```json
{"devSn":"TC002-TESTGERAET01","ssid":"heimnetz","ip":"192.168.1.20",
 "mac":"aabbccdda86b","mcuVer":"V1.0.17","appVer":"1.1.1"}
```

The four digits for the prefix (§2) come from `mac`.

### 5.2 `GET /getMqttConfig` — what is entered

✅
```json
{"isMqtt":true,"ip":"192.168.1.10","port":"1883","mqtt_name":"awtrix",
 "mqtt_pwd":"…","mqtt_prefix":"awtrix","isHADiscoveryEnabled":false}
```

`mqtt_prefix` is the **entered** prefix, not the effective one — only together
with `mac` from §5.1 does it yield `awtrix_a86b`.

Noteworthy: the device hands out the MQTT password in the clear, to anyone on the
network, without authentication.

### 5.3 `GET /getMqttStatus` — is it connected to the broker?

✅
```json
{"code":200,"data":{"enabled":true,"connected":true}}
```

`connected` is the only reliable answer to "why does nothing arrive" — it
distinguishes "the device is not connected to the broker" from "the device is
connected, but my prefix is wrong".

### 5.4 `GET /getConfig` — device settings

✅
```json
{"brightness":{"level":"high"},"volume":4,"carouselSpeed":0,"scrollSpeed":7}
```

| Field | Meaning |
|---|---|
| `brightness.level` | brightness level |
| `volume` | volume of the alarm |
| `carouselSpeed` | ✅ **the page change.** `0` means: no paging happens, the first display stays up. Greater than zero is the dwell time per page. |
| `scrollSpeed` | scroll speed of long texts — ❌ **not** for your own displays via `custom`, see §4.3 |

✅ `carouselSpeed` is the answer to "why do I only ever see the first message":
without setting it, the device does not page.

❓ `scrollSpeed` applies, by our own reading, to the `text` command (§4.3) —
there long content scrolls through on the device. It does **not** apply to
self-rasterized `draw` frames (§4.1): a `draw` frame is a rigid pixel grid
without scrolling, whatever value `scrollSpeed` has. This assignment is a
reasoned assumption, not verified on the device — and neither is the valid value
range.

### 5.5 `POST /setConfig` — change settings

✅ Accepted and effective with the **complete** configuration object.
❓ Whether a partial payload such as `{"carouselSpeed":20}` loses the remaining
fields or is rejected has not been tried — the firmware of other Ulanzi devices
behaves that way, and so the safe procedure is in any case: read `/getConfig`,
change one field, send everything back.

```bash
K=$(curl -s http://192.168.1.20/getConfig \
    | python3 -c 'import json,sys; k=json.load(sys.stdin); k["carouselSpeed"]=20; print(json.dumps(k))')
curl -s -X POST http://192.168.1.20/setConfig -H 'Content-Type: application/json' -d "$K"
# {"code":200,"message":"Settings saved successfully"}
```

### 5.6 `POST /api/custom?name=<name>` — the same without a broker

✅ Accepts **the same frame JSON** as §3.1 and sets the same named display —
just without the detour via the broker.

```bash
curl -s -X POST 'http://192.168.1.20/api/custom?name=notiz' \
  -H 'Content-Type: application/json' \
  -d '{"draw":[{"df":[0,0,4,4,"#00FF66"]}]}'
```

✅ **The new display appears immediately**, without switching. If another one is
already standing, however, that one stays — then only `switchDiyApp` (§5.8)
moves things on.

✅ **Deleting works this way too — with the body `{}`.** Measured on 2026-09-13
and checked against `GET /api/customList` (§5.7):

```bash
curl -s http://192.168.1.20/api/customList
# {"apps":["meldung2","meldung3","meldung1"],"count":3}

curl -s -X POST 'http://192.168.1.20/api/custom?name=probe' \
  -H 'Content-Type: application/json' -d '{"draw":[{"df":[0,0,8,8,"#FF0000"]}]}'
# {"code":200,"message":"ok"}   → the list names four displays afterwards

curl -s -X POST 'http://192.168.1.20/api/custom?name=probe' \
  -H 'Content-Type: application/json' -d '{}'
# {"code":200,"message":"ok"}

curl -s http://192.168.1.20/api/customList
# {"apps":["meldung2","meldung3","meldung1"],"count":3}   → probe is gone
```

> ❌ **An empty body does not delete.** It answers the same
> `{"code":200,"message":"ok"}`, but the display stays up — verified on
> 2026-09-11. The trap is that over MQTT it is exactly the other way round: there
> the **empty** payload deletes (§3.2) and `{}` achieves nothing.

[PixDeck](https://github.com/cailurus/PixDeck) takes this route, and that is why
the MQTT chapter of the vendor documentation recommends a program that in truth
works over HTTP. For a device on the same network this is the shorter path; over
MQTT, by contrast, it works even when sender and clock cannot reach each other
directly.

### 5.7 `GET /api/customList` — which displays are on the clock

✅ Names the named displays the device currently knows — the same answer as the
MQTT topic in §3.5, only on request and without a broker. Measured on
2026-09-13:

```bash
curl -s http://192.168.1.20/api/customList
{"apps":["meldung2","meldung5","meldung3"],"count":3}
```

> ⚠️ **The path is `/api/customList`.** `GET /customList` — without `/api` —
> returns nothing.

The spelling differs from §3.5: here they are plain strings, there objects with
`appName`. The same list is meant.

These are **names only**. What is on a display the device does not reveal this
way either — occupied or free is therefore certain, the content is not.

### 5.8 `POST /api/switchDiyApp?name=<name>` — switching without a broker

✅ The call is accepted, answers — and the clock really does jump to the named
display. Measured on 2026-09-13:

```bash
curl -s -X POST 'http://192.168.1.20/api/switchDiyApp?name=meldung2'
{"code":200,"message":"app switch requested","data":{"name":"meldung2","index":100}}
```

This is the counterpart to the MQTT topic in §3.3 — and more forthcoming: there
is no answer at all there, here there is one with a name and a number.

✅ **The effect has been seen, not merely reported.** "app switch **requested**"
is the wording of the answer, not a reservation. Measured on 2026-09-13 with the
page change switched off (`carouselSpeed` `0`, §5.4), so that the device does not
move on by itself — the display was watched at every step:

```bash
curl -s -X POST 'http://192.168.1.20/api/custom?name=probe' \
  -H 'Content-Type: application/json' -d '{"draw":[{"df":[0,0,52,16,"#FF0000"]}]}'
# {"code":200,"message":"ok"}
curl -s http://192.168.1.20/api/customList
# {"apps":["probe"],"count":1}            → the clock shows the red area at once

curl -s -X POST 'http://192.168.1.20/api/custom?name=probe2' \
  -H 'Content-Type: application/json' -d '{"draw":[{"df":[0,0,52,16,"#00FF00"]}]}'
# {"code":200,"message":"ok"}
curl -s http://192.168.1.20/api/customList
# {"apps":["probe","probe2"],"count":2}   → the clock stays on red

curl -s -X POST 'http://192.168.1.20/api/switchDiyApp?name=probe2'
# {"code":200,"message":"app switch requested","data":{"name":"probe2","index":111}}
#                                         → the clock turns green
```

> ✅ **A newly created display appears immediately**, without switching.
>
> ✅ **A second one does not take over.** The first stays; whoever wants to see
> the second one switches. For showing things one after another over HTTP that
> means: send `switchDiyApp`, or always write to the same display (§5.6).

❓ Both were measured with the page change switched **off**. How it behaves when
the clock pages through the displays by itself is unproven.

> ✅ **A display that does not exist is rejected:**
> `{"code":404,"message":"custom app not found"}`. The endpoint checks the name
> and reports a real error.

> ❓ **`index` is uninterpreted.** Observed values are `100` and `111` — so the
> number is not fixed. What it means we do not know; it is written down here,
> not explained.

---

## 6. When nothing appears

In order, from the most common to the rarest:

1. **Prefix.** Query `/getMqttConfig` and `/getBase` and assemble it (§2).
   Almost always this is the cause.
2. **Is the device connected to the broker at all?** `/getMqttStatus` (§5.3).
3. **Is the account allowed to write to the topic?** The permissions are in the
   broker's permissions file; with Mosquitto the log reports a rejected publish —
   the sender itself learns nothing about it (§2).
4. **Is an old display still standing?** `GET /api/customList` (§5.7) says which
   ones exist; get rid of them with the empty MQTT payload (§3.2) or over HTTP
   with the body `{}` (§5.6).
5. **Not paging?** `carouselSpeed` is `0` (§5.4).
6. **Characters missing from the text?** Umlauts and most punctuation marks do
   not exist in the device font — send them as pixels (§1, §4.1).

---

## 7. What is still missing here

Named honestly instead of kept quiet:

- ❓ How `duration` and `carouselSpeed` interact (§4.4).
- ❓ How the **MQTT** topic `switchDiyApp` behaves for a display that does not
  exist (§3.3) — over HTTP it is proven: `404 custom app not found` (§5.8).
- ❓ What `index` in the answer of `POST /api/switchDiyApp` means. Observed
  values are `100` and `111` (§5.8).
- ❓ Whether a newly created display also appears immediately, and a second one
  still does not take over, when the page change is switched **on** (§5.8).
- ❓ Whether the device font has uppercase letters (§1).
- ❓ Whether `status` and `customList` are published retained (§3.5).
- ❓ How **large** a payload may be. What is proven is that around **14 KB** get
  through (318 frames, sent on 2026-09-11 and displayed cleanly); where the limit
  lies above that, nobody has explored. If you go looking for it, you should have
  read §4.2a first — what looked like a size limit was in truth the disposal
  method there.
- ❓ Whether there are **further** topics below the prefix. The device subscribes
  to `<prefix>/#`, that is, to everything. Three have been found (§3.1 to §3.5),
  all three only by looking; which others it evaluates is not documented.
- ❓ Whether and how alarm, volume and brightness can be set over MQTT instead of
  via `/setConfig`.
