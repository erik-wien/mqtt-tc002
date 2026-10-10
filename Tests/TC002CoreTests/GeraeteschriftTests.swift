import XCTest
@testable import TC002Core

/// Die Vorschau der Schrift der Uhr gegen eine Messung an der echten TC002.
final class GeraeteschriftTests: XCTestCase {
    /// Messung vom 10.10.2026: TC002, NG 1.2.2, `enlargeApps` an, globales
    /// `uppercase` an. Gepusht `{"text":"Hello!"}` ohne Icon, gelesen über
    /// `display/screen` (52 × 16, „#“ ist weiß).
    private static let messung = [
        "....................................................",
        "....................................................",
        "....##..##..######..##......##........##....##......",
        "....##..##..######..##......##........##....##......",
        "....##..##..##......##......##......##..##..##......",
        "....##..##..##......##......##......##..##..##......",
        "....######..######..##......##......##..##..##......",
        "....######..######..##......##......##..##..##......",
        "....##..##..##......##......##......##..##..........",
        "....##..##..##......##......##......##..##..........",
        "....##..##..######..######..######....##....##......",
        "....##..##..######..######..######....##....##......",
        "....................................................",
        "....................................................",
        "....................................................",
        "....................................................",
    ]

    private func zeilen(_ f: Pixelfeld) -> [String] {
        (0..<f.hoehe).map { y in
            String((0..<f.breite).map { f.farbe(x: $0, y: y) == nil ? "." : "#" })
        }
    }

    private let tc002 = Anzeigemass(breite: 52, hoehe: 16)
    private let tc001 = Anzeigemass(breite: 32, hoehe: 8)

    func testHelloEntsprichtDerMessungAnDerTC002() {
        let o = Meldungsoptionen(text: "Hello!", weg: .text, grossbuchstaben: true, waagrecht: .mittig)
        let f = Meldungsbau.feld(o, mitIcon: false, mass: tc002)
        XCTAssertEqual(zeilen(f), Self.messung)
    }

    /// Ohne den Schalter geht `asTyped` hinaus (`NGNutzlast.anzeige`): Die
    /// Vorschau zeigt die Kleinbuchstaben, nicht Versalien.
    func testOhneGrossbuchstabenStehtDerTextWieGetippt() {
        let f = Meldungsbau.feld(Meldungsoptionen(text: "Hello!", weg: .text, waagrecht: .mittig), mitIcon: false, mass: tc002)
        XCTAssertNotEqual(zeilen(f), Self.messung)
        XCTAssertEqual(f.farbe(x: 4, y: 2), "#00FF66", "das H steht trotzdem links in Zeile 1")
    }

    /// Auf einer 8-zeiligen Uhr gibt es keine Vergrößerung: dieselbe Schrift 1:1,
    /// Zeilen 1–5.
    func testTC001ZeichnetDieselbeSchriftEinsZuEins() {
        let o = Meldungsoptionen(text: "Hello!", weg: .text, grossbuchstaben: true, waagrecht: .mittig)
        let f = Meldungsbau.feld(o, mitIcon: false, mass: tc001)
        let z = zeilen(f)
        XCTAssertEqual(z.count, 8)
        XCTAssertEqual(z[0], String(repeating: ".", count: 32))
        XCTAssertEqual(z[6], String(repeating: ".", count: 32))
        // Dieselben Pixel wie die Messung, halbiert und um 3 Spalten
        // verschoben (32 statt 26 Spalten, mittig).
        for y in 1...5 {
            let ref = Array(Self.messung[2 * y]).enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
            let erwartet = String(repeating: ".", count: 3) + String(ref[0..<26]) + String(repeating: ".", count: 3)
            XCTAssertEqual(z[y], erwartet, "Zeile \(y)")
        }
    }

    /// Mit Icon (8×8, vergrößert) beginnt der Text nach 8 Spalten Icon und 1
    /// Spalte Luft auf dem 26-Spalten-Raster, also bei Spalte 18 von 52 (§1.2).
    func testMitIconBeginntDerTextRechtsDavon() {
        let o = Meldungsoptionen(text: "H", weg: .text, grossbuchstaben: true, waagrecht: .mittig)
        let f = Meldungsbau.feld(o, mitIcon: true, iconKante: 8, mass: tc002)
        let belegt = (0..<52).filter { x in (0..<16).contains { f.farbe(x: x, y: $0) != nil } }
        XCTAssertEqual(belegt.min(), 32, "H mittig im Rest 17 breit: Spalte 9 + (17-3)/2 = 16, doppelt 32")
        XCTAssertEqual(Geraeteschrift.masstab(mitIcon: true, iconKante: 8, mass: tc002), 2)
        XCTAssertEqual(Geraeteschrift.masstab(mitIcon: true, iconKante: 16, mass: tc002), 1)
        XCTAssertEqual(Geraeteschrift.masstab(mitIcon: false, iconKante: 8, mass: tc001), 1)
    }

    /// Ein Zeichen ohne Abbildung wird genau ein „?“; „ß“ bleibt bei den
    /// Versalien ein „ß“; Umlaute tragen ihre Punkte in Zeile 0.
    func testZeichenundErsatz() {
        let o = Meldungsoptionen(text: "ß😀", weg: .text, grossbuchstaben: true, waagrecht: .mittig)
        XCTAssertEqual(Geraeteschrift.geschrieben(o), ["ß", "😀"])
        let ae = Meldungsbau.feld(Meldungsoptionen(text: "Ä", weg: .text), mitIcon: false, mass: tc001)
        XCTAssertNotNil((0..<32).first { ae.farbe(x: $0, y: 0) != nil }, "Punkte über dem Ä")
        let fremd = Meldungsbau.feld(Meldungsoptionen(text: "😀", weg: .text), mitIcon: false, mass: tc001)
        let fragezeichen = Meldungsbau.feld(Meldungsoptionen(text: "?", weg: .text), mitIcon: false, mass: tc001)
        XCTAssertEqual(zeilen(fremd), zeilen(fragezeichen))
    }

    /// Was nicht ins Raster passt, zeigt die Vorschau am Anfang; `passt` sagt es.
    func testZuLangerTextZeigtDenAnfang() {
        let lang = Meldungsoptionen(text: "HALLO WELT", weg: .text)
        XCTAssertFalse(Meldungsbau.passt(lang, mitIcon: false, mass: tc002))
        XCTAssertTrue(Meldungsbau.passt(Meldungsoptionen(text: "Hi", weg: .text), mitIcon: false, mass: tc002))
        XCTAssertTrue(Meldungsbau.laufschriftBilder(lang, iconBilder: [], mass: tc002).isEmpty)
        let f = Meldungsbau.feld(lang, mitIcon: false, mass: tc002)
        XCTAssertNotNil(f.farbe(x: 0, y: 2), "linksbündig ab Spalte 0")
    }
}
