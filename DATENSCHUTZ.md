# Datenschutzerklärung — Pixel Clock Messenger

*Stand: 14. September 2026 · [English version below](#privacy-policy--pixel-clock-messenger)*

**Pixel Clock Messenger erhebt keine Daten.** Es gibt kein Konto, keine
Anmeldung, keinen Server des Entwicklers und keinen Analyse- oder
Werbedienst. Nichts, was du eintippst oder malst, verlässt dein Gerät und dein
Netz.

## Womit die App überhaupt spricht

Nur mit Geräten, die du selbst einträgst:

- **Deine Pixeluhr**, über HTTP in deinem lokalen Netz.
- **Dein MQTT-Broker**, falls du einen benutzt — Adresse, Port, Benutzername
  und Kennwort trägst du selbst ein.

Sonst mit niemandem. Eine Ausnahme gibt es, und sie geschieht nur auf deinen
Druck: Wenn du in der Icon-Auswahl eine LaMetric-Nummer eingibst und
„Nachladen" wählst, holt die App dieses eine Icon von `developer.lametric.com`.
Dabei wird nur die Nummer übertragen, die du eingegeben hast.

## Was wo gespeichert wird

- **Auf deinem Gerät:** deine Einstellungen, deine Icons und Bilder und die
  zuletzt gesendeten Meldungen.
- **In deinem Schlüsselbund:** das Kennwort deines MQTT-Brokers. Es steht
  nirgendwo sonst und wird nicht abgeglichen.
- **In deiner iCloud**, und nur wenn du den Abgleich einschaltest: Icons,
  Bilder und Einstellungen, damit sie auf deinen Geräten gleich sind. Das ist
  *deine* iCloud unter deiner Apple-Account-Kennung; der Entwickler hat
  keinerlei Zugriff darauf.

## Berechtigungen

- **Lokales Netzwerk** — um deine Uhr und deinen Broker zu erreichen. Ohne
  diese Freigabe kann die App nichts senden.
- **Dateien** — nur, wenn du selbst ein Bild oder Icon öffnest.

## Kinder, Tracking, Weitergabe

Es findet kein Tracking statt, es werden keine Kennungen zu Werbezwecken
verwendet, und es werden keine Daten an Dritte weitergegeben — es gibt keine.

## Nachprüfbar

Der vollständige Quelltext steht unter der GPL-3.0 offen:
<https://github.com/erik-wien/mqtt-tc002>. Wer dieser Erklärung nicht glaubt,
kann sie dort nachlesen.

## Kontakt

Erik Huemer · <https://github.com/erik-wien/mqtt-tc002/issues>

---

# Privacy Policy — Pixel Clock Messenger

*Last updated: 14 September 2026*

**Pixel Clock Messenger collects no data.** There is no account, no sign-in, no
server run by the developer, and no analytics or advertising service. Nothing
you type or draw leaves your device and your network.

## What the app talks to

Only devices you enter yourself:

- **Your pixel clock**, over HTTP on your local network.
- **Your MQTT broker**, if you use one — address, port, user name and password
  are entered by you.

Nothing else. There is one exception, and it happens only when you ask for it:
if you enter a LaMetric number in the icon picker and choose “Reload”, the app
fetches that one icon from `developer.lametric.com`. Only the number you typed
is transmitted.

## What is stored where

- **On your device:** your settings, your icons and images, and the messages
  sent most recently.
- **In your keychain:** the password of your MQTT broker. It is stored nowhere
  else and is never synchronised.
- **In your iCloud**, and only if you switch synchronisation on: icons, images
  and settings, so that they are the same on all your devices. That is *your*
  iCloud under your Apple Account; the developer has no access to it
  whatsoever.

## Permissions

- **Local network** — to reach your clock and your broker. Without it the app
  cannot send anything.
- **Files** — only when you open an image or icon yourself.

## Children, tracking, sharing

There is no tracking, no identifier is used for advertising, and no data is
shared with third parties — there is none to share.

## Verifiable

The complete source code is published under the GPL-3.0:
<https://github.com/erik-wien/mqtt-tc002>. Anyone who does not believe this
policy can read it there.

## Contact

Erik Huemer · <https://github.com/erik-wien/mqtt-tc002/issues>
