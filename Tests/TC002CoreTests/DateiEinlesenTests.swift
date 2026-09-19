import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import TC002Core

/// Ein GIF wird in seiner eigenen Groesse aufgenommen — Kleineres mittig in
/// den kleinsten Raster, der es fasst — und Groesseres mit Begruendung
/// abgelehnt, statt es stillschweigend herunterzurechnen.
/// Zusaetzlich liest der Kern Bytes an, statt sich eine URL zu merken und
/// spaeter zu lesen — dann waere der Zugriff auf eine zugriffsgeschuetzte
/// Datei laengst zu.
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

    /// C1. Eine Datei wird in ihrer eigenen Groesse aufgenommen — der Editor
    /// stellt sich auf sie ein, nicht umgekehrt: `einlesen` nimmt nicht die
    /// gewuenschte Groesse als Argument entgegen und rechnet nichts darauf
    /// herunter.
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

    /// Kleineres kommt mittig in den kleinsten Raster, der es fasst: Ein
    /// 7×7 ist ein 8×8-Icon mit leerem Rand, ein 12×10 ein 16×16, ein 32×8
    /// eine Anzeige. Nachgewiesen am roten Pixel, der mitwandert.
    func testKleineresKommtMittigInDenKleinstenRaster() throws {
        let faelle: [(Int, Int, Leinwandgroesse, Int)] = [
            (7, 7, .icon8, 0), (12, 10, .icon16, 3 * 16 + 2), (32, 8, .anzeige, 4 * 52 + 10),
        ]
        for (qb, qh, erwartet, index) in faelle {
            let eintrag = try bestand.einlesen(daten: try gif(breite: qb, hoehe: qh),
                                               nummer: "k\(qb)", name: "K\(qb)")
            XCTAssertEqual(eintrag.groesse, erwartet, "\(qb)×\(qh)")
            let zurueck = try bestand.oeffnen(eintrag)
            XCTAssertEqual(zurueck.breite, erwartet.breite, "\(qb)×\(qh): Breite")
            XCTAssertEqual(zurueck.hoehe, erwartet.hoehe, "\(qb)×\(qh): Höhe")
            XCTAssertEqual(zurueck.bild[index], "#FF0000", "\(qb)×\(qh): das rote Pixel sitzt nicht mittig")
        }
    }

    /// Und was nicht auf die Anzeige passt, wird abgelehnt, statt auf sie
    /// gerechnet zu werden. Geprueft wird beides: dass es wirft — und dass
    /// danach nichts auf der Platte liegt.
    func testEineFremdeGroesseWirdAbgelehntUndSchreibtNichts() throws {
        for (qb, qh) in [(32, 32), (104, 32), (53, 16), (52, 17)] {
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

    /// Die Begruendung nennt beides: was es ist und was ginge, beides in
    /// Breite × Höhe. Eine Meldung, die nur „geht nicht" sagt, laesst den
    /// Anwender raten.
    func testDieBegruendungNenntDieGroesseUndDieAnzeige() {
        let text = EditorbestandFehler.fremdeGroesse(breite: 32, hoehe: 32).errorDescription ?? ""
        XCTAssertTrue(text.contains("32×32"), "die Begründung nennt die Größe der Datei nicht: \(text)")
        XCTAssertTrue(text.contains("52×16"), "die Begründung nennt die Anzeige nicht: \(text)")
    }

    /// Ein animiertes GIF behaelt seine Einzelbilder — in seiner eigenen
    /// Groesse.
    func testEinAnimiertesGifBehaeltSeineEinzelbilder() throws {
        let eintrag = try bestand.einlesen(daten: try gif(breite: 16, hoehe: 16, bilder: 3),
                                           nummer: "", name: "Lauf")
        XCTAssertEqual(eintrag.groesse, .icon16)
        XCTAssertEqual(try bestand.oeffnen(eintrag).bilder.count, 3)
    }

    // MARK: - A4: was das Blatt vorschlaegt und was es warnt

    /// A4. Aus `2981_Severe TStorm` wird die Nummer `2981` und der Titel
    /// `Severe TStorm`.
    ///
    /// Geraten wird nur, wo es etwas zu raten gibt: `maze_2` ist keine
    /// Nummer, und wo keine dasteht, bleibt das Feld leer, statt einen
    /// Dateinamen als LaMetric-Nummer auszugeben.
    func testAusNummerUnterstrichTitelWerdenNummerUndTitel() {
        let faelle: [(String, String, String)] = [
            ("2981_Severe TStorm", "2981", "Severe TStorm"),
            ("2981", "2981", "2981"),
            ("12_34_56", "12", "34_56"),
            ("2981_  Severe  ", "2981", "Severe"),
            ("maze", "", "maze"),
            ("maze_2", "", "maze_2"),
            ("_foo", "", "_foo"),
            ("2981_", "", "2981_"),
        ]
        for (basis, nummer, name) in faelle {
            let vorschlag = Editorbestand.vorschlag(fuerDateinamen: basis)
            XCTAssertEqual(vorschlag.nummer, nummer, "Nummer aus „\(basis)“")
            XCTAssertEqual(vorschlag.name, name, "Name aus „\(basis)“")
        }
    }

    /// Und eine schon vergebene Nummer faellt auf, bevor gesichert wird.
    /// Ersetzt wird sie trotzdem — aber sichtbar: Der Eintrag, den es trifft,
    /// wird beim Namen genannt.
    ///
    /// Bei 8×8 entscheidet die Nummer, bei den anderen beiden der Name; das
    /// ist dieselbe Rechnung, nach der abgelegt wird
    /// (`Editorbestand.schluessel`), und darf nicht daneben noch einmal
    /// stehen.
    func testEineVergebeneNummerFaelltVorDemSichernAuf() throws {
        try bestand.einlesen(daten: try gif(breite: 8, hoehe: 8),
                             nummer: "2981", name: "Severe TStorm")
        try bestand.einlesen(daten: try gif(breite: 16, hoehe: 16), nummer: "", name: "Maze")
        let liste = bestand.alle()

        XCTAssertEqual(Editorbestand.belegt(in: liste, groesse: .icon8,
                                            nummer: "2981", name: "ganz anders")?.name,
                       "Severe TStorm",
                       "die vergebene Nummer fällt nicht auf")
        XCTAssertNil(Editorbestand.belegt(in: liste, groesse: .icon8,
                                          nummer: "2982", name: "Severe TStorm"),
                     "bei 8×8 entscheidet die Nummer, nicht der Name")
        XCTAssertNil(Editorbestand.belegt(in: liste, groesse: .icon16,
                                          nummer: "2981", name: "etwas Neues"),
                     "ein 8×8 belegt nichts im 16×16-Bestand")
        XCTAssertEqual(Editorbestand.belegt(in: liste, groesse: .icon16,
                                            nummer: "", name: " maze ")?.name, "Maze",
                       "auf diesen Dateisystemen ersetzt „maze“ sehr wohl „Maze“")
        XCTAssertNil(Editorbestand.belegt(in: liste, groesse: .icon8, nummer: "", name: ""),
                     "ohne Schlüssel ist nichts belegt")
    }

    // MARK: - Verdacht 2: der Weg ueber die Daten

    /// Damit die Ansicht sofort lesen kann, statt sich eine URL zu merken
    /// und erst spaeter zu lesen — wenn der Zugriff auf eine
    /// zugriffsgeschuetzte Datei laengst zu ist —, muss der Kern Bytes
    /// annehmen und dabei dasselbe liefern wie ueber die Datei.
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

    /// Was keine Bilddatei ist, muss auffallen — und zwar bevor ein Blatt
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
