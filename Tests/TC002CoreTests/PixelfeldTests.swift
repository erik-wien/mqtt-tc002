import XCTest
@testable import TC002Core

final class PixelfeldTests: XCTestCase {
    func testEinzelnerPixelWirdEinRechteckDerGroesseEins() {
        var feld = Pixelfeld()
        feld.setzen(x: 3, y: 4, farbe: "#FF0000")
        XCTAssertEqual(feld.alsDrawBefehle(),
                       [DrawBefehl(x: 3, y: 4, breite: 1, hoehe: 1, farbe: "#FF0000")])
    }

    /// Der Kern der Sache: benachbarte Pixel gleicher Farbe werden zusammengefasst,
    /// sonst wird die Nutzlast unnoetig gross.
    func testWaagrechteNachbarnWerdenZusammengefasst() {
        var feld = Pixelfeld()
        for x in 5...9 { feld.setzen(x: x, y: 2, farbe: "#00FF66") }
        XCTAssertEqual(feld.alsDrawBefehle(),
                       [DrawBefehl(x: 5, y: 2, breite: 5, hoehe: 1, farbe: "#00FF66")])
    }

    func testFarbwechselTrenntDenLauf() {
        var feld = Pixelfeld()
        feld.setzen(x: 0, y: 0, farbe: "#FF0000")
        feld.setzen(x: 1, y: 0, farbe: "#00FF00")
        XCTAssertEqual(feld.alsDrawBefehle().count, 2)
    }

    func testLueckeTrenntDenLauf() {
        var feld = Pixelfeld()
        feld.setzen(x: 0, y: 0, farbe: "#FF0000")
        feld.setzen(x: 2, y: 0, farbe: "#FF0000")
        XCTAssertEqual(feld.alsDrawBefehle().count, 2)
    }

    func testLoeschenUndLeeresFeld() {
        var feld = Pixelfeld()
        feld.setzen(x: 1, y: 1, farbe: "#FFFFFF")
        feld.loeschen(x: 1, y: 1)
        XCTAssertTrue(feld.alsDrawBefehle().isEmpty)
        XCTAssertNil(feld.farbe(x: 1, y: 1))
    }

    func testAusserhalbWirdStillIgnoriert() {
        var feld = Pixelfeld()
        feld.setzen(x: 99, y: 0, farbe: "#FFFFFF")
        feld.setzen(x: -1, y: 0, farbe: "#FFFFFF")
        feld.setzen(x: 0, y: 99, farbe: "#FFFFFF")
        XCTAssertTrue(feld.alsDrawBefehle().isEmpty)
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
}
