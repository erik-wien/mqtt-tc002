import XCTest
@testable import TC002Core

/// Die Einstellungen sind die Nahtstelle zwischen App und Kommandozeilen-
/// werkzeug. Was hier schiefgeht, faellt erst auf, wenn das Werkzeug
/// stillschweigend an die falsche Uhr sendet — oder an gar keine.
final class EinstellungenTests: XCTestCase {

    private func uhr(_ name: String, _ host: String, praefix: String = "awtrix_0000") -> Uhr {
        Uhr(name: name, host: host, praefix: praefix)
    }

    private func einstellungen(uhren: [Uhr], zielIDs: Set<UUID> = []) -> Einstellungen {
        Einstellungen(brokerHost: "broker.local", brokerPort: 1883, benutzer: "u",
                      kennwort: "k", uhren: uhren, zielIDs: zielIDs)
    }

    /// Ohne Auswahl gilt: alle. Das ist die Lage nach einer frischen
    /// Installation — die App legt `zielIDs` erst ab, wenn jemand waehlt.
    func testOhneAuswahlSindAlleUhrenZiel() {
        let a = uhr("Küche", "10.0.0.1"), b = uhr("Bad", "10.0.0.2")
        XCTAssertEqual(einstellungen(uhren: [a, b]).ziele.map(\.name), ["Küche", "Bad"])
    }

    func testAuswahlGrenztEin() {
        let a = uhr("Küche", "10.0.0.1"), b = uhr("Bad", "10.0.0.2")
        let e = einstellungen(uhren: [a, b], zielIDs: [b.id])
        XCTAssertEqual(e.ziele.map(\.name), ["Bad"])
    }

    /// Eine Auswahl, die nur noch auf geloeschte Uhren zeigt, darf nicht als
    /// „keine Auswahl" durchgehen und damit plötzlich alle treffen — das waere
    /// aus Sicht des Anwenders eine Sendung an Geraete, die er abgewaehlt hat.
    /// Sie faellt deshalb auf „alle" zurueck, aber nur weil nichts uebrig ist;
    /// dieser Test haelt das Verhalten fest, damit es nicht unbemerkt kippt.
    func testVerwaisteAuswahlFaelltAufAlleZurueck() {
        let a = uhr("Küche", "10.0.0.1")
        let e = einstellungen(uhren: [a], zielIDs: [UUID()])
        XCTAssertEqual(e.ziele.map(\.name), ["Küche"])
    }

    func testSuchePerNameUndAdresse() {
        let a = uhr("Küche", "10.0.0.1"), b = uhr("Bad", "10.0.0.2")
        let e = einstellungen(uhren: [a, b])
        XCTAssertEqual(e.uhr(benannt: "Bad")?.id, b.id)
        XCTAssertEqual(e.uhr(benannt: "bad")?.id, b.id, "Gross- und Kleinschreibung zaehlt nicht")
        XCTAssertEqual(e.uhr(benannt: "10.0.0.1")?.id, a.id, "die Adresse geht auch")
        XCTAssertNil(e.uhr(benannt: "Keller"))
    }

    /// Der Name gewinnt gegen die Adresse: Wer eine Uhr „10.0.0.2" nennt,
    /// meint mit diesem Wort die Uhr mit dem Namen, nicht die dahinter.
    func testNameSchlaegtAdresse() {
        let getarnt = uhr("10.0.0.2", "10.0.0.9"), echt = uhr("Bad", "10.0.0.2")
        let e = einstellungen(uhren: [getarnt, echt])
        XCTAssertEqual(e.uhr(benannt: "10.0.0.2")?.id, getarnt.id)
    }

    func testZugangTraegtDieKennung() {
        let z = einstellungen(uhren: []).zugang(clientID: "tc002-cli-abc")
        XCTAssertEqual(z?.clientID, "tc002-cli-abc")
        XCTAssertEqual(z?.host, "broker.local")
        XCTAssertEqual(z?.port, 1883)
    }

    /// Ohne Broker gibt es keinen Zugang — und das Werkzeug soll das melden,
    /// statt an Port 0 zu laufen.
    func testOhneBrokerKeinZugang() {
        let ohneHost = Einstellungen(brokerHost: "", brokerPort: 1883, benutzer: nil,
                                     kennwort: nil, uhren: [], zielIDs: [])
        let ohnePort = Einstellungen(brokerHost: "broker.local", brokerPort: 0, benutzer: nil,
                                     kennwort: nil, uhren: [], zielIDs: [])
        XCTAssertNil(ohneHost.zugang(clientID: "x"))
        XCTAssertNil(ohnePort.zugang(clientID: "x"))
    }

    /// Die Codable-Form von `Uhr` ist ein Dateiformat: Die App hat sie
    /// geschrieben, das Werkzeug liest sie. Wer die Feldnamen aendert, macht
    /// die Einstellungen einer laufenden Installation unlesbar.
    func testUhrBleibtLesbar() throws {
        let json = """
        [{"id":"0E5E2F1A-6B4C-4E9B-9F3E-6A0C1D2E3F40","name":"Küche",\
        "host":"10.0.0.1","praefix":"awtrix_a86b","mac":"AA:BB"}]
        """
        let uhren = try JSONDecoder().decode([Uhr].self, from: Data(json.utf8))
        XCTAssertEqual(uhren.count, 1)
        XCTAssertEqual(uhren[0].name, "Küche")
        XCTAssertEqual(uhren[0].host, "10.0.0.1")
        XCTAssertEqual(uhren[0].praefix, "awtrix_a86b")
        XCTAssertEqual(uhren[0].mac, "AA:BB")
    }

    /// Die Vorgaben muessen dieselben sein wie in der App — sie legt einen
    /// unveraenderten Wert gar nicht erst ab, und dann gilt hier der Rueckfall.
    func testVorgabenSindGesetzt() {
        XCTAssertEqual(Einstellungen.Vorgabe.brokerPort, "1883")
        XCTAssertEqual(Einstellungen.Vorgabe.benutzer, "pixdeck")
        XCTAssertFalse(Einstellungen.Vorgabe.brokerHost.isEmpty)
    }

    /// Aus einem leeren Bereich kommen die Vorgaben, nicht Unsinn: ein Port 0
    /// liesse `NWEndpoint.Port` abstuerzen.
    func testLeererBereichLiefertVorgaben() {
        let bereich = "test.mqtt-tc002." + UUID().uuidString
        let e = Einstellungen.gelesen(bereich: bereich)
        XCTAssertEqual(e.brokerPort, 1883)
        XCTAssertTrue(e.uhren.isEmpty)
        XCTAssertTrue(e.ziele.isEmpty)
        UserDefaults.standard.removePersistentDomain(forName: bereich)
    }
}
