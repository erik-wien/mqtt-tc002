import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import TC002Core

/// „Der iPad Icon Editor kann die beiden maze gifs im Download Ordner nicht
/// importieren" — gemeldet am 13.09.2026.
///
/// Zwei Verdaechtige, und dieser Test trennt sie: Wird ein zu grosses GIF
/// **abgewiesen** (dann waere es der Kern), oder wird es heruntergerechnet
/// (dann liegt es an der Oberflaeche und ihrem Zugriff auf die Datei)?
///
/// Geschrieben wird ausschliesslich in ein Wegwerfverzeichnis.
final class DateiEinlesenTests: XCTestCase {
    private var wurzel: URL!

    override func setUpWithError() throws {
        wurzel = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("Einlesen-\(UUID().uuidString)")
        for teil in ["Icons", "Icons16", "Bilder", "Quelle"] {
            try FileManager.default.createDirectory(
                at: wurzel.appendingPathComponent(teil), withIntermediateDirectories: true)
        }
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: wurzel)
    }

    private var bestand: Editorbestand {
        Editorbestand(icons8: Iconsammlung(schreibordner: wurzel.appendingPathComponent("Icons")),
                      icons16: Iconsammlung(schreibordner: wurzel.appendingPathComponent("Icons16"), kante: 16),
                      bilder: Bildersammlung(ordner: wurzel.appendingPathComponent("Bilder")))
    }

    /// Ein GIF beliebiger Groesse, Pixel oben links rot, der Rest schwarz.
    /// `bilder` > 1 ergibt ein animiertes.
    private func gif(breite: Int, hoehe: Int, bilder: Int = 1) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: breite * hoehe * 4)
        for i in 0..<(breite * hoehe) { bytes[i * 4 + 3] = 255 }
        bytes[0] = 255
        guard let anbieter = CGDataProvider(data: Data(bytes) as CFData),
              let bild = CGImage(width: breite, height: hoehe, bitsPerComponent: 8, bitsPerPixel: 32,
                                 bytesPerRow: breite * 4, space: CGColorSpaceCreateDeviceRGB(),
                                 bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                 provider: anbieter, decode: nil, shouldInterpolate: false,
                                 intent: .defaultIntent),
              let daten = CFDataCreateMutable(nil, 0),
              let senke = CGImageDestinationCreateWithData(daten, UTType.gif.identifier as CFString,
                                                          bilder, nil)
        else { throw BildrasterFehler.nichtLesbar }
        for _ in 0..<bilder { CGImageDestinationAddImage(senke, bild, nil) }
        guard CGImageDestinationFinalize(senke) else { throw BildrasterFehler.nichtLesbar }
        return daten as Data
    }

    // MARK: - Verdacht 1: wird zu Grosses abgewiesen?

    /// Nein. Ein 32×32 wird auf die Groesse des Bestands heruntergerechnet,
    /// ohne Glaettung — so wie die Hilfe es seit jeher sagt. Der Kern ist
    /// unschuldig.
    func testEinZuGrossesGifWirdHeruntergerechnetUndNichtAbgewiesen() throws {
        let daten = try gif(breite: 32, hoehe: 32)
        let eintrag = try bestand.einlesen(daten: daten, groesse: .icon8,
                                           nummer: "maze", name: "Maze")
        XCTAssertEqual(eintrag.groesse, .icon8)
        let zurueck = try bestand.oeffnen(eintrag)
        XCTAssertEqual(zurueck.bild.count, 64, "aus 32×32 muss ein 8×8 geworden sein")
        XCTAssertEqual(zurueck.bild[0], "#FF0000", "oben links bleibt oben links")
    }

    /// Dasselbe fuer die beiden anderen Groessen — damit nicht eine davon
    /// stillschweigend eine andere Regel bekommt.
    func testJedeGroesseNimmtEineFremdeVorlageAn() throws {
        let faelle: [(Leinwandgroesse, Int, Int)] = [
            (.icon8, 32, 32), (.icon16, 64, 64), (.anzeige, 104, 32),
        ]
        for (groesse, qb, qh) in faelle {
            let eintrag = try bestand.einlesen(daten: try gif(breite: qb, hoehe: qh),
                                               groesse: groesse,
                                               nummer: "q\(qb)", name: "Q\(qb)")
            let zurueck = try bestand.oeffnen(eintrag)
            XCTAssertEqual(zurueck.bild.count, groesse.breite * groesse.hoehe,
                           "\(qb)×\(qh) → \(groesse.beschriftung)")
        }
    }

    /// Und ein animiertes behaelt beim Umrechnen seine Einzelbilder.
    func testEinAnimiertesGifBehaeltSeineEinzelbilder() throws {
        let eintrag = try bestand.einlesen(daten: try gif(breite: 40, hoehe: 40, bilder: 3),
                                           groesse: .icon16, nummer: "", name: "Lauf")
        XCTAssertEqual(try bestand.oeffnen(eintrag).bilder.count, 3)
    }

    // MARK: - Verdacht 2: der Weg ueber die Daten

    /// Der eigentliche Fehler sass in der Ansicht: Sie merkte sich die URL aus
    /// dem Dateiwaehler und las erst spaeter — da war der Zugriff auf die
    /// zugriffsgeschuetzte Datei laengst zu. Damit sie sofort lesen **kann**,
    /// muss der Kern Bytes annehmen und dabei dasselbe liefern wie ueber die
    /// Datei.
    func testAusDatenKommtDasselbeHerausWieAusEinerDatei() throws {
        let daten = try gif(breite: 32, hoehe: 32)
        let datei = wurzel.appendingPathComponent("Quelle/maze.gif")
        try daten.write(to: datei)

        XCTAssertEqual(try Bildraster.lesen(daten, breite: 8, hoehe: 8),
                       try Bildraster.lesen(datei, breite: 8, hoehe: 8))
        // Auch nicht quadratisch: Ein quadratischer Vergleich allein saehe
        // nicht, wenn Breite und Hoehe vertauscht oder gleichgesetzt wuerden.
        XCTAssertEqual(try Bildraster.lesen(daten, breite: 52, hoehe: 16),
                       try Bildraster.lesen(datei, breite: 52, hoehe: 16))
        XCTAssertEqual(try Bildraster.lesenMitZeiten(daten, breite: 52, hoehe: 16),
                       try Bildraster.lesenMitZeiten(datei, breite: 52, hoehe: 16))
        let a = Bildraster.groesse(daten), b = Bildraster.groesse(datei)
        XCTAssertEqual(a?.breite, b?.breite)
        XCTAssertEqual(a?.hoehe, b?.hoehe)
        XCTAssertEqual(a?.breite, 32)
    }

    /// Was keine Bilddatei ist, muss auffallen — und zwar **bevor** ein Blatt
    /// aufgeht, das nach einem Namen fragt. `groesse(_ daten:)` ist die Probe,
    /// die die Ansicht dafuer benutzt.
    func testWasKeinBildIstWirdErkannt() {
        XCTAssertNil(Bildraster.groesse(Data("kein Bild, nur Text".utf8)))
        XCTAssertNil(Bildraster.groesse(Data()))
        XCTAssertThrowsError(try Bildraster.lesen(Data("kein Bild".utf8), breite: 8, hoehe: 8))
    }
}
