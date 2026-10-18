# Pixel Clock Messenger — Texte für TestFlight und App Store

Stand 18. Oktober 2026. Zum Hineinkopieren in App Store Connect (App „Pixel Clock Messenger“, iOS; Repo `mqtt-tc002`).
Store-Sprachen: Deutsch und English (U.K.). Zeichengrenzen von Apple in Klammern; alle Texte unten halten sie ein.
Screenshots und Banner: siehe `README.md` in diesem Ordner.

---

## 1. TestFlight › Testinformationen (für externe Tests nötig)

### Beta-App-Beschreibung (4000)

**Deutsch**

> Pixel Clock Messenger schickt Text, Icons und Bilder an deine Ulanzi-Pixeluhr (TC002 oder TC001 mit der freien Firmware AWTRIX NG) — direkt über HTTP im Heimnetz oder über deinen MQTT-Broker. Die Vorschau zeigt vorher Pixel für Pixel, was auf der Uhr stehen wird; zu langer Text läuft von selbst durch. Dazu Hintergründe, Effekte und Overlays, Nachrichten mit Klang und ein Bereich „Uhr“ mit Fernbedienung und Live-Bild. Ohne Uhr lässt sich alles mit der eingebauten virtuellen Uhr ausprobieren. Auf dem iPad malt ein Editor Icons und Animationen pixelgenau, zwölf Kurzbefehle schicken Anzeigen und Nachrichten und steuern die Uhr aus Siri und aus Automationen. Icons, Bilder und Einstellungen gleichen sich über iCloud ab. Kein Konto, kein Server dazwischen.

**English**

> Pixel Clock Messenger sends text, icons and images to your Ulanzi pixel clock (TC002 or TC001 running the free AWTRIX NG firmware) — directly over HTTP on your home network or via your MQTT broker. The preview shows pixel by pixel what will appear on the clock; text that is too long scrolls on its own. Plus backgrounds, effects and overlays, messages with sound, and a “Clock” area with a remote control and a live picture of the clock. Without a clock you can try everything with the built-in virtual clock. On iPad an editor draws icons and animations pixel-perfect, and twelve shortcuts send displays and messages and control the clock from Siri and from automations. Icons, images and settings sync via iCloud. No account, no server in between.

### Was zu testen ist (4000, je Build)

**Deutsch**

