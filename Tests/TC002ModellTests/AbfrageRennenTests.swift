import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

/// Eine Abfrage, die nach einer jüngeren zurückkommt, darf deren Ergebnis nicht
/// überschreiben. Kein Gerät: Zwei Sitzungen mit einem `URLProtocol`, die eine
/// antwortet spät, die andere sofort.
@MainActor
final class AbfrageRennenTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "zielIDs", "bekannteAnzeigen"]
    private var sicherung: [String: Any?] = [:]

    override func setUp() {
        super.setUp()
        sicherung = Dictionary(uniqueKeysWithValues: schluessel.map { ($0, d.object(forKey: $0)) })
    }

    override func tearDown() {
        for schl in schluessel {
            if let wert = sicherung[schl] ?? nil { d.set(wert, forKey: schl) } else { d.removeObject(forKey: schl) }
        }
        super.tearDown()
    }

    /// Antwortet auf `/api/v1/system` mit dem Präfix aus dem Kopf `X-Praefix`,
    /// nach `X-Verzoegerung` Sekunden.
    final class Staffeldoppelgaenger: URLProtocol, @unchecked Sendable {
        static func sitzung(praefix: String, verzoegerung: TimeInterval) -> URLSession {
            let k = URLSessionConfiguration.ephemeral
            k.protocolClasses = [Staffeldoppelgaenger.self]
            k.httpAdditionalHeaders = ["X-Praefix": praefix, "X-Verzoegerung": "\(verzoegerung)"]
            return URLSession(configuration: k)
        }

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }

        override func startLoading() {
            let pfad = request.url?.path ?? ""
            let praefix = request.value(forHTTPHeaderField: "X-Praefix") ?? ""
            let verzug = Double(request.value(forHTTPHeaderField: "X-Verzoegerung") ?? "0") ?? 0
            let text = pfad == "/api/v1/system" ? #"{"mqttPrefix":"\#(praefix)"}"# : "{}"
            DispatchQueue.global().asyncAfter(deadline: .now() + verzug) { [self] in
                let antwort = HTTPURLResponse(url: request.url!, statusCode: 200,
                                              httpVersion: nil, headerFields: nil)!
                client?.urlProtocol(self, didReceive: antwort, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: Data(text.utf8))
                client?.urlProtocolDidFinishLoading(self)
            }
        }
        override func stopLoading() {}
    }

    private func warteBis(_ bedingung: () -> Bool, frist: TimeInterval = 5) {
        let ende = Date().addingTimeInterval(frist)
        while !bedingung(), Date() < ende {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }

    func testSpaeteAntwortDerAeltherenAbfrageUeberschreibtDieJuengereNicht() throws {
        let uhr = Uhr(name: "Küche", host: "uhr.example", betriebsart: .http)
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        d.set(uhr.id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set([uhr.id])), forKey: "zielIDs")
        let zustand = AppZustand(schluesselbund: Schluesselbunddoppelgaenger())

        zustand.abfragen(uhr.id, sitzung: Staffeldoppelgaenger.sitzung(praefix: "alt/uhr", verzoegerung: 0.3))
        zustand.abfragen(uhr.id, sitzung: Staffeldoppelgaenger.sitzung(praefix: "neu/uhr", verzoegerung: 0))
        warteBis { zustand.uhren.first?.praefix == "neu/uhr" }
        XCTAssertEqual(zustand.uhren.first?.praefix, "neu/uhr")

        // Die ältere Antwort trifft jetzt ein.
        let ende = Date().addingTimeInterval(3)
        while Date() < ende { RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05)) }
        XCTAssertEqual(zustand.uhren.first?.praefix, "neu/uhr", "die späte, ältere Antwort gilt nicht mehr")
    }
}
