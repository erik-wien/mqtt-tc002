# CLAUDE.md

Arbeitsregeln für dieses Repo. Was die App tut, steht in `README.md`; wie man
sie bedient, in ihrer Hilfe (⌘?); was das Gerät kann, in
`docs/tc002-protokoll.md`; was uns an dessen Firmware als Mangel aufgefallen
ist und bei einem Update nachzuprüfen wäre, in
`docs/firmware-beobachtungen.md`. Hier nur, was sonst verletzt würde.

- Logik gehört in `TC002Core` und wird dort getestet. `TC002App` bleibt dünn
  — reine SwiftUI-Views und Zustandsverdrahtung, keine Geschäftslogik.
- Das echte Gerät (`192.168.1.20`) und der Broker (`192.168.1.10`) sind in
  Tests tabu. Dafür gibt es Doppelgänger: `URLProtocol` für die
  HTTP-Schnittstelle des Geräts, `NachrichtSendend` für das MQTT-Senden.
- Die MQTT-Bytes sind gegen eine echte Aufzeichnung von `mosquitto_pub`
  geprüft (`MQTTPaketTests`). Dieser Test wird nicht abgeschwächt.
- Das Themen-Präfix nie hart eintragen, immer über `Geraet.themenPraefix()`
  ermitteln — es weicht vom eingestellten Präfix ab (siehe
  `docs/tc002-protokoll.md`, §2).
- Blockierende Netzaufrufe nie auf dem Hauptthread: `AppZustand` ist
  `@MainActor`-isoliert, die eigentlichen Aufrufe laufen in `Task.detached`.
- Je Uhr eine eigene MQTT-Client-Kennung, sonst trennt der Broker die
  vorherige Sitzung.
- Eigene Icons liegen unter
  `~/Library/Application Support/MQTT-TC002/Icons`, nie im App-Bündel — dort
  wären sie beim nächsten Bau weg, und unter `/Applications` ist der Ordner
  nicht beschreibbar.

## Sprachen

Deutsch ist die Entwicklungssprache: Der deutsche Wortlaut steht im Quelltext
und ist zugleich der Schlüssel. Eine fehlende Übersetzung fällt damit auf den
deutschen Satz zurück, nicht auf einen Schlüsselnamen.

- Was SwiftUI als `LocalizedStringKey` bekommt (`Text`, `Button`, `Label`,
  `.help` …), schlägt es selbst nach. Nichts zu tun.
- Alles, was als gewöhnliches `String` weitergereicht wird — Fehlertexte,
  Meldungen, Protokollzeilen, die Hilfebausteine, das Kommandozeilenwerkzeug —
  muss durch `lok(…)` bzw. `lokf(…, %@)`. Sonst bleibt es deutsch, ohne dass
  irgendetwas darauf hinweist.
- **Keine Werte in den Schlüssel einsetzen.** `Text("Rand \(rand)")` trägt zur
  Laufzeit den Schlüssel `Rand %lld`, im Quelltext steht aber `Rand \(rand)` —
  gesucht wird dann etwas, das es nicht gibt. Stattdessen `lokf("Rand %d", rand)`.

Geprüft wird das nicht von Hand:

    python3 scripts/texte-sammeln.py --pruefen

meldet jeden sichtbaren Text ohne Übersetzung und jeden Eintrag, den es nicht
mehr gibt. Vor einer Veröffentlichung muss die Zeile `0 ohne Uebersetzung`
lauten; `cli.hilfe` steht dort zu Recht als überzählig, weil dieser eine
Schlüssel erfunden ist.

Texte, die über eine Variable nachgeschlagen werden (`lok(a.rawValue)`), kann
der Sammler nicht sehen. Sie stehen als `DYNAMISCH` von Hand im Skript.

Eine neue Sprache ist ein Ordner `Resources/Sprachen/<code>.lproj` mit einer
`Localizable.strings`; `build.sh` nimmt jeden solchen Ordner mit. Die
Gerätereferenz ist ein durchgehendes Dokument und wird am Stück übersetzt
(`docs/en/tc002-protocol.md`), nicht Satz für Satz.

Probieren, ohne etwas umzustellen:

    /Applications/MQTT-TC002.app/Contents/MacOS/TC002App -AppleLanguages '(en)'
    mqtttc002 -AppleLanguages '(en)' hilfe

## Das Kommandozeilenwerkzeug

`mqtttc002` liest die Einrichtung der App (`Einstellungen` im Kern) und
schreibt sie nie. Es reist im Bündel mit (`Contents/MacOS/mqtttc002`) und wird
über einen Verweis benutzt. Zwei Fallen, beide schon zugeschnappt:

- **`Bundle.main` ist über einen Verweis nicht das App-Bündel**, sondern der
  Ordner des Verweises. Fassungsnummer, Schriften und Übersetzungen fehlen dann
  still. Deshalb `Programmbuendel.eigenes`, nie `Bundle.main`.
- **`UserDefaults(suiteName:)` mit der eigenen Kennung liefert nichts.** Genau
  das passiert, wenn das Werkzeug unmittelbar im Bündel aufgerufen wird. Dort
  ist `.standard` das Richtige — siehe `Einstellungen.ablage`.

Die `Codable`-Form von `Uhr` ist ein Dateiformat: Die App schreibt sie, das
Werkzeug liest sie. Feldnamen ändern macht die Einstellungen einer laufenden
Installation unlesbar (`EinstellungenTests` hält das fest).

## Fassungsnummer

Nicht im Quelltext eintragen. `build.sh` nimmt sie aus `TC002_VERSION` oder vom
jüngsten Tag, die Baunummer ist die Zahl der Commits. `release.sh <fassung>`
setzt die Variable, bricht bei geändertem Arbeitsbaum ab und prüft hinterher
die Info.plist gegen sein Argument.

## Nach /Applications installieren

**Nicht** mit `rm -rf` und `cp` ersetzen. Die Freigabe „Lokales Netzwerk" haengt
bei macOS am Programm; ein so ausgetauschtes Buendel gilt leicht als ein anderes.
Die Freigabe steht dann weiter auf „erteilt", greift aber nicht mehr, und
nachgefragt wird auch nicht — die App erreicht Uhr und Broker einfach nicht.
Am 11.09.2026 genau so passiert, nach dreimaligem Austausch.

Stattdessen an Ort und Stelle ersetzen, das erhaelt die Identitaet:

    ditto build/MQTT-TC002.app /Applications/MQTT-TC002.app

Und die App moeglichst nur von **einem** Ort aus starten. Zwei Kopien mit
derselben Buendelkennung — etwa `/Applications` und `build/` — verwirren die
Rechteverwaltung zusaetzlich.

Ist es doch passiert: Systemeinstellungen > Datenschutz & Sicherheit >
Lokales Netzwerk > den Eintrag aus- und wieder einschalten.