> Neu in dieser Fassung: nur noch AWTRIX NG (die Werksfirmware der Uhr wird nicht mehr bedient), dazu Darstellung (Hintergrund, Effekte, Overlay, Palette), Nachrichten mit „Steht …“ (bis zurückgezogen, Sekunden oder Durchläufe) und Klang, der Bereich „Uhr“ (Fernbedienung und Vorgaben der Uhr in Gruppen), der Bereich „Klänge“ und die Kommandozeile am Mac.
>
> Bitte ausprobieren (ohne Uhr, mit der virtuellen Uhr):
> 1. Einstellungen (Zahnrad oben rechts) › Allgemein › „Virtuelle Uhr“ einschalten, dann „Als Uhr eintragen“ tippen und mit „Fertig“ schließen.
> 2. Senden: Text eintippen (z. B. „HALLO“), den Pfeil im Feld tippen. Die Vorschau darüber zeigt, was auf der Uhr stehen wird; langer Text läuft durch.
> 3. Einstellungen › Allgemein › „Ansehen“: die virtuelle Uhr zeigt die Anzeige mit Geräterahmen und Platz.
> 4. Darstellung: in der Formatpille den Pinsel tippen (Blatt „Darstellung“): einen Effekt oder ein Overlay wählen und senden.
> 5. Nachricht: über dem Textfeld von „Anzeige“ auf „Nachricht“ umschalten, senden; sie bleibt stehen („Steht …“ steht auf „bis ich sie zurückziehe“), bis „Nachricht zurückziehen“ (durchgestrichene Glocke neben dem Segment) getippt wird. Unter dem Regler-Symbol neben dem Segment „Steht …“ auf „Sekunden“ oder „Durchläufe“ stellen; beim Notensymbol einen Klang wählen, einmal oder „In Schleife“ (die virtuelle Uhr meldet, was sie kann).
> 6. Uhr: oben auf den Namen der Uhr tippen › „Uhr …“: Live-Bild, Display aus und an, Helligkeit, Overlay jetzt auf der Uhr, Moodlight, Abschnitt „Ton“, Abschnitt „Gerät“ und „Vorgaben der Uhr“ (Anzeigedauer, Schleife …). Im selben Menü: „Klänge …“ für die Klangsammlung und „Hilfe“.
> 7. Icons: den Smiley-Knopf neben dem Textfeld tippen, ein Icon wählen oder unter „Hinzufügen“ eine LaMetric-Nummer eingeben (z. B. 2056) und „Nachladen“ tippen; danach senden.
> 8. Kurzbefehle-App: „Anzeige an die Uhr schicken“ suchen, Text eintragen, ausführen — auch per Siri („Schicke eine Anzeige mit Pixel Clock Messenger“). Danach „Anzeige von der Uhr löschen“ mit Platz 1.
> 9. iPad (falls vorhanden): Bereich „Icons“ › „Neu zeichnen“: ein Icon malen, mehrere Einzelbilder als Animation, Rückgängig; speichern und senden. Mit iCloud erscheint es auf dem iPhone.
> 10. Mit echter Uhr (AWTRIX NG): Einstellungen › Uhren: Adresse der Uhr eintragen (optional MQTT-Broker unter „MQTT-Broker“), „Abfragen“, senden. Name, Adresse, Betriebsart und Modell stehen dort; alles Übrige an der Uhr im Bereich „Uhr“.
> Rückmeldungen gern per Screenshot in TestFlight.

**English**

