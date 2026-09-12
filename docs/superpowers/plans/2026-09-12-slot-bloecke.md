# Die fünf Slot-Blöcke — Implementierungsplan

> **Für agentische Umsetzer:** Pflicht-Unterskill: `superpowers:subagent-driven-development`.

**Ziel:** Die Ziffernreihe ①–⑤ wird durch fünf Blöcke ersetzt, die zeigen, was auf jedem Slot der Uhr liegt.

**Spec:** `docs/superpowers/specs/2026-09-12-slot-bloecke-design.md`

**Aufbau:** Ein MQTT-Mitleser im Zustand (`<präfix>/custom/#`) liefert den Inhalt; `customList` liefert belegt/frei; eine eigene Datei je Uhr merkt sich die Regler je Slot und wird von App, Werkzeug und Kurzbefehlen geschrieben. Die Blöcke selbst sind eine geteilte Ansicht in `TC002Ansichten`.

## Global Constraints

- Keine externen Pakete. Swift-Sprachmodus `.v5`. macOS 14, iOS 17.
- `meldung1`…`meldung5` bleiben die Gerätebezeichner. Dateiformat, unantastbar (`Meldungsplatz.name(fuer:)`, `testMeldungsplatzNamenBleiben`).
- `TC002Core`, `TC002Modell`, `TC002Ansichten` bleiben plattformfrei: kein AppKit, kein UIKit.
- Die Rechnung in `Meldungsbau` wird nicht angefasst; 20 Byte-Schnappschüsse nageln sie fest.
- Deutscher Wortlaut = Übersetzungsschlüssel. Kein Ternär mit String-Zweig in einem lokalisierenden Modifikator. Kein Erklärtext in der Bedienung — der gehört in die Hilfe.
- Ausgangsstand: **177 Tests grün**, `444 Texte, 0 ohne Uebersetzung, 1 ueberzaehlig`, Bündelprüfung grün für beide Plattformen.
- Nie ein Bedienelement ersatzlos streichen, ohne dass seine Aufgabe woanders sitzt.

---

### Aufgabe 1: Der Mitleser — Inhalt je Slot aus dem Broker

**Dateien:** `Sources/TC002Core/Anzeigen.swift` (Zerlegen der Nutzlast), `Sources/TC002Modell/AppZustand.swift`, `Tests/TC002CoreTests/`

**Erzeugt:** `AppZustand.slotInhalt: [UUID: [Int: Slotbild]]` — je Uhr, je Platz (1…5) das zuletzt gesehene Bild. `Slotbild` trägt die Pixel (52×16 als `[String?]`) und den Zeitpunkt.

- [ ] **Schritt 1: `Slotbild` und das Zerlegen im Kern**

Neuer Typ in `TC002Core`, plus eine Funktion, die aus einer `custom`-Nutzlast das erste Einzelbild als Pixel gewinnt. Das Format ist unser eigenes (`Rahmen.alsJSON()`): `draw` mit Rechtecken, oder `bitmap`, oder ein Lauf-GIF in `icon`. Für den Anfang genügt der stehende Fall; beim GIF das erste Einzelbild.

- [ ] **Schritt 2: Test zuerst**

`Tests/TC002CoreTests/SlotbildTests.swift`: eine echte Nutzlast, wie `Meldungsbau.rahmen(...).alsJSON()` sie erzeugt, hineingeben und prüfen, dass dieselben Pixel herauskommen, die `Meldungsbau.feld(...)` liefert. **Der Test muss zuerst rot sein.**

- [ ] **Schritt 3: Abonnement erweitern**

In `AppZustand.horchenAbgleichen` das Thema `"\(uhr.praefix)/custom/#"` dazunehmen. In `gemeldet(thema:nutzlast:fuer:)` einen Fall dafür: Thema endet auf `/custom/meldungN` → Platz ableiten, Nutzlast zerlegen, `slotInhalt` setzen. Leere Nutzlast → Eintrag entfernen.

- [ ] **Schritt 4: Prüfen und einchecken**

`swift test` (neue Tests grün), `swift build` warnungsfrei.

---

### Aufgabe 2: Das Slotgedächtnis — Regler je Slot, von allen drei Absendern

**Dateien:** `Sources/TC002Core/Slotgedaechtnis.swift` (neu), `Tests/TC002CoreTests/SlotgedaechtnisTests.swift` (neu)

**Erzeugt:** `Slotgedaechtnis` mit `merken(_ optionen: Meldungsoptionen, dauer: Int?, icon: String?, fuer uhr: UUID, platz: Int)` und `gemerkt(fuer:platz:) -> Slotstand?`. Ablage: eine JSON-Datei je Uhr unter `Application Support/MQTT-TC002/Slots/<uuid>.json`.

