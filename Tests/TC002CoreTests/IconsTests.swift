import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import TC002Core

final class IconsTests: XCTestCase {
    /// Ein frischer, noch nicht angelegter Ordnerpfad unter dem temporaeren
    /// Verzeichnis — anlegen bleibt Sache des Aufrufers.
    private func temp() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    /// Schreibt ein Testbild mit gegebener Groesse; bei `roterPixelObenLinks`
    /// ist genau das Pixel oben links rot, alles andere schwarz — ueber
    /// `CGImageDestination`, wie `Iconsammlung.sichern` es tut.
    private func schreibeTestbild(_ datei: URL, breite: Int, hoehe: Int, roterPixelObenLinks: Bool) throws {
        var bytes = [UInt8](repeating: 0, count: breite * hoehe * 4)
        for i in 0..<(breite * hoehe) { bytes[i * 4 + 3] = 255 }
        if roterPixelObenLinks {
            bytes[0] = 255; bytes[1] = 0; bytes[2] = 0; bytes[3] = 255
        }
        guard let anbieter = CGDataProvider(data: Data(bytes) as CFData),
              let bild = CGImage(width: breite, height: hoehe, bitsPerComponent: 8, bitsPerPixel: 32,
                                 bytesPerRow: breite * 4, space: CGColorSpaceCreateDeviceRGB(),
                                 bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                 provider: anbieter, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { throw IconFehler.nichtSchreibbar("test") }
        guard let senke = CGImageDestinationCreateWithURL(datei as CFURL, UTType.gif.identifier as CFString, 1, nil) else {
            throw IconFehler.nichtSchreibbar("test")
        }
        CGImageDestinationAddImage(senke, bild, nil)
        guard CGImageDestinationFinalize(senke) else { throw IconFehler.nichtSchreibbar("test") }
    }

    private func ordnerMitIcon() throws -> URL {
        let ordner = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        // kleinstes gueltiges GIF-Kopfstueck genuegt: geprueft wird die Kodierung, nicht das Bild
        try Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]).write(to: ordner.appendingPathComponent("1673.gif"))
        try Data(#"[{"nummer":"1673","name":"Wolke","kategorie":"Wetter"}]"#.utf8)
            .write(to: ordner.appendingPathComponent("names.json"))
        return ordner
    }

    /// Ephemere Sitzung ueber den in GeraetTests.swift definierten Doppelgaenger —
    /// kein Netz, keine zweite Bauweise fuers Abfangen von Anfragen.
    private func doppelgaengerSitzung() -> URLSession {
        let konfiguration = URLSessionConfiguration.ephemeral
        konfiguration.protocolClasses = [Doppelgaenger.self]
        return URLSession(configuration: konfiguration)
    }

    override func setUp() {
        Doppelgaenger.antworten = [:]
        Doppelgaenger.statusCodes = [:]
        Doppelgaenger.gesendeteRuempfe = [:]
    }

    func testSammlungLiestOrdnerUndNamen() throws {
        let sammlung = Iconsammlung(ordner: try ordnerMitIcon())
        let alle = sammlung.alle()
        XCTAssertEqual(alle.count, 1)
        XCTAssertEqual(alle.first?.nummer, "1673")
        XCTAssertEqual(alle.first?.name, "Wolke")
    }

    func testDatenURIBeginntMitDemRichtigenTyp() throws {
        let sammlung = Iconsammlung(ordner: try ordnerMitIcon())
        let uri = try sammlung.datenURI(fuer: XCTUnwrap(sammlung.alle().first))
        XCTAssertTrue(uri.hasPrefix("data:image/gif;base64,"))
        XCTAssertTrue(uri.hasSuffix("R0lGODlh"))          // "GIF89a" in Base64
    }

    func testUnbekannterNameFaelltAufDieNummerZurueck() throws {
        let ordner = try ordnerMitIcon()
        try Data([0x47, 0x49, 0x46].self).write(to: ordner.appendingPathComponent("9999.gif"))
        let sammlung = Iconsammlung(ordner: ordner)
        let neu = try XCTUnwrap(sammlung.alle().first { $0.nummer == "9999" })
        XCTAssertEqual(neu.name, "9999")
    }

