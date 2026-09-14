import XCTest
@testable import TC002Core

/// Ein Leerzeichen am Rand des Praefixes hat am 14.09.2026 eine Stunde
/// gekostet: Das Geraet hoerte auf `awtrix /cmd/…`, die App schrieb auf
/// `awtrix/cmd/…`, und in der Uhrenzeile stand beides Mal `awtrix`.
final class ThemenpraefixTests: XCTestCase {
    func testEinLeerzeichenAmEndeWirdSichtbar() {
        XCTAssertEqual(Themenpraefix.sichtbar("awtrix "), "awtrix␣")
    }

    func testEinLeerzeichenVornWirdSichtbar() {
        XCTAssertEqual(Themenpraefix.sichtbar(" awtrix"), "␣awtrix")
    }

    func testMehrereAnBeidenRaendern() {
        XCTAssertEqual(Themenpraefix.sichtbar("  a b  "), "␣␣a b␣␣")
    }

    /// Der gewoehnliche Fall bleibt unangetastet — auch der mit Schraegstrichen
    /// darin, den NG ausdruecklich zulaesst.
    func testOhneLeerraumBleibtAllesWieEsIst() {
        XCTAssertEqual(Themenpraefix.sichtbar("awtrix_a86b//common"), "awtrix_a86b//common")
        XCTAssertEqual(Themenpraefix.sichtbar(""), "")
    }

    /// Ein Praefix aus lauter Leerraum ist ganz Rand — und darf dabei nicht
    /// laenger werden, als es ist.
    func testNurLeerraum() {
        XCTAssertEqual(Themenpraefix.sichtbar("   "), "␣␣␣")
    }

    /// Auch ein Tabulator ist Leerraum.
    func testTabulatorZaehltMit() {
        XCTAssertEqual(Themenpraefix.sichtbar("awtrix\t"), "awtrix␣")
    }
}
