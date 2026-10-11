import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

/// Das Modell einer Uhr entsteht bei der ersten Abfrage und wird danach nie
/// überschrieben; Lautsprecher und Lichtmessung erreichen die Fähigkeiten, die
/// alle Oberflächen lesen. Kein Gerät: ein `URLProtocol` antwortet mit
/// gemessenen Auskünften (NG 1.2.2, 11. Oktober 2026, ohne Kennungen).
@MainActor
final class UhrmodellZustandTests: XCTestCase {
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

    /// Antwortet für einen ESP32 mit `X-Geraet`: `eigenbau` (kein Akku, kein
    /// Fotowiderstand, 64 × 8) oder `tc001` (Akku, Fotowiderstand, 32 × 8).
    final class Geraetedoppelgaenger: URLProtocol, @unchecked Sendable {
        static func sitzung(_ geraet: String) -> URLSession {
            let k = URLSessionConfiguration.ephemeral
            k.protocolClasses = [Geraetedoppelgaenger.self]
            k.httpAdditionalHeaders = ["X-Geraet": geraet]
            return URLSession(configuration: k)
        }

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }

        override func startLoading() {
            let eigenbau = request.value(forHTTPHeaderField: "X-Geraet") == "eigenbau"
            let breite = eigenbau ? 64 : 32
            let text: String
            switch request.url?.path ?? "" {
            case "/api/v1/device":
                text = eigenbau ? #"{"uid":"aabbccddeeff","boardType":"awtrixng","batteryVoltage":0.25,"batteryPercent":0,"ldrRaw":0}"#
                                : #"{"uid":"aabbccddeeff","boardType":"awtrixng","batteryVoltage":3.9,"batteryPercent":63,"ldrRaw":281}"#
            case "/api/v1/system":
                text = #"{"mqttPrefix":"bastel/uhr"}"#
            case "/api/v1/capabilities":
                text = """
                {"effects":["Fade"],"platform":{"id":"esp32"},"sensors":{"light":true},
                 "display":{"width":\(breite),"height":8,"configurable":true,"minWidth":32,"maxWidth":128,"minHeight":8,"maxHeight":8},
                 "audio":{"mp3":false,"rtttl":true,"song":false,"speech":false,"track":false,"radio":false,"url":false,"effect":false,"clip":false}}
                """
            default:
                text = "{}"
            }
            let antwort = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: antwort, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(text.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    private func warteBis(_ bedingung: () -> Bool, frist: TimeInterval = 5) {
        let ende = Date().addingTimeInterval(frist)
        while !bedingung(), Date() < ende {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }

    private func zustand(mit uhr: Uhr) throws -> AppZustand {
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        d.set(uhr.id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set([uhr.id])), forKey: "zielIDs")
        return AppZustand(schluesselbund: Schluesselbunddoppelgaenger())
    }

    func testDieErsteAbfrageSchlaegtDasModellVorUndMerktDieBreite() throws {
        let uhr = Uhr(name: "Bastel", host: "uhr.example", betriebsart: .http)
        let z = try zustand(mit: uhr)
        z.abfragen(uhr.id, sitzung: Geraetedoppelgaenger.sitzung("eigenbau"))
        warteBis { z.uhren.first?.modell != nil }
        XCTAssertEqual(z.uhren.first?.modell, .esp32DIY)
        XCTAssertEqual(z.uhren.first?.anzeigemass.breite, 64)
        // Ohne Fotowiderstand gilt der Lichtsensor der Fähigkeiten nicht.
        XCTAssertEqual(z.faehigkeiten[uhr.id]?.lichtsensorGemeldet, true)
        XCTAssertEqual(z.faehigkeiten[uhr.id]?.lichtsensor, false)
    }

    func testEineTC001WirdAlsTC001Erkannt() throws {
        let uhr = Uhr(name: "Flur", host: "uhr.example", betriebsart: .http)
        let z = try zustand(mit: uhr)
        z.abfragen(uhr.id, sitzung: Geraetedoppelgaenger.sitzung("tc001"))
        warteBis { z.uhren.first?.modell != nil }
        XCTAssertEqual(z.uhren.first?.modell, .tc001)
        XCTAssertEqual(z.faehigkeiten[uhr.id]?.lichtsensor, true)
    }

    func testEineGewaehlteWahlBleibtBeiJederAbfrage() throws {
        let uhr = Uhr(name: "Flur", host: "uhr.example", betriebsart: .http, modell: .tc001)
        let z = try zustand(mit: uhr)
        z.abfragen(uhr.id, sitzung: Geraetedoppelgaenger.sitzung("eigenbau"))
        warteBis { z.uhren.first?.anzeigemass.breite == 64 }
        XCTAssertEqual(z.uhren.first?.anzeigemass.breite, 64, "die Abfrage ist durch")
        XCTAssertEqual(z.uhren.first?.modell, .tc001, "die Wahl des Nutzers wird nicht überschrieben")
    }

    func testLautsprecherSchalterErreichtDieFaehigkeitenUndKlangziele() throws {
        let uhr = Uhr(name: "Bastel", host: "uhr.example", betriebsart: .http)
        let z = try zustand(mit: uhr)
        z.abfragen(uhr.id, sitzung: Geraetedoppelgaenger.sitzung("eigenbau"))
        warteBis { z.uhren.first?.modell != nil }
        XCTAssertTrue(z.klangMoeglich)
        XCTAssertEqual(z.faehigkeiten[uhr.id]?.kann(.rtttl), true)

        z.uhren[0].lautsprecher = false
        z.ausstattungGeaendert(uhr.id)
        XCTAssertEqual(z.faehigkeiten[uhr.id]?.kann(.rtttl), false)
        XCTAssertEqual(z.faehigkeiten[uhr.id]?.ton, Tonfaehigkeiten())
        XCTAssertFalse(z.klangMoeglich)

        // Zurück: die Auskunft der Uhr gilt wieder.
        z.uhren[0].lautsprecher = nil
        z.ausstattungGeaendert(uhr.id)
        XCTAssertEqual(z.faehigkeiten[uhr.id]?.kann(.rtttl), true)
        XCTAssertTrue(z.klangMoeglich)
    }

    func testOhneAuskunftDerUhrBleibtDerAbgewaehlteLautsprecherAbgewaehlt() throws {
        let uhr = Uhr(name: "Bastel", host: "uhr.example", betriebsart: .http, modell: .esp32DIY, lautsprecher: false)
        let z = try zustand(mit: uhr)
        XCTAssertNil(z.faehigkeiten[uhr.id])
        XCTAssertFalse(z.klangMoeglich, "auch vor der ersten Abfrage")
        XCTAssertEqual(z.klangziel(z.uhren[0]).faehigkeiten?.ton, Tonfaehigkeiten())
    }
}
