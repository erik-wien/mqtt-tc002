import Foundation
import XCTest
@testable import TC002Core

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

    /// Mit Icon beginnt die Textflaeche bei Spalte 10 und ist 42 breit. Diese
    /// Zahlen stehen in keinem Schnappschuss, weil die dort alle ohne Icon
    /// gebaut werden — und das Icon sitzt senkrecht mittig auf `y: 4`, was
    /// ebenso von Hand gesetzt wurde.
    func testIconVersatz() {
        var o = Meldungsoptionen(text: "Hallo")
        XCTAssertEqual(Meldungsbau.flaecheX(mitIcon: true), 10)
        XCTAssertEqual(Meldungsbau.flaecheBreite(mitIcon: true), 42)
        XCTAssertEqual(Meldungsbau.flaecheX(mitIcon: false), 0)
        XCTAssertEqual(Meldungsbau.flaecheBreite(mitIcon: false), 52)
        o.waagrecht = .links
        XCTAssertEqual(Meldungsbau.versatzX(o, mitIcon: true), 10)
        o.waagrecht = .mittig
        XCTAssertEqual(Meldungsbau.versatzX(o, mitIcon: true), 22)
        XCTAssertEqual(Meldungsbau.textblock(o, mitIcon: true).flaeche, [10, 0, 42, 16])
        XCTAssertEqual(Meldungsbau.textblock(o, mitIcon: false).flaeche, [0, 0, 52, 16])
    }

    /// Mehr Rand verlangen, als Platz ist, darf nicht abschneiden: Der Wert
    /// wird auf die Haelfte des freien Raums geklammert. Die Schnappschuesse
    /// loesen das nie aus, weil dort jeder Rand unter der Grenze liegt.
    /// Mehr Rand verlangen, als Platz ist, darf nicht abschneiden: `r` wird auf
    /// die Haelfte des freien Raums geklammert. Fuer „Hallo" liegt die Tinte
    /// bei Zeile 2 bis 7 (sechs Pixel hoch), also `max(0, (16-6)/2) = 5`; bei
    /// Rand 8 klemmt `r` also auf 5 statt 8, und `versatzY` — das noch den
    /// Tintenbeginn `-2` einrechnet — landet bei `-2 + 5 = 3`. Ohne die
    /// Klammerung waere es `-2 + 8 = 6` geworden. Die Schnappschuesse loesen
    /// das nie aus, weil dort jeder Rand unter der Grenze liegt.
    func testRandWirdGeklammert() {
        var o = Meldungsoptionen(text: "Hallo")
        o.senkrecht = .oben
        o.rand = 3
        let mitDrei = Meldungsbau.versatzY(o)
        o.rand = 8
        XCTAssertEqual(Meldungsbau.versatzY(o), 3,
                       "acht Rand wird bei sechs Pixeln Tinte auf fuenf geklammert, versatzY = -2 + 5 = 3")
        XCTAssertLessThan(mitDrei, Meldungsbau.versatzY(o))
    }

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
        XCTAssertEqual(Meldungsplatz.anzahl, 5)
        XCTAssertEqual((1...5).map(Meldungsplatz.name(fuer:)),
                       ["meldung1", "meldung2", "meldung3", "meldung4", "meldung5"])
    }
}
