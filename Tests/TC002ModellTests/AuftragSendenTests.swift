import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

/// Zeichnet Thema und Nutzlast auf, die über MQTT hinausgingen. Kein Broker.
private final class Aufzeichner: NachrichtSendend, @unchecked Sendable {
    private let sperre = NSLock()
    private var _gesendet: [(thema: String, nutzlast: String)] = []
    var gesendet: [(thema: String, nutzlast: String)] { sperre.lock(); defer { sperre.unlock() }; return _gesendet }

    func senden(_ nutzlast: Data, an thema: String, zugang: MQTTZugang) throws {
        sperre.lock(); _gesendet.append((thema, String(decoding: nutzlast, as: UTF8.self))); sperre.unlock()
    }
}

/// `auftragSenden` ohne `nurIDs`: so ruft es die Senden-Ansicht.
@MainActor
final class AuftragSendenTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "bekannteAnzeigen", "zielIDs",
                              "brokerHost", "brokerPort", "benutzer", "protokollAn", "verlaufAn", "grabsteine"]
    private var sicherung: [String: Any?] = [:]
    private var ordner: [URL] = []

    private let uhrA = Uhr(name: "Wohnzimmer", host: "", praefix: "wz/uhr", betriebsart: .mqtt)
    private let uhrB = Uhr(name: "Küche", host: "", praefix: "kue/uhr", betriebsart: .mqtt)
    private let uhrOhne = Uhr(name: "Flur", host: "", praefix: "", betriebsart: .mqtt)

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

    private func temp() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("auftrag-" + UUID().uuidString)
        ordner.append(u)
        return u
    }

    private func feld() throws -> (z: AppZustand, sender: Aufzeichner, sammlung: Iconsammlung) {
        d.set(try JSONEncoder().encode([uhrA, uhrB, uhrOhne]), forKey: "uhren")
        d.set(uhrA.id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set([uhrA.id])), forKey: "zielIDs")
        d.set("127.0.0.1", forKey: "brokerHost")
        d.set("1883", forKey: "brokerPort")
        d.set("u", forKey: "benutzer")
        let z = AppZustand(schluesselbund: Schluesselbunddoppelgaenger(),
                           favoritenablage: Favoritenablage(ordner: temp()))
        let sender = Aufzeichner()
        z.mqttSender = sender
        z.netzsitzung = Belegungsdoppelgaenger.sitzung()
        z.slotgedaechtnisErsatz = Slotgedaechtnis(ordner: temp())
        z.sendeverlauf = Sendeverlauf(ordner: temp(), kennung: "Test")
        return (z, sender, Iconsammlung(schreibordner: temp()))
    }

    private func auftrag(zielIDs: [UUID] = [], nachricht: Nachrichtwahl? = nil) -> Sendeauftrag {
        Sendeauftrag(optionen: Meldungsoptionen(text: "Grüß", weg: .pixel, schrift: "Silkscreen", groesse: 8),
                     nachricht: nachricht, zielIDs: zielIDs)
    }

    func testLeereZielIDsSendenAnDieGewaehlteUhr() async throws {
        let p = try feld()

        await p.z.auftragSenden(auftrag(), bestaende: [p.sammlung])

        XCTAssertEqual(p.sender.gesendet.map(\.thema), ["wz/uhr/cmd/apps/pushed/meldung1"], p.z.fehler ?? "")
    }

    func testNachrichtNimmtDieStehtDauerAlsDurationMs() async throws {
        let p = try feld()
        let wahl = Nachrichtwahl(steht: Nachrichtdauerwahl(art: .sekunden, sekunden: 7))

        await p.z.auftragSenden(auftrag(nachricht: wahl), bestaende: [p.sammlung])

        let s = try XCTUnwrap(p.sender.gesendet.first, p.z.fehler ?? "")
        XCTAssertTrue(s.thema.hasSuffix("/notify"), s.thema)
        XCTAssertTrue(s.nutzlast.contains("\"durationMs\":7000"), s.nutzlast)
    }

    func testKlangDerNachrichtErreichtDieNutzlast() async throws {
        let p = try feld()
        let wahl = Nachrichtwahl(klang: Klangwahl(art: .vorlesen))

        await p.z.auftragSenden(auftrag(nachricht: wahl), bestaende: [p.sammlung])

        let s = try XCTUnwrap(p.sender.gesendet.first, p.z.fehler ?? "")
        XCTAssertTrue(s.nutzlast.contains("\"sound\""), s.nutzlast)
    }

    /// Eine gewählte Uhr ohne Präfix fehlt in `ziele()`; die Ansicht reicht keine
    /// vorgefilterten IDs, damit das Protokoll sie weiter nennt.
    func testGewaehlteUhrOhnePraefixStehtUebersprungenImProtokoll() async throws {
        let p = try feld()
        p.z.zielIDs = [uhrA.id, uhrOhne.id]

        await p.z.auftragSenden(auftrag(), bestaende: [p.sammlung])

        XCTAssertTrue(p.z.protokoll.contains { $0.contains("Flur übersprungen") }, p.z.protokoll.joined(separator: "\n"))
    }

    /// Die Ablage des Telefons trug die Kante nie; ihr Vorgabewert 8 darf ein
    /// 16×16-Icon nicht verlieren.
    func testIconFindetSichAuchBeiFalscherKante() async throws {
        let p = try feld()
        let sammlung16 = Iconsammlung(schreibordner: temp(), kante: 16)
        try sammlung16.sichern(nummer: "zz16", name: "Test", pixel: Array(repeating: "#ff0000", count: 256))
        var a = auftrag()
        a.iconNummer = "zz16"
        a.iconKante = 8

        await p.z.auftragSenden(a, bestaende: [p.sammlung, sammlung16])

        let s = try XCTUnwrap(p.sender.gesendet.first, p.z.fehler ?? "")
        XCTAssertTrue(s.nutzlast.contains("\"icon\""), s.nutzlast)
        XCTAssertEqual(Iconsammlung.finden(nummer: "zz16", kante: 8, in: [p.sammlung, sammlung16])?.kante, 16)
        XCTAssertNil(Iconsammlung.finden(nummer: "gibtesnicht", kante: 8, in: [sammlung16]))
    }
}
