import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

/// Zeichnet auf, was über MQTT hinausginge. Kein Broker.
private final class Aufzeichner: NachrichtSendend, @unchecked Sendable {
    private let sperre = NSLock()
    private var _gesendet: [String] = []
    var themen: [String] { sperre.lock(); defer { sperre.unlock() }; return _gesendet }

    func senden(_ nutzlast: Data, an thema: String, zugang: MQTTZugang) throws {
        sperre.lock(); _gesendet.append(thema); sperre.unlock()
    }
}

/// Favoriten senden an ihre eigenen Uhren; Ablage, Gedächtnis und Verlauf liegen
/// in Testordnern.
@MainActor
final class FavoritenbetriebTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "bekannteAnzeigen", "zielIDs",
                              "brokerHost", "brokerPort", "benutzer", "protokollAn", "verlaufAn", "grabsteine"]
    private var sicherung: [String: Any?] = [:]
    private var ordner: [URL] = []

    override func setUp() {
        super.setUp()
        sicherung = Dictionary(uniqueKeysWithValues: schluessel.map { ($0, d.object(forKey: $0)) })
        d.set(false, forKey: "verlaufAn")
        Belegungsdoppelgaenger.antwort = "{}"
        Belegungsdoppelgaenger.weitere = [:]
        Belegungsdoppelgaenger.pfade = []
    }

    override func tearDown() {
        for schl in schluessel {
            if let wert = sicherung[schl] ?? nil { d.set(wert, forKey: schl) } else { d.removeObject(forKey: schl) }
        }
        ordner.forEach { try? FileManager.default.removeItem(at: $0) }
        super.tearDown()
    }

    private let uhrA = Uhr(name: "Wohnzimmer", host: "", praefix: "wz/uhr", betriebsart: .mqtt)
    private let uhrB = Uhr(name: "Küche", host: "", praefix: "kue/uhr", betriebsart: .mqtt)

    private func temp() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("favoriten-" + UUID().uuidString)
        ordner.append(u)
        return u
    }

    private struct Prueffeld {
        let z: AppZustand
        let sender: Aufzeichner
        let ablage: Favoritenablage
        let ablageordner: URL
        let gedaechtnis: Slotgedaechtnis
        let sammlung: Iconsammlung
    }

    /// Beide Uhren sind gewählt, die globale Wahl lautet [A].
    private func feld() throws -> Prueffeld {
        let uhren = [uhrA, uhrB]
        d.set(try JSONEncoder().encode(uhren), forKey: "uhren")
        d.set(uhrA.id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set([uhrA.id])), forKey: "zielIDs")
        d.set("127.0.0.1", forKey: "brokerHost")
        d.set("1883", forKey: "brokerPort")
        d.set("u", forKey: "benutzer")
        let ao = temp()
        let ablage = Favoritenablage(ordner: ao)
        let z = AppZustand(schluesselbund: Schluesselbunddoppelgaenger(), favoritenablage: ablage)
        let sender = Aufzeichner()
        z.mqttSender = sender
        z.netzsitzung = Belegungsdoppelgaenger.sitzung()
        let gedaechtnis = Slotgedaechtnis(ordner: temp())
        z.slotgedaechtnisErsatz = gedaechtnis
        z.sendeverlauf = Sendeverlauf(ordner: temp(), kennung: "Test")
        z.favoritenstandDauer = .milliseconds(50)
        let sammlung = Iconsammlung(schreibordner: temp())
        return Prueffeld(z: z, sender: sender, ablage: ablage, ablageordner: ao, gedaechtnis: gedaechtnis, sammlung: sammlung)
    }

    private func favorit(_ ziele: [UUID], platz: Int = 1, icon: String? = nil,
                         nachricht: Nachrichtwahl? = nil) -> Favorit {
        Favorit(titel: "Gruß", auftrag: Sendeauftrag(
            optionen: Meldungsoptionen(text: "Grüß", weg: .pixel, schrift: "Silkscreen", groesse: 8),
            iconNummer: icon, platz: platz, nachricht: nachricht, zielIDs: ziele))
    }

    /// Legt den Favoriten in die Liste, wie es die Ansicht über die Ablage täte.
    private func einlegen(_ f: Favorit, in p: Prueffeld) -> AppZustand {
        p.ablage.sichern([f])
        p.z.favoriten = p.ablage.alle()
        return p.z
    }

    func testFavoritGehtNurAnSeineUhren() async throws {
        let p = try feld()
        let f = favorit([uhrB.id])
        let z = einlegen(f, in: p)

        await z.favoritSenden(f.id, bestaende: [p.sammlung])

        XCTAssertEqual(p.sender.themen, ["kue/uhr/cmd/apps/pushed/meldung1"], z.fehler ?? "")
        XCTAssertEqual(z.zielIDs, [uhrA.id])
    }

    func testFavoritOhneVorhandeneUhrMeldetFehler() async throws {
        let p = try feld()
        let f = favorit([UUID()])
        let z = einlegen(f, in: p)

        await z.favoritSenden(f.id, bestaende: [p.sammlung])

        XCTAssertNotNil(z.fehler)
        XCTAssertTrue(p.sender.themen.isEmpty)
        XCTAssertNil(z.favoritenstand[f.id])
    }

    func testFavoritMitGeloeschtemIconSendetOhneIcon() async throws {
        let p = try feld()
        let f = favorit([uhrB.id], icon: "gibtesnicht")
        let z = einlegen(f, in: p)

        await z.favoritSenden(f.id, bestaende: [p.sammlung])

        XCTAssertEqual(p.sender.themen.count, 1)
        XCTAssertNil(z.fehler)
    }

    func testFavoritAlsNachrichtGehtAufNotify() async throws {
        let p = try feld()
        let f = favorit([uhrB.id], nachricht: Nachrichtwahl())
        let z = einlegen(f, in: p)

        await z.favoritSenden(f.id, bestaende: [p.sammlung])

        XCTAssertEqual(p.sender.themen.count, 1, z.fehler ?? "")
        XCTAssertTrue(p.sender.themen[0].hasSuffix("/notify"), p.sender.themen[0])
    }

    func testFavoritAnzeigeMerktSlot() async throws {
        let p = try feld()
        let f = favorit([uhrB.id], platz: 2)
        let z = einlegen(f, in: p)

        await z.favoritSenden(f.id, bestaende: [p.sammlung])

        XCTAssertEqual(p.gedaechtnis.gemerkt(fuer: uhrB.id, platz: 2)?.platz, 2)
        XCTAssertNil(p.gedaechtnis.gemerkt(fuer: uhrA.id, platz: 2))
    }

    func testStandWirdNachKurzerZeitEntfernt() async throws {
        let p = try feld()
        let f = favorit([uhrB.id])
        let z = einlegen(f, in: p)

        await z.favoritSenden(f.id, bestaende: [p.sammlung])
        XCTAssertEqual(z.favoritenstand[f.id], .ganz)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(z.favoritenstand[f.id])
    }

    func testUmbenennenUndLoeschenSichern() throws {
        let p = try feld()
        let f = favorit([uhrB.id])
        let z = einlegen(f, in: p)

        z.favoritUmbenennen(f.id, zu: " Neu ")
        XCTAssertEqual(Favoritenablage(ordner: p.ablageordner).alle().map(\.titel), ["Neu"])

        z.favoritLoeschen(f.id)
        XCTAssertTrue(Favoritenablage(ordner: p.ablageordner).alle().isEmpty)
    }
}
