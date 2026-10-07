# Pixel Clock Messenger — Texte für TestFlight und App Store

Stand 07.10.2026. Zum Hineinkopieren in App Store Connect (App „Pixel Clock Messenger“, iOS; Repo `mqtt-tc002`).
Store-Sprachen: Deutsch und English (U.K.). Zeichengrenzen von Apple in Klammern; alle Texte unten halten sie ein.
Screenshots und Banner: siehe `README.md` in diesem Ordner.

---

## 1. TestFlight › Testinformationen (für externe Tests nötig)

### Beta-App-Beschreibung (4000)

**Deutsch**

> Pixel Clock Messenger schickt Text, Icons und Bilder an deine Ulanzi-Pixeluhr (TC002 oder TC001, Werksfirmware oder AWTRIX NG) — direkt über HTTP im Heimnetz oder über deinen MQTT-Broker. Die Vorschau zeigt vorher Pixel für Pixel, was auf der Uhr stehen wird; zu langer Text läuft von selbst durch. Ohne Uhr lässt sich alles mit der eingebauten virtuellen Uhr ausprobieren. Auf dem iPad malt ein Editor Icons und Animationen pixelgenau, drei Kurzbefehle schicken Meldungen aus Siri und aus Automationen. Icons, Bilder und Einstellungen gleichen sich über iCloud ab. Kein Konto, kein Server dazwischen.

**English**

> Pixel Clock Messenger sends text, icons and images to your Ulanzi pixel clock (TC002 or TC001, factory firmware or AWTRIX NG) — directly over HTTP on your home network or via your MQTT broker. The preview shows pixel by pixel what will appear on the clock; text that is too long scrolls on its own. Without a clock you can try everything with the built-in virtual clock. On iPad an editor draws icons and animations pixel-perfect, and three shortcuts send messages from Siri and from automations. Icons, images and settings sync via iCloud. No account, no server in between.

### Was zu testen ist (4000, je Build)

**Deutsch**

> Bitte ausprobieren (ohne Uhr, mit der virtuellen Uhr):
> 1. Einstellungen (Zahnrad oben rechts) › Erweitert › „Virtuelle Uhr“ einschalten, dann „Als Uhr eintragen“ tippen und mit „Fertig“ schließen.
> 2. Senden: Text eintippen (z. B. „HALLO“), den Pfeil im Feld tippen. Die Vorschau darüber zeigt, was auf der Uhr stehen wird; langer Text läuft durch.
> 3. Einstellungen › Erweitert › „Ansehen“: die virtuelle Uhr zeigt die Meldung mit Geräterahmen und Platz.
> 4. Icons: den Smiley-Knopf neben dem Textfeld tippen, ein Icon wählen oder unter „Hinzufügen“ eine LaMetric-Nummer eingeben (z. B. 2056) und „Nachladen“ tippen; danach senden.
> 5. Kurzbefehle-App: „Meldung an die Uhr schicken“ suchen, Text eintragen, ausführen — auch per Siri („Schicke eine Meldung mit Pixel Clock Messenger“). Danach „Meldung von der Uhr nehmen“ mit Platz 1.
> 6. iPad (falls vorhanden): Bereich „Icons“ › „Neu zeichnen“: ein Icon malen, mehrere Einzelbilder als Animation, Rückgängig; speichern und senden. Mit iCloud erscheint es auf dem iPhone.
> 7. Mit echter Uhr: Einstellungen › Uhren: Adresse der Uhr eintragen (optional MQTT-Broker unter „MQTT-Broker“), senden.
> Rückmeldungen gern per Screenshot in TestFlight.

**English**

> Please try (without a clock, using the virtual clock):
> 1. Settings (gear at the top right) › Advanced › switch on “Virtual clock”, tap “Add as a clock” and close with “Done”.
> 2. Send: type a text (e.g. “HELLO”) and tap the arrow in the field. The preview above shows what will appear on the clock; long text scrolls.
> 3. Settings › Advanced › “Show”: the virtual clock shows the message with device frame and slot.
> 4. Icons: tap the smiley button next to the text field, pick an icon, or under “Add” enter a LaMetric number (e.g. 2056) and tap “Fetch”; then send.
> 5. Shortcuts app: search for “Send a message to the clock”, enter a text, run it — also by Siri (“Send a message with Pixel Clock Messenger”). Then “Remove a message from the clock” with slot 1.
> 6. iPad (if available): area “Icons” › “Draw new”: draw an icon, several frames as an animation, Undo; save and send. With iCloud it appears on iPhone.
> 7. With a real clock: Settings › Clocks: enter the clock's address (optionally an MQTT broker under “MQTT-Broker”), send.
> Feedback welcome as screenshots in TestFlight.

### Feedback-E-Mail
support@eriks.cloud

