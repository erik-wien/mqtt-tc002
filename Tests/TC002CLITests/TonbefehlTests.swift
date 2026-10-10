import XCTest
import TC002Core
@testable import TC002CLI

/// Die Tonbefehle: Zerlegen, Trockenlauf und die Ausgabe von Text der Uhr.
final class TonbefehlTests: XCTestCase {
    private let melodie = "ping:d=4,o=5,b=120:c,e,g"

    private func befehl(_ a: String...) throws -> Optionen.Befehl { try Optionen.zerlegt(a).befehl }

    // MARK: - Zerlegen

    func testSpielenMitJederQuelle() throws {
        XCTAssertEqual(try befehl("ton", "spielen", "--datei", "ding"), .tonSpielen(Klang(.datei("ding"))))
        XCTAssertEqual(try befehl("ton", "spielen", "--rtttl", melodie), .tonSpielen(Klang(.rtttl(melodie))))
        XCTAssertEqual(try befehl("ton", "spielen", "--lied", "x"), .tonSpielen(Klang(.lied("x"))))
        XCTAssertEqual(try befehl("ton", "spielen", "--sprache", "Hallo"), .tonSpielen(Klang(.sprache("Hallo"))))
        XCTAssertEqual(try befehl("ton", "spielen", "--sender", "Radio Beispiel"),
                       .tonSpielen(Klang(.sender("Radio Beispiel"))))
        XCTAssertEqual(try befehl("ton", "spielen", "--sender", "0"), .tonSpielen(Klang(.senderPosition(0))))
        XCTAssertEqual(try befehl("ton", "spielen", "--sender", "http://example.com/s"),
                       .tonSpielen(Klang(.sender("http://example.com/s"))))
        XCTAssertEqual(try befehl("sound", "play", "--file", "ding", "--loop"),
                       .tonSpielen(Klang(.datei("ding"), wiederholen: true)))
        XCTAssertEqual(try befehl("ton", "spielen", "--datei", "ding", "--wiederholen"),
                       .tonSpielen(Klang(.datei("ding"), wiederholen: true)))
    }

    func testSpielenBrauchtGenauEineQuelleUndGueltigeWerte() {
        XCTAssertThrowsError(try befehl("ton", "spielen")) { XCTAssertEqual($0 as? KlangFehler, .keineQuelle) }
        XCTAssertThrowsError(try befehl("ton", "spielen", "--datei", "a", "--rtttl", melodie)) {
            XCTAssertEqual($0 as? KlangFehler, .mehrereQuellen)
        }
        XCTAssertThrowsError(try befehl("ton", "spielen", "--sender", "x", "--wiederholen")) {
            XCTAssertEqual($0 as? KlangFehler, .wiederholenMitSender)
        }
        XCTAssertThrowsError(try befehl("ton", "spielen", "--datei", "ding.mp3"))
        XCTAssertThrowsError(try befehl("ton", "spielen", "--datei", "a", "--loeschen"))
        XCTAssertThrowsError(try befehl("ton", "spielen", "ding"), "ein loses Wort")
    }

    func testStoppZustandMelodienSender() throws {
        XCTAssertEqual(try befehl("ton", "stopp"), .tonStopp(nil))
        XCTAssertEqual(try befehl("ton", "stopp", "alarm"), .tonStopp(.alarm))
        XCTAssertEqual(try befehl("ton", "stopp", "app"), .tonStopp(.app))
        XCTAssertEqual(try befehl("ton", "stopp", "radio"), .tonStopp(.radio))
        XCTAssertThrowsError(try befehl("ton", "stopp", "alles")) {
            XCTAssertEqual($0 as? KlangFehler, .ungueltigeGruppe("alles"))
        }
        XCTAssertThrowsError(try befehl("ton", "stopp", "app", "radio"))
        XCTAssertEqual(try befehl("ton", "zustand"), .tonZustand)
        XCTAssertEqual(try befehl("ton", "melodien"), .tonMelodien)
        XCTAssertEqual(try befehl("ton", "sender"), .tonSender)
        XCTAssertThrowsError(try befehl("ton", "zustand", "--datei", "a"))
        XCTAssertThrowsError(try befehl("ton"))
        XCTAssertThrowsError(try befehl("ton", "singen"))
    }

