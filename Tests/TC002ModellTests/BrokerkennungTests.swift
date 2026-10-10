import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

/// Das Vergleichsfeld, an dem `horchenAbgleichen` erkennt, dass sich der Broker
/// geändert hat, trägt das Kennwort nicht im Klartext.
@MainActor
final class BrokerkennungTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "zielIDs", "brokerHost", "brokerPort", "benutzer"]
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

    func testDasKennwortStehtNichtImKlartextImVergleichsfeld() {
        let z = AppZustand(schluesselbund: Schluesselbunddoppelgaenger())
        z.brokerHost = "broker.example"
        z.kennwort = "streng-geheim-4711"
        XCTAssertFalse(z.brokerkennung.contains("streng-geheim"))
        XCTAssertFalse(z.brokerkennung.contains("broker.example"))
    }

    /// Wer Adresse, Port, Benutzer oder Kennwort ändert, bekommt ein anderes
    /// Feld und damit ein neues Abonnement.
    func testJedeAenderungAmBrokerAendertDasVergleichsfeld() {
        let z = AppZustand(schluesselbund: Schluesselbunddoppelgaenger())
        var gesehen: Set<String> = [z.brokerkennung]
        z.brokerHost = "a.example"; gesehen.insert(z.brokerkennung)
        z.brokerPort = "1884"; gesehen.insert(z.brokerkennung)
        z.benutzer = "erik"; gesehen.insert(z.brokerkennung)
        z.kennwort = "eins"; gesehen.insert(z.brokerkennung)
        z.kennwort = "zwei"; gesehen.insert(z.brokerkennung)
        XCTAssertEqual(gesehen.count, 6)
        z.kennwort = "zwei"
        XCTAssertTrue(gesehen.contains(z.brokerkennung), "unverändert bleibt es gleich")
    }
}
