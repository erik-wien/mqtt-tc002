import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

/// Sicherung in der Fernbedienung, gegen die virtuelle Uhr auf `127.0.0.1`.
@MainActor
final class SicherungSteuerungTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "bekannteAnzeigen", "zielIDs",
                              "brokerHost", "brokerPort", "benutzer", "protokollAn", "verlaufAn"]
    private var gesichert: [String: Any?] = [:]
    private var server: [Uhrenserver] = []

    override func setUp() {
        super.setUp()
        gesichert = Dictionary(uniqueKeysWithValues: schluessel.map { ($0, d.object(forKey: $0)) })
    }

    override func tearDown() {
        server.forEach { $0.beenden() }
        server = []
        for schl in schluessel {
            if let wert = gesichert[schl] ?? nil { d.set(wert, forKey: schl) } else { d.removeObject(forKey: schl) }
        }
        super.tearDown()
    }

    private func httpUhr(mitIcon: Bool, host: String? = nil) throws -> (AppZustand, Uhr, Uhrenserver) {
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            var stand = NGUhrzustand()
            if mitIcon { stand.ablage.dateien["/ICONS/a.gif"] = Data("GIF89a".utf8) + Data([1, 2]) }
            let s = Uhrenserver(port: port, zustand: stand)
            do {
                try s.starten()
                server.append(s)
                let uhr = Uhr(name: "Küche", host: host ?? "127.0.0.1:\(port)", praefix: "", betriebsart: .http)
                d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
                d.set(uhr.id.uuidString, forKey: "aktiveID")
                d.set(try JSONEncoder().encode(Set([uhr.id])), forKey: "zielIDs")
                return (AppZustand(schluesselbund: Schluesselbunddoppelgaenger()), uhr, s)
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    func testSichernDateiLesenZurueckspielen() async throws {
        let (z, uhr, _) = try httpUhr(mitIcon: true)
        let zipOpt = await z.sicherungErstellen(fuer: uhr.id)
        let zip = try XCTUnwrap(zipOpt)
        let datei = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
        try zip.write(to: datei)
        let gelesenOpt = await z.sicherungLesen(datei: datei)
        let gelesen = try XCTUnwrap(gelesenOpt)
        XCTAssertGreaterThan(gelesen.vorschau.eintraege, 0)

        let (z2, uhr2, s2) = try httpUhr(mitIcon: false)
        let ergebnisOpt = await z2.sicherungZurueckspielen(gelesen.zip, name: "k.zip", fuer: uhr2.id)
        let ergebnis = try XCTUnwrap(ergebnisOpt)
        XCTAssertEqual(ergebnis.angewendet["icons"], 1)
        XCTAssertNil(z2.fehler)
        XCTAssertEqual(s2.zustand.ablage.dateien.keys.sorted(), ["/ICONS/a.gif"])
    }

    func testKeineSicherungWirdVorDemSendenAbgewiesen() async throws {
        let (z, _, _) = try httpUhr(mitIcon: false)
        let datei = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
        try Data("kein zip".utf8).write(to: datei)
        let r = await z.sicherungLesen(datei: datei)
        XCTAssertNil(r)
        XCTAssertNotNil(z.fehler)
    }

    func testOhneAdresseMeldetEs() async throws {
        let (z, uhr, _) = try httpUhr(mitIcon: false, host: "")
        let zip = await z.sicherungErstellen(fuer: uhr.id)
        XCTAssertNil(zip)
        XCTAssertTrue(z.fehler?.contains("Ohne Adresse") == true, z.fehler ?? "nil")
    }
}
