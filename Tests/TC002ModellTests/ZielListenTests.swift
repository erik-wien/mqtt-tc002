import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

/// Menünamen und Vorschau folgen den Zieluhren, nicht der angesehenen Uhr.
/// Gegen virtuelle Uhren auf `127.0.0.1`; nichts verlässt den Rechner.
@MainActor
final class ZielListenTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "zielIDs", "grabsteine"]
    private var sicherung: [String: Any?] = [:]
    private var server: [Uhrenserver] = []

    override func setUp() {
        super.setUp()
        sicherung = Dictionary(uniqueKeysWithValues: schluessel.map { ($0, d.object(forKey: $0)) })
    }

    override func tearDown() {
        server.forEach { $0.beenden() }
        server = []
        for s in schluessel {
            if let w = sicherung[s] ?? nil { d.set(w, forKey: s) } else { d.removeObject(forKey: s) }
        }
        super.tearDown()
    }

    private func uhr(_ name: String, melodien: [String: String] = [:], mp3: [String] = []) throws -> Uhr {
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            var stand = NGUhrzustand()
            stand.ton.melodien = melodien
            stand.ton.mp3 = mp3
            let s = Uhrenserver(port: port, zustand: stand)
            do {
                try s.starten()
                server.append(s)
                return Uhr(name: name, host: "127.0.0.1:\(port)", praefix: "", betriebsart: .http)
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    /// `angesehen` ist aktiv, `ziele` die Sendeziele.
    private func zustand(_ uhren: [Uhr], angesehen: Uhr, ziele: [Uhr]) throws -> AppZustand {
        d.set(try JSONEncoder().encode(uhren), forKey: "uhren")
        d.set(angesehen.id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set(ziele.map(\.id))), forKey: "zielIDs")
        return AppZustand(schluesselbund: Schluesselbunddoppelgaenger())
    }

    func testKlangnamenKommenVonDenZielenNichtVonDerAngesehenen() async throws {
        let a = try uhr("angesehen")
        let b = try uhr("ziel", melodien: ["ping": "ping:d=4,o=5,b=120:c"], mp3: ["gong"])
        let z = try zustand([a, b], angesehen: a, ziele: [b])
        XCTAssertEqual(z.referenzUhr?.id, b.id, "die angesehene ist kein Ziel: die Vorschau zeigt das Ziel")
        await z.listenFuerZieleHolen(tonlisten: true)
        XCTAssertNil(z.tonlisten[a.id], "die gezeigte Uhr wird nicht gefragt")
        XCTAssertEqual(Klangeignung.melodien(in: z.klangziele()), ["ping"])
        XCTAssertEqual(Klangeignung.mp3(in: z.klangziele()), ["gong"])
        XCTAssertEqual(z.listenlage(tonlisten: true), Listenlage())
    }

    func testVereinigungUeberMehrereZiele() async throws {
        let a = try uhr("a", melodien: ["ping": "x:d=4,o=5,b=120:c"])
        let b = try uhr("b", melodien: ["ping": "x:d=4,o=5,b=120:c", "tick": "x:d=4,o=5,b=120:c"])
        let z = try zustand([a, b], angesehen: a, ziele: [a, b])
        await z.listenFuerZieleHolen(tonlisten: true)
        XCTAssertEqual(Klangeignung.melodien(in: z.klangziele()), ["ping", "tick"])
        let wahl = Klangwahl(art: .uhr, name: "tick")
        XCTAssertEqual(Klangeignung.ohne(wahl, in: z.klangziele()).map(\.name), ["a"])
    }

    func testBekannteListenWerdenNichtNeuGeholt() async throws {
        let b = try uhr("ziel", melodien: ["neu": "x:d=4,o=5,b=120:c"])
        let z = try zustand([b], angesehen: b, ziele: [b])
        z.tonlisten[b.id] = Tonlisten(melodien: ["alt"], mp3: [])
        await z.listenFuerZieleHolen(tonlisten: true)
        XCTAssertEqual(z.tonlisten[b.id]?.melodien, ["alt"])
    }

    func testLeereUhrWirdMitNamenGenannt() async throws {
        let b = try uhr("awtrix-gross")
        let z = try zustand([b], angesehen: b, ziele: [b])
        await z.listenFuerZieleHolen(tonlisten: true)
        XCTAssertEqual(z.listenlage(tonlisten: true).leer, ["awtrix-gross"])
    }

    func testUhrOhneAntwortUndOhneAdresseWerdenGenannt() async throws {
        let tot = Uhr(name: "TC002", host: "127.0.0.1:1", praefix: "", betriebsart: .http)
        let ohne = Uhr(name: "Flur", host: "", praefix: "awtrix_flur", betriebsart: .mqtt)
        let z = try zustand([tot, ohne], angesehen: tot, ziele: [tot, ohne])
        await z.listenFuerZieleHolen(tonlisten: true)
        let lage = z.listenlage(tonlisten: true)
        XCTAssertEqual(lage.ausgeblieben, ["TC002"])
        XCTAssertEqual(lage.ohneAdresse, ["Flur"])
        XCTAssertFalse(lage.laeuft)
        XCTAssertEqual(z.tonlistenAbruf[tot.id], .ausgeblieben)
    }

    func testFaehigkeitenDerZieleWerdenGeholtUndBestimmenDasDarstellungsangebot() async throws {
        let a = try uhr("angesehen")
        let b = try uhr("ziel")
        let z = try zustand([a, b], angesehen: a, ziele: [b])
        XCTAssertTrue(z.darstellungsangebot().effekte.isEmpty)
        XCTAssertTrue(z.listenlage(tonlisten: false).laeuft, "noch nichts gefragt: es steht aus")
        await z.listenFuerZieleHolen(tonlisten: false)
        XCTAssertNotNil(z.faehigkeiten[b.id])
        XCTAssertNil(z.faehigkeiten[a.id])
        XCTAssertFalse(z.darstellungsangebot().effekte.isEmpty)
        XCTAssertFalse(z.listenlage(tonlisten: false).laeuft)
    }

    func testVorschauZeigtNurDieZieleUndFolgtIhnen() throws {
        let u = (0..<3).map { Uhr(name: "U\($0)", host: "u\($0).invalid", praefix: "", betriebsart: .http) }
        let z = try zustand(u, angesehen: u[0], ziele: [u[1], u[2]])
        XCTAssertEqual(z.vorschauuhren().map(\.name), ["U1", "U2"])
        XCTAssertEqual(z.referenzUhr?.name, "U1", "die angesehene ist kein Ziel: die erste Zieluhr")
        z.uhrAnsehen(u[2].id)
        XCTAssertEqual(z.referenzUhr?.name, "U2")
        z.uhrWeiter(um: 1)
        XCTAssertEqual(z.referenzUhr?.name, "U1")
        z.zielUmschalten(u[1].id)
        XCTAssertEqual(z.vorschauuhren().map(\.name), ["U2"])
        XCTAssertEqual(z.referenzUhr?.name, "U2")
        z.zielUmschalten(u[1].id)
        z.uhrAnsehen(u[1].id)
        z.zielUmschalten(u[1].id)
        XCTAssertEqual(z.referenzUhr?.name, "U2", "fällt die angesehene aus dem Ziel, rückt die erste Zieluhr nach")
    }
}
