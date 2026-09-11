import XCTest
@testable import TC002Core

final class SchluesselbundTests: XCTestCase {
    private let konto = "test-\(UUID().uuidString)"

    override func tearDown() { Schluesselbund.loeschen(konto) }

    func testSchreibenLesenLoeschen() {
        XCTAssertNil(Schluesselbund.lesen(konto))
        Schluesselbund.setzen("geheim", fuer: konto)
        XCTAssertEqual(Schluesselbund.lesen(konto), "geheim")
        Schluesselbund.setzen("neu", fuer: konto)
        XCTAssertEqual(Schluesselbund.lesen(konto), "neu", "Überschreiben muss gehen")
        Schluesselbund.loeschen(konto)
        XCTAssertNil(Schluesselbund.lesen(konto))
    }

    /// Der Rueckgabewert ist der einzige Weg, ein gescheitertes Schreiben zu
    /// bemerken — sonst ist das Kennwort erst nach dem Neustart weg.
    func testSetzenMeldetErfolg() {
        XCTAssertTrue(Schluesselbund.setzen("geheim", fuer: konto))
        XCTAssertTrue(Schluesselbund.setzen("geheim", fuer: konto), "Überschreiben ebenso")
    }

    /// Ein leeres Kennwort ist kein Eintrag, aber auch kein Fehlschlag.
    func testLeererWertLoeschtOhneFehlschlag() {
        Schluesselbund.setzen("geheim", fuer: konto)
        XCTAssertTrue(Schluesselbund.setzen("", fuer: konto))
        XCTAssertNil(Schluesselbund.lesen(konto))
    }
}