- [ ] **Schritt 1: Das Format festlegen und testen**

`Slotstand: Codable` mit allen Reglern (Weg, Schrift, Größe, Fett, Großbuchstaben, Rand, Abstand, waagrecht, senkrecht, Farbe, Tempo, Icon mitscrollen, Iconnummer, Dauer) **plus** einer Prüfsumme der zuletzt gesendeten Nutzlast.

**Die Prüfsumme ist der Kern:** Sie entscheidet, ob das Gedächtnis noch zum Slot passt. Weicht die über den Broker gesehene Nutzlast davon ab, hat ein fremder Absender geschrieben, und die Regler werden **nicht** angerührt.

Test: schreiben, lesen, Feldnamen festnageln (wie `EinstellungenTests` es für `Uhr` tut) — eine Umbenennung macht sonst die Ablage einer laufenden Installation unlesbar.

- [ ] **Schritt 2: Zwei Schreiber dürfen nicht kollidieren**

Je Uhr eine Datei, atomar geschrieben (`.atomic`). Ein Leser, der eine unlesbare Datei findet, behandelt sie als leer statt abzustürzen. Test dafür.

---

### Aufgabe 3: Der Block als geteilte Ansicht

**Dateien:** `Sources/TC002Ansichten/Slotblock.swift` (neu)

**Erzeugt:** `public struct Slotblock: View` mit `platz: Int`, `zustand: Slotzustand` (`frei`, `bekannt([String?])`, `unbekannt`), `gewaehlt: Bool`.

- [ ] **Schritt 1: Die drei Zustände**

Frei: gedämpfter leerer Rahmen. Bekannt: die Pixel im Verhältnis 52:16. Unbekannt: das Wort „belegt", ohne Begründung — die steht in der Hilfe.

Zustand **nicht allein über Farbe** (Richtlinie): frei und unbekannt unterscheiden sich auch in der Form. Der gewählte Block trägt einen sichtbaren Rahmen, nicht nur eine Tönung.

- [ ] **Schritt 2: Beschriftung für die Sprachausgabe**

Je Block: Slotnummer und Zustand als Wort. Vorhandene Wörter nehmen, wo es sie gibt.

---

### Aufgabe 4: Einbau in die Mac-Sendeansicht

**Dateien:** `Sources/TC002App/SendenView.swift`, `Sources/TC002App/MeldungsplatzView.swift` (entfällt)

- [ ] **Schritt 1: Die Blöcke in die leere Mitte**

Fünf `Slotblock` nebeneinander zwischen Statuszeile und Eingabefeld. Antippen wählt den Slot **und** stellt die Regler wieder her, falls das Gedächtnis passt (Prüfsumme).

- [ ] **Schritt 2: Ziffernreihe und Papierkorb**

`MeldungsplatzWahl` entfällt; der Papierkorb bleibt und leert den gewählten Block. `MeldungsplatzView.swift` restlos entfernen, wenn niemand sie mehr braucht — `--pruefen` meldet verwaiste Übersetzungen.

---

### Aufgabe 5: Einbau in die iPhone-Sendeansicht

**Dateien:** `Sources/TC002iOS/SendeniOS.swift`

Dieselben Blöcke an derselben Stelle: unter der Vorschau, über der Formatpille. Die Ziffernreihe entfällt auch dort; „Dauer" bleibt.

---

### Aufgabe 6: Werkzeug und Kurzbefehle schreiben ins Gedächtnis

**Dateien:** `Sources/TC002CLI/main.swift`, `Sources/TC002iOS/Kurzbefehle.swift`

Nach einer **erfolgreichen** Sendung `Slotgedaechtnis.merken(...)` aufrufen. Schlägt das Schreiben fehl, ist das kein Grund, die Sendung als gescheitert zu melden — aber eine Zeile ins Protokoll.

**Achtung, alte Regel:** Das Werkzeug schreibt nie in die *Einstellungen*. Das Gedächtnis ist eine eigene Datei; die Regel bleibt für die Einstellungen bestehen und wird in `CLAUDE.md` entsprechend geschärft.

---

### Aufgabe 7: Hilfe und Dokumentation

**Dateien:** `Sources/TC002App/HilfeView.swift`, `README.md`, `README.en.md`, `CLAUDE.md`

Was die drei Zustände bedeuten, warum „unbekannt" vorkommt, und dass die Uhr nur Namen meldet (Gerätereferenz §3.5). Kein Erklärtext in der Ansicht selbst.
