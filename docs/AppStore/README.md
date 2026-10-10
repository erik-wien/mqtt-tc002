# App Store Connect: Screenshots und Banner (Pixel Clock Messenger, iOS)

Alle Bilder sind PNG, RGB ohne Alphakanal. Aufnahme im Simulator mit der virtuellen Uhr und erfundenen
Beispieldaten (Uhren „Küche“/„Kitchen“, „Wohnzimmer“/„Living room“, Broker `mqtt.example.org`); keine echten
Adressen. Statusleiste 9:41.

| Datei(en) | Ziel in App Store Connect |
|---|---|
| `screenshots/{de,en}/iphone-6.3/01…05-*.png` (1206 × 2622) | iPhone, „Dynamic Island (medium display)“ / 6,3 Zoll |
| `screenshots/{de,en}/ipad/01…04-*.png` (2064 × 2752) | iPad 13 Zoll |
| `banner/header-{de,en}.png` (3840 × 1646) | Header |
| `banner/suche-{de,en}.png` (3840 × 2560) | Search Results |

Deutsch für die deutsche, Englisch für die englische Lokalisierung. Reihenfolge = Dateinummer.

| iPhone | iPad |
|---|---|
| `01-senden` Senden mit 52×16-Vorschau, Plätze belegt | `01-senden` Senden mit Inspektor |
| `02-darstellung` Formatblatt Darstellung (Schrift der Uhr, Effekt, Palette) | `02-darstellung` Inspektor-Reiter Darstellung |
| `03-klang` Nachricht mit Klang (Formatblatt) | `03-steuerung` Fernbedienung mit Live-Bild, Ton, Radio |
| `04-steuerung` Fernbedienung mit Live-Bild, Ton, Radio | `04-icons` Icons (Sammlung) |
| `05-icons` Icons (Sammlung) | |

Die Banner entstehen aus `~/GitSwift/Marketing/appstore/banner-mqtt.html` per `render-mqtt.sh` (verwenden die
iPhone-Screenshots `01-senden` und `02-darstellung`).
