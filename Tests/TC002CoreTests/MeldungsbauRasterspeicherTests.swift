import XCTest
@testable import TC002Core

/// `Meldungsbau.puffer` und `breite` sind zwischengespeichert: Dieselbe Frage
/// beantwortet dasselbe, und was in den Schluessel gehoert, unterscheidet.
final class MeldungsbauRasterspeicherTests: XCTestCase {
    func testWiederholteFrageGibtDasselbe() {
        let o = Meldungsoptionen(text: "Speicher")
        let a = Meldungsbau.puffer(o, mass: .vorgabe)
        XCTAssertEqual(Meldungsbau.puffer(o, mass: .vorgabe), a)
        XCTAssertEqual(Meldungsbau.breite(o), Meldungsbau.breite(o))
    }

    func testMassUndTextUnterscheiden() {
        let o = Meldungsoptionen(text: "Speicher")
        let klein = Anzeigemass(breite: 32, hoehe: 8)
        XCTAssertEqual(Meldungsbau.puffer(o, mass: klein).hoehe, 8)
        XCTAssertEqual(Meldungsbau.puffer(o, mass: .vorgabe).hoehe, Anzeigemass.vorgabe.hoehe)
        var p = o
        p.text = "Speicher und mehr"
        XCTAssertGreaterThan(Meldungsbau.breite(p), Meldungsbau.breite(o))
    }
}
