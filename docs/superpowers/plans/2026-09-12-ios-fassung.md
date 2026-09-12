# iOS-Fassung — Umsetzungsplan

> **Für agentische Arbeiter:** ERFORDERLICHE UNTER-SKILL: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, um diesen Plan Aufgabe für Aufgabe umzusetzen. Die Schritte benutzen Kästchen (`- [ ]`) zur Fortschrittsverfolgung.

**Ziel:** Eine iPhone-App, die Meldungen an eine Ulanzi TC002 schickt und sich mit der bestehenden macOS-App Kern und Zustandsschicht teilt.

**Aufbau:** Die Rechnungen zum Bau einer Meldung wandern aus der macOS-Sendeansicht in den Kern, abgesichert durch Schnappschusstests, die das heutige Rahmen-JSON Byte für Byte festhalten. Die Zustandsschicht `AppZustand` wandert in ein eigenes Ziel `TC002Modell`, das beide Oberflächen benutzen. Die iPhone-Oberfläche entsteht neu als drei Reiter.

**Technik:** Swift 6 (Sprachmodus 5), SwiftUI, Swift Package Manager, xcodegen, Xcode 26.6, iOS-26.5-SDK. Keine Paketabhängigkeiten.

**Spezifikation:** `docs/superpowers/specs/2026-09-12-ios-fassung-design.md`

## Übergreifende Vorgaben

- Zweig `ios`. `main` wird nicht angefasst.
- Keine neuen Paketabhängigkeiten. `xcodegen` ist ein Entwicklungswerkzeug.
- Plattformen: macOS 14, iOS 17. iOS 17 ist die Untergrenze für `@Observable`.
- Bündelkennung iOS: `cloud.eriks.mqtt-tc002` (dieselbe wie macOS). Mannschaftskennung `25ZK4SS655`.
- Quelltext, Kommentare und Oberfläche auf Deutsch. Englisch entsteht über `Resources/Sprachen/en.lproj/Localizable.strings`.
- Jeder sichtbare Text, der als gewöhnliches `String` weitergereicht wird, geht durch `lok(…)` bzw. `lokf(…)`. `python3 scripts/texte-sammeln.py --pruefen` muss am Ende jeder Aufgabe `0 ohne Uebersetzung` melden.
- Die `rawValue`-Zeichenketten der Aufzählungen und die `Codable`-Form von `Uhr` sind ein Dateiformat. Wer sie ändert, macht die Einstellungen einer laufenden Installation unlesbar.
- Das echte Gerät (`10.10.10.96`) und der Broker (`10.10.10.18`) sind in Tests tabu.
- Nach jeder Aufgabe: `swift test` grün.

---

### Aufgabe 1: Meldungsoptionen und der Rahmenbau, wortgetreu aus der Sendeansicht gelöst

Die Sendeansicht rechnet heute Dinge aus, die keine Ansichtssache sind. Sie stehen in einer `View` und sind deshalb nicht prüfbar. Diese Aufgabe löst sie heraus — **ohne eine einzige Rechnung zu ändern** — und nagelt sie mit Schnappschüssen fest. Erst die nächste Aufgabe verschiebt sie in den Kern.

**Dateien:**
- Anlegen: `Sources/TC002App/Meldungsbau.swift`
- Anlegen: `Tests/TC002AppTests/MeldungsbauTests.swift`
- Anlegen: `Tests/TC002AppTests/Schnappschuesse/` (Ordner, wird von den Tests gefüllt)
- Ändern: `Sources/TC002App/SendenView.swift`

**Schnittstellen:**
- Verbraucht: `Textraster.rasterPuffer`, `Textraster.einsetzen`, `Textraster.tintenZeilen`, `Textraster.breite`, `Textraster.laufschrift`, `Pixelfeld`, `Frame`, `Bild`, `Textblock`, `Icon`, `Iconsammlung` — alle bereits in `TC002Core`.
- Erzeugt: `Meldungsoptionen` (Wertetyp) und `Meldungsbau` (Aufzählung mit statischen Funktionen), beide zunächst `internal` in `TC002App`.

- [ ] **Schritt 1: Den Wertetyp und den Rahmenbau anlegen**

`Sources/TC002App/Meldungsbau.swift`:

```swift
import Foundation
import TC002Core

/// Alles, was eine Meldung ausmacht — ohne Ansicht, ohne Zustand.
///
/// Die Felder entsprechen eins zu eins den `@AppStorage`-Werten der
/// Sendeansicht. Wer hier etwas umbenennt, muss dort denselben Namen benutzen,
/// sonst liest eine laufende Installation ihre Einstellungen nicht mehr.
struct Meldungsoptionen {
    var text: String
    var weg: SendeWeg = .pixel
    var schrift: String = "Silkscreen"
    var groesse: Double = 8
    var fett: Bool = false
    var farbe: String = "#00FF66"
    var grossbuchstaben: Bool = false
    var waagrecht: SendenHAusrichtung = .links
    var senkrecht: SendenVAusrichtung = .oben
    var rand: Int = 1
    var abstand: Int = 1
    var tempo: Lauftempo = .mittel
    var iconLaeuftMit: Bool = false
    var dauer: Int?

    /// Der Text, wie er tatsächlich gerastert bzw. geschickt wird — die einzige
    /// Stelle, an der „Großbuchstaben" wirkt. Nebeneffekt von `uppercased()`:
    /// aus „ß" wird „SS".
    var gesendeterText: String { grossbuchstaben ? text.uppercased() : text }

    /// `align`/`valign` in den Namen, die das Gerät für `text` erwartet (§4.3).
    var geraeteAusrichtung: String {
        switch waagrecht { case .links: "left"; case .mittig: "center"; case .rechts: "right" }
    }
    var geraeteVertikal: String {
        switch senkrecht { case .oben: "top"; case .mittig: "middle"; case .unten: "bottom" }
    }
}

/// Baut aus Optionen und Icon den Rahmen, den die Uhr bekommt.
///
/// Wortgetreu aus `SendenView` gelöst. Keine Rechnung wurde dabei geändert;
/// die Schnappschusstests halten das fest.
enum Meldungsbau {
    /// Wo das Icon endet: acht Pixel breit, zwei Pixel Luft.
    static let iconBreite = 10

    static func flaecheX(mitIcon: Bool) -> Int { mitIcon ? iconBreite : 0 }
    static func flaecheBreite(mitIcon: Bool) -> Int {
        Pixelfeld.breiteStandard - flaecheX(mitIcon: mitIcon)
    }

    /// Der gerasterte Text ohne jede Ausrichtung — die Grundlage für `versatzY`
    /// und für das fertige Feld.
    static func puffer(_ o: Meldungsoptionen) -> Pixelfeld {
        Textraster.rasterPuffer(o.gesendeterText, schrift: o.schrift, groesse: o.groesse,
                                fett: o.fett, farbe: o.farbe, luecke: o.abstand)
    }

    static func breite(_ o: Meldungsoptionen) -> Int {
        Textraster.breite(o.gesendeterText, schrift: o.schrift, groesse: o.groesse,
                          fett: o.fett, luecke: o.abstand)
    }

    /// Passt der Text in die verfügbare Breite, steht er still — sonst läuft er
    /// als GIF durch. Gerechnet wird mit der Breite des stehenden Falls (mit
    /// Icon 42 Spalten). Hinge die Rechnung an „Icon mitscrollen", würde das
    /// Einschalten den Text passend machen, den Schalter verschwinden lassen
    /// und ihn wieder umwerfen.
    static func passt(_ o: Meldungsoptionen, mitIcon: Bool) -> Bool {
        breite(o) <= flaecheBreite(mitIcon: mitIcon)
    }

    /// Senkrechte Ausrichtung über die tatsächliche Tinte, nicht über die
    /// Schriftgröße: `rasterPuffer` legt die Tinte dorthin, wo die Grundlinie
    /// sie hinlegt, nicht an den oberen Rand.
    static func versatzY(_ o: Meldungsoptionen) -> Int {
        guard let tinte = Textraster.tintenZeilen(puffer(o)) else { return 0 }
        let hoehe = tinte.letzte - tinte.erste + 1
        // Mehr Rand, als Platz da ist, gaebe es nicht — dann bliebe nur
        // Abschneiden, und das will niemand.
        let r = min(o.rand, max(0, (Pixelfeld.hoeheStandard - hoehe) / 2))
        switch o.senkrecht {
        case .oben:   return -tinte.erste + r
        case .mittig: return (Pixelfeld.hoeheStandard - hoehe) / 2 - tinte.erste
        case .unten:  return (Pixelfeld.hoeheStandard - hoehe) - tinte.erste - r
        }
    }

    static func versatzX(_ o: Meldungsoptionen, mitIcon: Bool) -> Int {
        let x = flaecheX(mitIcon: mitIcon), b = flaecheBreite(mitIcon: mitIcon)
        switch o.waagrecht {
        case .links:  return x
        case .mittig: return x + max(0, (b - breite(o)) / 2)
        case .rechts: return x + max(0, b - breite(o))
        }
    }

    /// Vorschau und Sendung entstehen aus demselben Feld. Gerastert wird immer
    /// in derselben Phase, ausgerichtet wird durch Verschieben — sonst sähe
    /// dieselbe Schrift stehend anders aus als laufend.
    static func feld(_ o: Meldungsoptionen, mitIcon: Bool) -> Pixelfeld {
        var f = Pixelfeld()
        Textraster.einsetzen(puffer(o), x: versatzX(o, mitIcon: mitIcon),
                             y: versatzY(o), in: &f)
        return f
    }

    /// Die Einzelbilder der Laufschrift. Getrennt von `rahmen`, weil die
    /// Vorschau sie zum Abspielen braucht, während `rahmen` sie bereits zu
    /// einem GIF verpackt hat.
    static func laufschriftBilder(_ o: Meldungsoptionen,
                                  iconBilder: [[String?]]) -> [Bildraster.Einzelbild] {
        Textraster.laufschriftEinzelbilder(
            o.gesendeterText, schrift: o.schrift, groesse: o.groesse, fett: o.fett,
            farbe: o.farbe, schrittweite: o.tempo.schrittweite, bilddauer: o.tempo.bilddauer,
            versatzY: versatzY(o), iconBilder: iconBilder,
            iconLaeuftMit: o.iconLaeuftMit, luecke: o.abstand)
    }

    static func textblock(_ o: Meldungsoptionen, mitIcon: Bool) -> Textblock {
        var t = Textblock(inhalt: o.gesendeterText)
        t.schrifthoehe = Int(o.groesse)
        t.x = flaecheX(mitIcon: mitIcon)
        t.y = 0
        t.farbe = o.farbe
        t.ausrichtung = o.geraeteAusrichtung
        t.vertikal = o.geraeteVertikal
        t.flaeche = [flaecheX(mitIcon: mitIcon), 0,
                     flaecheBreite(mitIcon: mitIcon), Pixelfeld.hoeheStandard]
        return t
    }

    /// Baut den Rahmen für den gewählten Weg. Beim Pixel-Weg zwei Fälle, einer
    /// je Entscheidung von `passt`: ein starrer `draw`-Rahmen mit dem Icon als
    /// zweitem Bild, oder ein einziges animiertes GIF, in dem das Icon schon
    /// steckt. Beim Text-Weg ein `Textblock`, den die Uhr selbst setzt.
    ///
    /// `vorberechnet` ist das bereits gebaute Laufschrift-GIF. Die Sendeansicht
    /// hat es für die Vorschau ohnehin erzeugt; es zweimal zu rastern wäre die
    /// teuerste Rechnung der App, doppelt ausgeführt.
    static func rahmen(_ o: Meldungsoptionen, icon: Icon?, sammlung: Iconsammlung,
                       vorberechnet: String? = nil) throws -> Frame {
        let mitIcon = icon != nil
        switch o.weg {
        case .pixel:
            guard passt(o, mitIcon: mitIcon) else {
                let iconBilder = icon.flatMap { i -> [[String?]]? in
                    try? Bildraster.lesenMitZeiten(i.datei, breite: 8, hoehe: 8).map(\.pixel)
                } ?? []
                let uri = try vorberechnet.flatMap { $0.isEmpty ? nil : $0 }
                    ?? Textraster.laufschrift(
                        o.gesendeterText, schrift: o.schrift, groesse: o.groesse, fett: o.fett,
                        farbe: o.farbe, schrittweite: o.tempo.schrittweite,
                        bilddauer: o.tempo.bilddauer, versatzY: versatzY(o),
                        iconBilder: iconBilder, iconLaeuftMit: o.iconLaeuftMit, luecke: o.abstand)
                return Frame(bilder: [Bild(datenURI: uri, x: 0, y: 0)], dauer: o.dauer)
            }
            var frame = Frame(draw: feld(o, mitIcon: mitIcon).alsDrawBefehle(), dauer: o.dauer)
            if let icon {
                frame.bilder.append(Bild(datenURI: try sammlung.datenURI(fuer: icon), x: 0, y: 4))
            }
            return frame
        case .text:
            var frame = Frame(texte: [textblock(o, mitIcon: mitIcon)], dauer: o.dauer)
            if let icon {
                frame.bilder.append(Bild(datenURI: try sammlung.datenURI(fuer: icon), x: 0, y: 4))
            }
            return frame
        }
    }
}
```

