# Ulanzi TC002 — firmware observations

*[Deutsche Fassung](../firmware-beobachtungen.md)*

Collected while building MQTT-TC002. Two purposes: a checklist to re-test **when
a new firmware is released**, and a basis for reporting these to the vendor.

**Tested against:** `mcuVer V1.0.17`, `appVer 1.1.1`, read via `GET /getBase`
(device reference §5.1). All measurements from 2026-09-11.

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
| 2 | empty HTTP body does not delete | `POST /api/custom?name=x` with an empty body | ❌ |
| 3 | GIF disposal method 1 not honored | send an opaque scrolling GIF | ❌ |
| 4 | a wildcard in the prefix bricks the connection | set `#` as the prefix | ❌ |
| 5 | no HTTP route for switching displays | look for an HTTP equivalent of `switchDiyApp` | ❌ |
| 6 | `customList` over MQTT only | `GET /customList` | ❌ |
| 7 | built-in font has no umlauts | send `"content":"Grüße"` | ❌ |
| 8 | clock drops off the network until power-cycled | `curl http://<address>/getBase` | ❌ |

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

## 2. An empty HTTP body reports success and does nothing

**Device reference §5.6.** `POST /api/custom?name=x` with an empty body answers
`{"code":200,"message":"ok"}`, but the display stays on the clock. Over MQTT the
same empty payload deletes reliably (§3.2).

**Why it matters.** A success response for something that does not happen is
worse than an error. It is also the reason HTTP alone is not usable as an
operating mode: without a broker, no display can ever be removed.

**Check.** Create a display, send an empty body after it, look at the device.

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

## 5. The effective prefix is shown nowhere

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

## 6. Two things are missing over HTTP entirely

**Device reference §3.3 and §3.5.**

- Switching to a display is only possible via the MQTT topic `switchDiyApp`.
  There is no HTTP equivalent.
- `customList` is an MQTT topic; `GET /customList` returns nothing.

**Why it matters.** Together with point 2, this rules out HTTP-only operation.
Anyone who does not want to run a broker, and people do ask for this, can send
but can neither delete, nor switch, nor find out what is on the clock.

Worth noting: the clock reports displays over `customList` **even when they were
created over HTTP** (§3.5). So the state is there, it is just not served over
HTTP.

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

## Not verified yet

These are not defects but gaps in our knowledge. A new firmware would be a good
occasion to settle them. The checks are described in device reference §7.

- Whether the built-in font knows uppercase letters (§1).
- Whether `status` and `customList` are published as retained (§3.5). This
  decides whether a fresh subscription gets a state immediately.
- Whether `switchDiyApp` has any effect on a display that does not exist (§3.3).
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
