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

    /// Beide Wege muessen den Text in derselben Phase rastern. Bei 11 Punkt ohne
    /// Kantenglaettung entscheidet ein Pixel Versatz darueber, welche Punkte den
    /// Schwellwert ueberschreiten — sonst sieht dieselbe Schrift stehend anders
    /// aus als laufend, und genau das ist gemeldet worden.
    func testLaufschriftRastertWieDerStehendeWeg() {
        let text = "Hallo Armin!"
        var stehend = Pixelfeld()
        Textraster.einsetzen(Textraster.rasterPuffer(text, schrift: "Menlo", groesse: 11,
                                                     fett: false, farbe: "#00FF66"),
                             x: 0, y: 0, in: &stehend)

        let bilder = Textraster.laufschriftEinzelbilder(text, schrift: "Menlo", groesse: 11,
                                                        fett: false, farbe: "#00FF66",
                                                        schrittweite: 1, bilddauer: 0.08)
        // Das Fenster startet 52 Spalten vor dem Text und wandert in Einerschritten:
        // Bild 52 zeigt ihn ab Spalte 0 — dieselbe Lage wie stehend.
        let bild = bilder[Pixelfeld.breiteStandard]
        for y in 0..<Pixelfeld.hoeheStandard {
            for x in 0..<Pixelfeld.breiteStandard {
                XCTAssertEqual(bild.pixel[y * Pixelfeld.breiteStandard + x], stehend.farbe(x: x, y: y),
                               "Punkt \(x)/\(y)")
            }
        }
    }

    /// Die senkrechte Ausrichtung gilt auch fuer die Laufschrift — vorher rechnete
    /// sie sich stur die Mitte aus und liess die Einstellung liegen.
    func testLaufschriftFolgtDerSenkrechtenAusrichtung() {
        func zeilen(versatzY: Int) -> [Int] {
            let bild = Textraster.laufschriftEinzelbilder("Hallo", schrift: "Menlo", groesse: 11,
                                                          fett: false, farbe: "#FFFFFF",
                                                          schrittweite: 1, bilddauer: 0.08,
                                                          versatzY: versatzY)[Pixelfeld.breiteStandard]
            return (0..<Pixelfeld.hoeheStandard).filter { y in
                (0..<Pixelfeld.breiteStandard).contains { bild.pixel[y * Pixelfeld.breiteStandard + $0] != nil }
            }
        }
        let oben = zeilen(versatzY: 0), unten = zeilen(versatzY: 3)
        XCTAssertFalse(oben.isEmpty)
        XCTAssertEqual(unten.first, oben.first.map { $0 + 3 })
    }

    /// Das feststehende Icon gehoert in jedes Einzelbild an dieselbe Stelle, und
    /// seine Spalten bleiben frei vom durchlaufenden Text — sonst blitzt der
    /// zwischen den Iconpunkten hindurch.
    func testFeststehendesIconStehtInJedemBild() {
        var icon = [String?](repeating: nil, count: 64)
        icon[0] = "#FF0000"                                  // oben links im Icon
        let bilder = Textraster.laufschriftEinzelbilder("Hallo Welt, hallo Welt", schrift: "Menlo",
                                                        groesse: 11, fett: false, farbe: "#00FF66",
                                                        schrittweite: 1, bilddauer: 0.08,
                                                        iconBilder: [icon])
        XCTAssertGreaterThan(bilder.count, 10)
        let breite = Pixelfeld.breiteStandard
        for (n, bild) in bilder.enumerated() {
            XCTAssertEqual(bild.pixel[4 * breite + 0], "#FF0000", "Iconpunkt in Bild \(n)")
            for y in 0..<Pixelfeld.hoeheStandard {
                for x in 0..<(8 + 2) where !(x == 0 && y == 4) {
                    XCTAssertNil(bild.pixel[y * breite + x], "Spalte \(x) in Bild \(n) gehört dem Icon")
                }
            }
        }
        XCTAssertNotEqual(bilder[bilder.count / 3].pixel, bilder[bilder.count / 2].pixel,
                          "der Textbereich läuft trotzdem durch")
    }

    /// Mitlaufend heisst: das Icon wandert selbst durchs Bild und haelt die
    /// linken Spalten nicht frei.
    func testMitlaufendesIconWandert() {
        var icon = [String?](repeating: nil, count: 64)
        icon[0] = "#FF0000"
        let bilder = Textraster.laufschriftEinzelbilder("Hallo", schrift: "Menlo", groesse: 11,
                                                        fett: false, farbe: "#00FF66",
                                                        schrittweite: 1, bilddauer: 0.08,
                                                        iconBilder: [icon], iconLaeuftMit: true)
        let breite = Pixelfeld.breiteStandard
        let stellen = bilder.compactMap { bild -> Int? in
            (0..<breite).first { bild.pixel[4 * breite + $0] == "#FF0000" }
        }
        XCTAssertGreaterThan(stellen.count, 5)
        XCTAssertGreaterThan(Set(stellen).count, 5, "das Icon steht nicht still")
    }

    /// Ein animiertes Icon spielt waehrend des Laufs ab, statt auf seinem ersten
    /// Einzelbild stehenzubleiben.
    func testAnimiertesIconWechseltDieBilder() {
        var eins = [String?](repeating: nil, count: 64), zwei = [String?](repeating: nil, count: 64)
        eins[0] = "#FF0000"
        zwei[63] = "#0000FF"
        let bilder = Textraster.laufschriftEinzelbilder("Hallo", schrift: "Menlo", groesse: 11,
                                                        fett: false, farbe: "#00FF66",
                                                        schrittweite: 1, bilddauer: 0.08,
                                                        iconBilder: [eins, zwei])
        let breite = Pixelfeld.breiteStandard
        XCTAssertEqual(bilder[0].pixel[4 * breite + 0], "#FF0000")
        XCTAssertEqual(bilder[1].pixel[(4 + 7) * breite + 7], "#0000FF")
    }
}
