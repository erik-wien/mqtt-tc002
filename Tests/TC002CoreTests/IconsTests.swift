import XCTest
@testable import TC002Core

final class IconsTests: XCTestCase {
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
}