### Hinweise für die Prüfer (Review Notes, 4000) — nur Englisch nötig

> No account, no sign-in. The app needs a hardware device to be useful: an Ulanzi TC001/TC002 pixel clock (factory firmware or AWTRIX NG), optionally an MQTT broker. Because a reviewer will not have one, the app contains a virtual clock that behaves like a real device. To review the app without any hardware (iPhone):
> 1. Open the app and tap the gear icon (Settings) at the top right.
> 2. Tap “Advanced” and switch on “Virtual clock”. The app shows the address 127.0.0.1:8752 and two buttons.
> 3. Tap “Add as a clock” (this enters the virtual clock as a clock; the app queries it once). Tap “Show” to open the virtual clock's window, check it, then close that window again. Close Settings with “Done”.
> 4. On the “Send” screen type any text into the field at the bottom (e.g. “HELLO”) and tap the send arrow in the field (or the Send key on the keyboard). The preview above shows what will appear on the clock; optionally pick an icon first with the smiley button.
> 5. Open Settings › Advanced › “Show” again: the virtual clock shows the message with device frame and slots, and scrolls the text if it does not fit.
> Shortcuts: the Shortcuts app and Siri offer three actions without setup: “Send a message to the clock”, “Send an image to the clock”, “Remove a message from the clock”. They use the same clock list as the app.
> On iPad the app additionally contains a pixel editor (area “Icons” › “Draw new”). On iPhone icons are chosen, not drawn.
> VIDEO: <Link folgt>
> Network access: the app talks only to (a) the user's own clock via HTTP on the local network, (b) the user's own MQTT broker, if configured, and (c) developer.lametric.com, only when the user types a LaMetric icon number and taps “Fetch” in the icon sheet; only that number is sent. Nothing is sent to the developer; there is no analytics, no advertising and no account. The broker password is kept in the iOS keychain.
> Local network: iOS asks for “Local Network” access the first time the app contacts a clock or broker (purpose string: “The app talks to the pixel clock and the MQTT broker on your home network.” in German: “Die App spricht die Pixeluhr und den MQTT-Broker in Ihrem Heimnetz an.”). Without it nothing can be sent to a real clock; the virtual clock does not need a device on the network.
> iCloud: icons, images and settings sync through the user's own iCloud container, if iCloud is available.
> Third-party content: the app ships about 30 small 8×8 icons from the public LaMetric icon gallery (used in the AWTRIX community by their numbers) and three pixel fonts (Micro 5, Silkscreen, Tiny5) under the SIL Open Font License 1.1. Further LaMetric icons are fetched only on the user's request. The app is open source under GPL-3.0 with an additional permission for app-store distribution (LIZENZ-AUSNAHME.md, bundled in the app). Ulanzi, TC001, TC002 and LaMetric are trademarks or products of their owners; the app is independent and not affiliated with them.

**Anmeldung erforderlich:** nein (Häkchen „Sign-in required“ entfernen).

### Begleitvideo (für Erik, Link in `VIDEO: <Link folgt>` oben eintragen)

Die Prüfer haben keine Uhr; ein kurzes Video zeigt, dass die App mit echter Hardware arbeitet. Es soll zeigen:
- ein echtes iPhone **und** die echte Uhr im selben Bild (Aufnahme von außen, nicht nur Bildschirmaufnahme);
- Text eintippen, Senden, Anzeige auf der Uhr;
- ein Icon wählen und mitschicken;
- eine Laufschrift (Text länger als das Display);
- einen Kurzbefehl auslösen (Kurzbefehle-App oder Siri) und die Meldung auf der Uhr;
- Länge 1–3 Minuten, ungelistet hochladen (Link ohne Anmeldung abspielbar).
Keine echten Adressen, Zugangsdaten oder Broker-Namen sichtbar (Einstellungen nicht zeigen oder vorher mit Beispielwerten füllen).

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

### Werbetext (170)

- **DE:** Text, Icons und Bilder an deine Ulanzi-Pixeluhr — mit Vorschau, virtueller Uhr zum Ausprobieren, Kurzbefehlen und Editor am iPad. Kein Konto, kein Server.
- **EN:** Text, icons and images for your Ulanzi pixel clock — with preview, a virtual clock to try it out, shortcuts and an editor on iPad. No account, no server.

### Beschreibung (4000)

Eriks Entwurf, wörtlich. Änderungen ggü. Eriks Entwurf (drei, sonst nichts):
1. Letzte Zeile um den Repo-Link ergänzt (beide Sprachen): `https://github.com/erik-wien/mqtt-tc002`.
2. Kurzbefehl-Namen so, wie sie in der App heißen: DE unverändert („Meldung an die Uhr schicken“, „Bild an die Uhr schicken“, „Meldung von der Uhr nehmen“); EN angepasst an die App („Send a message to the clock“, „Send an image to the clock“, „Remove a message from the clock“ statt „Send message to clock“ usw.).
3. Deutsch: „Slot“ → „Platz“ („Uhr, Icon, Dauer, Platz und das ganze Format …“).

