import XCTest
@testable import TC002Core

final class NGMeldungTests: XCTestCase {
    private let p = "wz/uhr"

    func testErreichbarkeit() {
        XCTAssertEqual(NGMeldung.auswerten(thema: "wz/uhr/availability", nutzlast: Data(" online\n".utf8), praefix: p),
                       .erreichbarkeit(online: true))
        XCTAssertEqual(NGMeldung.auswerten(thema: "wz/uhr/availability", nutzlast: Data("offline".utf8), praefix: p),
                       .erreichbarkeit(online: false))
    }

    func testAntwortUndAbweisung() {
        let m = NGMeldung.auswerten(thema: "wz/uhr/cmd/apps/pushed/meldung1/result",
                                    nutzlast: Data(#"{"ok":true}"#.utf8), praefix: p)
        XCTAssertEqual(m, .antwort(bezeichnung: "meldung1", .gelungen))
        let ab = NGMeldung.auswerten(thema: "wz/uhr/cmd/apps/pushed/meldung1/result",
                                     nutzlast: Data(#"{"ok":false,"error":{"code":"notFound"}}"#.utf8), praefix: p)
        guard case .antwort(_, .abgewiesen) = ab else { return XCTFail("Abweisung erwartet") }
    }

    /// Eine Nutzlast an der Grenze von 56 KiB wird zerlegt und behält Länge und Text.
    func testGrosseNutzlastEinerAnzeige() {
        let nutzlast = Data(#"{"icon":""#.utf8) + Data(repeating: 0x41, count: 56 * 1024) + Data(#""}"#.utf8)
        let m = NGMeldung.auswerten(thema: "wz/uhr/cmd/apps/pushed/meldung3", nutzlast: nutzlast, praefix: p)
        guard case .anzeige(let name, let platz, let leer, let text, let bytes) = m else { return XCTFail() }
        XCTAssertEqual(name, "meldung3")
        XCTAssertEqual(platz, 3)
        XCTAssertFalse(leer)
        XCTAssertEqual(bytes, nutzlast.count)
        XCTAssertEqual(text?.utf8.count, nutzlast.count)
    }

    func testLeereNutzlastUndFremdeAnzeige() {
        XCTAssertEqual(NGMeldung.auswerten(thema: "wz/uhr/cmd/apps/pushed/meldung2", nutzlast: Data(), praefix: p),
                       .anzeige(name: "meldung2", platz: 2, leer: true, text: nil, bytes: 0))
        XCTAssertEqual(NGMeldung.auswerten(thema: "wz/uhr/cmd/apps/pushed/cli", nutzlast: Data("{}".utf8), praefix: p),
                       .anzeige(name: "cli", platz: nil, leer: false, text: "{}", bytes: 2))
        XCTAssertEqual(NGMeldung.auswerten(thema: "anderswo", nutzlast: Data(), praefix: p), .unbeachtet)
    }
}