- [ ] **Schritt 2: Übersetzen lassen, damit die Signaturen stimmen**

Ausführen: `swift build`
Erwartet: fehlerfrei. `Meldungsbau` wird noch von niemandem benutzt.

- [ ] **Schritt 3: Die Schnappschusstests schreiben**

`Tests/TC002AppTests/MeldungsbauTests.swift`:

```swift
import Foundation
import XCTest
import TC002Core
@testable import TC002App

/// Nagelt den Rahmenbau fest. Diese Tests sind nicht dazu da, eine Absicht zu
/// beschreiben — sie halten fest, was die App **heute** erzeugt, damit das
/// Verschieben in den Kern nichts verändert. Weicht ein Schnappschuss ab, ist
/// das ein Fehler der Verschiebung und keine Verbesserung.
final class MeldungsbauTests: XCTestCase {

    /// Ein leerer Iconordner: Die Schnappschüsse sollen die Rechnung festhalten,
    /// nicht den Inhalt eines Icons.
    private func leereSammlung() -> Iconsammlung {
        Iconsammlung(schreibordner: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString))
    }

    private var ordner: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Schnappschuesse")
    }

    /// Vergleicht gegen die abgelegte Fassung. Fehlt sie, wird sie geschrieben
    /// und der Test schlägt einmal fehl — damit niemand versehentlich einen
    /// Schnappschuss einführt, ohne ihn angesehen zu haben.
    private func vergleiche(_ json: String, mit name: String,
                            datei: StaticString = #filePath, zeile: UInt = #line) throws {
        let pfad = ordner.appendingPathComponent("\(name).json")
        guard let erwartet = try? String(contentsOf: pfad, encoding: .utf8) else {
            try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
            try json.write(to: pfad, atomically: true, encoding: .utf8)
            XCTFail("Schnappschuss \(name) neu angelegt — bitte ansehen und einchecken.",
                    file: datei, line: zeile)
            return
        }
        XCTAssertEqual(json, erwartet, "Schnappschuss \(name) weicht ab", file: datei, line: zeile)
    }

    private func json(_ o: Meldungsoptionen) throws -> String {
        try Meldungsbau.rahmen(o, icon: nil, sammlung: leereSammlung()).alsJSON()
    }

    func testWaagrechteAusrichtung() throws {
        for (name, wert) in [("links", SendenHAusrichtung.links),
                             ("mittig", .mittig), ("rechts", .rechts)] {
            var o = Meldungsoptionen(text: "Hallo")
            o.waagrecht = wert
            try vergleiche(json(o), mit: "waagrecht-\(name)")
        }
    }

    func testSenkrechteAusrichtungUndRand() throws {
        for (name, wert) in [("oben", SendenVAusrichtung.oben),
                             ("mittig", .mittig), ("unten", .unten)] {
            for rand in [0, 1, 3] {
                var o = Meldungsoptionen(text: "Hallo")
                o.senkrecht = wert
                o.rand = rand
                try vergleiche(json(o), mit: "senkrecht-\(name)-rand\(rand)")
            }
        }
    }

    func testAbstand() throws {
        for abstand in [0, 1, 3] {
            var o = Meldungsoptionen(text: "Hallo")
            o.abstand = abstand
            try vergleiche(json(o), mit: "abstand-\(abstand)")
        }
    }

    func testDauerUndGrossbuchstaben() throws {
        var o = Meldungsoptionen(text: "Grüße")
        o.dauer = 12
        o.grossbuchstaben = true
        try vergleiche(json(o), mit: "dauer-gross")
    }

    func testGeraeteschrift() throws {
        for (name, wert) in [("links", SendenHAusrichtung.links),
                             ("mittig", .mittig), ("rechts", .rechts)] {
            var o = Meldungsoptionen(text: "Hallo")
            o.weg = .text
            o.waagrecht = wert
            o.senkrecht = .unten
            try vergleiche(json(o), mit: "geraeteschrift-\(name)")
        }
    }

    func testLaufschrift() throws {
        var o = Meldungsoptionen(text: "Dieser Text ist viel zu lang für zweiundfünfzig Pixel")
        o.tempo = .mittel
        try vergleiche(json(o), mit: "laufschrift-mittel")
    }

    /// Die Entscheidung „passt oder läuft" hängt an der Breite des stehenden
    /// Falls, nicht an „Icon mitscrollen".
    func testPasstHaengtNichtAmMitlaufendenIcon() {
        var o = Meldungsoptionen(text: "Ziemlich langer Text")
        o.iconLaeuftMit = false
        let ohne = Meldungsbau.passt(o, mitIcon: true)
        o.iconLaeuftMit = true
        XCTAssertEqual(Meldungsbau.passt(o, mitIcon: true), ohne)
    }
}
```

- [ ] **Schritt 4: Die Tests laufen lassen, damit die Schnappschüsse entstehen**

Ausführen: `swift test --filter MeldungsbauTests`
Erwartet: Fehlschläge mit „Schnappschuss … neu angelegt". Das ist der gewollte erste Lauf.

- [ ] **Schritt 5: Die Schnappschüsse ansehen**

Ausführen: `ls Tests/TC002AppTests/Schnappschuesse/ && cat Tests/TC002AppTests/Schnappschuesse/senkrecht-oben-rand0.json`

Prüfen: Die Datei enthält `draw`-Befehle. Bei `senkrecht-oben-rand0` muss die kleinste `y` null sein, bei `senkrecht-unten-rand0` muss die größte `y` fünfzehn sein. Stimmt das nicht, ist die Herauslösung falsch und nicht der Schnappschuss.

- [ ] **Schritt 6: Die Tests erneut laufen lassen**

Ausführen: `swift test --filter MeldungsbauTests`
Erwartet: alle grün.

- [ ] **Schritt 7: Die Sendeansicht auf den neuen Bau umstellen**

In `Sources/TC002App/SendenView.swift` **entfernen**: `textY`, `textPuffer`, `feld`, `passt`, `textX`, `textBreite`, `textblock`, `geraeteAusrichtung`, `geraeteVertikal`, `gebauterRahmen()`. Die Aufzählungen `SendenHAusrichtung`, `SendenVAusrichtung`, `SendeWeg`, `Lauftempo` bleiben vorerst, wo sie sind.

**Hinzufügen** an ihrer Stelle:

```swift
    /// Die Optionen dieser Ansicht als Wertetyp — die einzige Stelle, an der
    /// aus Ansichtszustand ein Auftrag wird.
    private var optionen: Meldungsoptionen {
        Meldungsoptionen(text: text, weg: weg, schrift: schrift, groesse: groesse,
                         fett: fett, farbe: farbeHex, grossbuchstaben: grossbuchstaben,
                         waagrecht: horizontal, senkrecht: vertikal, rand: rand,
                         abstand: luecke, tempo: tempo, iconLaeuftMit: iconLaeuftMit,
                         dauer: dauer)
    }

    private var mitIcon: Bool { gewaehltesIcon != nil }
    private var passt: Bool { Meldungsbau.passt(optionen, mitIcon: mitIcon) }
    private var feld: Pixelfeld { Meldungsbau.feld(optionen, mitIcon: mitIcon) }
    private var textBreite: Int { Meldungsbau.breite(optionen) }
    private var flaecheX: Int { Meldungsbau.flaecheX(mitIcon: mitIcon) }
    private var flaecheBreite: Int { Meldungsbau.flaecheBreite(mitIcon: mitIcon) }
    private var textPuffer: Pixelfeld { Meldungsbau.puffer(optionen) }

    private func gebauterRahmen() throws -> Frame {
        try Meldungsbau.rahmen(optionen, icon: gewaehltesIcon, sammlung: sammlung,
                               vorberechnet: laufschriftURI)
    }
```

