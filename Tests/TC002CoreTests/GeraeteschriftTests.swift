import XCTest
@testable import TC002Core

/// Die eingebaute Schrift der Uhr kennt Buchstaben, Ziffern und vier
/// Satzzeichen (Geraetereferenz, §1). Was sie nicht kennt, zeigt sie nicht —
/// ohne Ersatzzeichen und ohne Meldung. Deshalb warnt die App davor, und
/// deshalb steht die Liste hier und nicht in einer der beiden Sendeansichten.
final class GeraeteschriftTests: XCTestCase {
    func testBuchstabenZiffernUndDieVierSatzzeichenGehenDurch() {
        XCTAssertTrue(Geraeteschrift.unbekannteZeichen(in: "Hallo 42%").isEmpty)
        XCTAssertTrue(Geraeteschrift.unbekannteZeichen(in: "12:30 -5.5%").isEmpty)
    }

    func testUmlauteUndSonderzeichenFallenAuf() {
        XCTAssertEqual(Geraeteschrift.unbekannteZeichen(in: "Grüße!"), ["ü", "ß", "!"])
    }

    /// Jedes nur einmal, in der Reihenfolge des Auftretens — sonst stuende in
    /// der Warnung dasselbe Zeichen dreimal.
    func testJedesZeichenNurEinmal() {
        XCTAssertEqual(Geraeteschrift.unbekannteZeichen(in: "ä?ä?ö"), ["ä", "?", "ö"])
    }

    func testDieAufzaehlungIstLesbar() {
        XCTAssertEqual(Geraeteschrift.unbekannteZeichenText(in: "Grüße"), "„ü“, „ß“")
        XCTAssertEqual(Geraeteschrift.unbekannteZeichenText(in: "ok"), "")
    }
}
