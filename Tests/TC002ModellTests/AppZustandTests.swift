import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

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

    /// Wird die einzige gewaehlte Uhr entfernt, muss zielIDs sofort wieder
    /// alle verbleibenden Uhren waehlen — sonst zaehlte die Menge als "keine
    /// Auswahl", und Einstellungen.ziele() (alle) und ziele() (die aktive Uhr)
    /// zeigten wieder auf verschiedene Ziele.
    func testEntfernenDerEinzigenAuswahlWaehltAlleVerbleibenden() throws {
        d.removeObject(forKey: "uhren")
        d.removeObject(forKey: "aktiveID")
        d.removeObject(forKey: "zielIDs")
        let zustand = AppZustand()
        let a = Uhr(name: "Küche", host: "10.0.0.1", praefix: "pa")
        let b = Uhr(name: "Bad", host: "10.0.0.2", praefix: "pb")
        zustand.uhren = [a, b]
        zustand.zielIDs = [a.id]

        zustand.uhrEntfernen(a.id)

        XCTAssertFalse(zustand.zielIDs.isEmpty)
        XCTAssertEqual(zustand.zielIDs, [b.id])
        XCTAssertEqual(zustand.ziele(), [b])
    }

    /// Eine Installation von vor dem Zielmenue hat Uhren, aber nie eine
    /// ausdrueckliche Auswahl geschrieben — zielIDs steht leer in den
    /// Einstellungen. Der Start muss das auf "alle" aufloesen, sonst zeigte
    /// die App fortan nur die aktive Uhr, waehrend Werkzeug und Kurzbefehle
    /// weiter alle ansprechen.
    func testAlteInstallationOhneAuswahlBekommtAlleUhrenBeimStart() throws {
        let a = Uhr(name: "Küche", host: "10.0.0.1", praefix: "pa")
        let b = Uhr(name: "Bad", host: "10.0.0.2", praefix: "pb")
        d.set(try JSONEncoder().encode([a, b]), forKey: "uhren")
        d.set(a.id.uuidString, forKey: "aktiveID")
        d.removeObject(forKey: "zielIDs")

        let zustand = AppZustand()

        XCTAssertEqual(zustand.zielIDs, Set([a.id, b.id]))
        XCTAssertEqual(zustand.ziele(), [a, b])
    }

    // MARK: Slot-Blöcke

    /// Ein frischer, noch nicht angelegter Ordnerpfad unter dem temporaeren
    /// Verzeichnis — nie unter „Application Support/MQTT-TC002": dort liegen
    /// die echten Slotdateien einer Installation.
    private func temp() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    /// Ein belegter Platz ohne mitgelesene Pixel zeigt trotzdem etwas, sobald
    /// das Gedaechtnis einen Stand dafuer hat — neu gerechnet ueber
    /// `Meldungsbau`, nicht aus der Nutzlast zurueckgewonnen. Ohne diesen
    /// Rueckfall saehe ein gerade selbst gefuellter Platz nach einem Neustart
    /// „unbekannt" aus.
    func testSlotzustandFaelltAufDasGedaechtnisZurueck() throws {
        let uhr = Uhr(name: "Küche", host: "10.0.0.1", praefix: "pa")
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        d.set(uhr.id.uuidString, forKey: "aktiveID")
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let optionen = Meldungsoptionen(text: "Bus kommt")
        gedaechtnis.merken(optionen, dauer: nil, icon: nil, fuer: uhr.id, platz: 2)

        let zustand = AppZustand()

        XCTAssertEqual(zustand.slotzustand(2, belegt: true, gedaechtnis: gedaechtnis),
                       .bekannt(Meldungsbau.feld(optionen, mitIcon: false).punkteRoh))
        XCTAssertEqual(zustand.slotzustand(3, belegt: true, gedaechtnis: gedaechtnis), .unbekannt)
        XCTAssertEqual(zustand.slotzustand(2, belegt: false, gedaechtnis: gedaechtnis), .frei)
    }

    /// Die Bloecke richten sich nach der **aktiven** Uhr, nicht nach der
    /// ersten Zieluhr: Bei mehreren Zieluhren waere „die erste" willkuerlich,
    /// und zwei Ansichten derselben Sitzung zeigten verschiedene Bilder.
    func testSlotzustandRichtetSichNachDerAktivenUhr() throws {
        let a = Uhr(name: "Küche", host: "10.0.0.1", praefix: "pa")
        let b = Uhr(name: "Büro", host: "10.0.0.2", praefix: "pb")
        d.set(try JSONEncoder().encode([a, b]), forKey: "uhren")
        d.set(b.id.uuidString, forKey: "aktiveID")
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        let pixel = Meldungsbau.feld(Meldungsoptionen(text: "nur auf a"), mitIcon: false).punkteRoh

        let zustand = AppZustand()
        zustand.slotInhalt[a.id] = [1: Slotbild(pixel: pixel, zeitpunkt: Date())]

        XCTAssertEqual(zustand.slotzustand(1, belegt: true, gedaechtnis: gedaechtnis), .unbekannt,
                       "Das Bild der ersten Uhr darf nicht für die aktive Uhr einstehen.")
    }
}
