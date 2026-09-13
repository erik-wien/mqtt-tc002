# Ulanzi TC002 — firmware observations

*[Deutsche Fassung](../firmware-beobachtungen.md)*

Collected while building MQTT-TC002. Two purposes: a checklist to re-test **when
a new firmware is released**, and a basis for reporting these to the vendor.

**Tested against:** `mcuVer V1.0.17`, `appVer 1.1.1`, read via `GET /getBase`
(device reference §5.1). Measurements from 2026-09-11 to 2026-09-13.

The evidence for each point is in [`tc002-protocol.md`](tc002-protocol.md). This
file only says what is wrong with it and how to check in two minutes whether it
still is.

---

## Re-test on the next firmware update

Work through them in order and record the result here together with the new
version number. A line that turns green means the matching section of the device
reference needs changing, and possibly something in the app.

| # | Defect | Check | As of 1.0.17 |
|---|---|---|---|
| 1 | `text` does not scroll | send a long text as `text` | ❌ |
| 2 | an empty HTTP body reports success without deleting | `POST /api/custom?name=x` with an empty body, then `GET /api/customList` | ❌ |
| 3 | GIF disposal method 1 not honored | send an opaque scrolling GIF | ❌ |
| 4 | a wildcard in the prefix bricks the connection | set `#` as the prefix | ❌ |
| 5 | no HTTP route for switching displays — **not a defect**, our wrong path | `POST /api/switchDiyApp?name=x` | ✅ works |
| 6 | display list over MQTT only — **not a defect**, our wrong path | `GET /api/customList` | ✅ works |
| 7 | built-in font has no umlauts | send `"content":"Grüße"` | ❌ |
| 8 | clock drops off the network until power-cycled | `curl http://<address>/getBase` | ❌ |
| 9 | the effective prefix is shown nowhere | look for it in the device's own interface | ❌ |

The numbers are identifiers: they stay put even when a point is no longer a
defect — other documents refer to them.

**HTTP-only operation is possible.** Creating and deleting (device reference
§5.6), switching (§5.8) and the display list (§5.7) all work without a broker —
all four measured on the device and watched on the display. Switching really is
needed: the first display appears immediately, a second one does not take over
by itself (§5.8). What only MQTT delivers: the **content** of a display,
listened in on `custom` (§3.1), and the report of whether the clock is online
(§3.4).

---

## 1. `text` does not scroll, although it should

**Device reference §4.3.** Text wider than the 52 pixels is cut off instead of
scrolling, even with `scrollSpeed` above zero. Checked in three variants: with
`rect` and every field, without `rect`, and with nothing but `content` and
`color`. None of them scrolled.

**Why it matters.** `scrollSpeed` is a device setting that exists (§5.4). That it
has no effect on custom displays sent via `custom` looks like a forgotten case,
not a decision. If it were fixed, long text would no longer need a hand-built
scrolling GIF, and with it several kilobytes of payload for one sentence.

**Check.** Send a sixty-character text as `text` and look at the device.

---

## 2. An empty HTTP body reports success without deleting

**Device reference §5.6.** `POST /api/custom?name=x` deletes the display if the
body is `{}`. An **empty** body answers the same `{"code":200,"message":"ok"}`
but leaves the display standing.

**Why it matters.** A success response for something that does not happen is
worse than an error. And the empty body is exactly the obvious attempt, because
over MQTT it is the **empty** payload that deletes (§3.2) — same intent, two
routes, opposite means.

**Check.** Create a display, send `POST /api/custom?name=x` with an empty body
after it, then query `GET /api/customList` (§5.7): if the display is still in the
list, the defect stands. The check changes a real display and therefore belongs
on the device, not in a test.

---

## 3. Only one of the GIF disposal methods is honored

**Device reference §4.2a.** Every frame of an animated GIF carries an
instruction about what should happen to the screen before the next frame.
Method 2 means "clear first", method 1 means "leave it standing and draw only
the changed region on top". The clock does not honor method 1: the shapes are
right, but individual pixels are missing from them.

**Why it matters.** Method 1 is the more common one and the default in most
image tools. Anyone taking a GIF from elsewhere is likely to get a holey image,
with no hint as to why. This one point cost us a whole evening, and the false
trail ran through seven disproved hypotheses.

**Check.** Build the same scrolling GIF twice, once with unlit pixels opaque and
once with them transparent, and send both. The method can be read in the third
byte of each graphics control extension (`0x21 0xF9`), bits 2 to 4.

---

## 4. A wildcard in the prefix makes the device unreachable

**Device reference §2.** If the configured prefix contains `#` or `+`, the
firmware builds an invalid CONNECT packet. The broker logs
`bad socket read/write: Invalid input` and refuses the connection.

**Why it matters.** The device is then attached to no broker at all, and the user
interface does not say why. Validating the input in the settings dialog would be
one line of work.

