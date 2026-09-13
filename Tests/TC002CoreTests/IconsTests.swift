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

    /// Eigene Icons liegen im Schreibordner und sind loeschbar, mitgelieferte
    /// liegen nur im Leseordner und sind es nicht — dieselbe Unterscheidung,
    /// auf der auch der Loeschen-Knopf in der Oberflaeche beruht.
    func testIstEigenUnterscheidetEigeneVonMitgelieferten() throws {
        let mit = temp(), eigen = temp()
        try FileManager.default.createDirectory(at: mit, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: eigen, withIntermediateDirectories: true)
        try Data("GIF89a-mitgeliefert".utf8).write(to: mit.appendingPathComponent("1.gif"))

        let sammlung = Iconsammlung(schreibordner: eigen, leseordner: [mit])
        let eigenes = try sammlung.sichern(nummer: "2", name: "Eigen",
                                           pixel: [String?](repeating: nil, count: 64))
        let mitgeliefertes = try XCTUnwrap(sammlung.alle().first { $0.nummer == "1" })

        XCTAssertTrue(sammlung.istEigen(eigenes))
        XCTAssertFalse(sammlung.istEigen(mitgeliefertes))
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

    /// `lesenMitZeiten` liefert zu jedem Einzelbild die beim Sichern vergebene
    /// Standzeit zurueck — die abspielende Vorschau braucht genau das.
    func testLesenMitZeitenLiefertDieStandzeitenZurueck() throws {
        let eigen = temp()
        try FileManager.default.createDirectory(at: eigen, withIntermediateDirectories: true)
        let sammlung = Iconsammlung(schreibordner: eigen)

        var eins = [String?](repeating: nil, count: 64); eins[0] = "#FF0000"
        var zwei = [String?](repeating: nil, count: 64); zwei[63] = "#00FF66"
        let icon = try sammlung.sichern(nummer: "lauf2", name: "Lauf 2",
                                        bilder: [eins, zwei], verzoegerung: 0.2)

        let zurueck = try Bildraster.lesenMitZeiten(icon.datei, breite: 8, hoehe: 8)
        XCTAssertEqual(zurueck.count, 2)
        XCTAssertEqual(zurueck[0].dauer, 0.2, accuracy: 0.01)
        XCTAssertEqual(zurueck[1].dauer, 0.2, accuracy: 0.01)
        XCTAssertEqual(zurueck[0].pixel[0], "#FF0000")
        XCTAssertEqual(zurueck[1].pixel[63], "#00FF66")
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

    /// `Bildraster` ist seit dem Wegfall von `Bildladen` der einzige Leseweg der
    /// Mac-Ansichten. Ein animiertes Icon darf dabei keine Einzelbilder
    /// verlieren: Der Icon-Editor baut aus ihnen wieder ein animiertes GIF, und
    /// was hier fehlt, ist beim naechsten Sichern endgueltig weg.
    ///
    /// Fuenf Bilder, nicht zwei — so faellt auch auf, wer nur das erste und das
    /// letzte durchlaesst.
    func testAnimiertesGifBehaeltAlleEinzelbilder() throws {
        let datei = temp().appendingPathExtension("gif")
        let bilder: [[String?]] = (0..<5).map { i in
            var p = [String?](repeating: nil, count: 64); p[i] = "#FF0000"; return p
        }
        let uri = try Bildraster.alsDatenURI(bilder, breite: 8, hoehe: 8, verzoegerung: 0.1)
        let daten = try XCTUnwrap(Data(base64Encoded: String(uri.dropFirst("data:image/gif;base64,".count))))
        try daten.write(to: datei)

        let gelesen = try Bildraster.lesen(datei, breite: 8, hoehe: 8)
        XCTAssertEqual(gelesen.count, 5, "alle fuenf Einzelbilder")
        for i in 0..<5 {
            XCTAssertEqual(gelesen[i][i], "#FF0000", "Einzelbild \(i) in seiner Reihenfolge")
        }
    }

    /// Der einzige Daseinsgrund des entfallenen `Bildladen`: `NSImage(contentsOf:)`
    /// merkt sich Bilder am Pfad, ein im Editor geaendertes Icon saehe anderswo
    /// weiter alt aus. `Bildraster` liest ueber `CGImageSource` **aus der Datei**
    /// und kennt keinen Zwischenspeicher — hier festgehalten, damit niemand den
    /// Leseweg gegen einen zwischenspeichernden tauscht.
    ///
    /// Derselbe Pfad, zweimal beschrieben: Ein Zwischenspeicher am Pfad haette
    /// beim zweiten Lesen noch das rote Pixel.
    func testGeaendertesIconWirdFrischGelesen() throws {
        let datei = temp().appendingPathExtension("gif")

        var rot = [String?](repeating: nil, count: 64); rot[0] = "#FF0000"
        try schreibeRaster(rot, nach: datei)
        XCTAssertEqual(try Bildraster.lesen(datei, breite: 8, hoehe: 8)[0][0], "#FF0000")

        var gruen = [String?](repeating: nil, count: 64); gruen[0] = "#00FF66"
        try schreibeRaster(gruen, nach: datei)
        XCTAssertEqual(try Bildraster.lesen(datei, breite: 8, hoehe: 8)[0][0], "#00FF66",
                       "dieselbe Datei, neuer Inhalt — nichts darf aus einem Zwischenspeicher kommen")
    }

    /// Schreibt ein einzelnes 8×8-Raster als GIF an die gegebene Stelle.
    private func schreibeRaster(_ pixel: [String?], nach datei: URL) throws {
        let uri = try Bildraster.alsDatenURI([pixel], breite: 8, hoehe: 8, verzoegerung: 0.1)
        let daten = try XCTUnwrap(Data(base64Encoded: String(uri.dropFirst("data:image/gif;base64,".count))))
        try daten.write(to: datei)
    }

    func testKeineBilddateiWirdAbgelehnt() throws {
        let kaputt = temp().appendingPathExtension("gif")
        try Data("kein Bild".utf8).write(to: kaputt)
        XCTAssertThrowsError(try Bildraster.lesen(kaputt, breite: 8, hoehe: 8))
    }

    /// Die Standzeit muss den Rundlauf ueberleben — sonst zeigt der Editor beim
    /// Oeffnen immer seinen Anfangswert und ueberschreibt das Gesicherte still.
    func testVerzoegerungUeberlebtDenRundlauf() throws {
        let eigen = temp()
        try FileManager.default.createDirectory(at: eigen, withIntermediateDirectories: true)
        let sammlung = Iconsammlung(schreibordner: eigen)

        var eins = [String?](repeating: nil, count: 64); eins[0] = "#FF0000"
        var zwei = [String?](repeating: nil, count: 64); zwei[63] = "#00FF66"
        let icon = try sammlung.sichern(nummer: "takt", name: "Takt",
                                        bilder: [eins, zwei], verzoegerung: 0.4)

        let gelesen = try sammlung.einzelbilder(fuer: icon)
        XCTAssertEqual(gelesen.count, 2)
        XCTAssertEqual(gelesen[0].dauer, 0.4, accuracy: 0.001,
                       "0,4 Sekunden muessen als 0,4 zurueckkommen, nicht als Vorgabe")
        XCTAssertEqual(gelesen[1].dauer, 0.4, accuracy: 0.001)
    }

    /// Erststart-Szenario: ein leerer Schreibordner bekommt alle mitgelieferten
    /// Dateien samt ihrem Namen aus `names.json`.
    func testMitgelieferteUebernehmenKopiertInLeeresVerzeichnis() throws {
        let mit = temp(), eigen = temp()
        try FileManager.default.createDirectory(at: mit, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: eigen, withIntermediateDirectories: true)
        try Data("GIF89a-a".utf8).write(to: mit.appendingPathComponent("1.gif"))
        try Data("GIF89a-b".utf8).write(to: mit.appendingPathComponent("2.gif"))
        try Data(#"[{"nummer":"1","name":"Eins","kategorie":"Test"}]"#.utf8)
            .write(to: mit.appendingPathComponent("names.json"))

        let sammlung = Iconsammlung(schreibordner: eigen, leseordner: [mit])
        XCTAssertEqual(sammlung.mitgelieferteUebernehmen(), 2)

        XCTAssertTrue(FileManager.default.fileExists(atPath: eigen.appendingPathComponent("1.gif").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: eigen.appendingPathComponent("2.gif").path))
        let kopiert = try XCTUnwrap(sammlung.alle().first { $0.nummer == "1" })
        XCTAssertTrue(sammlung.istEigen(kopiert))
        XCTAssertEqual(kopiert.name, "Eins", "der Name aus names.json muss mitkommen")
    }

    /// „Grundschatz wiederherstellen“ darf Vorhandenes nicht anruehren und
    /// ergaenzt ausschliesslich, was im Schreibordner fehlt.
    func testMitgelieferteUebernehmenUeberschreibtVorhandenesNichtUndErgaenztNurFehlendes() throws {
        let mit = temp(), eigen = temp()
        try FileManager.default.createDirectory(at: mit, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: eigen, withIntermediateDirectories: true)
        try Data("GIF89a-1".utf8).write(to: mit.appendingPathComponent("1.gif"))
        try Data("GIF89a-2-mitgeliefert".utf8).write(to: mit.appendingPathComponent("2.gif"))
        try Data("GIF89a-2-eigen".utf8).write(to: eigen.appendingPathComponent("2.gif"))

        let sammlung = Iconsammlung(schreibordner: eigen, leseordner: [mit])
        XCTAssertEqual(sammlung.mitgelieferteUebernehmen(), 1, "nur die fehlende Nummer 1 kommt dazu")

        XCTAssertTrue(FileManager.default.fileExists(atPath: eigen.appendingPathComponent("1.gif").path))
        XCTAssertEqual(try Data(contentsOf: eigen.appendingPathComponent("2.gif")), Data("GIF89a-2-eigen".utf8),
                       "die eigene Datei darf nicht ueberschrieben werden")
    }

    /// Der Merker sorgt dafuer, dass die Uebernahme wirklich nur einmal
    /// laeuft — ein danach geloeschtes Icon darf beim naechsten Aufruf nicht
    /// zurueckkommen.
    func testGrundschatzEinmalUebernehmenLaeuftNurBeimErstenMal() throws {
        let mit = temp(), eigen = temp()
        try FileManager.default.createDirectory(at: mit, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: eigen, withIntermediateDirectories: true)
        try Data("GIF89a".utf8).write(to: mit.appendingPathComponent("1.gif"))

        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let sammlung = Iconsammlung(schreibordner: eigen, leseordner: [mit])

        XCTAssertEqual(sammlung.grundschatzEinmalUebernehmen(defaults: defaults), 1)
        try FileManager.default.removeItem(at: eigen.appendingPathComponent("1.gif"))

        XCTAssertEqual(sammlung.grundschatzEinmalUebernehmen(defaults: defaults), 0,
                       "der zweite Aufruf darf nichts mehr tun")
        XCTAssertFalse(FileManager.default.fileExists(atPath: eigen.appendingPathComponent("1.gif").path),
                       "ein zuvor geloeschtes Icon darf nicht zurueckkommen")
    }

    /// Schlaegt die erste Uebernahme fehl — der Leseordner ist nicht da, etwa
    /// beim Start aus `swift run` —, darf der Merker nicht gesetzt sein: der
    /// naechste Start bekommt noch einen Versuch.
    func testGrundschatzMerkerBleibtOhneErfolgUngesetzt() throws {
        let fehlt = temp(), eigen = temp()
        try FileManager.default.createDirectory(at: eigen, withIntermediateDirectories: true)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))

        XCTAssertEqual(Iconsammlung(schreibordner: eigen, leseordner: [fehlt])
                           .grundschatzEinmalUebernehmen(defaults: defaults), 0)

        // Jetzt gibt es den Ordner samt Inhalt — und die Uebernahme laeuft noch.
        try FileManager.default.createDirectory(at: fehlt, withIntermediateDirectories: true)
        try Data("GIF89a".utf8).write(to: fehlt.appendingPathComponent("1.gif"))
        XCTAssertEqual(Iconsammlung(schreibordner: eigen, leseordner: [fehlt])
                           .grundschatzEinmalUebernehmen(defaults: defaults), 1)
    }

    /// Die Namen kommen in einem Zug in die `names.json`, nicht je Datei einmal.
    func testMitgelieferteUebernehmenTraegtAlleNamenEin() throws {
        let mit = temp(), eigen = temp()
        try FileManager.default.createDirectory(at: mit, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: eigen, withIntermediateDirectories: true)
        for n in ["1", "2", "3"] { try Data("GIF89a".utf8).write(to: mit.appendingPathComponent("\(n).gif")) }
        try Data(#"[{"nummer":"1","name":"eins","kategorie":"k"},{"nummer":"3","name":"drei","kategorie":"k"}]"#.utf8)
            .write(to: mit.appendingPathComponent("names.json"))

        XCTAssertEqual(Iconsammlung(schreibordner: eigen, leseordner: [mit]).mitgelieferteUebernehmen(), 3)
        let namen = Dictionary(uniqueKeysWithValues:
            Iconsammlung(schreibordner: eigen).alle().map { ($0.nummer, $0.name) })
        XCTAssertEqual(namen["1"], "eins")
        XCTAssertEqual(namen["3"], "drei")
        XCTAssertEqual(namen["2"], "2", "ohne Eintrag bleibt die Nummer der Name")
    }

    // MARK: - Das Entsorgungsverfahren

    /// Die eine Sache, die niemand am Schreibtisch sieht: Unbeleuchtete Pixel
    /// muessen im GIF durchsichtig sein, nicht schwarz. ImageIO waehlt danach
    /// das Entsorgungsverfahren — deckende Bilder ergeben Verfahren 1
    /// („stehenlassen“), und damit fehlen auf der Uhr einzelne Pixel;
    /// durchsichtige ergeben Verfahren 2 („vor jedem Bild loeschen“). Geprueft
    /// wird direkt im Bytestrom: im dritten Byte jeder Grafiksteuer-Erweiterung
    /// (0x21 0xF9) stehen die Bits 2 bis 4.
    func testLaufschriftGifNutztEntsorgungsverfahrenZwei() throws {
        let breite = 52, hoehe = 16
        var a = [String?](repeating: nil, count: breite * hoehe)
        var b = a
        a[0] = "#00FF66"; a[breite * hoehe - 1] = "#FF0000"
        b[breite + 1] = "#00FF66"
        let uri = try Bildraster.alsDatenURI([a, b, a], breite: breite, hoehe: hoehe, verzoegerung: 0.08)
        let bytes = [UInt8](try XCTUnwrap(Data(base64Encoded: String(uri.dropFirst("data:image/gif;base64,".count)))))

        var gefunden = 0
        for i in 0..<(bytes.count - 3) where bytes[i] == 0x21 && bytes[i + 1] == 0xF9 && bytes[i + 2] == 0x04 {
            let verfahren = (bytes[i + 3] >> 2) & 0x07
            XCTAssertEqual(verfahren, 2, "Grafiksteuer-Erweiterung bei Byte \(i): Verfahren \(verfahren)")
            gefunden += 1
        }
        XCTAssertEqual(gefunden, 3, "eine Grafiksteuer-Erweiterung je Einzelbild")
    }

    /// Einen Schritt naeher an der Ursache: `nil` muss im CGImage Alpha 0 haben.
    /// Wer „aus“ in Schwarz aendert, bricht diesen Test, bevor er das GIF bricht.
    func testAusBleibtImBildDurchsichtig() throws {
        let bild = try Bildraster.cgBild(aus: [nil, "#FFFFFF", "#000000", nil], breite: 2, hoehe: 2)
        let daten = try XCTUnwrap(bild.dataProvider?.data as Data?)
        XCTAssertEqual(daten[3], 0, "aus: Alpha 0")
        XCTAssertEqual(daten[7], 255, "weiss: deckend")
        XCTAssertEqual(daten[11], 255, "schwarz gemalt: deckend, also von „aus“ unterscheidbar")
        XCTAssertEqual(daten[15], 0)
    }

    /// Und der Rundlauf: gesichert und wieder geladen bleibt „aus“ `nil`, und
    /// schwarz gemalt bleibt Schwarz — die beiden sind nicht dasselbe.
    func testRundlaufUnterscheidetAusVonSchwarz() throws {
        let ordner = temp()
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        var pixel = [String?](repeating: nil, count: 64)
        pixel[0] = "#000000"; pixel[9] = "#00FF66"
        let sammlung = Iconsammlung(schreibordner: ordner)
        let icon = try sammlung.sichern(nummer: "7", name: "probe", pixel: pixel)
        let zurueck = try sammlung.bilder(fuer: icon)[0]
        XCTAssertEqual(zurueck[0], "#000000")
        XCTAssertEqual(zurueck[9], "#00FF66")
        XCTAssertNil(zurueck[1])
        XCTAssertNil(zurueck[63])
    }
}