> New in this version: AWTRIX NG only (the clock's factory firmware is no longer served), plus appearance (background, effects, overlay, palette), messages with “Stays …” (until withdrawn, seconds or passes) and sound, a “Clock” area (remote control and clock defaults in groups), a “Sounds” area, and the command line on Mac.
>
> Please try (without a clock, using the virtual clock):
> 1. Settings (gear at the top right) › General › switch on “Virtual clock”, tap “Add as a clock” and close with “Done”.
> 2. Send: type a text (e.g. “HELLO”) and tap the arrow in the field. The preview above shows what will appear on the clock; long text scrolls.
> 3. Settings › General › “Show”: the virtual clock shows the display with device frame and slot.
> 4. Appearance: tap the brush in the format pill (sheet “Appearance”): pick an effect or an overlay and send.
> 5. Message: switch from “Display” to “Message” above the text field and send; it stays (“Stays …” is set to “until I withdraw it”) until you tap “Dismiss message” (crossed-out bell next to the control). Under the sliders symbol next to the control set “Stays …” to “Seconds” or “Passes”; under the note symbol choose a sound, once or “Loop” (the virtual clock reports what it can do).
> 6. Clock: tap the clock's name at the top › “Clock …”: live picture, display off and on, brightness, overlay on the clock now, moodlight, the “Sound” section, the “Device” section and “Clock defaults” (display time, loop …). The same menu has “Sounds …” for the sound collection and “Help”.
> 7. Icons: tap the smiley button next to the text field, pick an icon, or under “Add” enter a LaMetric number (e.g. 2056) and tap “Fetch”; then send.
> 8. Shortcuts app: search for “Show on clock”, enter a text, run it — also by Siri (“Show on the clock with Pixel Clock Messenger”). Then “Remove from clock” with slot 1.
> 9. iPad (if available): area “Icons” › “Draw new”: draw an icon, several frames as an animation, Undo; save and send. With iCloud it appears on iPhone.
> 10. With a real clock (AWTRIX NG): Settings › Clocks: enter the clock's address (optionally an MQTT broker under “MQTT-Broker”), “Query”, send. Name, address, mode and model live there; everything else on the clock is in the “Clock” area.
> Feedback welcome as screenshots in TestFlight.

### Feedback-E-Mail
support@eriks.cloud

### Hinweise für die Prüfer (Review Notes, 4000) — nur Englisch nötig

> No account, no sign-in. The app needs a hardware device to be useful: an Ulanzi TC001/TC002 pixel clock running the free AWTRIX NG firmware, optionally an MQTT broker. Because a reviewer will not have one, the app contains a virtual clock that behaves like a real device (same HTTP interface as AWTRIX NG). To review without hardware (iPhone):
> 1. Tap the gear icon (Settings) at the top right, then “General”, and switch on “Virtual clock”. The app shows the address 127.0.0.1:8752 and two buttons.
> 2. Tap “Add as a clock” (enters the virtual clock as a clock; the app queries it once). Tap “Show” to open the virtual clock's window, check it, close it again. Close Settings with “Done”.
> 3. On the “Send” screen type any text into the field at the bottom (e.g. “HELLO”) and tap the send arrow in the field. The preview above shows what will appear on the clock; optionally pick an icon first with the smiley button. Open Settings › General › “Show” again: the virtual clock shows the display with device frame and slots and scrolls text that does not fit.
> 4. Switch the control above the field from “Display” to “Message” and send again. A message interrupts the loop once and uses no slot; “Stays …” (sliders symbol next to the control) sets how long it stays: until withdrawn (default), seconds or passes. “Dismiss message” (crossed-out bell) withdraws the visible message. The note symbol (sound, once or loop) appears only if the clock reports sound capability.
> 5. Tap the clock's name at the top and choose “Clock …”: live picture, display on/off, brightness, overlay, moodlight, indicators, “Sound”, “Device”, and “Clock defaults” (the settings stored on the clock, in groups). “Sounds …” in the same menu opens the sound collection.
> 6. In the format pill tap the brush (sheet “Appearance”) to choose background, effect, overlay and palette (names come from the clock).
> Shortcuts: the Shortcuts app offers twelve actions without setup, nine also by Siri phrase: “Show on clock”, “Send image”, “Remove from clock”, “Send message”, “Dismiss message”, and for remote control “Switch the clock's display”, “Set the clock's brightness”, “Set the clock's overlay”, “Set the clock's moodlight”, “Set one of the clock's indicators”, “Change the clock's display” and “Restart clock”. They use the app's clock list and work with the virtual clock.
> On iPad the app also has a pixel editor (area “Icons” › “Draw new”); on iPhone icons are chosen, not drawn.
> VIDEO: <Link folgt>
> Network access: only (a) the user's own clock via HTTP on the local network, (b) the user's own MQTT broker, if configured, and (c) developer.lametric.com, only when the user types a LaMetric icon number and taps “Fetch”; only that number is sent. Radio and speech are played by the clock itself. Nothing is sent to the developer; no analytics, no advertising, no account. The broker password is kept in the iOS keychain.
> Local network: iOS asks for “Local Network” access when the app first contacts a clock or broker (purpose string: “The app talks to the pixel clock and the MQTT broker on your home network.”). Without it nothing reaches a real clock; the virtual clock needs no device on the network.
> iCloud: icons, images and settings sync through the user's own iCloud container, if available.
> Third-party content: about 30 small 8×8 icons from the public LaMetric icon gallery (used in the AWTRIX community by their numbers) and three pixel fonts (Micro 5, Silkscreen, Tiny5) under the SIL Open Font License 1.1. Further LaMetric icons are fetched only on the user's request. The app is open source under GPL-3.0 with an additional permission for app-store distribution (LIZENZ-AUSNAHME.md, bundled). Ulanzi, TC001, TC002 and LaMetric are trademarks or products of their owners; the app is independent and not affiliated with them.

**Anmeldung erforderlich:** nein (Häkchen „Sign-in required“ entfernen).

### Begleitvideo

Drehbuch und Anforderungen: [demovideo.md](demovideo.md). Den Link zum Video oben bei `VIDEO: <Link folgt>` eintragen.

### Kontakt für die Prüfer
Vorname, Nachname, Telefon, E-Mail — deine Daten.

---

## 2. App Store (erst für eine Veröffentlichung; für TestFlight nicht nötig)

| Feld | Deutsch | English (U.K.) |
|---|---|---|
| Name (30) | Pixel Clock Messenger | Pixel Clock Messenger |
| Untertitel (30) | Nachrichten auf die Pixeluhr | Messages to your pixel clock |
| Kategorie | Dienstprogramme (Zweitkategorie: Lifestyle) | Utilities (secondary: Lifestyle) |
| Copyright | © 2026 Erik R. Huemer | © 2026 Erik R. Huemer |
| Altersfreigabe | 4+ | 4+ |

Kategorie: Die App ist ein Werkzeug, das ein Gerät im Haus bedient; „Dienstprogramme“ passt am besten, „Lifestyle“ als zweite, weil die Uhr Wohnraum-Dekoration und Alltag ist (Vorschlag, frei änderbar).

### Neuigkeiten in dieser Version (4000) — Fassung 2.0

**DE:**

Pixel Clock Messenger spricht jetzt AWTRIX NG — auf der Ulanzi TC002 (52 × 16) und der TC001 (32 × 8).

- Darstellung: Hintergrundfarbe, bewegte Effekte, Wetter-Overlays und Farbpaletten. Mit „Schrift der Uhr“ setzt die Uhr den Text selbst.
- Nachrichten mit Klang: eine Melodie oder MP3 von der Uhr, oder die Uhr liest vor (Englisch). Wie lange eine Nachricht steht, wählst du: bis du sie zurückziehst, Sekunden oder Durchläufe.
- Bereich „Uhr“: Live-Bild der Uhr, Display, Helligkeit, Moodlight, Anzeiger, Ton und Radio, Neustart — alles, was auf der Uhr eingestellt wird, an einer Stelle.
- Klänge verwalten: MP3 auf die Uhr laden — die App schlägt einen gültigen Namen vor.
- Vorgaben der Uhr in übersichtlichen Gruppen, dazu das Zertifikat für MQTT über TLS.
- Mehrere Geräte lesen gleichzeitig mit, ohne sich gegenseitig vom Broker zu werfen.

Wichtig: Die Werksfirmware der TC002 wird nicht mehr unterstützt. Bitte die Uhr vorher auf AWTRIX NG umstellen.

**EN:**

Pixel Clock Messenger now speaks AWTRIX NG — on the Ulanzi TC002 (52 × 16) and the TC001 (32 × 8).

- Appearance: background colour, animated effects, weather overlays and colour palettes. With “Clock font” the clock sets the text itself.
- Messages with sound: a melody or MP3 from the clock, or the clock reads the text aloud (English). You choose how long a message stays: until you withdraw it, seconds or passes.
- “Clock” area: live image of the clock, display, brightness, mood light, indicators, sound and radio, restart — everything that is set on the clock in one place.
- Manage sounds: upload MP3s to the clock — the app suggests a valid name.
- Clock defaults in clear groups, plus the certificate for MQTT over TLS.
- Several devices can listen at the same time without pushing each other off the broker.

Important: the TC002 factory firmware is no longer supported. Please switch the clock to AWTRIX NG first.

### Werbetext (170)

- **DE:** Text, Icons und Bilder an deine Ulanzi-Pixeluhr, dazu Fernbedienung, Klang und Kurzbefehle — mit Vorschau und virtueller Uhr zum Ausprobieren. Kein Konto, kein Server.
- **EN:** Text, icons and images for your Ulanzi pixel clock, plus remote control, sound and shortcuts — with preview and a virtual clock to try it out. No account, no server.

### Beschreibung (4000)

Grundlage ist Eriks Entwurf. Änderungen in dieser Fassung (Oktober 2026): nur noch AWTRIX NG (Werksfirmware gestrichen, TC001 genannt); Anzeigemaß „52×16“ statt „16×52“; neue Abschnitte „Nachrichten und Klang“, „Die Uhr fernsteuern“; Darstellung bei „Was du schicken kannst“; zwölf statt drei Kurzbefehle; Repo-Link in der letzten Zeile; DE „Slot“ → „Platz“; Wortlaut „Anzeige“ und „Nachricht“ statt „Meldung“, Bereich „Uhr“ als eine Tür zur Uhr.

**Deutsch**

> Deine Pixeluhr kann mehr als die Uhrzeit.
>
> Die Ulanzi TC002 und TC001 hängen an der Wand und zeigen die Uhrzeit. Mit der freien Firmware AWTRIX NG können sie mehr — nur fehlte bisher die Software dafür. Pixel Clock Messenger ist sie.
>
> Tipp einen Text, wähl ein Icon, drück Senden. Die Vorschau zeigt vorher Pixel für Pixel, was auf der Uhr stehen wird. Passt der Text nicht aufs Display, läuft er von selbst durch.
>
> WAS DU SCHICKEN KANNST
>
> • Text in drei mitgelieferten Pixelschriften, dazu die monospacen Schriften des Systems
> • Farbe, Ausrichtung, Rand, Zeichenabstand und Lauftempo
> • Hintergrund, Effekte, Overlays wie Regen oder Schnee und Farbpaletten
> • Icons in 8×8 und 16×16
> • Ganze Bilder über die volle Breite, 52×16 (TC001: 32×8)
>
> NACHRICHTEN UND KLANG
>
> Eine Anzeige läuft in der Schleife der Uhr, wie lange du willst — oder sie verfällt nach einer Lebensdauer von selbst. Eine Nachricht dagegen unterbricht die Schleife einmal und weckt das Display. Unter „Steht …“ wählst du, wie lange sie steht: bis du sie zurückziehst, Sekunden oder Durchläufe. Dazu kann sie einen Klang mitbringen, einmal oder in Schleife: eine Melodie oder MP3-Datei von der Uhr, oder einen Text, den die Uhr vorliest.
>
> DIE UHR FERNSTEUERN
>
> Der Bereich „Uhr“ ist die eine Tür zur Uhr: ein Live-Bild des Displays, der Zustand der Uhr, Display, Helligkeit, Moodlight, Overlay und die Anzeiger am Rand. Er spielt und stoppt Klang, regelt die Lautstärke und wählt Radiosender aus der Liste der Uhr. Die Vorgaben der Uhr — Helligkeit, Laufschrift, Schleife mit Anzeigedauer, Zeit und Datum, Klang — stehen im selben Bereich in Gruppen bereit, samt dem Zertifikat für verschlüsseltes MQTT.
>
> OHNE UHR AUSPROBIEREN
>
> Noch kein Gerät im Haus? Schalte unter Einstellungen › Allgemein die virtuelle Uhr ein. Sie nimmt Anzeigen entgegen wie ein echtes Gerät und zeigt sie in einem eigenen Fenster mit Geräterahmen und fünf Plätzen.
>
> WAS DU SELBST MACHEN KANNST
>
> Auf dem iPad malt der eingebaute Editor Icons und Bilder pixelgenau: Mehrere Einzelbilder ergeben eine Animation, Rückgängig gilt für jeden Schritt. Was du machst, landet in deiner Sammlung. Am iPhone wird geschickt, nicht gemalt — ein Raster unter dem Finger ist keine Arbeitsfläche.
>
> WOHER DIE ICONS KOMMEN
>
> Hol dir fertige Icons aus der LaMetric-Galerie — Nummer eintippen, fertig. Oder nimm deine eigenen GIFs aus „Dateien".
>
> AUF ALLEN DEINEN GERÄTEN
>
> Icons, Bilder und Einstellungen gleichen sich über iCloud ab. Was du am iPad malst, liegt auf dem iPhone bereit.
>
> FÜNF PLÄTZE, UND DU BEHÄLTST DEN ÜBERBLICK
>
> Die Uhr hält fünf Anzeigen gleichzeitig. Pixel Clock Messenger zeigt, was auf jedem Platz steht — und holt die Einstellungen zurück, wenn du eine davon noch einmal bearbeiten willst.
>
> MEHRERE UHREN
>
> Über HTTP direkt oder über deinen MQTT-Broker, je Uhr wählbar. Die App spricht AWTRIX NG; die Werksfirmware der Uhr wird nicht unterstützt.
>
> KURZBEFEHLE UND AUTOMATIONEN
>
> Zwölf Kurzbefehle stehen ohne Einrichtung bereit, neun davon auch in Siri:
>
> • Anzeige schicken
> • Bild schicken
> • Anzeige löschen
> • Nachricht senden
> • Nachricht zurückziehen
> • und sieben zur Fernbedienung: Display, Helligkeit, Moodlight, Overlay, Anzeiger, Anzeige wechseln, Neustart
>
> Verlangt wird nur das Wesentliche — ein Text, ein Bildname, ein Platz. Alles Weitere ist wahlfrei: Uhr, Icon, Dauer, Klang und das ganze Format. Was fehlt, kommt aus dem, was zuletzt in der App eingestellt war.
>
> Damit lässt sich die Uhr in Automationen einbauen: eine Nachricht beim Ankommen zu Hause, ein Bild zur vollen Stunde, ein leerer Platz, wenn der Kalender nichts mehr hergibt. Die App muss dafür nicht geöffnet werden, und wo eine Angabe fehlt oder nicht passt, fragt der Kurzbefehl an genau dem Feld nach, statt wortlos abzubrechen.
>
> KEIN KONTO, KEIN DIENST
>
> Pixel Clock Messenger redet mit deiner Uhr und mit deinem Broker, sonst mit niemandem. Kein Konto, keine Anmeldung, kein Server dazwischen.
>
> Quelloffen unter der GPL-3.0: https://github.com/erik-wien/mqtt-tc002

**English**

> Your pixel clock can do more than tell the time.
>
> The Ulanzi TC002 and TC001 hang on the wall and show the time. With the free AWTRIX NG firmware they can do more — they just lacked the software. Pixel Clock Messenger is that software.
>
> Type a text, pick an icon, tap Send. The preview shows you pixel by pixel what will appear on the clock — device frame included, so you can picture it. If the text doesn't fit the display, it scrolls on its own.
>
> WHAT YOU CAN SEND
>
> • Text in three bundled pixel fonts, plus the system's monospaced fonts
> • Colour, alignment, margin, letter spacing and scroll speed
> • Backgrounds, effects, overlays such as rain or snow, and colour palettes
> • Icons in 8×8 and 16×16
> • Full-width images, 52×16 (TC001: 32×8)
>
> MESSAGES AND SOUND
>
> A display runs in the clock's loop for as long as you like — or expires by itself after a lifetime. A message, by contrast, interrupts the loop once and wakes the display. Under “Stays …” you choose how long it stays: until you withdraw it, seconds or passes. It can also bring a sound, once or in a loop: a melody or MP3 file from the clock, or a text the clock reads aloud.
>
> REMOTE CONTROL FOR THE CLOCK
>
> The “Clock” area is the one door to the clock: a live picture of the display, the state of the clock, and display, brightness, moodlight, overlay and the indicators at the edge. It plays and stops sound, sets the volume and picks radio stations from the clock's list. The clock defaults — brightness and colour, scrolling, loop with display time, time and date, sound — are in the same area in groups, including the certificate for encrypted MQTT.
>
> TRY IT WITHOUT A CLOCK
>
> No device at home yet? Turn on the virtual clock under Settings › General. It accepts displays just like a real device and shows them in a window of its own — with device frame, the five slots and paging.
>
> WHAT YOU CAN MAKE YOURSELF
>
> On iPad, the built-in editor draws icons and images pixel-perfect: several frames make an animation, and Undo works for every step. Whatever you make goes into your collection. On iPhone you send rather than draw — a grid under your finger is no canvas.
>
> WHERE THE ICONS COME FROM
>
> Get ready-made icons from the LaMetric gallery — type the number, done. Or use your own GIFs from Files.
>
> ON ALL YOUR DEVICES
>
> Icons, images and settings sync via iCloud. What you draw on iPad is waiting on iPhone.
>
> FIVE SLOTS, AND YOU KEEP TRACK
>
> The clock holds five displays at once. Pixel Clock Messenger shows what is on each slot — and brings the settings back if you want to edit one of them again.
>
> SEVERAL CLOCKS
>
> Directly over HTTP or via your MQTT broker, chosen per clock. The app speaks AWTRIX NG; the clock's factory firmware is not supported.
>
> SHORTCUTS AND AUTOMATIONS
>
> Twelve shortcuts are ready with no setup, nine of them also in Siri:
>
> • Show on clock
> • Send image
> • Remove from clock
> • Send message
> • Dismiss message
> • and seven for remote control: display, brightness, moodlight, overlay, indicators, change display, restart
>
> Each asks only for the essentials — a text, an image name, a slot. Everything else is optional: clock, icon, duration, slot, sound and the whole format, from typeface to letter spacing. Whatever you leave out comes from what was last set in the app.
>
> That lets you build the clock into automations: a message when you get home, an image on the hour, an empty slot when the calendar has nothing left. The app doesn't need to be open, and where a value is missing or doesn't fit, the shortcut asks for exactly that field instead of giving up silently.
>
> NO ACCOUNT, NO SERVICE
>
> Pixel Clock Messenger talks to your clock and your broker, and to nobody else. No account, no sign-in, no server in between.
>
> Open source under GPL-3.0: https://github.com/erik-wien/mqtt-tc002

### Schlüsselwörter (100, kommagetrennt, ohne Leerzeichen)

- **DE:** `pixeluhr,ulanzi,tc002,tc001,awtrix,mqtt,kurzbefehle,laufschrift,led,matrix,display,icon,gif,siri,uhr`
- **EN:** `ulanzi,tc002,tc001,awtrix,mqtt,shortcuts,scrolling,ticker,led,matrix,display,icon,gif,siri,wall`

### URLs

- **Support-URL (Pflicht):** https://www.eriks.cloud/apps/mqtt-tc002/support.html
- **Datenschutz-URL (Pflicht für App Store, für externe Tests ggf. verlangt):** https://www.eriks.cloud/apps/mqtt-tc002/datenschutz.html
- **Marketing-URL (optional):** https://www.eriks.cloud/apps/mqtt-tc002/

### Datenschutz (App Privacy) — Angaben in App Store Connect

Kein Textfeld, sondern Fragebogen: App Privacy › Data Types › Edit › **„No, we do not collect data“** (Anzeige „Data Not Collected“) + Privacy Policy URL. Begründung, nur falls ein Prüfer fragt (aus `DATENSCHUTZ.md`): kein Konto, kein Server des Entwicklers, keine Analyse- oder Werbedienste. Die App spricht nur mit der eigenen Uhr (HTTP im lokalen Netz) und dem eigenen MQTT-Broker; einzige Ausnahme ist das Nachladen eines LaMetric-Icons auf Nutzerwunsch, dabei geht nur die eingegebene Nummer an developer.lametric.com. Das Broker-Kennwort liegt im Schlüsselbund; Icons, Bilder und Einstellungen liegen auf dem Gerät bzw. in der eigenen iCloud des Nutzers.

- **TODO (Firmware-Update, eingang#155):** Neue Netzabhängigkeit GitHub (`api.github.com`, `github.com`, Dateihoster von GitHub): Die App lädt auf ausdrücklichen Druck das Firmware-Paket von `Blueforcer/awtrix-ng` (ohne Konto, ohne Kennung, ohne Übermittlung von Nutzerdaten außer der IP-Adresse an GitHub). Vor der nächsten Einreichung prüfen: Datenschutzseite (`…/mqtt-tc002/datenschutz.html`, Marketing) und `DATENSCHUTZ.md` um GitHub ergänzen; „Data Not Collected“ bleibt (keine Erhebung durch den Entwickler); Review Notes um einen Satz erweitern („The app can download a firmware package from github.com/Blueforcer/awtrix-ng, only on the user's explicit tap, and uploads it to the user's own clock after confirmation.“).

### Inhalte Dritter (App Information › Content Rights)

„Contains, shows, or accesses third-party content“ → **Ja**; „Has all necessary rights“ → **Ja** (Empfehlung, siehe Vorbehalt). Begründung:
- Mitgeliefert sind rund 30 kleine 8×8-Icons aus der öffentlichen LaMetric-Galerie („Grundschatz“, im AWTRIX-Umfeld per Nummer üblich) und drei Pixelschriften (Micro 5, Silkscreen, Tiny5) unter SIL OFL 1.1 (Lizenztexte im Bundle). Weitere LaMetric-Icons holt die App nur auf Nutzerwunsch per Nummer.
- Die App selbst steht unter GPL-3.0 mit zusätzlicher Erlaubnis für den App-Store-Vertrieb (`LIZENZ-AUSNAHME.md`, im Bundle).
- Vorbehalt: Eine ausdrückliche Lizenz für die LaMetric-Icons liegt im Repo nicht vor (offene Frage an Erik, siehe Bericht).
- Marken: Ulanzi und TC001/TC002 sind Marken bzw. Produkte von Ulanzi, LaMetric von seinem Inhaber; die App ist unabhängig (Formulierung wie im Fuß der Werbeseite).

Satz für die Review Notes (steht dort bereits): „Third-party content: the app ships about 30 small 8×8 icons from the public LaMetric icon gallery and three pixel fonts under the SIL Open Font License 1.1 … Ulanzi, TC001, TC002 and LaMetric are trademarks or products of their owners; the app is independent and not affiliated with them.“

### Altersfreigabe-Fragebogen

Alle Fragen **Nein / None**, „Unrestricted Web Access“: **Nein** (die iPhone-App öffnet kein Web; die einzige Netzabfrage holt ein Icon per Nummer), kein Glücksspiel, keine nutzergenerierten Inhalte, kein Chat → **4+**. LaMetric-Galerie: auf dem iPhone nicht durchsuchbar, nur die eingetippte Nummer wird geholt, das Ergebnis ist ein 8×8-Pixelbild; ob die Galerie Uploads von Nutzern enthält, ist nicht geprüft (offene Frage an Erik); bei 8×8 Pixeln ist anstößiger Inhalt praktisch ausgeschlossen. Radiosender spielt die Uhr selbst ab, die App streamt nichts und öffnet kein Web.

### Exportkonformität

`ITSAppUsesNonExemptEncryption: false` steht in `project.yml` (bestätigt), die Frage entfällt je Build. Die App verschlüsselt nichts selbst: MQTT und HTTP gehen unverschlüsselt ins Heimnetz, das Kennwort liegt im System-Schlüsselbund. Das MQTT-TLS-Zertifikat lädt die App nur auf die Uhr; die Verschlüsselung macht die Uhr.
