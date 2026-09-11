import Foundation
import XCTest
@testable import TC002App

/// Die Tests fassen nur die Einstellungs-Schluessel `uhren`, `aktiveID`,
/// `bekannteAnzeigen` und `zielIDs` an — nie den Schluesselbund, nie eine echte
/// Uhr oder einen echten Broker. Vor und nach jedem Test wird der Bestand
/// dieser Schluessel im Testprozess gesichert und wiederhergestellt.
@MainActor
final class AppZustandTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "bekannteAnzeigen", "zielIDs"]
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

    /// Die alte, uhrenlose Anzeigenliste muss genau einmal auf die aktive Uhr
    /// uebernommen werden. Bliebe der alte Schluessel stehen, wanderte sie bei
    /// jedem Start erneut — und zwar an die dann jeweils aktive Uhr.
    func testAlteAnzeigenlisteWirdNurEinmalUebernommen() throws {
        let id = UUID()
        let uhr = Uhr(id: id, name: "Küche", host: "10.0.0.5")
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        d.set(id.uuidString, forKey: "aktiveID")
        d.set(["Alt1", "Alt2"], forKey: "bekannteAnzeigen")

        let zustand = AppZustand()

        XCTAssertEqual(zustand.bekannteAnzeigen[id], ["Alt1", "Alt2"])
        XCTAssertNil(d.stringArray(forKey: "bekannteAnzeigen"),
                      "Der alte Schlüssel muss nach der Übernahme verschwinden, sonst wandert die Liste bei jedem Start erneut.")
    }

    /// UUID(uuidString:) ist gegenueber Gross-/Kleinschreibung nachsichtig: zwei von
    /// Hand verbogene Schluessel in unterschiedlicher Schreibweise ergeben dieselbe
    /// UUID. Das darf die App beim Start nicht zum Absturz bringen.
    func testDoppelteUuidUnterschiedlicherSchreibweiseStuerztNichtAb() throws {
        let text = "3F2504E0-4F89-11D3-9A0C-0305E82C3301"
        let flach = [text: ["A"], text.lowercased(): ["B"]]
        d.set(try JSONEncoder().encode(flach), forKey: "bekannteAnzeigen")
        d.removeObject(forKey: "uhren")
        d.removeObject(forKey: "aktiveID")

        let zustand = AppZustand() // darf nicht abstürzen

        let id = try XCTUnwrap(UUID(uuidString: text))
        XCTAssertEqual(zustand.bekannteAnzeigen.count, 1)
        let liste = try XCTUnwrap(zustand.bekannteAnzeigen[id])
        XCTAssertTrue(liste == ["A"] || liste == ["B"])
    }

    /// Leere Auswahl heisst: gesendet wird an die aktive Uhr — sonst liefe ein
    /// Sendeversuch ohne jede Wahl stillschweigend ins Leere.
    func testLeereAuswahlFaelltAufAktiveUhrZurueck() throws {
        d.removeObject(forKey: "uhren")
        d.removeObject(forKey: "aktiveID")
        d.removeObject(forKey: "zielIDs")
        let zustand = AppZustand()
        let a = Uhr(name: "Küche", host: "10.0.0.1", praefix: "pa")
        let b = Uhr(name: "Bad", host: "10.0.0.2", praefix: "pb")
        zustand.uhren = [a, b]
        zustand.aktiveID = b.id

        XCTAssertTrue(zustand.zielIDs.isEmpty)
        XCTAssertEqual(zustand.ziele(), [b])
    }

    /// Eine entfernte Uhr darf in der Auswahl nicht als Geist weiterleben.
    func testEntfernteUhrVerschwindetAusDerAuswahl() throws {
        d.removeObject(forKey: "uhren")
        d.removeObject(forKey: "aktiveID")
        d.removeObject(forKey: "zielIDs")
        let zustand = AppZustand()
        let a = Uhr(name: "Küche", host: "10.0.0.1", praefix: "pa")
        let b = Uhr(name: "Bad", host: "10.0.0.2", praefix: "pb")
        zustand.uhren = [a, b]
        zustand.zielIDs = [a.id, b.id]

        zustand.uhrEntfernen(a.id)

        XCTAssertFalse(zustand.zielIDs.contains(a.id))
        XCTAssertEqual(zustand.ziele(), [b])
    }

    /// Eine gewaehlte Uhr ohne Praefix darf nicht als Sendeziel auftauchen — sie
    /// kann noch gar nichts empfangen, weil sie nie abgefragt wurde.
    func testUhrenOhnePraefixWerdenUebersprungen() throws {
        d.removeObject(forKey: "uhren")
        d.removeObject(forKey: "aktiveID")
        d.removeObject(forKey: "zielIDs")
        let zustand = AppZustand()
        let a = Uhr(name: "Küche", host: "10.0.0.1") // kein Präfix — nie abgefragt
        let b = Uhr(name: "Bad", host: "10.0.0.2", praefix: "pb")
        zustand.uhren = [a, b]
        zustand.zielIDs = [a.id, b.id]

        XCTAssertEqual(zustand.ziele(), [b])
    }
}
