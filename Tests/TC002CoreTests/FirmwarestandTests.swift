import XCTest
@testable import TC002Core

final class FirmwarestandTests: XCTestCase {
    func testZahlenAusFassungen() {
        XCTAssertEqual(Firmwarestand.zahlen("1.2.2"), [1, 2, 2])
        XCTAssertEqual(Firmwarestand.zahlen("v1.10"), [1, 10])
        XCTAssertEqual(Firmwarestand.zahlen(" 1.2.2-beta.1 "), [1, 2, 2])
        XCTAssertEqual(Firmwarestand.zahlen("1.2.2+abc"), [1, 2, 2])
        XCTAssertNil(Firmwarestand.zahlen(""))
        XCTAssertNil(Firmwarestand.zahlen("dev"))
        XCTAssertNil(Firmwarestand.zahlen("1..2"))
    }

    func testVergleichIstNumerischUndNichtTextlich() {
        XCTAssertEqual(Firmwarestand.vergleichen("1.1.0", "1.2.2"), .orderedAscending)
        XCTAssertEqual(Firmwarestand.vergleichen("1.10.0", "1.9.9"), .orderedDescending)
        XCTAssertEqual(Firmwarestand.vergleichen("1.2", "1.2.0"), .orderedSame)
        XCTAssertEqual(Firmwarestand.vergleichen("1.2.2-beta", "1.2.2"), .orderedSame)
        XCTAssertNil(Firmwarestand.vergleichen("unbekannt", "1.2.2"))
    }

    func testHinweisNurBeiAelterer() {
        XCTAssertEqual(Firmwarestand.hinweis(fuer: "1.1.0"),
                       Firmwarehinweis(gemeldet: "1.1.0", erwartet: Firmwarestand.unterstuetzt))
        XCTAssertNil(Firmwarestand.hinweis(fuer: "1.2.2"))
        XCTAssertNil(Firmwarestand.hinweis(fuer: "1.2.2-beta"))
        XCTAssertNil(Firmwarestand.hinweis(fuer: "1.3.0"))
        XCTAssertNil(Firmwarestand.hinweis(fuer: "2.0"))
        XCTAssertNil(Firmwarestand.hinweis(fuer: nil))
        XCTAssertNil(Firmwarestand.hinweis(fuer: "dev"))
    }

    func testGeraetezustandLiefertDenHinweis() throws {
        let alt = try Geraetezustand(daten: Data(#"{"version":"1.1.0","boardType":"esp32"}"#.utf8))
        XCTAssertEqual(alt.firmwarehinweis?.gemeldet, "1.1.0")
        XCTAssertTrue(alt.firmwarehinweis?.meldung.contains("1.1.0") == true)
        let neu = try Geraetezustand(daten: Data(#"{"version":"1.2.2"}"#.utf8))
        XCTAssertNil(neu.firmwarehinweis)
        let ohne = try Geraetezustand(daten: Data("{}".utf8))
        XCTAssertNil(ohne.firmwarehinweis)
    }
}
