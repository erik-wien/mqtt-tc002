import XCTest
@testable import TC002Core

final class FingerabdruckTests: XCTestCase {
    func testGleicheAngabenGebenDenselbenFingerabdruck() {
        XCTAssertEqual(Fingerabdruck.von(["h", "1883", "u", "k"]), Fingerabdruck.von(["h", "1883", "u", "k"]))
    }

    func testJedeAenderungAendertIhn() {
        let basis = Fingerabdruck.von(["h", "1883", "u", "k"])
        for i in 0..<4 {
            var t = ["h", "1883", "u", "k"]
            t[i] += "x"
            XCTAssertNotEqual(Fingerabdruck.von(t), basis, "Teil \(i)")
        }
    }

    /// Die Trennung gehört dazu: Sonst wären Host „a“ + Port „bc“ und Host „ab“
    /// + Port „c“ derselbe Broker.
    func testDieGrenzenZwischenDenTeilenZaehlen() {
        XCTAssertNotEqual(Fingerabdruck.von(["a", "bc"]), Fingerabdruck.von(["ab", "c"]))
    }

    /// 64 Hexzeichen, kein Klartext.
    func testKeinKlartext() {
        let f = Fingerabdruck.von(["broker", "1883", "erik", "geheimes-Kennwort"])
        XCTAssertEqual(f.count, 64)
        XCTAssertFalse(f.contains("geheim"))
        XCTAssertNotNil(f.range(of: "^[0-9a-f]{64}$", options: .regularExpression))
    }

    /// Bekannter Wert (SHA-256 von „abc“), damit der Test die Hashfunktion
    /// festhält und nicht nur die Gleichheit.
    func testBekannterWert() {
        XCTAssertEqual(Fingerabdruck.von(["abc"]),
                       "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