Im `.task(id: laufschriftSchluessel)` den Aufruf von `Textraster.laufschriftEinzelbilder` durch `Meldungsbau.laufschriftBilder(optionen, iconBilder: iconBilder)` ersetzen. Die eingesammelten Einzelwerte davor entfallen; stattdessen wird `optionen` und `iconRaster` vor dem `Task.detached` in lokale Konstanten genommen.

- [ ] **Schritt 8: Bauen und alle Tests laufen lassen**

Ausführen: `swift build && swift test`
Erwartet: fehlerfrei, alle Tests grün, die Schnappschüsse unverändert.

- [ ] **Schritt 9: Am Bildschirm gegenprüfen**

Ausführen: `./build.sh`

Die App starten, unter „Senden" die Ausrichtung und den Rand durchschalten und mit dem vergleichen, was vorher war. Die Vorschau muss sich genauso verhalten wie zuvor. **Nicht senden** — die Uhr bleibt aus dem Spiel.

- [ ] **Schritt 10: Einchecken**

```bash
git add Sources/TC002App/Meldungsbau.swift Sources/TC002App/SendenView.swift \
        Tests/TC002AppTests/MeldungsbauTests.swift Tests/TC002AppTests/Schnappschuesse
git commit -m "refactor(senden): Rahmenbau aus der Ansicht geloest, mit Schnappschuessen festgenagelt"
```

---

### Aufgabe 2: Den Rahmenbau in den Kern verschieben

Jetzt, da die Rechnungen festgenagelt sind, wandern sie dorthin, wo beide Oberflächen und das Kommandozeilenwerkzeug sie erreichen. Das Werkzeug verliert dabei seinen eigenen Nachbau.

**Dateien:**
- Verschieben: `Sources/TC002App/Meldungsbau.swift` → `Sources/TC002Core/Meldungsbau.swift`
- Verschieben: `Tests/TC002AppTests/MeldungsbauTests.swift` → `Tests/TC002CoreTests/MeldungsbauTests.swift`
- Verschieben: `Tests/TC002AppTests/Schnappschuesse/` → `Tests/TC002CoreTests/Schnappschuesse/`
- Löschen: `Sources/TC002CLI/Meldungsbau.swift`
- Ändern: `Sources/TC002App/SendenView.swift` (die vier Aufzählungen ziehen mit)
- Ändern: `Sources/TC002CLI/Optionen.swift`, `Sources/TC002CLI/main.swift`
- Ändern: `Tests/TC002CLITests/OptionenTests.swift`
- Ändern: `Sources/TC002App/MeldungsplatzView.swift` (Verschiebung von `MeldungsplatzWahl`)

**Schnittstellen:**
- Verbraucht: `Meldungsoptionen`, `Meldungsbau` aus Aufgabe 1.
- Erzeugt: dieselben Typen, nun `public` in `TC002Core`. Zusätzlich `public enum MeldungsplatzWahl { static let anzahl = 5; static func name(fuer: Int) -> String }`.

- [ ] **Schritt 1: Verschieben und öffentlich machen**

```bash
git mv Sources/TC002App/Meldungsbau.swift Sources/TC002Core/Meldungsbau.swift
git mv Tests/TC002AppTests/MeldungsbauTests.swift Tests/TC002CoreTests/MeldungsbauTests.swift
git mv Tests/TC002AppTests/Schnappschuesse Tests/TC002CoreTests/Schnappschuesse
```

In `Sources/TC002Core/Meldungsbau.swift`: `import TC002Core` entfernen, `struct Meldungsoptionen` zu `public struct`, `enum Meldungsbau` zu `public enum`, jede Eigenschaft und Funktion darin `public`. Ein `public init` für `Meldungsoptionen` mit denselben Vorgaben ergänzen, weil der abgeleitete Initialisierer außerhalb des Moduls nicht sichtbar ist.

Die vier Aufzählungen `SendenHAusrichtung`, `SendenVAusrichtung`, `SendeWeg`, `Lauftempo` aus dem Kopf von `SendenView.swift` in dieselbe Datei verschieben und `public` machen. Ihre `rawValue`-Zeichenketten bleiben **unverändert**.

In `Tests/TC002CoreTests/MeldungsbauTests.swift`: `@testable import TC002App` und `import TC002Core` ersetzen durch `@testable import TC002Core`.

- [ ] **Schritt 2: Tests laufen lassen**

Ausführen: `swift test --filter MeldungsbauTests`
Erwartet: alle grün, **ohne** dass ein Schnappschuss neu angelegt wird. Wird einer neu angelegt, wurde der Ordner nicht mitverschoben.

- [ ] **Schritt 3: `MeldungsplatzWahl` in den Kern**

Die Aufzählung aus `Sources/TC002App/MeldungsplatzView.swift` herauslösen und in `Sources/TC002Core/Meldungsbau.swift` ans Ende setzen:

```swift
/// Die fünf Plätze, unter denen diese App Anzeigen auf der Uhr ablegt.
///
/// Der Name ist zugleich der Bezeichner der Anzeige auf dem Gerät. Wer ihn
/// ändert, findet die alten Anzeigen nicht mehr und kann sie nicht mehr löschen.
public enum MeldungsplatzWahl {
    public static let anzahl = 5
    public static func name(fuer platz: Int) -> String { "meldung\(platz)" }
}
```

In `MeldungsplatzView.swift` die alte Fassung entfernen.

- [ ] **Schritt 4: Das Kommandozeilenwerkzeug umstellen**

`Sources/TC002CLI/Meldungsbau.swift` löschen. In `Sources/TC002CLI/Optionen.swift` die Aufzählungen `Waagrecht`, `Senkrecht` und `Tempo` entfernen und stattdessen die Felder auf die Kerntypen setzen: `waagrecht: SendenHAusrichtung`, `senkrecht: SendenVAusrichtung`, `tempo: Lauftempo`. Die Zuordnung der Kommandozeilenwörter bleibt: `--links`/`--left` auf `.links`, `--zentriert`/`--center` auf `.mittig`, `--rechts`/`--right` auf `.rechts`, `--oben`/`--top` auf `.oben`, `--mitte`/`--middle` auf `.mittig`, `--unten`/`--bottom` auf `.unten`.

Dazu eine Abbildung auf den gemeinsamen Wertetyp:

```swift
    /// Die Optionen der Kommandozeile als das, was der Kern versteht.
    var meldung: Meldungsoptionen {
        var o = Meldungsoptionen(text: "")
        o.weg = geraeteschrift ? .text : .pixel
        o.schrift = schrift
        o.groesse = groesse
        o.fett = fett
        o.farbe = farbe
        o.waagrecht = waagrecht
        o.senkrecht = senkrecht
        o.rand = rand
        o.abstand = abstand
        o.tempo = tempo
        o.dauer = dauer
        return o
    }
```

In `main.swift` den Aufruf ersetzen:

```swift
        var m = optionen.meldung
        m.text = text
        let rahmen = try Meldungsbau.rahmen(m, icon: icon, sammlung: sammlung)
```

`Optionen.zerlegt` wendet `uppercased()` bereits auf den Text an; `grossbuchstaben` bleibt deshalb im Wertetyp auf `false`, sonst würde zweimal umgewandelt.

- [ ] **Schritt 5: Die Tests des Werkzeugs anpassen**

In `Tests/TC002CLITests/OptionenTests.swift` die drei Aufrufe von `Meldungsbau.rahmen(text:optionen:icon:sammlung:)` auf die neue Form umstellen:

```swift
        var m = o.meldung
        m.text = "Hi"
        let rahmen = try Meldungsbau.rahmen(m, icon: nil, sammlung: sammlung())
```

`import TC002Core` steht dort bereits.

- [ ] **Schritt 6: Die Aufzählungen als Dateiformat festnageln**

An `Tests/TC002CoreTests/MeldungsbauTests.swift` anhängen:

```swift
    /// Die `rawValue`-Zeichenketten sind ein Dateiformat: `@AppStorage` legt sie
    /// so ab. Wer sie ändert, macht die Einstellungen einer laufenden
    /// Installation unlesbar — die Ansicht fiele wortlos auf ihre Vorgabe
    /// zurück, und niemand wüsste warum.
    func testAufzaehlungenBehaltenIhreZeichenketten() {
        XCTAssertEqual(SendeWeg.allCases.map(\.rawValue), ["pixel", "text"])
        XCTAssertEqual(SendenHAusrichtung.allCases.map(\.rawValue), ["links", "mittig", "rechts"])
        XCTAssertEqual(SendenVAusrichtung.allCases.map(\.rawValue), ["oben", "mittig", "unten"])
        XCTAssertEqual(Lauftempo.allCases.map(\.rawValue), ["langsam", "mittel", "schnell"])
    }

    /// Der Name des Meldungsplatzes ist der Bezeichner der Anzeige auf dem
    /// Gerät. Ändert er sich, findet die App ihre alten Anzeigen nicht mehr und
    /// kann sie auch nicht mehr löschen.
    func testMeldungsplatzNamenBleiben() {
        XCTAssertEqual(MeldungsplatzWahl.anzahl, 5)
        XCTAssertEqual((1...5).map(MeldungsplatzWahl.name(fuer:)),
                       ["meldung1", "meldung2", "meldung3", "meldung4", "meldung5"])
    }
```

- [ ] **Schritt 7: Alles bauen und prüfen**

Ausführen: `swift build && swift test && python3 scripts/texte-sammeln.py --pruefen`
Erwartet: fehlerfrei, alle Tests grün, `0 ohne Uebersetzung`.

