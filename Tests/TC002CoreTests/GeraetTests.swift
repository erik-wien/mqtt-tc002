import XCTest
@testable import TC002Core

/// Faengt alle Anfragen ab und antwortet aus einer Tabelle. Kein Netz, kein Geraet.
final class Doppelgaenger: URLProtocol {
    nonisolated(unsafe) static var antworten: [String: String] = [:]
    /// Binaere Antworten (Bilder), die den Text aus `antworten` ersetzen.
    nonisolated(unsafe) static var antwortDaten: [String: Data] = [:]
    nonisolated(unsafe) static var statusCodes: [String: Int] = [:]
    nonisolated(unsafe) static var gesendeteRuempfe: [String: String] = [:]
    /// Die Abfrage hinter dem Pfad (`?name=…`) — bei den `/api`-Endpunkten
    /// steht der Anzeigenname dort und nirgends sonst.
    nonisolated(unsafe) static var abfragen: [String: String] = [:]
    nonisolated(unsafe) static var methoden: [String: String] = [:]
    /// Der `Content-Type` je Pfad. Bei AWTRIX NG ist er bei `PUT` und `PATCH`
    /// Pflicht: Ohne ihn wird die Anfrage mit `415` abgewiesen, bevor der
    /// Rumpf ueberhaupt gelesen wird.
    nonisolated(unsafe) static var inhaltstypen: [String: String] = [:]
    nonisolated(unsafe) static var pfade: [String] = []
    /// Die Cache-Richtlinie je Pfad, wie sie die Anfrage mitbringt.
    nonisolated(unsafe) static var cacheRichtlinien: [String: URLRequest.CachePolicy] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }

    override func startLoading() {
        let pfad = request.url?.path ?? ""
        Self.pfade.append(pfad)
        Self.abfragen[pfad] = request.url?.query ?? ""
        Self.methoden[pfad] = request.httpMethod ?? ""
        Self.cacheRichtlinien[pfad] = request.cachePolicy
        Self.inhaltstypen[pfad] = request.value(forHTTPHeaderField: "Content-Type") ?? ""
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
        client?.urlProtocol(self, didLoad: Self.antwortDaten[pfad] ?? Data(text.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class GeraetTests: XCTestCase {
    private func geraet(host: String) -> Geraet {
        let k = URLSessionConfiguration.ephemeral
        k.protocolClasses = [Doppelgaenger.self]
        return Geraet(host: host, sitzung: URLSession(configuration: k))
    }

    override func setUp() {
        Doppelgaenger.antworten = [:]
        Doppelgaenger.statusCodes = [:]
        Doppelgaenger.gesendeteRuempfe = [:]
        Doppelgaenger.abfragen = [:]
        Doppelgaenger.methoden = [:]
        Doppelgaenger.inhaltstypen = [:]
        Doppelgaenger.pfade = []
    }

    // MARK: - Eine Adresse, die keine ist

    /// Ein Leerzeichen in der eingetragenen Adresse laesst `URL(string:)`
    /// `nil` liefern; ein Zwangsauspacken dahinter (`!`) beendet dann die App
    /// mit „Unexpectedly found nil while unwrapping an Optional value", ohne
    /// dass der Anwender erfaehrt, dass es an seiner Eingabe lag. Eine
    /// Adresse kommt aus den Einstellungen und ist von Hand eingetippt und
    /// muss eine Meldung ergeben koennen, keinen Absturz.
    func testEineAdresseMitLeerzeichenWirftStattAbzustuerzen() {
        XCTAssertThrowsError(try geraet(host: "awtrix a86b").praefixUndBasis()) { fehler in
            guard case GeraetFehler.ungueltigeAdresse(let genannt) = fehler else {
                return XCTFail("falscher Fehler: \(fehler)")
            }
            XCTAssertEqual(genannt, "awtrix a86b", "die Meldung muss die Adresse nennen")
        }
    }

    /// Derselbe Weg ueber `holeFeld` (`GET /api/v1/apps`), einen anderen
    /// Aufrufer derselben Zeile.
    func testAuchDerNGWegWirft() {
        XCTAssertThrowsError(try geraet(host: "awtrix a86b").anzeigennamen())
    }

    /// Und der schreibende Weg (`PUT`), der seine URL frueher selbst baute.
    func testAuchDerSchreibendeWegWirft() {
        XCTAssertThrowsError(try geraet(host: "a b")
            .anzeigeSetzen("{}", name: "meldung1"))
    }

    /// Die Gegenprobe: Ein leerer Host stuerzt nicht ab und wirft auch nicht
    /// hier — `http:///api/v1/device` ist eine gueltige URL.
    func testEinLeererHostErgibtEineGueltigeURL() {
        XCTAssertNotNil(URL(string: "http:///api/v1/device"))
    }

}
