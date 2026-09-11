import XCTest
@testable import TC002Core

final class TextrasterTests: XCTestCase {
    func testTextErzeugtUeberhauptPixel() {
        var feld = Pixelfeld()
        Textraster.rastern("HI", schrift: "Menlo", groesse: 11, farbe: "#00FF66",
                           x: 1, y: 3, feld: &feld)
        XCTAssertGreaterThan(feld.alsDrawBefehle().count, 3)
    }

    func testBreiteWaechstMitDerZeichenzahl() {
        let kurz = Textraster.breite("A", schrift: "Menlo", groesse: 11)
        let lang = Textraster.breite("AAAA", schrift: "Menlo", groesse: 11)
        XCTAssertGreaterThan(lang, kurz)
        XCTAssertGreaterThan(kurz, 0)
    }

    /// Ein "L" hat unten den breiten Fuss. Liegt die breiteste Zeile in der oberen
    /// Haelfte, steht die Schrift auf dem Kopf.
    func testSchriftStehtNichtAufDemKopf() {
        var feld = Pixelfeld()
        Textraster.rastern("L", schrift: "Menlo", groesse: 12, farbe: "#FFFFFF",
                           x: 1, y: 2, feld: &feld)
        var proZeile = [Int](repeating: 0, count: feld.hoehe)
        for y in 0..<feld.hoehe {
            for x in 0..<feld.breite where feld.farbe(x: x, y: y) != nil { proZeile[y] += 1 }
        }
        let breiteste = proZeile.firstIndex(of: proZeile.max()!)!
        XCTAssertGreaterThan(breiteste, feld.hoehe / 2, "der Fuss des L gehört nach unten")
    }

    func testUmlauteWerdenGerastert() {
        var mitUmlaut = Pixelfeld(), ohne = Pixelfeld()
        Textraster.rastern("Ä", schrift: "Menlo", groesse: 11, farbe: "#FFFFFF", x: 1, y: 3, feld: &mitUmlaut)
        Textraster.rastern("A", schrift: "Menlo", groesse: 11, farbe: "#FFFFFF", x: 1, y: 3, feld: &ohne)
        XCTAssertNotEqual(mitUmlaut.alsDrawBefehle(), ohne.alsDrawBefehle(),
                          "die Punkte des Ä müssen zusätzliche Pixel erzeugen")
    }

    func testLeererTextLaesstDasFeldUnberuehrt() {
        var feld = Pixelfeld()
        Textraster.rastern("", schrift: "Menlo", groesse: 11, farbe: "#FFFFFF", x: 0, y: 0, feld: &feld)
        XCTAssertTrue(feld.alsDrawBefehle().isEmpty)
    }
}
