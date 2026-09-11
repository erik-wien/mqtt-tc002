import ImageIO
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

    /// Fett muss mehr Pixel schwaerzen als der normale Schnitt bei gleicher Groesse.
    func testFettErzeugtMehrPixelAlsNichtFett() {
        func gesetztePixel(fett: Bool) -> Int {
            var feld = Pixelfeld()
            Textraster.rastern("HI", schrift: "Menlo", groesse: 11, farbe: "#FFFFFF",
                               x: 1, y: 3, feld: &feld, fett: fett)
            var n = 0
            for y in 0..<feld.hoehe {
                for x in 0..<feld.breite where feld.farbe(x: x, y: y) != nil { n += 1 }
            }
            return n
        }
        XCTAssertGreaterThan(gesetztePixel(fett: true), gesetztePixel(fett: false))
    }

    func testHoeheLiegtZwischenEinsUndDerFeldhoehe() {
        let h = Textraster.hoehe("Hallo", schrift: "Menlo", groesse: 11, fett: false)
        XCTAssertGreaterThanOrEqual(h, 1)
        XCTAssertLessThanOrEqual(h, Pixelfeld.hoeheStandard)
    }

    /// Der Rueckgabewert ist eine Daten-URI, und das darin steckende GIF hat so
    /// viele Einzelbilder, wie Textbreite und Schrittweite ergeben — ein Bild je
    /// Schritt von -52 (Fenster ganz vor dem Text) bis zur Textbreite (Fenster
    /// ganz dahinter).
    func testLaufschriftErgibtErwarteteAnzahlEinzelbilder() throws {
        let text = "Grüße", schrift = "Menlo", groesse = 11.0, schrittweite = 2
        let uri = try Textraster.laufschrift(text, schrift: schrift, groesse: groesse, fett: false,
                                             farbe: "#00FF66", schrittweite: schrittweite, bilddauer: 0.08)
        let praefix = "data:image/gif;base64,"
        XCTAssertTrue(uri.hasPrefix(praefix))

        let daten = try XCTUnwrap(Data(base64Encoded: String(uri.dropFirst(praefix.count))))
        let quelle = try XCTUnwrap(CGImageSourceCreateWithData(daten as CFData, nil))
        let textBreite = Textraster.breite(text, schrift: schrift, groesse: groesse, fett: false)
        let erwartet = Array(stride(from: -Pixelfeld.breiteStandard, through: textBreite, by: schrittweite)).count
        XCTAssertEqual(CGImageSourceGetCount(quelle), erwartet)
    }
}