**Deutsch** (2944 Zeichen)

> Deine Pixeluhr kann mehr als die Uhrzeit.
>
> Die Ulanzi TC002 hängt an der Wand und zeigt die Uhrzeit. Sie kann mehr — nur fehlte bisher die Software dafür. Pixel Clock Messenger ist sie.
>
> Tipp eine Nachricht, wähl ein Icon, drück Senden. Die Vorschau zeigt vorher Pixel für Pixel, was auf der Uhr stehen wird — samt Gerät drumherum, damit du es dir vorstellen kannst. Passt der Text nicht aufs Display, läuft er von selbst durch.
>
> WAS DU SCHICKEN KANNST
>
> • Text in drei mitgelieferten Pixelschriften, dazu die monospacen Schriften des Systems
> • Farbe, Ausrichtung, Rand, Zeichenabstand und Lauftempo
> • Icons in 8×8 und 16×16
> • Ganze Bilder über die volle Breite, 16×52
>
> OHNE UHR AUSPROBIEREN
>
> Noch kein Gerät im Haus? Schalte in den Einstellungen die virtuelle Uhr ein. Sie nimmt Anzeigen entgegen wie ein echtes Gerät und zeigt sie in einem eigenen Fenster — mit Geräterahmen, den fünf Plätzen und dem Blättern.
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
> MEHRERE UHREN, BEIDE FIRMWARES
>
> Über HTTP direkt oder über deinen MQTT-Broker, je Uhr wählbar. Neben der Ulanzi-Werksfirmware spricht die App auch AWTRIX NG.
>
> KURZBEFEHLE UND AUTOMATIONEN
>
> Drei Kurzbefehle stehen ohne Einrichtung in Siri und in der Kurzbefehle-App bereit:
>
> • Meldung an die Uhr schicken
> • Bild an die Uhr schicken
> • Meldung von der Uhr nehmen
>
> Verlangt wird jeweils nur das Wesentliche — ein Text, ein Bildname, ein Platz. Alles Weitere ist wahlfrei: Uhr, Icon, Dauer, Platz und das ganze Format von der Schriftart bis zum Zeichenabstand. Was nicht angegeben wird, kommt aus dem, was zuletzt in der App eingestellt war.
>
> Damit lässt sich die Uhr in Automationen einbauen: eine Meldung beim Ankommen zu Hause, ein Bild zur vollen Stunde, ein leerer Platz, wenn der Kalender nichts mehr hergibt. Die App muss dafür nicht geöffnet werden, und wo eine Angabe fehlt oder nicht passt, fragt der Kurzbefehl an genau dem Feld nach, statt wortlos abzubrechen.
>
> KEIN KONTO, KEIN DIENST
>
> Pixel Clock Messenger redet mit deiner Uhr und mit deinem Broker, sonst mit niemandem. Kein Konto, keine Anmeldung, kein Server dazwischen.
>
> Quelloffen unter der GPL-3.0: https://github.com/erik-wien/mqtt-tc002

**English** (2663 characters)

> Your pixel clock can do more than tell the time.
>
> The Ulanzi TC002 hangs on the wall and shows the time. It can do more — it just lacked the software. Pixel Clock Messenger is that software.
>
> Type a message, pick an icon, tap Send. The preview shows you pixel by pixel what will appear on the clock — device frame included, so you can picture it. If the text doesn't fit the display, it scrolls on its own.
>
> WHAT YOU CAN SEND
>
> • Text in three bundled pixel fonts, plus the system's monospaced fonts
> • Colour, alignment, margin, letter spacing and scroll speed
> • Icons in 8×8 and 16×16
> • Full-width images, 16×52
>
> TRY IT WITHOUT A CLOCK
>
> No device at home yet? Turn on the virtual clock in Settings. It accepts displays just like a real device and shows them in a window of its own — with device frame, the five slots and paging.
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
> SEVERAL CLOCKS, BOTH FIRMWARES
>
> Directly over HTTP or via your MQTT broker, chosen per clock. Besides the Ulanzi factory firmware, the app also speaks AWTRIX NG.
>
> SHORTCUTS AND AUTOMATIONS
>
> Three shortcuts are ready in Siri and the Shortcuts app with no setup:
>
> • Send a message to the clock
> • Send an image to the clock
> • Remove a message from the clock
>
> Each asks only for the essentials — a text, an image name, a slot. Everything else is optional: clock, icon, duration, slot and the whole format, from typeface to letter spacing. Whatever you leave out comes from what was last set in the app.
>
> That lets you build the clock into automations: a message when you get home, an image on the hour, an empty slot when the calendar has nothing left. The app doesn't need to be open, and where a value is missing or doesn't fit, the shortcut asks for exactly that field instead of giving up silently.
>
> NO ACCOUNT, NO SERVICE
>
> Pixel Clock Messenger talks to your clock and your broker, and to nobody else. No account, no sign-in, no server in between.
>
> Open source under GPL-3.0: https://github.com/erik-wien/mqtt-tc002

