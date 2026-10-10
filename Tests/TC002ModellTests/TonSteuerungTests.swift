import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

/// Ton in der Fernbedienung und die Klangwahl der Nachricht, gegen die virtuelle
/// Uhr auf `127.0.0.1`; nichts verlässt den Rechner.
@MainActor
final class TonSteuerungTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "bekannteAnzeigen", "zielIDs",
                              "brokerHost", "brokerPort", "benutzer", "protokollAn", "verlaufAn"]
    private var sicherung: [String: Any?] = [:]
    private var server: Uhrenserver?

    override func setUp() {
        super.setUp()
        sicherung = Dictionary(uniqueKeysWithValues: schluessel.map { ($0, d.object(forKey: $0)) })
    }

    override func tearDown() {
        server?.beenden()
        server = nil
        for schl in schluessel {
            if let wert = sicherung[schl] ?? nil { d.set(wert, forKey: schl) } else { d.removeObject(forKey: schl) }
        }
        super.tearDown()
    }

    private func httpUhr(_ ton: NGTon) throws -> (AppZustand, Uhr, Uhrenserver) {
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            var stand = NGUhrzustand()
            stand.ton = ton
            let s = Uhrenserver(port: port, zustand: stand)
            do {
                try s.starten()
                server = s
                let uhr = Uhr(name: "Küche", host: "127.0.0.1:\(port)", praefix: "", betriebsart: .http)
                d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
                d.set(uhr.id.uuidString, forKey: "aktiveID")
                d.set(try JSONEncoder().encode(Set([uhr.id])), forKey: "zielIDs")
                let z = AppZustand(schluesselbund: Schluesselbunddoppelgaenger())
                z.faehigkeiten[uhr.id] = Geraetefaehigkeiten(
                    ton: Tonfaehigkeiten(mp3: true, rtttl: true, speech: true, radio: true))
                return (z, uhr, s)
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    func testZustandHoltDenTonImSelbenTakt() async throws {
        var ton = NGTon()
        ton.radio.spielt = true
        ton.radio.name = "Fm4"
        let (z, uhr, _) = try httpUhr(ton)
        await z.zustandAbfragen(uhr.id)
        XCTAssertEqual(z.tonzustand[uhr.id]?.radio.spielt, true)
        XCTAssertEqual(z.tonzustand[uhr.id]?.radio.sender, "Fm4")
        XCTAssertEqual(z.tonzustand[uhr.id]?.sender.map(\.name), ["Fm4"])
    }

    func testOhneAudioFaehigkeitWirdDerTonNichtGefragt() async throws {
        let (z, uhr, _) = try httpUhr(NGTon())
        z.faehigkeiten[uhr.id] = Geraetefaehigkeiten()
        await z.zustandAbfragen(uhr.id)
        XCTAssertNil(z.tonzustand[uhr.id])
    }

    func testRadioSpielenUndAus() async throws {
        let (z, uhr, s) = try httpUhr(NGTon())
        let b = await z.radioSpielen(sender: "Fm4", fuer: uhr.id)
        XCTAssertTrue(b.ganz)
        XCTAssertEqual(s.zustand.ton.gespielt, [.objekt(["station": .text("Fm4")])])
        XCTAssertEqual(z.tonzustand[uhr.id]?.radio.spielt, true, "der Stand kommt von der Uhr")
        _ = await z.tonStoppen(.radio, fuer: uhr.id)
        XCTAssertEqual(s.zustand.ton.gestoppt, ["radio"])
        XCTAssertEqual(z.tonzustand[uhr.id]?.radio.spielt, false)
        _ = await z.tonStoppen(fuer: uhr.id)
        XCTAssertEqual(s.zustand.ton.gestoppt.last, "all")
    }

    func testLautstaerkeGehtUeberDieEinstellung() async throws {
        let (z, uhr, _) = try httpUhr(NGTon())
        await z.zustandAbfragen(uhr.id)
        let b = await z.einstellungSetzen("volume", wert: "35", fuer: uhr.id)
        XCTAssertTrue(b.ganz)
        XCTAssertEqual(z.uhreneinstellungen[uhr.id]?.ganzzahl(.volume), 35)
    }

    func testTonlistenKommenVonDerUhr() async throws {
        var ton = NGTon()
        ton.melodien = ["ping": "ping:d=4,o=5,b=120:c,e,g"]
        ton.mp3 = ["gong"]
        let (z, uhr, _) = try httpUhr(ton)
        XCTAssertNil(z.tonlisten[uhr.id])
        let ok = await z.tonlistenAbfragen(uhr.id)
        XCTAssertTrue(ok)
        XCTAssertEqual(z.tonlisten[uhr.id], Tonlisten(melodien: ["ping"], mp3: ["gong"]))
    }

    private func mp3Datei(_ name: String, _ inhalt: Data) throws -> URL {
        let ordner = FileManager.default.temporaryDirectory.appendingPathComponent("mp3test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        let url = ordner.appendingPathComponent(name)
        try inhalt.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: ordner) }
        return url
    }

    func testMP3HochladenHoltDieListenNeu() async throws {
        let (z, uhr, s) = try httpUhr(NGTon())
        let datei = try mp3Datei("Grüße aus Wien.mp3", Data("ID3".utf8) + Data(repeating: 1, count: 997))
        let ok = await z.mp3Hochladen(datei: datei, name: Klangname.vorschlag(ausDateiname: datei.lastPathComponent),
                                      fuer: uhr.id)
        XCTAssertTrue(ok, "\(z.fehler ?? "")")
        XCTAssertEqual(s.zustand.ton.mp3, ["Gruesse-aus-Wien"])
        XCTAssertEqual(z.tonlisten[uhr.id]?.mp3, ["Gruesse-aus-Wien"], "Klang › Von der Uhr kennt den Namen")
        XCTAssertEqual(z.mp3Ablage[uhr.id]?.groessen["Gruesse-aus-Wien"], 1000)
        XCTAssertEqual(z.mp3Ablage[uhr.id]?.belegteBytes, 1000)
        let weg = await z.mp3Loeschen(name: "Gruesse-aus-Wien", fuer: uhr.id)
        XCTAssertTrue(weg)
        XCTAssertEqual(z.tonlisten[uhr.id]?.mp3, [])
    }

    func testMP3HochladenMeldetFehlerStattSieZuVerschlucken() async throws {
        let (z, uhr, _) = try httpUhr(NGTon())
        let kein = try mp3Datei("text.mp3", Data("kein mp3".utf8))
        let a = await z.mp3Hochladen(datei: kein, name: "text", fuer: uhr.id)
        XCTAssertFalse(a)
        XCTAssertTrue(z.fehler?.contains("MP3") == true, z.fehler ?? "nil")
        z.fehler = nil
        let fehlt = FileManager.default.temporaryDirectory.appendingPathComponent("gibt-es-nicht.mp3")
        let b = await z.mp3Hochladen(datei: fehlt, name: "x", fuer: uhr.id)
        XCTAssertFalse(b)
        XCTAssertNotNil(z.fehler)
    }

    func testMP3HochladenOhneAdresse() async throws {
        let (z, uhr, _) = try httpUhr(NGTon())
        z.uhren[0].host = ""
        let datei = try mp3Datei("x.mp3", Data("ID3abc".utf8))
        let ok = await z.mp3Hochladen(datei: datei, name: "x", fuer: uhr.id)
        XCTAssertFalse(ok)
        XCTAssertNotNil(z.fehler)
    }

    func testNachrichtMitKlangGehtHinaus() async throws {
        let (z, _, _) = try httpUhr(NGTon())
        let wahl = Nachrichtwahl(klang: Klangwahl(art: .vorlesen))
        let b = await z.benachrichtigen(rahmenFuer: { _ in Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "Hallo", weg: .text))) },
                                        wahl.optionen(nachrichtentext: "Hallo"))
        XCTAssertTrue(b.ganz, "\(z.fehler ?? "")")
    }
}
