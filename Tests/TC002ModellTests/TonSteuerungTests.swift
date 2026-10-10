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

    func testOhneTonFaehigkeitWirdDerTonNichtGefragt() async throws {
        let (z, uhr, _) = try httpUhr(NGTon())
        z.faehigkeiten[uhr.id] = Geraetefaehigkeiten(ton: Tonfaehigkeiten())
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

    func testKlangsammlungVonUhrUebernehmenUndAbgleichen() async throws {
        var ton = NGTon()
        ton.melodien["ping"] = "ping:d=4,o=5,b=100:c"
        let (z, uhr, s) = try httpUhr(ton)
        let ordner = FileManager.default.temporaryDirectory.appendingPathComponent("klangtest-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: ordner) }
        z.klangordnerAnders = ordner
        let bilanz = await z.melodienVonUhrUebernehmen(uhr.id)
        XCTAssertEqual(bilanz?.neu, ["ping"])
        XCTAssertEqual(z.klaenge().map(\.name), ["ping"])
        XCTAssertTrue(z.melodieSammeln(name: "pong", rtttl: "x:d=8:e"))
        XCTAssertFalse(z.melodieSammeln(name: "schlecht", rtttl: "kaputt"))
        XCTAssertNotNil(z.fehler)
        let datei = try mp3Datei("lied.mp3", Data("ID3".utf8) + Data(repeating: 1, count: 97))
        let dateiOK = await z.dateiSammeln(datei, name: "lied")
        XCTAssertTrue(dateiOK)
        let e = await z.klaengeAbgleichen(mit: [uhr.id])
        XCTAssertEqual(e.first?.hinzugefuegt.sorted(), ["lied", "pong"])
        XCTAssertEqual(e.first?.unveraendert, ["ping"])
        XCTAssertEqual(s.zustand.ton.mp3, ["lied"])
        XCTAssertEqual(z.tonlisten[uhr.id]?.melodien.sorted(), ["ping", "pong"])
        let probe = await z.rtttlProbehoeren("x:d=4:c", fuer: uhr.id)
        XCTAssertEqual(probe.erreicht.count, 1)
        XCTAssertEqual(s.zustand.ton.gespielt.count, 1)
    }

    func testZustandHoltFehlendeFaehigkeitenMit() async throws {
        var ton = NGTon()
        ton.faehigkeiten = NGTon.tc001
        let (z, uhr, _) = try httpUhr(ton)
        z.faehigkeiten[uhr.id] = nil
        await z.zustandAbfragen(uhr.id)
        XCTAssertEqual(z.faehigkeiten[uhr.id]?.kann(.mp3), false, "die Fernbedienung weiß sofort, dass die TC001 keine MP3 spielt")
        XCTAssertEqual(z.faehigkeiten[uhr.id]?.kann(.radio), false)
        XCTAssertFalse(Klangeignung.mp3Hochladbar(z.faehigkeiten[uhr.id]))
    }

    func testMelodieLoeschenHoltDieListenNeu() async throws {
        var ton = NGTon()
        ton.faehigkeiten = NGTon.tc001
        ton.melodien = ["ping": "ping:d=4,o=5,b=120:c,e,g", "pong": "pong:d=8,o=5,b=100:c"]
        let (z, uhr, s) = try httpUhr(ton)
        await z.tonlistenAbfragen(uhr.id)
        XCTAssertEqual(z.melodienAblage[uhr.id]?.namen.sorted(), ["ping", "pong"])
        let ok = await z.melodieLoeschen(name: "ping", fuer: uhr.id)
        XCTAssertTrue(ok, "\(z.fehler ?? "")")
        XCTAssertEqual(Array(s.zustand.ton.melodien.keys), ["pong"])
        XCTAssertEqual(z.melodienAblage[uhr.id]?.namen, ["pong"])
        XCTAssertEqual(z.tonlisten[uhr.id]?.melodien, ["pong"])
        let nochmal = await z.melodieLoeschen(name: "ping", fuer: uhr.id)
        XCTAssertFalse(nochmal)
        XCTAssertNotNil(z.fehler)
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

/// Gemischte Ziele: Die Nachricht geht an beide Uhren, der Klang nur an die, die ihn spielt.
@MainActor
final class KlangGemischteZieleTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "bekannteAnzeigen", "zielIDs",
                              "brokerHost", "brokerPort", "benutzer", "protokollAn", "verlaufAn"]
    private var sicherung: [String: Any?] = [:]
    private var server: [Uhrenserver] = []

    override func setUp() {
        super.setUp()
        sicherung = Dictionary(uniqueKeysWithValues: schluessel.map { ($0, d.object(forKey: $0)) })
    }

    override func tearDown() {
        server.forEach { $0.beenden() }
        server = []
        for schl in schluessel {
            if let wert = sicherung[schl] ?? nil { d.set(wert, forKey: schl) } else { d.removeObject(forKey: schl) }
        }
        super.tearDown()
    }

    private func start(_ name: String, tc001: Bool) throws -> (Uhr, Uhrenserver) {
        var stand = NGUhrzustand()
        if tc001 { stand.ton.faehigkeiten = NGTon.tc001 }
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port, zustand: stand)
            do {
                try s.starten()
                server.append(s)
                return (Uhr(name: name, host: "127.0.0.1:\(port)", praefix: "", betriebsart: .http), s)
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    func testKlangNurAnDieUhrDieIhnSpielt() async throws {
        let (alt, serverAlt) = try start("Flur", tc001: true)
        let (neu, serverNeu) = try start("Küche", tc001: false)
        d.set(try JSONEncoder().encode([alt, neu]), forKey: "uhren")
        d.set(neu.id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set([alt.id, neu.id])), forKey: "zielIDs")
        let z = AppZustand(schluesselbund: Schluesselbunddoppelgaenger())
        // Die Fähigkeiten kommen von den Uhren, nicht aus dem Test.
        z.faehigkeiten[alt.id] = try XCTUnwrap(try Geraet(host: alt.host).faehigkeiten())
        z.faehigkeiten[neu.id] = try XCTUnwrap(try Geraet(host: neu.host).faehigkeiten())
        XCTAssertEqual(z.faehigkeiten[alt.id]?.ton?.mp3, false)
        XCTAssertEqual(z.faehigkeiten[neu.id]?.ton?.mp3, true)

        let wahl = Nachrichtwahl(klang: Klangwahl(art: .vorlesen))
        let b = await z.benachrichtigen(
            rahmenFuer: { _ in Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "Hallo", weg: .text))) },
            wahl.optionen(nachrichtentext: "Hallo"))
        XCTAssertTrue(b.ganz, "\(z.fehler ?? "")")
        XCTAssertEqual(Set(b.erreicht), ["Flur", "Küche"], "die Nachricht geht an beide")
        XCTAssertNil(serverAlt.zustand.benachrichtigungen.first?.nutzlast["sound"], "kein Klang an die TC001")
        XCTAssertNotNil(serverNeu.zustand.benachrichtigungen.first?.nutzlast["sound"])
        XCTAssertEqual(z.teilfehler?.contains("Flur"), true, "der Hinweis steht neben dem Sendezeichen")
        XCTAssertEqual(z.teilfehler?.contains("Küche"), false)
    }

    func testMP3HochladenZurTC001WirdAbgelehnt() async throws {
        let (alt, s) = try start("Flur", tc001: true)
        d.set(try JSONEncoder().encode([alt]), forKey: "uhren")
        d.set(alt.id.uuidString, forKey: "aktiveID")
        d.set(try JSONEncoder().encode(Set([alt.id])), forKey: "zielIDs")
        let z = AppZustand(schluesselbund: Schluesselbunddoppelgaenger())
        z.faehigkeiten[alt.id] = try XCTUnwrap(try Geraet(host: alt.host).faehigkeiten())
        let datei = FileManager.default.temporaryDirectory.appendingPathComponent("mp3-\(UUID().uuidString).mp3")
        try (Data("ID3".utf8) + Data(repeating: 1, count: 100)).write(to: datei)
        defer { try? FileManager.default.removeItem(at: datei) }
        let ok = await z.mp3Hochladen(datei: datei, name: "x", fuer: alt.id)
        XCTAssertFalse(ok)
        XCTAssertNotNil(z.fehler)
        XCTAssertEqual(s.zustand.ton.mp3, [], "nichts liegt auf der Uhr")
    }
}