    func testMelodie() throws {
        XCTAssertEqual(try befehl("ton", "melodie", "ping", "--rtttl", melodie), .tonMelodie(name: "ping", rtttl: melodie))
        XCTAssertEqual(try befehl("ton", "melodie", "ping", "--loeschen"), .tonMelodieLoeschen(name: "ping"))
        XCTAssertThrowsError(try befehl("ton", "melodie"))
        XCTAssertThrowsError(try befehl("ton", "melodie", "ping"))
        XCTAssertThrowsError(try befehl("ton", "melodie", "ping", "--rtttl", "kaputt"))
        XCTAssertThrowsError(try befehl("ton", "melodie", "ping", "--datei", "a"))
        XCTAssertThrowsError(try befehl("ton", "melodie", "ping", "--rtttl", melodie, "--loeschen"))
        XCTAssertThrowsError(try befehl("ton", "melodie", String(repeating: "a", count: 25), "--rtttl", melodie)) {
            XCTAssertNotNil($0 as? KlangFehler)
        }
    }

    func testKlangAnNachricht() throws {
        let o = try Optionen.zerlegt(["nachricht", "Post", "--klang", "ding", "--wiederholen"])
        XCTAssertEqual(o.benachrichtigung.klang, [Klang(.datei("ding"), wiederholen: true)])
        XCTAssertEqual(try Optionen.zerlegt(["nachricht", "Post", "--rtttl", melodie]).benachrichtigung.klang,
                       [Klang(.rtttl(melodie))])
        XCTAssertEqual(try Optionen.zerlegt(["nachricht", "Post"]).benachrichtigung.klang, [])
        XCTAssertEqual(try Optionen.zerlegt(["nachricht", "Post", "--lied", "x"]).benachrichtigung.klang,
                       [Klang(.lied("x"))], "gemessen: song ist in sound erlaubt")
        XCTAssertThrowsError(try Optionen.zerlegt(["nachricht", "Post", "--sender", "x"])) {
            XCTAssertEqual($0 as? KlangFehler, .nichtInBenachrichtigung(feld: "station"))
        }
        XCTAssertThrowsError(try Optionen.zerlegt(["nachricht", "Post", "--wiederholen"]), "Loop ohne Klang")
        XCTAssertThrowsError(try Optionen.zerlegt(["nachricht", "Post", "--klang", "a", "--rtttl", melodie]))
        XCTAssertThrowsError(try Optionen.zerlegt(["senden", "Post", "--klang", "ding"]), "gilt nur für nachricht")
    }

    // MARK: - Trockenlauf

