import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import TC002Core

/// Befunde aus dem Codereview vom 09.10.2026 (#105, #108): Bildgrenzen,
/// Icon-Nummern in Pfaden und Adressen, Umbenennen ohne stilles Loeschen.
/// Alles gegen Wegwerfverzeichnisse.
final class HaertungTests: XCTestCase {
    private var wurzel = URL(fileURLWithPath: "/")

    override func setUp() {
        super.setUp()
        wurzel = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("haertung-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: wurzel, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: wurzel)
        super.tearDown()
    }

    /// Ein Graubild in `breite × hoehe` als PNG; leere Flaeche, darum klein.
    private func png(_ breite: Int, _ hoehe: Int) -> Data {
        let kontext = CGContext(data: nil, width: breite, height: hoehe, bitsPerComponent: 8,
                                bytesPerRow: breite, space: CGColorSpaceCreateDeviceGray(),
                                bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        let daten = NSMutableData()
        let senke = CGImageDestinationCreateWithData(daten, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(senke, kontext.makeImage()!, nil)
        CGImageDestinationFinalize(senke)
        return daten as Data
    }

    /// Ein GIF mit `bilder` verschiedenen 16×16-Einzelbildern (in jedem ist ein
    /// anderer Punkt hell; gleiche Bilder fasst der Kodierer sonst zusammen).
    static func kleinesGIF(bilder: Int = 1) -> Data {
        let daten = NSMutableData()
        let senke = CGImageDestinationCreateWithData(daten, UTType.gif.identifier as CFString, bilder, nil)!
        for i in 0..<bilder {
            let kontext = CGContext(data: nil, width: 16, height: 16, bitsPerComponent: 8,
                                    bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            kontext.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            kontext.fill(CGRect(x: i % 16, y: (i / 16) % 16, width: 1, height: 1))
            CGImageDestinationAddImage(senke, kontext.makeImage()!, nil)
        }
        CGImageDestinationFinalize(senke)
        return daten as Data
    }

    private func gif(bilder: Int) -> Data { Self.kleinesGIF(bilder: bilder) }

    // MARK: Bildgrenzen (#105)

    func testEinRiesenbildWirdVorDemDekodierenAbgelehnt() throws {
        let gross = png(30_000, 30_000)
        XCTAssertThrowsError(try Bildraster.lesen(gross, breite: 8, hoehe: 8)) { fehler in
            guard case BildrasterFehler.zuGross = fehler else { return XCTFail("\(fehler)") }
        }
        XCTAssertThrowsError(try Bildraster.lesenMitZeiten(gross, breite: 52, hoehe: 16))
        let sammlung = Iconsammlung(schreibordner: wurzel.appendingPathComponent("i"))
        XCTAssertThrowsError(try sammlung.einfuegen(daten: gross, nummer: "1", name: "x"))
        XCTAssertNoThrow(try Bildraster.lesen(png(2048, 2048), breite: 8, hoehe: 8))
    }

    func testZuVieleEinzelbilderWerdenAbgelehnt() throws {
        XCTAssertThrowsError(try Bildraster.lesen(gif(bilder: 257), breite: 8, hoehe: 8)) { fehler in
            guard case BildrasterFehler.zuGross = fehler else { return XCTFail("\(fehler)") }
        }
        XCTAssertEqual(try Bildraster.lesen(gif(bilder: 256), breite: 8, hoehe: 8).count, 256)
    }

    func testBildPruefen() {
        XCTAssertNoThrow(try Bildraster.bildPruefen(gif(bilder: 1), hoechstens: 10_000))
        XCTAssertThrowsError(try Bildraster.bildPruefen(Data("<html>".utf8), hoechstens: 10_000))
        XCTAssertThrowsError(try Bildraster.bildPruefen(gif(bilder: 1), hoechstens: 10))
    }

    // MARK: Nummern (#105)

    func testNummernMitPfadanteilenWerdenAbgewiesen() {
        for schlecht in ["../../x", "1/../2", "a/b", "..", ".", "", "  ", ".versteckt", "a:b", "a\u{0}b"] {
            XCTAssertThrowsError(try Iconnummer.dateiname(schlecht), schlecht)
        }
        for schlecht in ["1 2", "a.b", "x@evil/", "12/34", "é", String(repeating: "1", count: 65), ""] {
            XCTAssertThrowsError(try Iconnummer.lametric(schlecht), schlecht)
        }
        XCTAssertEqual(try Iconnummer.lametric(" a1021 "), "a1021")
        XCTAssertEqual(try Iconnummer.dateiname("Herz 2"), "Herz 2")
    }

    func testSichernSchreibtNieAusserhalbDesOrdners() throws {
        let sammlung = Iconsammlung(schreibordner: wurzel.appendingPathComponent("i"))
        XCTAssertThrowsError(try sammlung.sichern(nummer: "../draussen", name: "x",
                                                  pixel: [String?](repeating: nil, count: 64)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: wurzel.appendingPathComponent("draussen.gif").path))
    }

    func testHolenPrueftDieNummerVorDemNetz() throws {
        let sammlung = Iconsammlung(schreibordner: wurzel.appendingPathComponent("i"))
        for schlecht in ["1/../2", "x y", ""] {
            XCTAssertThrowsError(try sammlung.holen(nummer: schlecht), schlecht) { fehler in
                guard case IconFehler.ungueltigeNummer = fehler else { return XCTFail("\(fehler)") }
            }
        }
    }

    // MARK: Umbenennen ohne stilles Loeschen (#108)

    private func zwei(_ sammlung: Iconsammlung) throws -> (Icon, Icon) {
        var a = [String?](repeating: nil, count: 64); a[0] = "#FF0000"
        var b = [String?](repeating: nil, count: 64); b[0] = "#00FF00"
        return (try sammlung.sichern(nummer: "A", name: "Eins", pixel: a),
                try sammlung.sichern(nummer: "B", name: "Zwei", pixel: b))
    }

    func testIconUmbenennenInBelegtenSchluesselWirftUndLaesstBeidesStehen() throws {
        let sammlung = Iconsammlung(schreibordner: wurzel.appendingPathComponent("i"))
        let (a, b) = try zwei(sammlung)
        let vorher = try Data(contentsOf: b.datei)
        XCTAssertThrowsError(try sammlung.umbenennen(a, nummer: "B", name: "Eins")) { fehler in
            guard case IconFehler.zielBelegt = fehler else { return XCTFail("\(fehler)") }
            XCTAssertFalse((fehler as? LocalizedError)?.errorDescription?.isEmpty ?? true)
        }
        XCTAssertEqual(try Data(contentsOf: b.datei), vorher)
        XCTAssertTrue(FileManager.default.fileExists(atPath: a.datei.path))
    }

    func testIconUmbenennenMitUeberschreibenErsetzt() throws {
        let sammlung = Iconsammlung(schreibordner: wurzel.appendingPathComponent("i"))
        let (a, b) = try zwei(sammlung)
        let neu = try sammlung.umbenennen(a, nummer: "B", name: "Eins", ueberschreiben: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: a.datei.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: neu.datei.path))
        XCTAssertEqual(neu.datei, b.datei)
    }

    func testBildUmbenennenInBelegtenNamenWirftUndLaesstBeidesStehen() throws {
        let sammlung = Bildersammlung(ordner: wurzel.appendingPathComponent("b"))
        var voll = Pixelfeld(); voll.setzen(x: 0, y: 0, farbe: "#FF0000")
        let a = try sammlung.sichern(name: "A", feld: voll)
        let b = try sammlung.sichern(name: "B", feld: Pixelfeld())
        let vorher = try Data(contentsOf: b.datei)
        XCTAssertThrowsError(try sammlung.umbenennen(a, name: "B", nummer: nil)) { fehler in
            guard case BildersammlungFehler.zielBelegt = fehler else { return XCTFail("\(fehler)") }
        }
        XCTAssertEqual(try Data(contentsOf: b.datei), vorher)
        XCTAssertTrue(FileManager.default.fileExists(atPath: a.datei.path))
        let neu = try sammlung.umbenennen(a, name: "B", nummer: nil, ueberschreiben: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: a.datei.path))
        XCTAssertNotEqual(try Data(contentsOf: neu.datei), vorher)
    }

    func testNurGrossKleinschreibungAendernBleibtErlaubt() throws {
        let sammlung = Bildersammlung(ordner: wurzel.appendingPathComponent("b"))
        let a = try sammlung.sichern(name: "abc", feld: Pixelfeld())
        XCTAssertNoThrow(try sammlung.umbenennen(a, name: "ABC", nummer: nil))
    }
}
