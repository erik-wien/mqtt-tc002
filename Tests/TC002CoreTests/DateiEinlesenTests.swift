import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import TC002Core

/// „Der iPad Icon Editor kann die beiden maze gifs im Download Ordner nicht
/// importieren" — gemeldet am 13.09.2026.
///
/// Zwei Verdaechtige — und beide waren schuldig. Die Oberflaeche merkte sich
/// die URL und las erst spaeter, wenn der Zugriff laengst zu war; der Kern
/// rechnete jede Datei stillschweigend auf die eingestellte Groesse herunter,
/// und die beiden GIFs waren 16×16. Seit dem 13.09.2026 nimmt er jede der drei
/// Groessen in ihrer eigenen auf und lehnt jede andere mit Begruendung ab.
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

    // MARK: - C1: die Groesse der Datei entscheidet

    /// **C1.** Eine Datei wird in **ihrer eigenen** Groesse aufgenommen — der
    /// Editor stellt sich auf sie ein, nicht umgekehrt. Bis zum 13.09.2026
    /// nahm `einlesen` die gewuenschte Groesse als Argument entgegen und
    /// rechnete alles darauf herunter; genau daran ist der Auftraggeber mit
    /// zwei 16×16-`maze`-GIFs haengengeblieben, die als 8×8 landeten.
    ///
    /// Nachgewiesen an dem, was zurueckkommt, nicht an dem, was der
    /// Rueckgabewert behauptet.
    func testJedeDerDreiGroessenWirdInIhrerEigenenAufgenommen() throws {
        for groesse in Leinwandgroesse.allCases {
            let daten = try gif(breite: groesse.breite, hoehe: groesse.hoehe)
            let eintrag = try bestand.einlesen(daten: daten,
                                               nummer: "n\(groesse.breite)",
                                               name: "N\(groesse.breite)")
            XCTAssertEqual(eintrag.groesse, groesse)
            let zurueck = try bestand.oeffnen(eintrag)
            XCTAssertEqual(zurueck.breite, groesse.breite, "\(groesse.beschriftung): Breite")
            XCTAssertEqual(zurueck.hoehe, groesse.hoehe, "\(groesse.beschriftung): Höhe")
            XCTAssertEqual(zurueck.bild[0], "#FF0000", "oben links bleibt oben links")
        }
    }

    /// Und eine Fremdgroesse wird **abgelehnt**, statt auf die naechstliegende
    /// gerechnet zu werden (entschieden am 13.09.2026). Geprueft wird beides:
    /// dass es wirft — und dass danach **nichts** auf der Platte liegt. Ein
    /// Fehler, der trotzdem etwas schreibt, waere schlimmer als keiner.
    func testEineFremdeGroesseWirdAbgelehntUndSchreibtNichts() throws {
        for (qb, qh) in [(32, 32), (104, 32), (7, 7)] {
            XCTAssertThrowsError(try bestand.einlesen(daten: try gif(breite: qb, hoehe: qh),
                                                      nummer: "maze", name: "Maze"),
                                 "\(qb)×\(qh) wurde angenommen") { fehler in
                guard case EditorbestandFehler.fremdeGroesse(let b, let h) = fehler else {
                    return XCTFail("falscher Fehler: \(fehler)")
                }
                XCTAssertEqual([b, h], [qb, qh], "die Begründung nennt die falsche Größe")
            }
        }
        for teil in ["Icons", "Icons16", "Bilder"] {
            let inhalt = (try? FileManager.default.contentsOfDirectory(
                atPath: wurzel.appendingPathComponent(teil).path)) ?? []
            XCTAssertEqual(inhalt.filter { $0.hasSuffix(".gif") }, [],
                           "\(teil) hat trotz Ablehnung etwas bekommen")
        }
    }

    /// Die Begruendung nennt beides: **was es ist** und **was ginge**. Eine
    /// Meldung, die nur „geht nicht" sagt, laesst den Anwender raten, und
    /// genau darum ging es bei C1.
    func testDieBegruendungNenntDieGroesseUndDieDreiMoeglichen() {
        let text = EditorbestandFehler.fremdeGroesse(breite: 32, hoehe: 32).errorDescription ?? ""
        XCTAssertTrue(text.contains("32×32"), "die Begründung nennt die Größe der Datei nicht: \(text)")
        for moeglich in ["8×8", "16×16", "16×52"] {
            XCTAssertTrue(text.contains(moeglich),
                          "die Begründung nennt \(moeglich) nicht: \(text)")
        }
    }

    /// Ein animiertes GIF behaelt seine Einzelbilder — in seiner eigenen
    /// Groesse.
    func testEinAnimiertesGifBehaeltSeineEinzelbilder() throws {
        let eintrag = try bestand.einlesen(daten: try gif(breite: 16, hoehe: 16, bilder: 3),
                                           nummer: "", name: "Lauf")
        XCTAssertEqual(eintrag.groesse, .icon16)
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
    /// aufgeht, das nach einem Namen fragt. `zielgroesse(fuer:)` ist die Probe,
    /// die die Ansicht dafuer benutzt.
    func testWasKeinBildIstWirdErkannt() {
        XCTAssertNil(Bildraster.groesse(Data("kein Bild, nur Text".utf8)))
        XCTAssertNil(Bildraster.groesse(Data()))
        XCTAssertThrowsError(try Bildraster.lesen(Data("kein Bild".utf8), breite: 8, hoehe: 8))
        XCTAssertThrowsError(try Editorbestand.zielgroesse(fuer: Data("kein Bild".utf8))) { fehler in
            guard case EditorbestandFehler.keinBild = fehler else {
                return XCTFail("falscher Fehler: \(fehler)")
            }
        }
    }
}