- [ ] **Schritt 8: Das Werkzeug gegenprüfen**

Ausführen: `./build.sh && build/MQTT-TC002.app/Contents/MacOS/mqtttc002 senden "Hallo" --rechts --unten --trocken`
Erwartet: dieselbe Ausgabe wie vor dem Umbau. **Nicht ohne `--trocken` aufrufen.**

- [ ] **Schritt 9: Einchecken**

```bash
git add -A Sources Tests
git commit -m "refactor(core): Rahmenbau in den Kern, Nachbau im Werkzeug entfaellt"
```

---

### Aufgabe 3: `AppZustand` nach `TC002Modell`, Paket um iOS erweitern

**Dateien:**
- Verschieben: `Sources/TC002App/AppZustand.swift` → `Sources/TC002Modell/AppZustand.swift`
- Verschieben: `Tests/TC002AppTests/AppZustandTests.swift` → `Tests/TC002ModellTests/AppZustandTests.swift`
- Ändern: `Package.swift`
- Ändern: alle Dateien in `Sources/TC002App/`, die `AppZustand` benutzen (Import ergänzen)

**Schnittstellen:**
- Verbraucht: `TC002Core` in ganzer Breite.
- Erzeugt: Bibliothek `TC002Modell` mit `public final class AppZustand`. Zusätzlich zwei neue Methoden für den Lebenszyklus unter iOS: `public func inDenHintergrund()` und `public func ausDemHintergrund()`.

