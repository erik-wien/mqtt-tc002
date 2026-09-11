# mqtt-tc002

Meldungen an die Ulanzi TC002 (Pixbar, 52×16) schicken — per MQTT.

Noch nichts gebaut. Der Entwurf entsteht in `docs/superpowers/specs/`.

## Was über das Gerät bereits bekannt ist

Ermittelt am 11.09.2026 am laufenden Gerät, nicht aus der Herstellerdoku:

- Die Firmware hängt an das eingestellte MQTT-Präfix ihre Gerätekennung an:
  aus `awtrix` wird `awtrix_a86b`.
- Sie abonniert genau zwei Themen: `awtrix_a86b/custom/+` (Anzeigen) und
  `awtrix_a86b/switchDiyApp` (umschalten).
- Nutzlast ist ein JSON mit `text`-Array: content, fontHeight, x, y, color,
  align, valign, rect, charSpacing; dazu `duration` für die Standzeit.
- Eine leere Nachricht auf `custom/<name>` löscht die Anzeige.
- Dasselbe JSON nimmt das Gerät auch per HTTP: `POST /api/custom?name=<n>`.
- Gerät scrollt nicht selbst; Laufschrift muss Bild für Bild geschickt werden.
- Der Gerätefont kennt **keine Umlaute**, und an Satzzeichen nur `%`, `.`, `-`, `:`
  (am 11.09.2026 am Gerät durchprobiert). Kleinbuchstaben funktionieren entgegen
  einer verbreiteten Behauptung sehr wohl.
- `carouselSpeed` (0 = kein Wechsel) steuert, ob mehrere Anzeigen abwechseln;
  zu lesen und zu setzen über `/getConfig` und `/setConfig` am Gerät.

Broker: mosquitto auf hausserver, 192.168.1.10:1883, Konten siehe dortige
`aclfile`. Verwaltung mit `mqtt-user` auf hausserver.

## Quellen

- **Offizielles Repository des Herstellers:**
  https://github.com/UlanziTechnology/Ulanzi-U-Clock-TC002
  Bestaetigt die Praefixbildung `<eingestellt>_<letzte vier MAC-Stellen>` (Vorgabe
  `ulanzi`), nennt `text`, `image`, `draw` und `duration`, und fuehrt neben `df`
  (Rechteck) auch `dfc` (gefuellter Kreis: `{"dfc":[x,y,radius,"#RRGGBB"]}`) auf.
  Animierte GIFs sind laut dieser Quelle in `image` unterstuetzt.
- **Nicht** dokumentiert sind dort: das Steuerthema `<praefix>/switchDiyApp` und das
  Loeschen einer Anzeige durch eine leere Nutzlast. Beides haben wir am 11.09.2026 am
  Geraet ermittelt — `switchDiyApp` aus den SUBSCRIBE-Zeilen des Brokers.
- **PixDeck** (https://github.com/cailurus/PixDeck, GPL-3.0): Quelle der Erkenntnis, dass
  dasselbe JSON auch per HTTP an `/api/custom?name=<n>` geht.
