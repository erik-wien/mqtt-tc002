import XCTest
@testable import TC002Core

final class PixelfeldTests: XCTestCase {
    func testLoeschenUndLeeresFeld() {
        var feld = Pixelfeld()
        feld.setzen(x: 1, y: 1, farbe: "#FFFFFF")
        feld.loeschen(x: 1, y: 1)
        XCTAssertTrue(feld.punkteRoh.allSatisfy { $0 == nil })
        XCTAssertNil(feld.farbe(x: 1, y: 1))
    }

    func testAusserhalbWirdStillIgnoriert() {
        var feld = Pixelfeld()
        feld.setzen(x: 99, y: 0, farbe: "#FFFFFF")
        feld.setzen(x: -1, y: 0, farbe: "#FFFFFF")
        feld.setzen(x: 0, y: 99, farbe: "#FFFFFF")
        XCTAssertTrue(feld.punkteRoh.allSatisfy { $0 == nil })
    }

    /// Grundlage der Sicherung ueber Neustarts: hinaus und wieder hinein muss
    /// dasselbe Feld ergeben.
    func testPunkteRohHinUndZurueckErgibtDasselbeFeld() throws {
        var feld = Pixelfeld()
        feld.setzen(x: 0, y: 0, farbe: "#FF0000")
        feld.setzen(x: 51, y: 15, farbe: "#00FF00")

        let zurueck = try XCTUnwrap(Pixelfeld(punkte: feld.punkteRoh))

        XCTAssertEqual(zurueck, feld)
    }

    /// Eine falsche Laenge (z. B. ein veraltetes oder verbogenes Feld) darf kein
    /// halbes Bild ergeben, sondern muss klar scheitern.
    func testFalscheLaengeErgibtNil() {
        XCTAssertNil(Pixelfeld(punkte: Array(repeating: nil, count: 10)))
    }

    /// „Als Text" zeichnet NG auf 26 × 8, jedes Pixel 2 × 2 (§1.1): Ein
    /// einzelner Punkt wird ein Block, die Farbe bleibt.
    func testDoppelpixelMachenAusEinemPunktEinenBlock() {
        var feld = Pixelfeld()
        feld.setzen(x: 3, y: 5, farbe: "#FF0000")
        let doppelt = feld.inDoppelpixeln()
        for (x, y) in [(2, 4), (3, 4), (2, 5), (3, 5)] {
            XCTAssertEqual(doppelt.farbe(x: x, y: y), "#FF0000")
        }
        XCTAssertEqual(doppelt.punkteRoh.compactMap { $0 }.count, 4)
    }
}