**Check.** Set `#` as the prefix and look at the broker log. Then set it back.

---

## 5. No HTTP route for switching — not a defect, our wrong path

**Device reference §5.8.** `POST /api/switchDiyApp?name=<name>` does exist, and
it works. Measured on 2026-09-13 with the page change switched off ("no change"
on the device), and watched on the display:

```json
{"code":200,"message":"app switch requested","data":{"name":"probe2","index":111}}
```

The clock jumped to `probe2`. "requested" is the wording of the answer, not a
reservation. A name that does not exist is rejected by the endpoint with
`{"code":404,"message":"custom app not found"}`.

The endpoint was there; it had been looked for in the wrong place. None of this
is a firmware defect, and there is nothing here to re-test on the next update.

> ❓ **What `index` means remains unproven.** Observed values are `100` and
> `111` — so the number is not fixed. It is listed under "Not verified yet".

---

## 6. Display list over MQTT only — not a defect, our wrong path

**Device reference §5.7.** `GET /api/customList` names the device's named
displays, measured on 2026-09-13. The path is `/api/customList`;
`GET /customList` — without `/api` — returns nothing. That is the whole
difference.

The list also reports displays that were **created over HTTP** (§3.5) — it is
the state of the device, not the bookkeeping of one sender. But they are names
only: what is on a display the device does not hand out by any route.

---

## 7. The built-in font has no umlauts

**Device reference §1.** Lowercase letters and digits work; of the punctuation
only `%`, `.`, `-` and `:`. Everything else is missing without substitution. The
device shows nothing at that position and reports nothing either.

**Why it matters.** For a device sold in Europe this is a noticeable gap. Our app
works around it by rasterizing text itself and sending it as pixels. That costs
payload and rules out the device's own text features.

**Check.** Send `"content":"Grüße"`.

---

## 8. The clock drops off the network and only power cycling brings it back

**Observed on 2026-09-12.** The clock stopped answering any HTTP request — not
from the app, not from Safari on another device. It became reachable again
only after being unplugged and restarted. The broker was perfectly reachable
at the same time, so it was not the network.

**Why it matters, and why it is so hard to see.** In this state the broker
still accepts publishes and reports success — the clock no longer subscribes
to anything, and a publish to a topic with no subscriber stays silent in MQTT
3.1.1 (§3). A sending app therefore sees **no difference between "delivered"
and "went nowhere"**. We spent an hour looking at the network: local network
permission, WLAN client isolation, separate subnets, a VPN. None of them was
it.

**Check.** `curl -s --max-time 3 http://<address>/getBase`. If nothing comes
back while the broker answers, this is the case. HTTP is the reliable test
here because it addresses the clock directly instead of going through the
broker.

**Still open.** Whether the clock falls off the WLAN entirely or only its HTTP
service hangs is unresolved, as is whether it is still connected to the broker
in that state. Next time, first check whether the router still lists it as
connected and whether `customList` still reports anything.

---

## 9. The effective prefix is shown nowhere

**Device reference §2.** The firmware appends the last four digits of the MAC
address to the configured prefix. `awtrix` becomes `awtrix_a86b`. This full
prefix never appears in the user interface. It can only be determined over HTTP,
or from which topics the device subscribes to at the broker.

**Why it matters.** It is by far the most common source of setup failures, and
with MQTT 3.1.1 it does not announce itself: publishing to a topic nobody
subscribes to stays silent. This is exactly why our app determines the prefix
itself instead of letting the user type it.

**Check.** Look for the full topic anywhere in the device's own interface.

---

## Not verified yet

These are not defects but gaps in our knowledge. A new firmware would be a good
occasion to settle them. The checks are described in device reference §7.

- Whether the built-in font knows uppercase letters (§1).
- Whether `status` and `customList` are published as retained (§3.5). This
  decides whether a fresh subscription gets a state immediately.
- How the **MQTT** topic `switchDiyApp` behaves for a display that does not
  exist (§3.3) — over HTTP it is proven: `404 custom app not found`.
- What `index` in the answer of `POST /api/switchDiyApp` means; observed values
  are `100` and `111` (§5.8).
- Whether a newly created display also appears immediately, and a second one
  still does not take over, when the page change is switched on (§5.8).
- How `duration` and the device-wide page change interact (§4.4).
- How large a payload may be. About 14 KB is demonstrated (§4.2a).
- Whether a partial `POST /setConfig` loses the remaining fields (§5.5).
- Whether there are further topics below the prefix. The device subscribes to
  `<prefix>/#`, so everything (§7).
- Whether alarm, volume and brightness can also be set over MQTT (§7).

---

## Where a new firmware would appear

The vendor repository
[UlanziTechnology/Ulanzi-U-Clock-TC002](https://github.com/UlanziTechnology/Ulanzi-U-Clock-TC002)
and Ulanzi Studio. The running version is not shown in our app, but
`curl -s http://<address>/getBase` names it.
