# CLAUDE.md

Arbeitsregeln für dieses Repo. Was die App tut, steht in `README.md`; wie man
sie bedient, in ihrer Hilfe (⌘?); was das Gerät kann, in
`docs/tc002-protokoll.md`. Hier nur, was sonst verletzt würde.

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
