import XCTest
@testable import TC002Core

/// Ein Hintergrund aus #000001 zählt als Tinte und hält den Rand; reines
/// Schwarz und Durchsichtiges tun es nicht (`Bildraster.istSchwarz`).
final class IconzuschnittRandTests: XCTestCase {
    func testHintergrundNullNullNullEinsHaeltDenRand() throws {
        var p = [String?](repeating: "#000001", count: 64)
        p[3 * 8 + 3] = "#FF0000"
        let platz = try XCTUnwrap(Iconplatz.vermessen([p], kante: 8))
        XCTAssertEqual(platz.links, 0)
        XCTAssertEqual(platz.breite, 8, "der ganze Rand bleibt")
        var schwarz = [String?](repeating: "#000000", count: 64)
        schwarz[3 * 8 + 3] = "#FF0000"
        XCTAssertEqual(try XCTUnwrap(Iconplatz.vermessen([schwarz], kante: 8)).breite, 1)
        var leer = [String?](repeating: nil, count: 64)
        leer[3 * 8 + 3] = "#FF0000"
        XCTAssertEqual(try XCTUnwrap(Iconplatz.vermessen([leer], kante: 8)).breite, 1)
    }
}
