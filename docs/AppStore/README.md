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
| `01-senden` Senden mit 52×16-Vorschau, fünf Plätze belegt, Segment „Anzeige \| Nachricht“ mit Lebensdauer | `01-senden` Senden mit Inspektor (Reiter Format) |
| `02-darstellung` Blatt „Darstellung“ (Hintergrund, Effekt, Overlay, Palette) | `02-darstellung` Inspektor-Reiter Darstellung |
| `03-klang` Nachricht: Blatt „Klang“ (Melodie von der Uhr, 1× \| In Schleife) | `03-steuerung` Bereich „Uhr“ (Live-Bild, Gerät, Anzeige, Moodlight, Anzeiger) |
| `04-steuerung` Blatt „Uhr“ (Live-Bild, Gerät, Anzeige) | `04-icons` Icons (Sammlung) |
| `05-icons` Icons (Sammlung) mit Nummer unter dem Namen | |

Der Dateiname `…-steuerung` ist geblieben, auch wenn der Bereich jetzt „Uhr“ heißt (die Banner und Verweise hängen daran).
Zeitangaben im Verlauf zeigen die Aufnahmezeit; in „Uhr“ steht als aktive Anzeige der Platzname `meldung1`, so heißt der Platz auf dem Gerät.

Die Banner entstehen aus `~/GitSwift/Marketing/appstore/banner-mqtt.html` per `render-mqtt.sh` (verwenden die
iPhone-Screenshots `01-senden` und `02-darstellung`).
