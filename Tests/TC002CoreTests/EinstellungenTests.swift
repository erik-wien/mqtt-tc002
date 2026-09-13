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

    /// Eine Einstellungszeile, wie eine laufende Installation sie abgelegt hat:
    /// ohne `typ`, denn den gab es beim Schreiben noch nicht.
    private static let alteZeile = """
    [{"id":"0E5E2F1A-6B4C-4E9B-9F3E-6A0C1D2E3F40","name":"Küche",\
    "host":"10.0.0.1","praefix":"awtrix_a86b","mac":"AA:BB"}]
    """

    /// Die Codable-Form von `Uhr` ist ein Dateiformat: Die App hat sie
    /// geschrieben, das Werkzeug liest sie. Wer die Feldnamen aendert, macht
    /// die Einstellungen einer laufenden Installation unlesbar.
    func testUhrBleibtLesbar() throws {
        let uhren = try JSONDecoder().decode([Uhr].self, from: Data(Self.alteZeile.utf8))
        XCTAssertEqual(uhren.count, 1)
        XCTAssertEqual(uhren[0].name, "Küche")
        XCTAssertEqual(uhren[0].host, "10.0.0.1")
        XCTAssertEqual(uhren[0].praefix, "awtrix_a86b")
        XCTAssertEqual(uhren[0].mac, "AA:BB")
        XCTAssertNil(uhren[0].typ, "kein `typ` in der Datei heisst: TC002, wie bisher")
    }

    /// Warum `typ` ein `Optional` ist — nachgemessen, nicht geglaubt.
    ///
    /// Swift setzt beim synthetisierten Decode **keine** Vorgabewerte fuer
    /// fehlende Schluessel ein. Ein Pflichtfeld mit Vorgabe wirft deshalb
    /// genauso `keyNotFound` wie eines ohne. Und weil beide Leser (`gelesen`
    /// hier, `AppZustand.init` in der App) mit `try?` lesen und auf `?? []`
    /// fallen, waere die Folge keine Fehlermeldung, sondern eine leere
    /// Uhrenliste: alle eingerichteten Uhren still weg.
    func testNurEinOptionalHaeltDieAlteDateiLesbar() throws {
        /// Dieselbe Uhr, nur mit `typ` als Pflichtfeld **samt Vorgabewert**.
        struct UhrMitPflichtfeld: Codable {
            var id = UUID()
            var name: String
            var host: String
            var praefix: String = ""
            var mac: String = ""
            var typ: Geraetetyp = .tc002
        }
        let alt = Data(Self.alteZeile.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode([UhrMitPflichtfeld].self, from: alt)) { fehler in
            guard case DecodingError.keyNotFound(let schluessel, _) = fehler else {
                return XCTFail("war stattdessen \(fehler)")
            }
            XCTAssertEqual(schluessel.stringValue, "typ",
                           "der Vorgabewert traegt nicht — es fehlt der Schluessel")
        }
        // Und was die beiden Leser daraus machten: keine Meldung, keine Uhren.
        XCTAssertNil(try? JSONDecoder().decode([UhrMitPflichtfeld].self, from: alt))

        // Das Optional traegt.
        XCTAssertEqual(try JSONDecoder().decode([Uhr].self, from: alt).count, 1)
    }

    /// Die Gegenrichtung: Solange `typ` nil ist, schreibt der Encoder ihn gar
    /// nicht — `encodeIfPresent` bekommen nur Optionals. Eine aeltere Fassung
    /// der App liest die Datei damit weiterhin.
    func testEinLeererTypLandetNichtInDerDatei() throws {
        let daten = try JSONEncoder().encode([Uhr(name: "Küche", host: "10.0.0.1")])
        let text = String(decoding: daten, as: UTF8.self)
        XCTAssertFalse(text.contains("typ"), "war: \(text)")

        let mitTyp = try JSONEncoder().encode([Uhr(name: "Küche", host: "10.0.0.1", typ: .tc002)])
        XCTAssertTrue(String(decoding: mitTyp, as: UTF8.self).contains("\"typ\":\"tc002\""))
    }

    /// Die Vorgaben muessen dieselben sein wie in der App — sie legt einen
    /// unveraenderten Wert gar nicht erst ab, und dann gilt hier der Rueckfall.
    ///
    /// Adresse und Benutzer sind **leer**, und das ist die Zusicherung: Eine
    /// erfundene Vorgabe stuende auf einer frischen Installation im Feld, ohne
    /// dass jemand sie eingetragen haette — und `brokerEingerichtet` waere dort
    /// wahr, obwohl es keinen Broker gibt. Der Port ist der Gegenfall: 1883 ist
    /// der Standardport von MQTT und sagt nichts ueber diese Installation.
    func testVorgabenSindGesetzt() {
        XCTAssertEqual(Einstellungen.Vorgabe.brokerPort, "1883")
        XCTAssertTrue(Einstellungen.Vorgabe.benutzer.isEmpty,
                      "ein vorausgefuellter Benutzername ist schlechter als ein leeres Feld")
        XCTAssertTrue(Einstellungen.Vorgabe.brokerHost.isEmpty,
                      "eine erfundene Brokeradresse taeuscht eine Einrichtung vor")
    }

    /// Und was daraus folgt: Aus einem leeren Bereich kommt **kein**
    /// eingerichteter Broker. Das Werkzeug meldet dann, dass keiner eingetragen
    /// ist, statt an eine Adresse zu senden, die niemand genannt hat.
    func testFrischeInstallationHatKeinenBroker() {
        let bereich = "test.mqtt-tc002." + UUID().uuidString
        let e = Einstellungen.gelesen(bereich: bereich)
        XCTAssertEqual(e.brokerHost, "")
        XCTAssertNil(e.benutzer, "ein leerer Benutzername heisst „kein Konto“")
        XCTAssertFalse(e.brokerEingerichtet)
        XCTAssertNil(e.zugang(clientID: "x"))
        UserDefaults.standard.removePersistentDomain(forName: bereich)
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

    /// Das Kennwort wird erst beim Zugriff geholt, nicht beim Lesen der
    /// Einstellungen. Sonst fragt der Schluesselbund auch dann, wenn gar nicht
    /// gesendet wird — `mqtttc002 uhren` etwa.
    func testKennwortWirdErstBeiBedarfGelesen() {
        let bereich = "test-\(UUID().uuidString)"
        defer { Schluesselbund.loeschen("broker", dienst: bereich) }

        let e = Einstellungen.gelesen(bereich: bereich)
        Schluesselbund.setzen("geheim", fuer: "broker", dienst: bereich)

        XCTAssertEqual(e.kennwort, "geheim",
                       "Eifrig gelesen waere es hier nil — der Eintrag entstand danach.")
    }
}
