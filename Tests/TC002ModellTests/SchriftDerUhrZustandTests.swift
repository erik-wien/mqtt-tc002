import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

/// Zeichnet auf, was ueber MQTT hinausginge. Kein Broker.
private final class Aufzeichner: NachrichtSendend, @unchecked Sendable {
    private let sperre = NSLock()
    private var _gesendet: [(thema: String, nutzlast: Data)] = []
    var gesendet: [(thema: String, nutzlast: Data)] {
        sperre.lock(); defer { sperre.unlock() }
        return _gesendet
    }
    func senden(_ nutzlast: Data, an thema: String, zugang: MQTTZugang) throws {
        sperre.lock(); _gesendet.append((thema, nutzlast)); sperre.unlock()
    }
}

/// Der Weg `.text` aus der Oberflaeche: Sendung, Gedaechtnis, Mitlesen.
@MainActor
final class SchriftDerUhrZustandTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "bekannteAnzeigen", "zielIDs",
                              "brokerHost", "brokerPort", "benutzer", "protokollAn", "verlaufAn", "grabsteine"]
    private var sicherung: [String: Any?] = [:]

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
        super.tearDown()
    }

    private func temp() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    private func zustand(_ uhr: Uhr, sender: Aufzeichner) throws -> AppZustand {
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        d.set(uhr.id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set([uhr.id])), forKey: "zielIDs")
        d.set("127.0.0.1", forKey: "brokerHost")
        d.set("1883", forKey: "brokerPort")
        d.set("u", forKey: "benutzer")
        let z = AppZustand(schluesselbund: Schluesselbunddoppelgaenger())
        z.mqttSender = sender
        z.netzsitzung = Belegungsdoppelgaenger.sitzung()
        return z
    }

    private let uhr = Uhr(name: "Wohnzimmer", host: "", praefix: "wz/uhr", betriebsart: .mqtt)

    /// Mit dem Schalter geht Text und kein Bild hinaus, und das Echo der
    /// eigenen Sendung macht den gemerkten Stand nicht ungueltig; eine fremde
    /// Nutzlast danach schon.
    func testDerTextWegSendetTextUndUeberstehtDasEcho() async throws {
        let sender = Aufzeichner()
        let z = try zustand(uhr, sender: sender)
        defer { _ = Slotgedaechtnis.gemeinsam.vergessen(fuer: uhr.id, platz: 5) }
        let o = Meldungsoptionen(text: "Hallo", weg: .text)
        let sammlung = Iconsammlung(schreibordner: temp())

        let bilanz = await z.senden(rahmenFuer: { mass in
            try Meldungsbau.rahmen(o, icon: nil, sammlung: sammlung, mass: mass)
        }, als: "meldung5", slotOptionen: o, slotPlatz: 5)

        XCTAssertTrue(bilanz.ganz, z.fehler ?? "")
        let nutzlast = try XCTUnwrap(sender.gesendet.first).nutzlast
        let json = try XCTUnwrap(String(data: nutzlast, encoding: .utf8))
        XCTAssertTrue(json.contains(#""text":"Hallo""#), json)
        XCTAssertFalse(json.contains("data:image"), "kein GIF auf dem Weg „Schrift der Uhr“")

        let stand = try XCTUnwrap(z.wiederherstellbarerStand(platz: 5, fuer: uhr))
        XCTAssertEqual(stand.optionen?.weg, .text, "der Schalter kommt mit dem Platz zurueck")

        z.gemeldet(thema: "wz/uhr/cmd/apps/pushed/meldung5", nutzlast: nutzlast, fuer: uhr.id)
        XCTAssertNotNil(z.wiederherstellbarerStand(platz: 5, fuer: uhr), "das Echo der eigenen Sendung")

        z.gemeldet(thema: "wz/uhr/cmd/apps/pushed/meldung5",
                   nutzlast: Data(#"{"text":"fremd"}"#.utf8), fuer: uhr.id)
        XCTAssertNil(z.wiederherstellbarerStand(platz: 5, fuer: uhr), "fremd beschrieben")
    }

    /// Ein gemerkter Platz mit Weg `.text` zeigt im Block die Naeherung, nicht
    /// „unbekannt" — dieselbe Vorschau wie im Sendefeld.
    func testEinGemerkterTextPlatzZeigtDieNaeherung() throws {
        d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
        d.set(uhr.id.uuidString, forKey: "aktiveID")
        let z = AppZustand(schluesselbund: Schluesselbunddoppelgaenger())
        let g = Slotgedaechtnis(ordner: temp())
        g.merken(Meldungsoptionen(text: "Hi", weg: .text), icon: nil, iconKante: 8, fuer: uhr.id, platz: 1)

        guard case .bekannt(let pixel) = z.slotzustand(1, belegt: true, gedaechtnis: g) else {
            return XCTFail("gemerkter Stand mit Weg .text muss ein Bild ergeben")
        }
        XCTAssertTrue(pixel.contains { $0 != nil })
    }
}