### Schlüsselwörter (100, kommagetrennt, ohne Leerzeichen)

- **DE:** `pixeluhr,ulanzi,tc002,tc001,awtrix,mqtt,kurzbefehle,laufschrift,led,matrix,display,icon,gif,siri,uhr` (100)
- **EN:** `ulanzi,tc002,tc001,awtrix,mqtt,shortcuts,scrolling,ticker,led,matrix,display,icon,gif,siri,wall` (95)

### URLs

- **Support-URL (Pflicht):** https://www.eriks.cloud/apps/mqtt-tc002/support.html
- **Datenschutz-URL (Pflicht für App Store, für externe Tests ggf. verlangt):** https://www.eriks.cloud/apps/mqtt-tc002/datenschutz.html
- **Marketing-URL (optional):** https://www.eriks.cloud/apps/mqtt-tc002/

### Datenschutz (App Privacy) — Angaben in App Store Connect

Kein Textfeld, sondern Fragebogen: App Privacy › Data Types › Edit › **„No, we do not collect data“** (Anzeige „Data Not Collected“) + Privacy Policy URL. Begründung, nur falls ein Prüfer fragt (aus `DATENSCHUTZ.md`): kein Konto, kein Server des Entwicklers, keine Analyse- oder Werbedienste. Die App spricht nur mit der eigenen Uhr (HTTP im lokalen Netz) und dem eigenen MQTT-Broker; einzige Ausnahme ist das Nachladen eines LaMetric-Icons auf Nutzerwunsch, dabei geht nur die eingegebene Nummer an developer.lametric.com. Das Broker-Kennwort liegt im Schlüsselbund; Icons, Bilder und Einstellungen liegen auf dem Gerät bzw. in der eigenen iCloud des Nutzers.

### Inhalte Dritter (App Information › Content Rights)

„Contains, shows, or accesses third-party content“ → **Ja**; „Has all necessary rights“ → **Ja** (Empfehlung, siehe Vorbehalt). Begründung:
- Mitgeliefert sind rund 30 kleine 8×8-Icons aus der öffentlichen LaMetric-Galerie („Grundschatz“, im AWTRIX-Umfeld per Nummer üblich) und drei Pixelschriften (Micro 5, Silkscreen, Tiny5) unter SIL OFL 1.1 (Lizenztexte im Bundle). Weitere LaMetric-Icons holt die App nur auf Nutzerwunsch per Nummer.
- Die App selbst steht unter GPL-3.0 mit zusätzlicher Erlaubnis für den App-Store-Vertrieb (`LIZENZ-AUSNAHME.md`, im Bundle).
- Vorbehalt: Eine ausdrückliche Lizenz für die LaMetric-Icons liegt im Repo nicht vor (offene Frage an Erik, siehe Bericht).
- Marken: Ulanzi und TC001/TC002 sind Marken bzw. Produkte von Ulanzi, LaMetric von seinem Inhaber; die App ist unabhängig (Formulierung wie im Fuß der Werbeseite).

Satz für die Review Notes (steht dort bereits): „Third-party content: the app ships about 30 small 8×8 icons from the public LaMetric icon gallery and three pixel fonts under the SIL Open Font License 1.1 … Ulanzi, TC001, TC002 and LaMetric are trademarks or products of their owners; the app is independent and not affiliated with them.“

### Altersfreigabe-Fragebogen

Alle Fragen **Nein / None**, „Unrestricted Web Access“: **Nein** (die iPhone-App öffnet kein Web; die einzige Netzabfrage holt ein Icon per Nummer), kein Glücksspiel, keine nutzergenerierten Inhalte, kein Chat → **4+**. LaMetric-Galerie: auf dem iPhone nicht durchsuchbar, nur die eingetippte Nummer wird geholt, das Ergebnis ist ein 8×8-Pixelbild; ob die Galerie Uploads von Nutzern enthält, ist nicht geprüft (offene Frage an Erik); bei 8×8 Pixeln ist anstößiger Inhalt praktisch ausgeschlossen.

### Exportkonformität

`ITSAppUsesNonExemptEncryption: false` steht in `project.yml` (bestätigt), die Frage entfällt je Build. Die App verschlüsselt nichts selbst: MQTT und HTTP gehen unverschlüsselt ins Heimnetz, das Kennwort liegt im System-Schlüsselbund.
