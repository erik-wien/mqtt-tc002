import XCTest
@testable import TC002Core

/// Die Kurzbefehle fragen nach keinem Wert, wenn die Einrichtung fehlt: Aus
/// jedem Mangel wird ein `Kurzbefehlsziele.Fehler` mit eigenem Text.
final class KurzbefehlszieleTests: XCTestCase {

    private func mqtt(_ name: String, praefix: String = "p/x") -> Uhr {
        Uhr(name: name, host: "10.0.0.1", praefix: praefix, betriebsart: .mqtt)
    }
    private func http(_ name: String, host: String = "10.0.0.2") -> Uhr {
        Uhr(name: name, host: host, betriebsart: .http)
    }
    private func einstellungen(_ uhren: [Uhr], broker: String = "broker.local",
                               ziele: Set<UUID> = []) -> Einstellungen {
        Einstellungen(brokerHost: broker, brokerPort: 1883, benutzer: nil,
                      kennwort: nil, uhren: uhren, zielIDs: ziele)
    }

    func testUhrNachKennungFindenUndUnbekanntes() {
        let a = mqtt("Küche")
        let e = einstellungen([a, mqtt("Bad")])
        XCTAssertEqual(e.uhr(id: a.id)?.name, "Küche")
        XCTAssertNil(e.uhr(id: UUID()))
    }

    func testKennungBleibtNachUmbenennen() throws {
        var a = mqtt("Küche")
        let id = a.id
        a.name = "Esszimmer"
        let ziele = try Kurzbefehlsziele.bestimmen(einstellungen([a]), uhr: id)
        XCTAssertEqual(ziele.map(\.name), ["Esszimmer"])
    }

    func testOhneAngabeGeltenDieZiele() throws {
        let a = mqtt("A"), b = mqtt("B")
        let e = einstellungen([a, b], ziele: [b.id])
        XCTAssertEqual(try Kurzbefehlsziele.bestimmen(e, uhr: nil).map(\.name), ["B"])
        XCTAssertEqual(try Kurzbefehlsziele.bestimmen(einstellungen([a, b]), uhr: nil).count, 2)
    }

    func testKeineUhrEingerichtet() {
        XCTAssertThrowsError(try Kurzbefehlsziele.bestimmen(einstellungen([]), uhr: nil)) {
            XCTAssertEqual($0 as? Kurzbefehlsziele.Fehler, .keineUhrEingerichtet)
        }
    }

    func testGeloeschteUhrIstUnbekannt() {
        XCTAssertThrowsError(try Kurzbefehlsziele.bestimmen(einstellungen([mqtt("A")]), uhr: UUID())) {
            XCTAssertEqual($0 as? Kurzbefehlsziele.Fehler, .uhrUnbekannt)
        }
    }

    func testKeinBrokerNurWennEineUhrIhnBraucht() throws {
        let m = mqtt("M"), h = http("H")
        XCTAssertThrowsError(try Kurzbefehlsziele.bestimmen(einstellungen([m], broker: ""), uhr: m.id)) {
            XCTAssertEqual($0 as? Kurzbefehlsziele.Fehler, .keinBroker)
        }
        XCTAssertEqual(try Kurzbefehlsziele.bestimmen(einstellungen([m, h], broker: ""), uhr: h.id).count, 1)
    }

    func testNichtAbgefragtUndOhneAdresse() {
        let m = mqtt("M", praefix: ""), h = http("H", host: "")
        XCTAssertThrowsError(try Kurzbefehlsziele.bestimmen(einstellungen([m]), uhr: m.id)) {
            XCTAssertEqual($0 as? Kurzbefehlsziele.Fehler, .nichtAbgefragt(["M"]))
        }
        XCTAssertThrowsError(try Kurzbefehlsziele.bestimmen(einstellungen([h]), uhr: h.id)) {
            XCTAssertEqual($0 as? Kurzbefehlsziele.Fehler, .ohneAdresse(["H"]))
        }
    }

    func testNurBeschickbareLaesstUnfertigeWeg() throws {
        let fertig = mqtt("Fertig"), roh = mqtt("Roh", praefix: "")
        let e = einstellungen([fertig, roh])
        XCTAssertThrowsError(try Kurzbefehlsziele.bestimmen(e, uhr: nil))
        XCTAssertEqual(try Kurzbefehlsziele.bestimmen(e, uhr: nil, nurBeschickbare: true).map(\.name), ["Fertig"])
        XCTAssertThrowsError(try Kurzbefehlsziele.bestimmen(einstellungen([roh]), uhr: nil, nurBeschickbare: true)) {
            XCTAssertEqual($0 as? Kurzbefehlsziele.Fehler, .nichtAbgefragt(["Roh"]))
        }
    }

    func testFehlerHabenText() {
        let alle: [Kurzbefehlsziele.Fehler] = [.keineUhrEingerichtet, .uhrUnbekannt, .keinBroker,
                                               .nichtAbgefragt(["A"]), .ohneAdresse(["A"])]
        for f in alle {
            XCTAssertFalse((f.errorDescription ?? "").isEmpty)
        }
    }
}