- [ ] **Schritt 1: `Package.swift` umschreiben**

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TC002",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        // Der Name des Produkts ist der Name der Datei — so heisst das Werkzeug
        // auf der Kommandozeile `mqtttc002` und nicht `TC002CLI`.
        .executable(name: "mqtttc002", targets: ["TC002CLI"]),
        // Fuer das iOS-Projekt, das dieses Paket ueber xcodegen einbindet.
        .library(name: "TC002Core", targets: ["TC002Core"]),
        .library(name: "TC002Modell", targets: ["TC002Modell"]),
    ],
    targets: [
        .target(name: "TC002Core", swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "TC002Modell", dependencies: ["TC002Core"],
                swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "TC002App", dependencies: ["TC002Core", "TC002Modell"],
                          swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "TC002CLI", dependencies: ["TC002Core"],
                          swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "TC002CoreTests", dependencies: ["TC002Core"],
                    swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "TC002ModellTests", dependencies: ["TC002Modell"],
                    swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "TC002AppTests", dependencies: ["TC002App"],
                    swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "TC002CLITests", dependencies: ["TC002CLI"],
                    swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
```

- [ ] **Schritt 2: Verschieben und öffentlich machen**

```bash
mkdir -p Sources/TC002Modell Tests/TC002ModellTests
git mv Sources/TC002App/AppZustand.swift Sources/TC002Modell/AppZustand.swift
git mv Tests/TC002AppTests/AppZustandTests.swift Tests/TC002ModellTests/AppZustandTests.swift
```

In `AppZustand.swift`: `final class AppZustand` zu `public final class AppZustand`, alle Eigenschaften und Methoden, die die Oberfläche benutzt, `public`, dazu ein `public init()`. Die verschachtelten Typen `Brokerstand` und `Anzeigenquelle` ebenfalls `public`.

In `Tests/TC002ModellTests/AppZustandTests.swift`: `@testable import TC002App` zu `@testable import TC002Modell`.

In allen Dateien unter `Sources/TC002App/`, die `AppZustand` erwähnen: `import TC002Modell` ergänzen.

- [ ] **Schritt 3: Die Lebenszyklus-Methoden ergänzen**

Ans Ende von `AppZustand.swift`, vor die schließende Klammer:

```swift
    /// Die App geht in den Hintergrund. Unter iOS überlebt eine offene
    /// MQTT-Verbindung das nicht: Das System friert den Prozess ein, die
    /// Verbindung stirbt unbemerkt, und beim Zurückkommen hielte sich die App
    /// für verbunden. Also ausdrücklich beenden.
    ///
    /// Auf dem Mac wird das nie gerufen — dort läuft die App weiter.
    public func inDenHintergrund() {
        horchenBeenden()
    }

    /// Die App kommt zurück. Der Zuhörer wird neu aufgebaut, sofern es etwas
    /// zum Zuhören gibt.
    public func ausDemHintergrund() {
        horchenAbgleichen()
    }
```

Gibt es `horchenBeenden()` noch nicht, wird es aus dem bestehenden Abbau in `horchenAbgleichen()` herausgelöst; die Schleife über die laufenden Abonnenten samt `beenden()` und das Leeren der Sammlung kommen dorthin.

- [ ] **Schritt 4: Bauen und prüfen**

Ausführen: `swift build && swift test`
Erwartet: fehlerfrei, alle 159 Tests plus die aus Aufgabe 1 grün.

- [ ] **Schritt 5: Die Mac-App gegenprüfen**

Ausführen: `./build.sh`

Starten, unter „Verbindung" eine Uhr abfragen, unter „Anzeigen" nachsehen, ob das Protokoll läuft. Die App muss sich genau wie zuvor verhalten. Dies ist der letzte Punkt, an dem ein Rückzug nichts kostet.

- [ ] **Schritt 6: Einchecken**

```bash
git add -A Package.swift Sources Tests
git commit -m "refactor: AppZustand nach TC002Modell, Paket traegt jetzt auch iOS"
```

---

### Aufgabe 4: Das iOS-Projekt, leer aber lauffähig

Deliverable: eine App, die im Simulator startet und „Hallo" zeigt. Keine Funktion, aber der ganze Bauweg steht.

**Dateien:**
- Anlegen: `project.yml`
- Anlegen: `Sources/TC002iOS/App.swift`
- Anlegen: `Resources/AppIconiOS.xcassets/AppIcon.appiconset/Contents.json` samt PNG-Dateien
- Ändern: `.gitignore`
- Ändern: `CLAUDE.md`

**Schnittstellen:**
- Verbraucht: die Bibliotheken `TC002Core` und `TC002Modell` aus Aufgabe 3.
- Erzeugt: das Schema `MQTT-TC002-iOS`, baubar mit `xcodebuild`.

- [ ] **Schritt 1: xcodegen installieren**

Ausführen: `brew install xcodegen && xcodegen --version`
Erwartet: eine Versionsnummer.

- [ ] **Schritt 2: `project.yml` anlegen**

```yaml
name: MQTT-TC002-iOS
options:
  bundleIdPrefix: cloud.eriks
  deploymentTarget:
    iOS: "17.0"
  createIntermediateGroups: true

packages:
  TC002:
    path: .

targets:
  MQTT-TC002-iOS:
    type: application
    platform: iOS
    sources:
      - path: Sources/TC002iOS
    resources:
      - path: Icons
      - path: Resources/Schriften
      - path: Resources/Sprachen
    dependencies:
      - package: TC002
        product: TC002Core
      - package: TC002
        product: TC002Modell
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: cloud.eriks.mqtt-tc002
        DEVELOPMENT_TEAM: 25ZK4SS655
        CODE_SIGN_STYLE: Automatic
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        SWIFT_VERSION: "5.0"
        DEVELOPMENT_ASSET_PATHS: ""
    info:
      path: build/InfoiOS.plist
      properties:
        CFBundleName: MQTT-TC002
        CFBundleDisplayName: MQTT-TC002
        CFBundleDevelopmentRegion: de
        UILaunchScreen: {}
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
        # Ohne diesen Eintrag erreicht die App weder Uhr noch Broker, und die
        # Fehlermeldung zeigt in die falsche Richtung — derselbe Fall wie auf
        # dem Mac.
        NSLocalNetworkUsageDescription: >-
          Die App spricht die Pixeluhr und den MQTT-Broker in Ihrem Heimnetz an.
```

- [ ] **Schritt 3: Den Programmeinstieg anlegen**

`Sources/TC002iOS/App.swift`:

```swift
import SwiftUI
import TC002Core
import TC002Modell

@main
struct TC002iOSApp: App {
    /// Die Schriften muessen vor der ersten Ansicht angemeldet sein: Die Liste
    /// der Schriftarten ist eine statische Eigenschaft und wird nur einmal
    /// ausgewertet. In `.onAppear` waere es zu spaet.
    init() {
        Schriften.registrieren()
    }

    var body: some Scene {
        WindowGroup {
            Text("Hallo")
        }
    }
}
```

- [ ] **Schritt 4: Das Programmsymbol erzeugen**

Aus dem vorhandenen Symbol die für iOS 17 nötige Größe erzeugen (1024×1024, ohne Transparenz):

```bash
mkdir -p Resources/AppIconiOS.xcassets/AppIcon.appiconset
sips -s format png --resampleHeightWidth 1024 1024 \
     Resources/AppIcon.icon/Assets/*.png \
     --out Resources/AppIconiOS.xcassets/AppIcon.appiconset/icon-1024.png
```

Gibt es dort keine brauchbare PNG-Vorlage, wird sie aus dem gebauten Mac-Symbol gewonnen:

```bash
sips -s format png -Z 1024 build/MQTT-TC002.app/Contents/Resources/AppIcon.icns \
     --out Resources/AppIconiOS.xcassets/AppIcon.appiconset/icon-1024.png
```

`Resources/AppIconiOS.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images" : [
    { "filename" : "icon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`Resources/AppIconiOS.xcassets/Contents.json`:

```json
{ "info" : { "author" : "xcode", "version" : 1 } }
```

In `project.yml` unter `resources` den Katalog ergänzen: `- path: Resources/AppIconiOS.xcassets`.

- [ ] **Schritt 5: Projekt erzeugen und bauen**

```bash
xcodegen generate
xcodebuild -project MQTT-TC002-iOS.xcodeproj -scheme MQTT-TC002-iOS \
           -destination 'generic/platform=iOS Simulator' build
```

Erwartet: `** BUILD SUCCEEDED **`.

- [ ] **Schritt 6: Die erzeugte Projektdatei aus der Versionsverwaltung halten**

An `.gitignore` anhängen:

```
MQTT-TC002-iOS.xcodeproj/
build/InfoiOS.plist
```

- [ ] **Schritt 7: Die Arbeitsregeln ergänzen**

In `CLAUDE.md` nach dem Abschnitt „Fassungsnummer" einfügen:

```markdown
## Die iOS-Fassung

`project.yml` beschreibt das Xcode-Projekt; `xcodegen generate` erzeugt es.
Die `.xcodeproj` wird **nicht** eingecheckt — wer eine Quelldatei hinzufügt,
ändert die YAML und erzeugt neu, statt in erzeugtem XML zu schneiden.

    brew install xcodegen        # einmalig
    xcodegen generate
    xcodebuild -project MQTT-TC002-iOS.xcodeproj -scheme MQTT-TC002-iOS \
               -destination 'generic/platform=iOS Simulator' build

Aufs Gerät kommt sie aus Xcode. `TC002App` und `TC002CLI` binden AppKit ein und
sind nur unter macOS übersetzbar; das iOS-Ziel hängt ausschließlich an den
Bibliotheken `TC002Core` und `TC002Modell`.
```

- [ ] **Schritt 8: Einchecken**

```bash
git add project.yml Sources/TC002iOS Resources/AppIconiOS.xcassets .gitignore CLAUDE.md
git commit -m "feat(ios): Projektgeruest, baut gegen den Simulator"
```

---

### Aufgabe 5: Der Reiter „Verbindung"

Zuerst dieser, weil sich ohne eingerichtete Uhr nichts ausprobieren lässt.

**Dateien:**
- Anlegen: `Sources/TC002iOS/VerbindungiOS.swift`
- Ändern: `Sources/TC002iOS/App.swift`

**Schnittstellen:**
- Verbraucht: `AppZustand` mit `uhren`, `aktiveID`, `uhrHinzufuegen(host:)`, `uhrEntfernen(_:)`, `abfragen(_:)`, `adresseGeaendert(_:)`, `brokerHost`, `brokerPort`, `benutzer`, `kennwort`, `brokerSichernUndPruefen()`, `brokerStand`, `verbunden`, `fehler`.
- Erzeugt: `struct VerbindungiOS: View` mit `init(zustand: AppZustand)`.

- [ ] **Schritt 1: Die Ansicht anlegen**

`Sources/TC002iOS/VerbindungiOS.swift`:

```swift
import SwiftUI
import TC002Core
import TC002Modell

/// Uhren und Broker einrichten. Eine Liste im Hochformat; die Mac-Fassung
/// bringt dieselben Felder in einem Fenster unter, hier stehen sie in
/// Abschnitten untereinander.
struct VerbindungiOS: View {
    @Bindable var zustand: AppZustand
    @State private var neueAdresse = ""

    var body: some View {
        NavigationStack {
            Form {
                uhrenAbschnitt
                brokerAbschnitt
            }
            .navigationTitle("Verbindung")
        }
    }

    private var uhrenAbschnitt: some View {
        Section("Uhren") {
            ForEach(zustand.uhren) { uhr in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(uhr.name)
                        Spacer()
                        if zustand.verbunden[uhr.id] == true {
                            Image(systemName: "checkmark.circle").foregroundStyle(.green)
                        } else if zustand.verbunden[uhr.id] == false {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        }
                    }
                    Text(uhr.host).font(.caption).foregroundStyle(.secondary)
                    Text(uhr.praefix.isEmpty ? lok("noch nicht abgefragt") : uhr.praefix)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Abfragen") { zustand.abfragen(uhr.id) }
                        Spacer()
                        Button("Entfernen", role: .destructive) { zustand.uhrEntfernen(uhr.id) }
                    }
                    .buttonStyle(.bordered)
                    .font(.callout)
                }
            }
            HStack {
                TextField("Adresse einer weiteren Uhr", text: $neueAdresse)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Hinzufügen") { hinzufuegen() }
                    .disabled(neueAdresse.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("Das Präfix ermittelt die App selbst — es ist das eingestellte plus die letzten vier Stellen der MAC-Adresse.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var brokerAbschnitt: some View {
        Section("Broker") {
            LabeledContent("Adresse") {
                TextField("Adresse", text: $zustand.brokerHost)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            LabeledContent("Port") {
                TextField("Port", text: $zustand.brokerPort)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
            }
            LabeledContent("Benutzer") {
                TextField("Benutzer", text: $zustand.benutzer)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            LabeledContent("Kennwort") {
                SecureField("Kennwort", text: $zustand.kennwort)
                    .multilineTextAlignment(.trailing)
            }
            Button("Sichern und prüfen") { zustand.brokerSichernUndPruefen() }
            standText
            Text("Das Kennwort liegt im Schlüsselbund, nicht in den Einstellungen.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var standText: some View {
        switch zustand.brokerStand {
        case .unbekannt: Text("noch nicht geprüft").foregroundStyle(.secondary)
        case .laeuft: HStack { ProgressView(); Text("wird geprüft …") }
        case .angenommen: Text("angenommen").foregroundStyle(.green)
        case .abgelehnt(let grund): Text(grund).foregroundStyle(.red)
        }
    }

    private func hinzufuegen() {
        let adresse = neueAdresse.trimmingCharacters(in: .whitespaces)
        guard !adresse.isEmpty else { return }
        zustand.uhrHinzufuegen(host: adresse)
        neueAdresse = ""
    }
}
```

- [ ] **Schritt 2: In den Einstieg einhängen**

In `Sources/TC002iOS/App.swift` den Rumpf ersetzen:

```swift
@main
struct TC002iOSApp: App {
    @State private var zustand = AppZustand()
    @Environment(\.scenePhase) private var phase

    init() {
        Schriften.registrieren()
    }

    var body: some Scene {
        WindowGroup {
            // `Tab(_:systemImage:)` gibt es erst ab iOS 18; die Untergrenze
            // ist 17, deshalb die herkoemmliche Form mit `.tabItem`.
            TabView {
                VerbindungiOS(zustand: zustand)
                    .tabItem { Label("Verbindung", systemImage: "antenna.radiowaves.left.and.right") }
            }
            .onChange(of: phase) { _, neu in
                // Eine offene MQTT-Verbindung ueberlebt den Hintergrund nicht.
                switch neu {
                case .background: zustand.inDenHintergrund()
                case .active:     zustand.ausDemHintergrund()
                default:          break
                }
            }
        }
    }
}
```

- [ ] **Schritt 3: Die Fehlerleiste anlegen**

`Sources/TC002iOS/FehlerleisteiOS.swift`:

```swift
import SwiftUI
import TC002Modell

/// Zeigt `AppZustand.fehler` als schmale Leiste unter der Titelleiste.
///
/// Ausdrücklich kein Blatt: Ein Blatt verdeckte die Vorschau, und die
/// Meldungen sind Hinweise, keine Entscheidungen. Wegtippen räumt sie weg;
/// im Protokoll unter „Anzeigen" stehen sie ohnehin weiter.
struct FehlerleisteiOS: View {
    @Bindable var zustand: AppZustand

    var body: some View {
        if let fehler = zustand.fehler {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(fehler).font(.callout).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    zustand.fehler = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
```

Sie kommt in allen drei Reitern unmittelbar unter die Titelleiste. In
`VerbindungiOS` dafür den `Form`-Rumpf in ein `VStack(spacing: 0)` setzen, mit
`FehlerleisteiOS(zustand: zustand)` davor.

- [ ] **Schritt 4: Bauen**

```bash
xcodegen generate
xcodebuild -project MQTT-TC002-iOS.xcodeproj -scheme MQTT-TC002-iOS \
           -destination 'generic/platform=iOS Simulator' build
```

Erwartet: `** BUILD SUCCEEDED **`.

- [ ] **Schritt 5: Übersetzung prüfen**

Ausführen: `python3 scripts/texte-sammeln.py --pruefen`

Der Sammler liest `Sources/TC002App`, `Sources/TC002CLI` und `Sources/TC002Core`. In `scripts/texte-sammeln.py` die Liste `QUELLEN` um `WURZEL / "Sources" / "TC002iOS"` und `WURZEL / "Sources" / "TC002Modell"` erweitern. Danach erneut laufen lassen und jeden gemeldeten Text in `Resources/Sprachen/en.lproj/Localizable.strings` ergänzen, bis `0 ohne Uebersetzung` dasteht.

- [ ] **Schritt 6: Einchecken**

```bash
git add Sources/TC002iOS scripts/texte-sammeln.py Resources/Sprachen
git commit -m "feat(ios): Reiter Verbindung samt Fehlerleiste"
```

---

### Aufgabe 6: Icons wählen und nachladen

Ein Blatt zur Auswahl und das Nachladen über die LaMetric-Nummer. **Kein
Editor** — Icons werden am Schreibtisch gemalt, nicht auf dem Telefon.

Der Grundschatz reist im Bündel mit (`Icons/`, in Aufgabe 4 als Ressource
eingetragen). Nachgeladene landen im App-eigenen Ordner. Beides zusammen sieht
`Iconsammlung(schreibordner:leseordner:)`.

**Dateien:**
- Anlegen: `Sources/TC002iOS/IconauswahliOS.swift`

**Schnittstellen:**
- Verbraucht: `Iconsammlung`, `Iconordner`, `Icon`, `Array<Icon>.gefiltert(nach:)`, `Bildraster.lesen` aus `TC002Core`.
- Erzeugt: `struct IconauswahliOS: View` mit `init(gewaehlt: Binding<Icon?>)`, und `struct IconbildiOS: View` zum Zeichnen eines 8×8-Icons.

- [ ] **Schritt 1: Das Icon-Bildchen anlegen**

`Sources/TC002iOS/IconauswahliOS.swift`, erster Teil:

```swift
import SwiftUI
import TC002Core

/// Ein 8×8-Icon als Vorschau. Zeigt das erste Einzelbild; animierte Icons
/// laufen hier nicht, das wäre in einer Liste nur Unruhe.
struct IconbildiOS: View {
    let datei: URL
    var kante: Double = 3

    var body: some View {
        Canvas { kontext, _ in
            guard let bilder = try? Bildraster.lesen(datei, breite: 8, hoehe: 8),
                  let erstes = bilder.first else { return }
            for y in 0..<8 {
                for x in 0..<8 {
                    guard let farbe = erstes[y * 8 + x], let c = Color(hex: farbe) else { continue }
                    kontext.fill(Path(CGRect(x: Double(x) * kante, y: Double(y) * kante,
                                             width: kante, height: kante)), with: .color(c))
                }
            }
        }
        .frame(width: 8 * kante, height: 8 * kante)
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
```

- [ ] **Schritt 2: Das Auswahlblatt anlegen**

Zweiter Teil derselben Datei:

```swift
/// Blatt zur Icon-Auswahl. Suchen, wählen, abwählen, und über die
/// LaMetric-Nummer nachladen. Malen geht hier nicht — Icons werden am Mac
/// bearbeitet, ein 8×8-Raster mit dem Finger wäre keine Arbeitsfläche.
struct IconauswahliOS: View {
    @Binding var gewaehlt: Icon?
    @Environment(\.dismiss) private var schliessen

    @State private var vorhandene: [Icon] = []
    @State private var suche = ""
    @State private var lametricNummer = ""
    @State private var laedt = false
    @State private var meldung: String?

    /// Der Grundschatz wird gelesen, Nachgeladenes geschrieben.
    private var sammlung: Iconsammlung {
        Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("LaMetric-Nummer", text: $lametricNummer)
                            .keyboardType(.numberPad)
                        Button("Nachladen") { nachladen() }
                            .disabled(laedt || lametricNummer.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if let meldung {
                        Text(meldung).font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Nummer von developer.lametric.com — das Icon landet bei den eigenen.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button("Kein Icon") { gewaehlt = nil; schliessen() }
                    ForEach(vorhandene.gefiltert(nach: suche), id: \.nummer) { icon in
                        Button {
                            gewaehlt = icon
                            schliessen()
                        } label: {
                            HStack {
                                IconbildiOS(datei: icon.datei)
                                VStack(alignment: .leading) {
                                    Text(icon.name)
                                    Text(icon.nummer).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if gewaehlt?.nummer == icon.nummer {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
            .searchable(text: $suche, prompt: Text("Suchen"))
            .navigationTitle("Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { schliessen() }
            } }
            .onAppear { vorhandene = sammlung.alle() }
        }
    }

    /// Holt ein Icon über seine Nummer. Blockiert nicht den Hauptthread — der
    /// Abruf geht übers Netz und dauert.
    private func nachladen() {
        let nummer = lametricNummer.trimmingCharacters(in: .whitespaces)
        laedt = true
        meldung = nil
        let quelle = sammlung
        Task.detached {
            do {
                let icon = try quelle.holen(nummer: nummer)
                await MainActor.run {
                    vorhandene = quelle.alle()
                    gewaehlt = icon
                    meldung = lokf("%@ geholt.", icon.name)
                    lametricNummer = ""
                    laedt = false
                }
            } catch {
                await MainActor.run {
                    meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                    laedt = false
                }
            }
        }
    }
}
```

- [ ] **Schritt 3: Bauen**

```bash
xcodegen generate
xcodebuild -project MQTT-TC002-iOS.xcodeproj -scheme MQTT-TC002-iOS \
           -destination 'generic/platform=iOS Simulator' build
```

Erwartet: `** BUILD SUCCEEDED **`.

Schlägt es fehl, weil `Iconsammlung.holen(nummer:)` eine Sitzung verlangt: Die
Signatur lautet `holen(nummer:sitzung:)` mit `.shared` als Vorgabe — dann genügt
`try quelle.holen(nummer: nummer)`. Ist die Vorgabe nicht da, wird sie in
`Sources/TC002Core/Icons.swift` ergänzt, nicht am Aufruf vorbeigearbeitet.

- [ ] **Schritt 4: Übersetzung prüfen**

Ausführen: `python3 scripts/texte-sammeln.py --pruefen`
Erwartet: `0 ohne Uebersetzung`. Fehlende Texte in `Resources/Sprachen/en.lproj/Localizable.strings` ergänzen.

- [ ] **Schritt 5: Einchecken**

```bash
git add Sources/TC002iOS Resources/Sprachen
git commit -m "feat(ios): Icons waehlen und ueber die LaMetric-Nummer nachladen"
```

---

### Aufgabe 7: Der Reiter „Senden"

Der Kern der App, aufgebaut wie ein Nachrichtenfenster.

**Dateien:**
- Anlegen: `Sources/TC002iOS/SendeniOS.swift`
- Anlegen: `Sources/TC002iOS/FormatblattiOS.swift`
- Anlegen: `Sources/TC002iOS/VorschauiOS.swift`
- Anlegen: `Sources/TC002iOS/ZielauswahliOS.swift`
- Anlegen: `Sources/TC002iOS/Farbe.swift`
- Ändern: `Sources/TC002iOS/App.swift`

**Schnittstellen:**
- Verbraucht: `Meldungsoptionen`, `Meldungsbau`, `MeldungsplatzWahl`, `Iconsammlung`, `Iconordner`, `Bildraster`, `Pixelfeld` aus `TC002Core`; `AppZustand.senden(_:als:)`, `AppZustand.ziele()`, `AppZustand.anzeigeGemerkt(_:fuer:)` aus `TC002Modell`.
- Erzeugt: `struct SendeniOS: View`, `struct FormatblattiOS: View`, `struct VorschauiOS: View`.

- [ ] **Schritt 1: Die Vorschau anlegen**

`Sources/TC002iOS/VorschauiOS.swift`:

```swift
import SwiftUI
import TC002Core

/// Das Display, 52×16 Pixel, sechsfach vergroessert. Zeigt entweder ein
/// stehendes Feld oder spielt die Einzelbilder der Laufschrift ab.
struct VorschauiOS: View {
    let feld: Pixelfeld
    let icon: URL?
    let laufschriftBilder: [Bildraster.Einzelbild]?
    var kante: Double = 6

    var body: some View {
        TimelineView(.animation) { zeit in
            Canvas { kontext, _ in
                let punkte = punkteJetzt(zeit.date)
                for y in 0..<Pixelfeld.hoeheStandard {
                    for x in 0..<Pixelfeld.breiteStandard {
                        let farbe = punkte[y * Pixelfeld.breiteStandard + x]
                        guard let farbe, let c = Color(hex: farbe) else { continue }
                        kontext.fill(Path(CGRect(x: Double(x) * kante, y: Double(y) * kante,
                                                 width: kante - 0.5, height: kante - 0.5)),
                                     with: .color(c))
                    }
                }
            }
        }
        .frame(width: Double(Pixelfeld.breiteStandard) * kante,
               height: Double(Pixelfeld.hoeheStandard) * kante)
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    /// Bei Laufschrift das Einzelbild, das jetzt an der Reihe ist; sonst das
    /// stehende Feld mit eingesetztem Icon.
    private func punkteJetzt(_ jetzt: Date) -> [String?] {
        if let bilder = laufschriftBilder, !bilder.isEmpty {
            let gesamt = bilder.reduce(0.0) { $0 + $1.dauer }
            guard gesamt > 0 else { return bilder[0].pixel }
            var rest = jetzt.timeIntervalSince1970.truncatingRemainder(dividingBy: gesamt)
            for bild in bilder {
                rest -= bild.dauer
                if rest <= 0 { return bild.pixel }
            }
            return bilder[bilder.count - 1].pixel
        }
        var punkte = feld.punkteRoh
        if let icon, let bilder = try? Bildraster.lesen(icon, breite: 8, hoehe: 8), let erstes = bilder.first {
            for y in 0..<8 {
                for x in 0..<8 {
                    guard let p = erstes[y * 8 + x] else { continue }
                    punkte[(y + 4) * Pixelfeld.breiteStandard + x] = p
                }
            }
        }
        return punkte
    }
}
```

Die Farbhilfe liegt heute in `Sources/TC002App/VorschauView.swift:119`. Davon
ist `init?(hex:)` wortgetreu übertragbar, `hexWert` **nicht** — es benutzt
`NSColor`. `Sources/TC002iOS/Farbe.swift`:

```swift
import SwiftUI

extension Color {
    /// Wandelt "#RRGGBB" in eine Farbe. Ungültige Angaben ergeben nil.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let wert = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((wert >> 16) & 0xFF) / 255,
                  green: Double((wert >> 8) & 0xFF) / 255,
                  blue: Double(wert & 0xFF) / 255)
    }

    /// "#RRGGBB" aus der Farbe. Über sRGB, damit derselbe Farbwert
    /// herauskommt, den die Uhr später anzeigt. Die Mac-Fassung nimmt dafür
    /// `NSColor`; unter iOS heißt dasselbe `UIColor`, und die Komponenten
    /// kommen über `getRed(_:green:blue:alpha:)` statt über Eigenschaften.
    var hexWert: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
```

- [ ] **Schritt 2: Bauen**

```bash
xcodegen generate && xcodebuild -project MQTT-TC002-iOS.xcodeproj -scheme MQTT-TC002-iOS \
           -destination 'generic/platform=iOS Simulator' build
```

Erwartet: `** BUILD SUCCEEDED **`.

- [ ] **Schritt 3: Das Formatblatt anlegen**

`Sources/TC002iOS/FormatblattiOS.swift`:

```swift
import SwiftUI
import TC002Core

/// Alles, was man selten ändert. Auf dem Mac steht das in einer Leiste mit elf
/// Bedienelementen; auf einem Telefon geht das nicht, und untereinander
/// gestapelt verdeckte es die Vorschau.
struct FormatblattiOS: View {
    @Binding var weg: SendeWeg
    @Binding var schrift: String
    @Binding var groesse: Double
    @Binding var fett: Bool
    @Binding var grossbuchstaben: Bool
    @Binding var rand: Int
    @Binding var abstand: Int
    @Binding var tempo: Lauftempo
    @Binding var iconLaeuftMit: Bool
    @Environment(\.dismiss) private var schliessen

    /// Dieselbe Auswahl wie auf dem Mac. Nur diese wenigen, weil bei sechzehn
    /// Pixeln Höhe kaum eine Schrift sauber aufs Raster fällt.
    private static let schriften = ["Micro 5", "Silkscreen", "Tiny5", "Geneva",
                                    "Monaco", "Andale Mono", "Menlo", "PT Mono"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Weg", selection: $weg) {
                        Text("als Pixel").tag(SendeWeg.pixel)
                        Text("als Text").tag(SendeWeg.text)
                    }
                    .pickerStyle(.segmented)
                    Text(weg == .pixel
                         ? "Die App rastert selbst. Umlaute gehen, die Schrift ist frei wählbar."
                         : "Die Uhr setzt selbst, mit ihrer eingebauten Schrift. Die kennt keine Umlaute.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Schrift") {
                    Picker("Schriftart", selection: $schrift) {
                        ForEach(Self.schriften, id: \.self) { Text($0).tag($0) }
                    }
                    .disabled(weg == .text)
                    Stepper(lokf("Größe %d", Int(groesse)), value: $groesse, in: 6...16, step: 1)
                    Toggle("Fett", isOn: $fett).disabled(weg == .text)
                    Toggle("Großbuchstaben", isOn: $grossbuchstaben)
                }
                Section("Lage") {
                    Stepper(lokf("Rand %d", rand), value: $rand, in: 0...3)
                    Stepper(lokf("Abstand %d", abstand), value: $abstand, in: 0...3)
                }
                Section("Laufschrift") {
                    Picker("Tempo", selection: $tempo) {
                        Text("langsam").tag(Lauftempo.langsam)
                        Text("mittel").tag(Lauftempo.mittel)
                        Text("schnell").tag(Lauftempo.schnell)
                    }
                    .pickerStyle(.segmented)
                    Toggle("Icon mitscrollen", isOn: $iconLaeuftMit)
                    Text("Gilt nur, wenn der Text nicht ins Display passt.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { schliessen() }
            } }
        }
    }
}
```

- [ ] **Schritt 4: Die Sendeansicht anlegen**

`Sources/TC002iOS/SendeniOS.swift`:

```swift
import SwiftUI
import TC002Core
import TC002Modell

/// Der Kern der App, aufgebaut wie ein Nachrichtenfenster: die Vorschau oben
/// und sichtbar bleibend, Eingabe und Sendeknopf unten über der Tastatur. Wer
/// tippt, will sehen, was herauskommt — stünde die Vorschau unten, verdeckte
/// die Tastatur sie genau dann, wenn man sie braucht.
struct SendeniOS: View {
    @Bindable var zustand: AppZustand

    // Dieselben Schlüssel wie auf dem Mac. Wer sie ändert, verliert die
    // Einstellungen einer laufenden Installation.
    @AppStorage("senden.text") private var text = "Hallo"
    @AppStorage("senden.farbe") private var farbeHex = "#00FF66"
    @AppStorage("senden.schriftart") private var schrift = "Silkscreen"
    @AppStorage("senden.groesse") private var groesse = 8.0
    @AppStorage("senden.fett") private var fett = false
    @AppStorage("senden.luecke") private var luecke = 1
    @AppStorage("senden.grossbuchstaben") private var grossbuchstaben = false
    @AppStorage("senden.horizontal") private var horizontal: SendenHAusrichtung = .links
    @AppStorage("senden.vertikal") private var vertikal: SendenVAusrichtung = .oben
    @AppStorage("senden.rand") private var rand = 1
    @AppStorage("senden.weg") private var weg: SendeWeg = .pixel
    @AppStorage("senden.tempo") private var tempo: Lauftempo = .mittel
    @AppStorage("senden.iconmitlaufend") private var iconLaeuftMit = false
    @AppStorage("senden.icon") private var iconNummer = ""
    @AppStorage("senden.meldungsplatz") private var platz = 1
    @AppStorage("senden.dauer") private var dauerText = ""

    @State private var gewaehltesIcon: Icon?
    @State private var laufschriftFrames: [Bildraster.Einzelbild] = []
    @State private var laufschriftURI = ""
    @State private var laeuft = false
    @State private var zeigeFormat = false
    @State private var zeigeIcons = false
    @State private var zeigeZiele = false

    private var sammlung: Iconsammlung {
        Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert])
    }

    /// Leer oder 0 heisst: keine eigene Dauer, "duration" fehlt dann im Rahmen.
    private var dauer: Int? {
        guard let n = Int(dauerText.trimmingCharacters(in: .whitespaces)), n > 0 else { return nil }
        return n
    }

    /// Die einzige Stelle, an der aus Ansichtszustand ein Auftrag wird.
    private var optionen: Meldungsoptionen {
        Meldungsoptionen(text: text, weg: weg, schrift: schrift, groesse: groesse,
                         fett: fett, farbe: farbeHex, grossbuchstaben: grossbuchstaben,
                         waagrecht: horizontal, senkrecht: vertikal, rand: rand,
                         abstand: luecke, tempo: tempo, iconLaeuftMit: iconLaeuftMit,
                         dauer: dauer)
    }

    private var mitIcon: Bool { gewaehltesIcon != nil }
    private var passt: Bool { Meldungsbau.passt(optionen, mitIcon: mitIcon) }

    private var farbe: Binding<Color> {
        Binding(get: { Color(hex: farbeHex) ?? Color(red: 0, green: 1, blue: 0.4) },
                set: { farbeHex = $0.hexWert })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FehlerleisteiOS(zustand: zustand)
                ScrollView {
                    VStack(spacing: 14) {
                        VorschauiOS(feld: Meldungsbau.feld(optionen, mitIcon: mitIcon),
                                    icon: (weg == .text || passt) ? gewaehltesIcon?.datei : nil,
                                    laufschriftBilder: (weg == .pixel && !passt) ? laufschriftFrames : nil)
                        if weg == .pixel && !passt {
                            Text(lokf("Läuft durch: %d Einzelbilder", laufschriftFrames.count))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        platzUndDauer
                    }
                    .padding(.vertical, 12)
                }
                Divider()
                formatleiste
                eingabe
            }
            .navigationTitle(zustand.uhren.count > 1 ? zielName : "Senden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if zustand.uhren.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Ziel") { zeigeZiele = true }
                    }
                }
            }
        }
        .sheet(isPresented: $zeigeFormat) {
            FormatblattiOS(weg: $weg, schrift: $schrift, groesse: $groesse, fett: $fett,
                           grossbuchstaben: $grossbuchstaben, rand: $rand, abstand: $luecke,
                           tempo: $tempo, iconLaeuftMit: $iconLaeuftMit)
        }
        .sheet(isPresented: $zeigeIcons) {
            IconauswahliOS(gewaehlt: $gewaehltesIcon)
        }
        .sheet(isPresented: $zeigeZiele) {
            ZielauswahliOS(zustand: zustand)
        }
        .onAppear {
            if gewaehltesIcon == nil, !iconNummer.isEmpty {
                gewaehltesIcon = sammlung.alle().first { $0.nummer == iconNummer }
            }
        }
        .onChange(of: gewaehltesIcon?.nummer) { _, neu in iconNummer = neu ?? "" }
        .task(id: laufschriftSchluessel) { await laufschriftRechnen() }
    }

    private var zielName: String {
        let ziele = zustand.ziele()
        if ziele.count == 1 { return ziele[0].name }
        return lokf("an %d Uhren", ziele.count)
    }

    private var platzUndDauer: some View {
        HStack(spacing: 12) {
            Picker("Meldung", selection: $platz) {
                ForEach(1...MeldungsplatzWahl.anzahl, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            HStack(spacing: 4) {
                Text("Dauer")
                TextField("Uhr entscheidet", text: $dauerText)
                    .keyboardType(.numberPad)
                    .frame(width: 64)
                    .multilineTextAlignment(.trailing)
                Text("s")
            }
            .font(.callout)
        }
        .padding(.horizontal)
    }

    /// Was man ständig ändert, direkt erreichbar. Alles Übrige hinter „Format".
    private var formatleiste: some View {
        HStack(spacing: 14) {
            ColorPicker("Farbe", selection: farbe, supportsOpacity: false)
                .labelsHidden()
            Button { zeigeIcons = true } label: {
                if let icon = gewaehltesIcon {
                    IconbildiOS(datei: icon.datei, kante: 2.5)
                } else {
                    Image(systemName: "face.smiling")
                }
            }
            Picker("Ausrichtung", selection: $horizontal) {
                Image(systemName: "text.alignleft").tag(SendenHAusrichtung.links)
                Image(systemName: "text.aligncenter").tag(SendenHAusrichtung.mittig)
                Image(systemName: "text.alignright").tag(SendenHAusrichtung.rechts)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 150)
            Spacer()
            Button("Format") { zeigeFormat = true }
                .font(.callout)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var eingabe: some View {
        HStack(spacing: 8) {
            TextField("Text", text: $text, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await senden() }
            } label: {
                if laeuft {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
            }
            .disabled(laeuft || text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    /// Fasst alles zusammen, wovon die Laufschrift abhängt — damit die (nicht
    /// ganz billige) Berechnung nur bei einer tatsächlichen Änderung neu läuft.
    private var laufschriftSchluessel: String {
        "\(weg)|\(passt)|\(optionen.gesendeterText)|\(schrift)|\(groesse)|\(fett)|\(farbeHex)|\(tempo)|\(vertikal)|\(rand)|\(iconNummer)|\(iconLaeuftMit)|\(luecke)"
    }

    /// Mehrere hundert Einzelbilder rastern, als GIF kodieren, Base64 darüber —
    /// bei jedem Tastendruck. Das gehört nicht auf den Hauptthread, sonst
    /// stockt das Eingabefeld.
    private func laufschriftRechnen() async {
        guard weg == .pixel, !passt else {
            laufschriftFrames = []; laufschriftURI = ""; return
        }
        let o = optionen
        let iconBilder = gewaehltesIcon.flatMap { i -> [[String?]]? in
            try? Bildraster.lesenMitZeiten(i.datei, breite: 8, hoehe: 8).map(\.pixel)
        } ?? []
        let (frames, uri) = await Task.detached(priority: .userInitiated) {
            let frames = Meldungsbau.laufschriftBilder(o, iconBilder: iconBilder)
            let uri = (try? Bildraster.alsDatenURI(
                frames.map(\.pixel), breite: Pixelfeld.breiteStandard,
                hoehe: Pixelfeld.hoeheStandard, verzoegerung: o.tempo.bilddauer)) ?? ""
            return (frames, uri)
        }.value
        guard !Task.isCancelled else { return }
        laufschriftFrames = frames
        laufschriftURI = uri
    }

    private func senden() async {
        laeuft = true
        defer { laeuft = false }
        do {
            let rahmen = try Meldungsbau.rahmen(optionen, icon: gewaehltesIcon,
                                                sammlung: sammlung, vorberechnet: laufschriftURI)
            await zustand.senden(rahmen, als: MeldungsplatzWahl.name(fuer: platz))
        } catch {
            zustand.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }
}
```

Dazu die Zielauswahl, `Sources/TC002iOS/ZielauswahliOS.swift`:

```swift
import SwiftUI
import TC002Core
import TC002Modell

/// An welche Uhren gesendet wird. Erscheint nur, wenn es mehr als eine gibt.
struct ZielauswahliOS: View {
    @Bindable var zustand: AppZustand
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            List {
                ForEach(zustand.uhren) { uhr in
                    Button {
                        if zustand.zielIDs.contains(uhr.id) {
                            zustand.zielIDs.remove(uhr.id)
                        } else {
                            zustand.zielIDs.insert(uhr.id)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(uhr.name)
                                Text(uhr.host).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if zustand.zielIDs.contains(uhr.id) {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                    .tint(.primary)
                }
            }
            .navigationTitle("Ziel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { schliessen() }
            } }
            .onAppear {
                // Konkretisieren: Sonst zeigte das Blatt bei leerer Auswahl
                // keine Uhr angehakt, obwohl eben noch die aktive als Ziel galt.
                if zustand.zielIDs.isEmpty { zustand.zielIDs = Set(zustand.ziele().map(\.id)) }
            }
        }
    }
}
```

- [ ] **Schritt 5: In den Einstieg einhängen**

In `App.swift` einen zweiten Reiter vor „Verbindung" setzen:

```swift
                SendeniOS(zustand: zustand)
                    .tabItem { Label("Senden", systemImage: "paperplane") }
```

Er steht **vor** „Verbindung", damit die App dort aufgeht, wo man sie benutzt.

- [ ] **Schritt 6: Bauen und Übersetzung prüfen**

```bash
xcodegen generate
xcodebuild -project MQTT-TC002-iOS.xcodeproj -scheme MQTT-TC002-iOS \
           -destination 'generic/platform=iOS Simulator' build
python3 scripts/texte-sammeln.py --pruefen
```

Erwartet: `** BUILD SUCCEEDED **` und `0 ohne Uebersetzung`.

- [ ] **Schritt 7: Einchecken**

```bash
git add Sources/TC002iOS Resources/Sprachen
git commit -m "feat(ios): Reiter Senden als Nachrichtenfenster"
```

---

### Aufgabe 8: Der Reiter „Anzeigen", dann aufs Gerät

**Dateien:**
- Anlegen: `Sources/TC002iOS/AnzeigeniOS.swift`
- Ändern: `Sources/TC002iOS/App.swift`
- Ändern: `README.md`, `README.en.md`

**Schnittstellen:**
- Verbraucht: `AppZustand.anzeigenDerAktivenMitQuelle()`, `AppZustand.anzeigeVergessen(_:fuer:)`, `AppZustand.anzeigen(fuer:)`, `AppZustand.protokoll`, `AppZustand.log(_:)`, `AppZustand.geraetOnline`.
- Erzeugt: `struct AnzeigeniOS: View`.

- [ ] **Schritt 1: Die Ansicht anlegen**

`Sources/TC002iOS/AnzeigeniOS.swift`:

```swift
import SwiftUI
import TC002Core
import TC002Modell

/// Was auf der aktiven Uhr steht, und das Protokoll. Die Logik stammt aus
/// `AnzeigenView` der Mac-Fassung; ersetzt sind nur die Bedienelemente —
/// aus zwei Knöpfen je Zeile werden zwei Wischgesten.
struct AnzeigeniOS: View {
    @Bindable var zustand: AppZustand

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FehlerleisteiOS(zustand: zustand)
                List {
                    anzeigenAbschnitt
                    protokollAbschnitt
                }
            }
            .navigationTitle("Anzeigen")
        }
    }

    private var anzeigenAbschnitt: some View {
        let liste = zustand.anzeigenDerAktivenMitQuelle()
        return Section {
            if liste.namen.isEmpty {
                Text(liste.quelle == .geraet ? lok("Die Uhr meldet gerade keine Anzeige.")
                                             : lok("Noch nichts an diese Uhr gesendet."))
                    .foregroundStyle(.secondary)
            }
            ForEach(liste.namen, id: \.self) { name in
                Text(name).font(.system(.body, design: .monospaced))
                    .swipeActions(edge: .trailing) {
                        Button("Löschen", role: .destructive) { loeschen(name) }
                    }
                    .swipeActions(edge: .leading) {
                        Button("Zeigen") { umschalten(name) }.tint(.blue)
                    }
            }
        } header: {
            HStack {
                Text(liste.quelle == .geraet ? lok("vom Gerät gemeldet")
                                             : lok("von dieser App angelegt"))
                if let uhr = zustand.aktiveUhr, let online = zustand.geraetOnline[uhr.id] {
                    Text(online ? lok("· Uhr meldet sich online") : lok("· Uhr meldet sich offline"))
                }
            }
        } footer: {
            Text("Nach links wischen löscht, nach rechts schaltet auf die Anzeige um.")
        }
    }

    private var protokollAbschnitt: some View {
        Section {
            ForEach(Array(zustand.protokoll.enumerated()), id: \.offset) { _, zeile in
                Text(zeile).font(.system(.caption, design: .monospaced))
            }
        } header: {
            HStack {
                Text("Protokoll")
                Spacer()
                Button("Leeren") { zustand.protokoll.removeAll() }.font(.caption)
            }
        }
    }

    private func umschalten(_ name: String) {
        guard let uhr = zustand.aktiveUhr, let a = zustand.anzeigen(fuer: uhr) else {
            zustand.fehler = zustand.zugangsmeldung(zustand.aktiveUhr ?? Uhr(name: "", host: ""))
            return
        }
        Task.detached {
            do {
                try a.umschalten(auf: name)
                await MainActor.run { zustand.log(lokf("umgeschaltet auf %@", name)) }
            } catch {
                await MainActor.run { zustand.melde(error, uhr: uhr) }
            }
        }
    }

    private func loeschen(_ name: String) {
        guard let uhr = zustand.aktiveUhr, let a = zustand.anzeigen(fuer: uhr) else {
            zustand.fehler = zustand.zugangsmeldung(zustand.aktiveUhr ?? Uhr(name: "", host: ""))
            return
        }
        Task.detached {
            do {
                try a.loeschen(name)
                await MainActor.run {
                    zustand.anzeigeVergessen(name, fuer: uhr.id)
                    zustand.log(lokf("gelöscht: %@", name))
                }
            } catch {
                await MainActor.run { zustand.melde(error, uhr: uhr) }
            }
        }
    }
}
```

Verlangt eine der benutzten Methoden von `AppZustand` noch `public` — etwa
`melde(_:uhr:)`, `zugangsmeldung(_:)`, `anzeigen(fuer:)`, `aktiveUhr`,
`protokoll`, `log(_:)` —, wird das in `Sources/TC002Modell/AppZustand.swift`
nachgetragen.

- [ ] **Schritt 2: In den Einstieg einhängen**

In `App.swift` als dritten Reiter:

```swift
                AnzeigeniOS(zustand: zustand)
                    .tabItem { Label("Anzeigen", systemImage: "list.bullet") }
```

- [ ] **Schritt 3: Bauen und Übersetzung prüfen**

```bash
xcodegen generate
xcodebuild -project MQTT-TC002-iOS.xcodeproj -scheme MQTT-TC002-iOS \
           -destination 'generic/platform=iOS Simulator' build
swift test
python3 scripts/texte-sammeln.py --pruefen
```

Erwartet: `** BUILD SUCCEEDED **`, alle Tests grün, `0 ohne Uebersetzung`.

- [ ] **Schritt 4: Beide README ergänzen**

In `README.md` vor „## Tests" einen Abschnitt „## Auf dem iPhone" mit dem, was die iOS-Fassung kann (Verbindung, Senden, Anzeigen), was sie bewusst nicht kann (Icons bearbeiten, Malen — das bleibt dem Schreibtisch) und wie man sie baut (`xcodegen generate`, dann in Xcode starten). Dasselbe in `README.en.md` als „## On the iPhone".

- [ ] **Schritt 5: Einchecken**

```bash
git add Sources/TC002iOS README.md README.en.md Resources/Sprachen
git commit -m "feat(ios): Reiter Anzeigen; README um die iOS-Fassung ergaenzt"
```

- [ ] **Schritt 6: Auf das Gerät bringen**

Dieser Schritt gehört dem Menschen, nicht dem Agenten.

```bash
xcodegen generate
open MQTT-TC002-iOS.xcodeproj
```

In Xcode das iPhone als Ziel wählen und auf Start drücken. Beim ersten Lauf fragt iOS nach dem Zugriff aufs lokale Netzwerk — erlauben, sonst erreicht die App weder Uhr noch Broker.

Auf dem Gerät prüfen:

1. Unter „Verbindung" den Broker eintragen, „Sichern und prüfen" muss „angenommen" melden.
2. Eine Uhr hinzufügen und „Abfragen" — das Präfix muss erscheinen.
3. Unter „Senden" einen kurzen Text schicken. Er muss auf der Uhr stehen.
4. Einen langen Text schicken. Er muss durchlaufen.
5. Unter „Anzeigen" beides wieder löschen.
6. Die App in den Hintergrund schicken und zurückholen. Das Protokoll muss zeigen, dass der Zuhörer beendet und neu aufgebaut wurde.

---

## Was dieser Plan nicht enthält

- **Icon-Editor auf dem iPhone.** Dauerhafte Festlegung, siehe Spezifikation.
- **Malen.** Zurückgestellt.
- **Hilfe und Gerätereferenz auf dem iPhone.** Beide hängen am Markdown-Zerleger in der macOS-Schicht.
- **Automatische Oberflächentests.** Geprüft wird durch den Simulatorbau und am Gerät.
- **TestFlight und App Store.**
- **iPad-eigenes Layout.**