    /// Fängt, was `body` auf die Standardausgabe schreibt.
    private func ausgabe(_ body: () throws -> Void) rethrows -> String {
        let rohr = Pipe()
        let alt = dup(STDOUT_FILENO)
        fflush(stdout)
        dup2(rohr.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        defer { dup2(alt, STDOUT_FILENO); close(alt) }
        do { try body() } catch {
            fflush(stdout); dup2(alt, STDOUT_FILENO)
            throw error
        }
        fflush(stdout)
        dup2(alt, STDOUT_FILENO)
        try? rohr.fileHandleForWriting.close()
        return String(decoding: rohr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }

    private func trocken(_ args: [String]) throws -> String {
        let uhr = Uhr(name: "Test", host: "uhr.example.com", betriebsart: .http)
        let e = Einstellungen(brokerHost: "", brokerPort: 1883, benutzer: nil, kennwort: nil,
                              uhren: [uhr], zielIDs: [uhr.id])
        let o = try Optionen.zerlegt(args + ["--trocken"])
        return try ausgabe {
            XCTAssertTrue(try steuerbefehl(o, gewaehlte: [uhr], einstellungen: e, anAlle: { _, _ in
                XCTFail("Der Trockenlauf sendet nichts")
            }))
        }
    }

    func testTrockenlaufZeigtRouteUndJSON() throws {
        let a = try trocken(["ton", "spielen", "--datei", "ding", "--wiederholen"])
        XCTAssertTrue(a.contains("POST http://uhr.example.com/api/v1/audio/play"), a)
        XCTAssertTrue(a.contains(#"{"file":"ding","loop":true}"#), a)
        XCTAssertTrue(a.contains("--trocken"), a)
        XCTAssertTrue(try trocken(["ton", "stopp", "radio"]).contains(#"{"group":"radio"}"#))
        let m = try trocken(["ton", "melodie", "ping", "--rtttl", melodie])
        XCTAssertTrue(m.contains("PUT http://uhr.example.com/api/v1/audio/melodies/ping"), m)
        XCTAssertTrue(m.contains(#"{"rtttl":"\#(melodie)"}"#), m)
        XCTAssertTrue(try trocken(["ton", "melodie", "ping", "--loeschen"])
            .contains("DELETE http://uhr.example.com/api/v1/audio/melodies/ping"))
    }

    func testTrockenlaufNachrichtMitTon() throws {
        let uhr = Uhr(name: "Test", host: "uhr.example.com", betriebsart: .http)
        let o = try Optionen.zerlegt(["nachricht", "Post", "--klang", "ding", "--nicht-halten", "--nicht-wecken", "--trocken"])
        let json = try NGNutzlast.benachrichtigung(
            Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "Post", weg: .text))), o.benachrichtigung)
        XCTAssertTrue(json.contains(#""sound":"ding""#), json)
        _ = uhr
    }

    // MARK: - Text der Uhr im Terminal

    func testSteuerzeichenInTextenDerUhrKommenNichtDurch() {
        let boese = "A\u{1B}[2JB\u{07}\u{9B}C\u{202E}D\u{2066}E\n\tF"
        XCTAssertEqual(Terminaltext.sicher(boese), "A\u{FFFD}[2JB\u{FFFD}\u{FFFD}C\u{FFFD}D\u{FFFD}E\u{FFFD}\u{FFFD}F")
        XCTAssertEqual(Terminaltext.sicher("Grüße – 日本 ✓"), "Grüße – 日本 ✓")

        var z = Tonzustand()
        z.radio.spielt = true
        z.radio.sender = "S\u{1B}]0;x\u{07}"
        z.radio.titel = "\u{1B}[2J Titel"
        z.radio.fehler = "\u{1B}[31mrot"
        z.app.fehler = "\u{85}"
        z.alarm.name = "n\u{1B}c"
        z.alarm.spielt = true
        var zeilen: [String] = []
        tonzustandAusgeben(z, ausgabe: { zeilen.append($0) })
        melodienAusgeben(Tonablage(namen: ["m\u{1B}[H"]), ausgabe: { zeilen.append($0) })
        senderAusgeben([Radiosender(name: "N\u{1B}[0m", url: "http://example.com/\u{1B}")], ausgabe: { zeilen.append($0) })
        XCTAssertFalse(zeilen.isEmpty)
        for z in zeilen {
            XCTAssertFalse(z.unicodeScalars.contains { $0.value == 0x1B || $0.value == 0x07 || (0x80...0x9F).contains($0.value) },
                           "Steuerzeichen in: \(z)")
        }
        XCTAssertTrue(zeilen.contains("Titel\t\u{FFFD}[2J Titel") || zeilen.contains { $0.hasSuffix("\u{FFFD}[2J Titel") })
    }

    func testFehlerausgabeFiltertSteuerzeichenAberBehaeltZeilen() throws {
        let rohr = Pipe()
        let alt = dup(STDERR_FILENO)
        dup2(rohr.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
        fehlerAusgeben("eins\u{1B}[2J\nzwei")
        dup2(alt, STDERR_FILENO); close(alt)
        try rohr.fileHandleForWriting.close()
        let text = String(decoding: rohr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        XCTAssertEqual(text, "eins\u{FFFD}[2J\nzwei\n")
    }
}

extension TonbefehlTests {
    func testTonHilfe() throws {
        XCTAssertEqual(try Optionen.zerlegt(["ton", "--help"]).befehl, .hilfe)
        XCTAssertEqual(try Optionen.zerlegt(["ton", "hilfe"]).befehl, .hilfe)
    }
}

/// `ton mp3`: Zerlegen und die Ausgabe der Liste.
extension TonbefehlTests {
    func testMP3Befehle() throws {
        XCTAssertEqual(try Optionen.zerlegt(["ton", "mp3"]).befehl, .tonMP3Liste)
        XCTAssertEqual(try Optionen.zerlegt(["sound", "mp3"]).befehl, .tonMP3Liste)
        XCTAssertEqual(try Optionen.zerlegt(["ton", "mp3", "hochladen", "Grüße aus Wien.mp3"]).befehl,
                       .tonMP3Hochladen(datei: "Grüße aus Wien.mp3", name: nil, ersetzen: false))
        XCTAssertEqual(try Optionen.zerlegt(["sound", "mp3", "upload", "a.mp3", "--name", "klingel", "--replace"]).befehl,
                       .tonMP3Hochladen(datei: "a.mp3", name: "klingel", ersetzen: true))
        XCTAssertEqual(try Optionen.zerlegt(["ton", "mp3", "loeschen", "klingel"]).befehl, .tonMP3Loeschen(name: "klingel"))
        XCTAssertEqual(try Optionen.zerlegt(["sound", "mp3", "delete", "klingel.mp3"]).befehl, .tonMP3Loeschen(name: "klingel"))
    }

    func testMP3BefehleWeisenFalschesAb() {
        XCTAssertThrowsError(try Optionen.zerlegt(["ton", "mp3", "hochladen"]))
        XCTAssertThrowsError(try Optionen.zerlegt(["ton", "mp3", "hochladen", "a.mp3", "--name", "mit leer"])) {
            XCTAssertEqual($0 as? KlangFehler, .ungueltigerKlangname("mit leer"))
        }
        XCTAssertThrowsError(try Optionen.zerlegt(["ton", "mp3", "loeschen", "mit leer"]))
        XCTAssertThrowsError(try Optionen.zerlegt(["ton", "mp3", "loeschen"]))
        XCTAssertThrowsError(try Optionen.zerlegt(["ton", "mp3", "umbenennen", "a"]))
        XCTAssertThrowsError(try Optionen.zerlegt(["ton", "mp3", "--ersetzen"]), "--ersetzen gilt nur beim Hochladen")
        XCTAssertThrowsError(try Optionen.zerlegt(["ton", "mp3", "loeschen", "a", "--name", "b"]))
    }

    func testMP3ListeGibtSteuerzeichenNichtAus() {
        var zeilen: [String] = []
        mp3AusgebenListe(Tonablage(namen: ["x\u{1B}[2J", "y"], belegteBytes: 30, gesamteBytes: 100,
                                   groessen: ["x\u{1B}[2J": 10, "y": 20]), ausgabe: { zeilen.append($0) })
        XCTAssertEqual(zeilen.count, 4)
        XCTAssertEqual(zeilen[0], "x\u{FFFD}[2J\t10 Byte")
        XCTAssertEqual(zeilen[1], "y\t20 Byte")
        XCTAssertFalse(zeilen.contains { $0.unicodeScalars.contains { $0.value == 0x1B } })
    }

    // MARK: - Fähigkeiten der Uhr (virtuelle Uhr mit dem Tonsatz der TC001, nur 127.0.0.1)

    func testKlaengeWerdenGegenDieFaehigkeitenDerUhrGeprueft() throws {
        var z = NGUhrzustand()
        z.ton.faehigkeiten = NGTon.tc001
        z.ton.mp3 = ["ding"]
        z.ton.melodien = ["ping": melodie]
        var server: Uhrenserver?
        var port: UInt16 = 0
        for _ in 0..<20 {
            port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port, zustand: z)
            if (try? s.starten()) != nil { server = s; break }
        }
        let s = try XCTUnwrap(server)
        defer { s.beenden() }
        let uhr = Uhr(name: "Flur", host: "127.0.0.1:\(port)", praefix: "", betriebsart: .http)
        let anzeigen = try XCTUnwrap(Anzeigen.fuer(uhr, brokerzugang: nil))
        let caps = try XCTUnwrap(try Geraet(host: uhr.host).faehigkeiten())

        XCTAssertNoThrow(try klaengePruefen([Klang(.datei("ping"))], anzeigen: anzeigen, faehigkeiten: caps))
        XCTAssertThrowsError(try klaengePruefen([Klang(.datei("ding"))], anzeigen: anzeigen, faehigkeiten: caps)) {
            XCTAssertEqual($0 as? KlangFehler, .nichtGekonnt(faehigkeit: "audio.mp3"))
        }
        XCTAssertThrowsError(try klaengePruefen([Klang(.sprache("Hi"))], anzeigen: anzeigen, faehigkeiten: caps,
                                                inBenachrichtigung: true))
        XCTAssertNoThrow(try klaengePruefen([Klang(.datei("ding"))], anzeigen: anzeigen, faehigkeiten: nil),
                         "ohne Auskunft bleibt es ungeprüft")
    }
}
