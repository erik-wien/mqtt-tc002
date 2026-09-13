import XCTest
@testable import TC002Core

/// Faengt alle Anfragen ab und antwortet aus einer Tabelle. Kein Netz, kein Geraet.
final class Doppelgaenger: URLProtocol {
    nonisolated(unsafe) static var antworten: [String: String] = [:]
    nonisolated(unsafe) static var statusCodes: [String: Int] = [:]
    nonisolated(unsafe) static var gesendeteRuempfe: [String: String] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }

    override func startLoading() {
        let pfad = request.url?.path ?? ""
        if let koerper = request.httpBody ?? request.httpBodyStream.map({ s -> Data in
            s.open(); defer { s.close() }
            var d = Data(); var puffer = [UInt8](repeating: 0, count: 4096)
            while s.hasBytesAvailable { let n = s.read(&puffer, maxLength: puffer.count); if n <= 0 { break }; d.append(puffer, count: n) }
            return d
        }) {
            Self.gesendeteRuempfe[pfad] = String(data: koerper, encoding: .utf8) ?? ""
        }
        let text = Self.antworten[pfad] ?? "{}"
        let status = Self.statusCodes[pfad] ?? 200
        let antwort = HTTPURLResponse(url: request.url!, statusCode: status,
                                      httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: antwort, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(text.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class GeraetTests: XCTestCase {
    private func geraet() -> Geraet {
        let k = URLSessionConfiguration.ephemeral
        k.protocolClasses = [Doppelgaenger.self]
        return Geraet(host: "10.0.0.1", sitzung: URLSession(configuration: k))
    }

    override func setUp() {
        Doppelgaenger.antworten = [
            "/getBase": #"{"devSn":"TC002-TESTGERAET01","ssid":"heimnetz","ip":"192.168.1.20","mac":"aabbccdda86b","mcuVer":"V1.0.17","appVer":"1.1.1"}"#,
            "/getMqttConfig": #"{"isMqtt":true,"ip":"192.168.1.10","port":"1883","mqtt_name":"awtrix","mqtt_pwd":"x","mqtt_prefix":"awtrix","isHADiscoveryEnabled":false}"#,
            "/getMqttStatus": #"{"code":200,"data":{"enabled":true,"connected":true}}"#,
            "/getConfig": #"{"brightness":{"level":"high"},"volume":4,"carouselSpeed":0,"scrollSpeed":7}"#,
            "/setConfig": #"{"code":200,"message":"Settings saved successfully"}"#,
            // Genau die Antwort, die am 13.09.2026 am Geraet gemessen wurde.
            "/api/customList": #"{"apps":["meldung2","meldung5","meldung3"],"count":3}"#,
        ]
        Doppelgaenger.statusCodes = [:]
        Doppelgaenger.gesendeteRuempfe = [:]
    }

    /// Der Kern: das tatsaechliche Praefix ist das eingestellte plus die letzten
    /// vier Stellen der MAC. Genau hieran sind heute Stunden verlorengegangen.
    func testThemenPraefixWirdAusPraefixUndMacGebildet() throws {
        XCTAssertEqual(try geraet().themenPraefix(), "awtrix_a86b")
    }

    /// Ohne eingestelltes Praefix ergaebe die Formel "_a86b" — ein Thema, auf das
    /// die Uhr nie hoert. Das darf nicht als gueltiges Praefix durchgehen.
    func testLeeresPraefixErgibtFehlerStattUnsinn() {
        Doppelgaenger.antworten["/getMqttConfig"] = #"{"isMqtt":true,"mqtt_prefix":""}"#
        XCTAssertThrowsError(try geraet().themenPraefix()) { fehler in
            guard case GeraetFehler.keinPraefix = fehler else {
                return XCTFail("war stattdessen \(fehler)")
            }
        }
    }

    /// Praefix und Basisdaten kommen zusammen — sonst wird /getBase zweimal geholt.
    func testPraefixUndBasisLiefertBeides() throws {
        let ergebnis = try geraet().praefixUndBasis()
        XCTAssertEqual(ergebnis.praefix, "awtrix_a86b")
        XCTAssertEqual(ergebnis.basis.mac, "aabbccdda86b")
    }

    func testBasisdaten() throws {
        let b = try geraet().basis()
        XCTAssertEqual(b.mac, "aabbccdda86b")
        XCTAssertEqual(b.mcuVersion, "V1.0.17")
        XCTAssertEqual(b.appVersion, "1.1.1")
    }

    func testVerbindungsstand() throws {
        XCTAssertTrue(try geraet().verbunden())
    }

    /// setConfig erwartet die vollstaendige Konfiguration, nicht nur das geaenderte Feld.
    func testEinstellungSetzenSchicktAllesZurueck() throws {
        try geraet().konfigurationSetzen("carouselSpeed", 10)
        let gesendet = try XCTUnwrap(Doppelgaenger.gesendeteRuempfe["/setConfig"])
        XCTAssertTrue(gesendet.contains("\"carouselSpeed\":10"))
        XCTAssertTrue(gesendet.contains("\"volume\""), "die übrigen Felder müssen mit")
        XCTAssertTrue(gesendet.contains("\"scrollSpeed\""))
    }

    /// Welche Anzeigen auf der Uhr stehen, sagt sie ueber HTTP — und zwar unter
    /// `/api/customList`. `/customList` ohne `/api` liefert nichts; dass das ein
    /// Mangel der Firmware sei, war unser eigener Pfadfehler.
    func testAnzeigennamenKommenVomApiPfad() throws {
        XCTAssertEqual(try geraet().anzeigennamen(), ["meldung2", "meldung5", "meldung3"])
    }

    /// Eine leere Liste ist eine Auskunft — auf der Uhr steht nichts —, kein
    /// Fehler. Ohne den Unterschied waere „frei" nicht von „nicht gefragt" zu
    /// trennen.
    func testLeereAnzeigenlisteIstKeinFehler() throws {
        Doppelgaenger.antworten["/api/customList"] = #"{"apps":[],"count":0}"#
        XCTAssertEqual(try geraet().anzeigennamen(), [])
    }

    /// Eine Antwort ohne `apps` ist keine leere Liste, sondern keine Liste. Sie
    /// darf nicht als „auf der Uhr steht nichts" durchgehen — das raeumte in
    /// `AppZustand` die Belegung ab.
    func testAntwortOhneAppsFeldIstEinFehler() {
        Doppelgaenger.antworten["/api/customList"] = #"{"code":200}"#
        XCTAssertThrowsError(try geraet().anzeigennamen()) { fehler in
            XCTAssertTrue(fehler is GeraetFehler, "war stattdessen \(type(of: fehler))")
        }
    }

    /// Kein gueltiges JSON darf nicht als roher Systemfehler nach aussen dringen.
    func testUngueltigesJsonErgibtGeraetFehler() {
        Doppelgaenger.antworten["/getBase"] = "das ist kein JSON"
        XCTAssertThrowsError(try geraet().basis()) { fehler in
            XCTAssertTrue(fehler is GeraetFehler, "war stattdessen \(type(of: fehler))")
        }
    }

    /// Eine leere Antwort ist ebenfalls kein gueltiges JSON und muss genauso behandelt werden.
    func testLeereAntwortErgibtGeraetFehler() {
        Doppelgaenger.antworten["/getBase"] = ""
        XCTAssertThrowsError(try geraet().basis()) { fehler in
            XCTAssertTrue(fehler is GeraetFehler, "war stattdessen \(type(of: fehler))")
        }
    }

    /// Ein HTTP-Fehlerstatus muss erkannt werden, bevor irgendwelche (dann leeren)
    /// Werte zurueckgegeben werden — sonst zeigt die Oberflaeche Unsinn als Wahrheit an.
    func testHttpFehlerstatusErgibtGeraetFehlerVorLeerenWerten() {
        Doppelgaenger.statusCodes["/getBase"] = 500
        XCTAssertThrowsError(try geraet().basis()) { fehler in
            XCTAssertTrue(fehler is GeraetFehler, "war stattdessen \(type(of: fehler))")
        }
    }
}
