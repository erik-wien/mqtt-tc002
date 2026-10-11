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
        // Der Puffer ist nie niedriger als die Anzeige, aber hoeher, damit auf
        // acht Zeilen nichts vor dem Ausrichten abgeschnitten wird.
        XCTAssertGreaterThanOrEqual(Meldungsbau.puffer(o, mass: klein).hoehe, 8)
        XCTAssertGreaterThanOrEqual(Meldungsbau.puffer(o, mass: .vorgabe).hoehe, Anzeigemass.vorgabe.hoehe)
        XCTAssertEqual(Meldungsbau.puffer(o, mass: klein).breite, Meldungsbau.puffer(o, mass: .vorgabe).breite)
        var p = o
        p.text = "Speicher und mehr"
        XCTAssertGreaterThan(Meldungsbau.breite(p), Meldungsbau.breite(o))
    }
}
