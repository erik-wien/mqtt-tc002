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