    func testFehlendeDateiWirftVerstaendlich() throws {
        let sammlung = Iconsammlung(ordner: try ordnerMitIcon())
        let erfunden = Icon(nummer: "1", name: "x", kategorie: "",
                            datei: URL(fileURLWithPath: "/gibt/es/nicht.gif"))
        XCTAssertThrowsError(try sammlung.datenURI(fuer: erfunden)) { f in
            XCTAssertTrue((f as? LocalizedError)?.errorDescription?.contains("nicht lesen") == true)
        }
    }

    /// Ein erfolgreicher Abruf legt die Datei an und traegt Name/Kategorie in
    /// names.json nach.
    func testErfolgreicherAbrufLegtDateiAnUndTraegtNamenNach() throws {
        let ordner = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        Doppelgaenger.antworten = [
            "/content/apps/icon_thumbs/4242": "GIF89a-vollstaendig-genug-an-inhalt",
            "/api/v1/dev/preloadicons": #"{"name":"Testwolke","category_name":"Wetter"}"#,
        ]

        let sammlung = Iconsammlung(ordner: ordner)
        let icon = try sammlung.holen(nummer: "4242", sitzung: doppelgaengerSitzung())

        XCTAssertEqual(icon.name, "Testwolke")
        XCTAssertEqual(icon.kategorie, "Wetter")
        let dateiPfad = ordner.appendingPathComponent("4242.gif")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dateiPfad.path))

        let namenJson = try Data(contentsOf: ordner.appendingPathComponent("names.json"))
        let liste = try JSONSerialization.jsonObject(with: namenJson) as? [[String: String]]
        XCTAssertEqual(liste?.first { $0["nummer"] == "4242" }?["name"], "Testwolke")
    }

    /// Eine zu kurze Antwort gilt als unbekannte Nummer und darf keine halbe Datei
    /// hinterlassen.
    func testZuKurzeAntwortWirftNichtGefundenOhneHalbeDatei() throws {
        let ordner = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        Doppelgaenger.antworten = ["/content/apps/icon_thumbs/9999": "zu-kurz"]

        let sammlung = Iconsammlung(ordner: ordner)
        XCTAssertThrowsError(try sammlung.holen(nummer: "9999", sitzung: doppelgaengerSitzung())) { fehler in
            XCTAssertTrue((fehler as? LocalizedError)?.errorDescription?.contains("kein Icon") == true)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: ordner.appendingPathComponent("9999.gif").path))
    }

    /// Ein Fehlercode gilt ebenfalls als unbekannte Nummer, ohne halbe Datei.
    func testFehlercodeWirftNichtGefundenOhneHalbeDatei() throws {
        let ordner = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        Doppelgaenger.statusCodes = ["/content/apps/icon_thumbs/8888": 404]

        let sammlung = Iconsammlung(ordner: ordner)
        XCTAssertThrowsError(try sammlung.holen(nummer: "8888", sitzung: doppelgaengerSitzung())) { fehler in
            XCTAssertTrue((fehler as? LocalizedError)?.errorDescription?.contains("kein Icon") == true)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: ordner.appendingPathComponent("8888.gif").path))
    }

    /// Schlaegt nur die Namensabfrage fehl, bleibt das Icon mit der Nummer als
    /// Namen bestehen — das Bild ist die Hauptsache.
    func testNamensAbfrageFehlgeschlagenIconBleibtMitNummerAlsName() throws {
        let ordner = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        Doppelgaenger.antworten = ["/content/apps/icon_thumbs/5555": "GIF89a-vollstaendig-genug-an-inhalt"]
        Doppelgaenger.statusCodes = ["/api/v1/dev/preloadicons": 500]

        let sammlung = Iconsammlung(ordner: ordner)
        let icon = try sammlung.holen(nummer: "5555", sitzung: doppelgaengerSitzung())

        XCTAssertEqual(icon.name, "5555")
        XCTAssertEqual(icon.kategorie, "")
        XCTAssertTrue(FileManager.default.fileExists(atPath: ordner.appendingPathComponent("5555.gif").path))
    }

    func testZweiOrdnerWerdenZusammengefuehrt() throws {
        let mit = temp(), eigen = temp()
        try FileManager.default.createDirectory(at: mit, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: eigen, withIntermediateDirectories: true)
        try Data("GIF89a-mitgeliefert".utf8).write(to: mit.appendingPathComponent("1.gif"))
        try Data("GIF89a-eigen".utf8).write(to: eigen.appendingPathComponent("2.gif"))
        // Gleiche Nummer in beiden Ordnern: das eigene gewinnt.
        try Data("GIF89a-alt".utf8).write(to: mit.appendingPathComponent("3.gif"))
        try Data("GIF89a-neu".utf8).write(to: eigen.appendingPathComponent("3.gif"))

        let sammlung = Iconsammlung(schreibordner: eigen, leseordner: [mit])
        let alle = sammlung.alle()
        XCTAssertEqual(Set(alle.map(\.nummer)), ["1", "2", "3"])
        let drei = try XCTUnwrap(alle.first { $0.nummer == "3" })
        XCTAssertEqual(try Data(contentsOf: drei.datei), Data("GIF89a-neu".utf8),
                       "Das eigene Icon muss das mitgelieferte verdecken")
    }

    func testSichernSchreibtEinLesbaresGif() throws {
        let eigen = temp()
        try FileManager.default.createDirectory(at: eigen, withIntermediateDirectories: true)
        let sammlung = Iconsammlung(schreibordner: eigen)

        var pixel = [String?](repeating: nil, count: 64)
        pixel[0] = "#FF0000"; pixel[63] = "#00FF66"
        let icon = try sammlung.sichern(nummer: "eigen-1", name: "Testbild", pixel: pixel)

        XCTAssertEqual(icon.name, "Testbild")
        let daten = try Data(contentsOf: icon.datei)
        XCTAssertEqual(daten.prefix(4), Data("GIF8".utf8), "Muss eine echte GIF-Datei sein")
        XCTAssertTrue(try sammlung.datenURI(fuer: icon).hasPrefix("data:image/gif;base64,"))
        XCTAssertEqual(sammlung.alle().first { $0.nummer == "eigen-1" }?.name, "Testbild",
                       "Der Name muss aus names.json wieder auftauchen")

        try sammlung.loeschen(icon)
        XCTAssertFalse(FileManager.default.fileExists(atPath: icon.datei.path))
        XCTAssertNil(sammlung.alle().first { $0.nummer == "eigen-1" })
    }

    /// Der Rundlauf durch `sichern` und `pixel(fuer:)`: oben links muss oben links
    /// bleiben. Genau an dieser Stelle stand mit dem Ursprungsunterschied zwischen
    /// CGContext (unten links) und Raster (oben links) schon einmal etwas auf dem Kopf.
    func testPixelListDenRundlaufZuSichernRichtigHerum() throws {
        let eigen = temp()
        try FileManager.default.createDirectory(at: eigen, withIntermediateDirectories: true)
        let sammlung = Iconsammlung(schreibordner: eigen)

        var geschrieben = [String?](repeating: nil, count: 64)
        geschrieben[0] = "#FF0000"    // oben links
        geschrieben[63] = "#00FF66"   // unten rechts
        let icon = try sammlung.sichern(nummer: "rundlauf", name: "Testbild", pixel: geschrieben)

        let gelesen = try sammlung.pixel(fuer: icon)

        XCTAssertEqual(gelesen.count, 64)
        XCTAssertEqual(gelesen[0], "#FF0000", "oben links bleibt oben links")
        XCTAssertEqual(gelesen[63], "#00FF66", "unten rechts bleibt unten rechts")
    }

    func testSichernVerlangtAchtMalAcht() {
        let sammlung = Iconsammlung(schreibordner: temp())
        XCTAssertThrowsError(try sammlung.sichern(nummer: "x", name: "x", pixel: [nil, nil]))
    }

    /// Mehrere Einzelbilder ergeben ein animiertes GIF mit ebenso vielen Frames —
    /// und beim Zurücklesen bleibt jedes Einzelbild an seinem Platz.
    func testMehrereBilderErgebenEinAnimiertesGif() throws {
        let eigen = temp()
        try FileManager.default.createDirectory(at: eigen, withIntermediateDirectories: true)
        let sammlung = Iconsammlung(schreibordner: eigen)

        var eins = [String?](repeating: nil, count: 64); eins[0] = "#FF0000"
        var zwei = [String?](repeating: nil, count: 64); zwei[63] = "#00FF66"
        let icon = try sammlung.sichern(nummer: "lauf", name: "Lauf",
                                        bilder: [eins, zwei], verzoegerung: 0.2)

        let quelle = try XCTUnwrap(CGImageSourceCreateWithURL(icon.datei as CFURL, nil))
        XCTAssertEqual(CGImageSourceGetCount(quelle), 2, "beide Einzelbilder muessen drin sein")

        let zurueck = try sammlung.bilder(fuer: icon)
        XCTAssertEqual(zurueck.count, 2)
        XCTAssertEqual(zurueck[0][0], "#FF0000", "oben links bleibt oben links")
        XCTAssertEqual(zurueck[1][63], "#00FF66", "unten rechts bleibt unten rechts")
    }

    /// Der bisherige Einzelbild-Weg (`pixel:`) bleibt eine Abkuerzung auf ein
    /// einzelnes Bild — `bilder(fuer:)` liest davon genau eines zurueck.
    func testEinzelbildBleibtEinzelbild() throws {
        let eigen = temp()
        try FileManager.default.createDirectory(at: eigen, withIntermediateDirectories: true)
        let sammlung = Iconsammlung(schreibordner: eigen)
        var p = [String?](repeating: nil, count: 64); p[5] = "#123456"
        let icon = try sammlung.sichern(nummer: "einzel", name: "Einzel", pixel: p)
        XCTAssertEqual(try sammlung.bilder(fuer: icon).count, 1)
        XCTAssertEqual(try sammlung.bilder(fuer: icon)[0][5], "#123456")
    }

    func testSichernVerlangtMindestensEinBild() {
        let sammlung = Iconsammlung(schreibordner: temp())
        XCTAssertThrowsError(try sammlung.sichern(nummer: "x", name: "x",
                                                  bilder: [], verzoegerung: 0.2))
    }

    /// Der Ursprung bleibt die Falle: `CGContext` faengt unten links an, das
    /// Raster oben links — deshalb hier ausdruecklich oben links geprueft.
    func testFremdeGroesseWirdGerechnet() throws {
        let datei = temp().appendingPathExtension("gif")
        try schreibeTestbild(datei, breite: 16, hoehe: 16, roterPixelObenLinks: true)
        let raster = try Bildraster.lesen(datei, breite: 8, hoehe: 8)
        XCTAssertEqual(raster.count, 1)
        XCTAssertEqual(raster[0].count, 64)
        XCTAssertEqual(raster[0][0], "#FF0000", "oben links bleibt oben links")
    }

    func testEingefuegtesIconStehtInDerSammlung() throws {
        let eigen = temp()
        try FileManager.default.createDirectory(at: eigen, withIntermediateDirectories: true)
        let sammlung = Iconsammlung(schreibordner: eigen)
        var p = [String?](repeating: nil, count: 64); p[0] = "#FF0000"
        let quelle = try XCTUnwrap(try? sammlung.sichern(nummer: "quelle", name: "Quelle", pixel: p)).datei

        let neu = try sammlung.einfuegen(datei: quelle, nummer: "kopie", name: "Kopie")
        XCTAssertEqual(neu.name, "Kopie")
        XCTAssertEqual(try sammlung.bilder(fuer: neu)[0][0], "#FF0000")
        XCTAssertNotNil(sammlung.alle().first { $0.nummer == "kopie" })
    }

    func testKeineBilddateiWirdAbgelehnt() throws {
        let kaputt = temp().appendingPathExtension("gif")
        try Data("kein Bild".utf8).write(to: kaputt)
        XCTAssertThrowsError(try Bildraster.lesen(kaputt, breite: 8, hoehe: 8))
    }
}
