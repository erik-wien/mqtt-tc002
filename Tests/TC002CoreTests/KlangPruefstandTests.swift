import XCTest
@testable import TC002Core

/// Klang über den echten HTTP-Weg (`Anzeigen`/`Geraet` → Port auf `127.0.0.1` →
/// `VirtuelleNGUhr`) und über MQTT gegen den Doppelgänger. Kein Byte verlässt den Rechner.
final class KlangPruefstandTests: XCTestCase {
    private var server: Uhrenserver?
    private let melodie = "ping:d=4,o=5,b=120:c,e,g"

    override func tearDown() {
        server?.beenden()
        server = nil
        super.tearDown()
    }

    private func gestartet() throws -> (Uhrenserver, Anzeigen, Geraet) {
        var z = NGUhrzustand()
        z.ton.mp3 = ["ding"]
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port, zustand: z)
            do {
                try s.starten()
                server = s
                let g = Geraet(host: "127.0.0.1:\(port)")
                return (s, Anzeigen(geraet: g), g)
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    private func abgewiesen(_ tat: () throws -> Void, status: Int, code: String, feld: String? = nil,
                            datei: StaticString = #filePath, zeile: UInt = #line) {
        XCTAssertThrowsError(try tat(), file: datei, line: zeile) {
            guard case GeraetFehler.ngAbgewiesen(let s, let c, let f)? = $0 as? GeraetFehler else {
                return XCTFail("keine Abweisung der Uhr: \($0)", file: datei, line: zeile)
            }
            XCTAssertEqual(s, status, file: datei, line: zeile)
            XCTAssertEqual(c, code, file: datei, line: zeile)
            XCTAssertEqual(f, feld, file: datei, line: zeile)
        }
    }

    // MARK: - HTTP

    func testSpielenUndAnhaltenUeberHTTP() throws {
        let (s, uhr, g) = try gestartet()
        try uhr.tonSpielen([Klang(.datei("ding"), wiederholen: true)])
        XCTAssertEqual(s.zustand.ton.gespielt, [.objekt(["file": .text("ding"), "loop": .bool(true)])])
        let z = try g.tonzustand()
        XCTAssertTrue(z.alarm.spielt)
        XCTAssertEqual(z.alarm.name, "ding")
        XCTAssertEqual(try uhr.tonzustandLesen(), z)

        try uhr.tonStoppen(.alarm)
        XCTAssertFalse(try g.tonzustand().alarm.spielt)
        try uhr.tonSpielen([Klang(.sprache("Hallo"))])
        try uhr.tonStoppen()
        XCTAssertEqual(s.zustand.ton.gestoppt, ["alert", "all"])
        XCTAssertFalse(try g.tonzustand().alarm.spielt)
    }

    func testListeSpieltDenErstenSpielbaren() throws {
        let (s, uhr, _) = try gestartet()
        try uhr.tonSpielen([Klang(.datei("gibtsnicht")), Klang(.rtttl(melodie))])
        XCTAssertEqual(s.zustand.ton.gespielt, [.objekt(["rtttl": .text(melodie)])])
    }

    func testDieUhrWeistAbMitStatusCodeUndFeld() throws {
        let (_, uhr, _) = try gestartet()
        abgewiesen({ try uhr.tonSpielen([Klang(.datei("gibtsnicht"))]) }, status: 404, code: "notFound")
        abgewiesen({ try uhr.tonSpielen([Klang(.sender("Unbekannt"))]) }, status: 404, code: "notFound")
    }

    func testOhneAusgangMeldet503() throws {
        var z = NGUhrzustand()
        z.ton.ohneAusgabe = true
        let port = UInt16.random(in: 20_000...60_000)
        let s = Uhrenserver(port: port, zustand: z)
        try s.starten()
        server = s
        let uhr = Anzeigen(geraet: Geraet(host: "127.0.0.1:\(port)"))
        abgewiesen({ try uhr.tonSpielen([Klang(.rtttl(self.melodie))]) }, status: 503, code: "unavailable")
    }

    func testStationAbspielenUndRadioStoppen() throws {
        let (_, uhr, g) = try gestartet()
        try uhr.tonSpielen([Klang(.senderPosition(0))])
        XCTAssertTrue(try g.tonzustand().radio.spielt)
        XCTAssertEqual(try g.tonzustand().radio.sender, "Fm4")
        try uhr.tonStoppen(.radio)
        XCTAssertFalse(try g.tonzustand().radio.spielt)
    }

    func testSenderlisteLesenUndErsetzen() throws {
        let (s, uhr, _) = try gestartet()
        XCTAssertEqual(try uhr.senderLesen().count, 1)
        let neu = [Radiosender(name: "Eins", url: "http://example.com/a"),
                   Radiosender(name: "Zwei", url: "https://example.com/b")]
        try uhr.senderSetzen(neu)
        XCTAssertEqual(s.zustand.ton.sender, neu)
        XCTAssertEqual(try uhr.senderLesen(), neu)
        XCTAssertEqual(try uhr.tonzustandLesen().sender, neu)
        try uhr.senderSetzen([])
        XCTAssertEqual(try uhr.senderLesen(), [])
    }

    func testMelodienAnlegenErsetzenLoeschenUndLesen() throws {
        let (s, uhr, g) = try gestartet()
        XCTAssertEqual(try uhr.melodienLesen().namen, [])
        XCTAssertTrue(try uhr.melodieSetzen(name: "ping", rtttl: melodie), "neu: 201")
        XCTAssertFalse(try uhr.melodieSetzen(name: "ping", rtttl: "x:d=4:c"), "ersetzt: 200")
        XCTAssertEqual(s.zustand.ton.melodien["ping"], "ping:d=4:c", "die Uhr schreibt den Namensteil um")
        let liste = try uhr.melodienLesen()
        XCTAssertEqual(liste.namen, ["ping"])
        XCTAssertEqual(liste.belegteBytes, 10)
        XCTAssertNotNil(liste.gesamteBytes)
        // Die Melodie ist unter ihrem Namen abspielbar.
        try uhr.tonSpielen([Klang(.datei("ping"))])
        try uhr.melodieLoeschen(name: "ping")
        XCTAssertEqual(try g.melodien().namen, [])
        abgewiesen({ try uhr.melodieLoeschen(name: "ping") }, status: 404, code: "notFound")
        // Der Name gehört zugleich einer MP3.
        abgewiesen({ try uhr.melodieSetzen(name: "ding", rtttl: self.melodie) }, status: 409, code: "nameTaken")
    }

    func testMP3Liste() throws {
        let (_, uhr, _) = try gestartet()
        XCTAssertEqual(try uhr.mp3Lesen().namen, ["ding"])
    }

    func testBenachrichtigungMitTonUeberHTTP() throws {
        let (s, uhr, _) = try gestartet()
        let rahmen = Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "Post", weg: .text)))
        var o = Benachrichtigungsoptionen(name: "post")
        o.klang = [Klang(.datei("ding"), wiederholen: true)]
        try uhr.benachrichtigen(rahmen, o)
        XCTAssertEqual(s.zustand.benachrichtigungen.first?.nutzlast["sound"],
                       .objekt(["file": .text("ding"), "loop": .bool(true)]))
    }

    func testFaehigkeitenKommenAusDerUhr() throws {
        let (_, _, g) = try gestartet()
        let f = try XCTUnwrap(try g.faehigkeiten())
        XCTAssertEqual(f.ton, Tonfaehigkeiten(mp3: true, rtttl: true, song: true, speech: true, radio: true,
                                              url: true, effect: true, clip: true, track: false))
    }

    // MARK: - MQTT

    private let zugang = MQTTZugang(host: "127.0.0.1", benutzer: nil, kennwort: nil)
    private let p = "wz/uhr"

    private func mqtt(_ uhr: MQTTUhrDoppelgaenger, ausweich: Geraet? = nil, quittierend: Bool = true) -> Anzeigen {
        let a = Anzeigen(sender: uhr, zugang: zugang, praefix: p, ausweich: ausweich)
        return quittierend ? a.quittierend(lauscher: ErgebnisAmDoppelgaenger(uhr: uhr), beiAusbleiben: { _ in }) : a
    }

    private func letzte(_ uhr: MQTTUhrDoppelgaenger) -> (thema: String, nutzlast: String)? {
        uhr.eingang.last.map { ($0.thema, String(decoding: $0.nutzlast, as: UTF8.self)) }
    }

    func testMQTTSpielenAufDemAudioThema() throws {
        var vorgabe = NGUhrzustand()
        vorgabe.ton.mp3 = ["ding"]
        let uhr = MQTTUhrDoppelgaenger(praefix: p, zustand: vorgabe)
        try mqtt(uhr).tonSpielen([Klang(.datei("ding"), wiederholen: true)])
        XCTAssertEqual(letzte(uhr)?.thema, "wz/uhr/cmd/audio/play")
        XCTAssertEqual(letzte(uhr)?.nutzlast, #"{"file":"ding","loop":true}"#)
        XCTAssertTrue(uhr.zustand.ton.alarm.spielt)
        try mqtt(uhr).tonSpielen([Klang(.datei("ding")), Klang(.sprache("Hi"))])
        XCTAssertEqual(letzte(uhr)?.nutzlast, #"[{"file":"ding"},{"speech":"Hi"}]"#)
    }

    func testMQTTStoppGruppeUndAllesMitLeererNutzlast() throws {
        let uhr = MQTTUhrDoppelgaenger(praefix: p)
        try mqtt(uhr).tonStoppen(.radio)
        XCTAssertEqual(letzte(uhr)?.thema, "wz/uhr/cmd/audio/stop")
        XCTAssertEqual(letzte(uhr)?.nutzlast, #"{"group":"radio"}"#)
        try mqtt(uhr).tonStoppen()
        XCTAssertEqual(letzte(uhr)?.nutzlast, "")
        XCTAssertEqual(uhr.zustand.ton.gestoppt, ["radio", "all"])
    }

    func testMQTTSenderliste() throws {
        let uhr = MQTTUhrDoppelgaenger(praefix: p)
        let neu = [Radiosender(name: "Eins", url: "http://example.com/a")]
        try mqtt(uhr).senderSetzen(neu)
        XCTAssertEqual(letzte(uhr)?.thema, "wz/uhr/cmd/audio/stations")
        XCTAssertEqual(letzte(uhr)?.nutzlast, #"{"stations":[{"name":"Eins","url":"http://example.com/a"}]}"#)
        XCTAssertEqual(uhr.zustand.ton.sender, neu)
    }

    func testMQTTAbweisungKommtAlsFehlerZurueck() throws {
        let uhr = MQTTUhrDoppelgaenger(praefix: p)
        XCTAssertThrowsError(try mqtt(uhr).tonSpielen([Klang(.datei("gibtsnicht"))])) {
            guard case NGFehler.abgewiesen(let grund)? = $0 as? NGFehler else { return XCTFail("\($0)") }
            XCTAssertTrue(grund.contains("notFound"), grund)
        }
    }

    func testMQTTBenachrichtigungMitTon() throws {
        let uhr = MQTTUhrDoppelgaenger(praefix: p)
        let rahmen = Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "Post", weg: .text)))
        var o = Benachrichtigungsoptionen(name: "post", halten: false, einreihen: true, aufwecken: false, wiederholungen: nil)
        o.klang = [Klang(.rtttl(melodie))]
        try mqtt(uhr).benachrichtigen(rahmen, o)
        XCTAssertEqual(letzte(uhr)?.thema, "wz/uhr/cmd/notify")
        XCTAssertTrue(letzte(uhr)?.nutzlast.contains(#""sound":{"rtttl":"ping:d=4,o=5,b=120:c,e,g"}"#) == true)
        XCTAssertEqual(uhr.zustand.benachrichtigungen.count, 1)
    }

    func testMQTTLesenGehtNurUeberHTTP() throws {
        let uhr = MQTTUhrDoppelgaenger(praefix: p)
        let k = mqtt(uhr)
        for tat in [{ _ = try k.tonzustandLesen() }, { _ = try k.melodienLesen() }, { _ = try k.mp3Lesen() },
                    { _ = try k.senderLesen() }, { _ = try k.melodieSetzen(name: "a", rtttl: self.melodie) },
                    { try k.melodieLoeschen(name: "a") }] as [() throws -> Void] {
            XCTAssertThrowsError(try tat()) { XCTAssertEqual($0 as? KlangFehler, .nurUeberHTTP) }
        }
    }

    func testMQTTLesenMitAdresseGehtUeberHTTP() throws {
        let (_, _, g) = try gestartet()
        let uhr = MQTTUhrDoppelgaenger(praefix: p)
        let k = mqtt(uhr, ausweich: g)
        XCTAssertEqual(try k.senderLesen().count, 1)
        XCTAssertTrue(try k.melodieSetzen(name: "ping", rtttl: melodie))
        XCTAssertEqual(try k.melodienLesen().namen, ["ping"])
    }

    func testMQTTLiedUeberAchtKiBGehtUeberHTTP() throws {
        let (s, _, g) = try gestartet()
        let uhr = MQTTUhrDoppelgaenger(praefix: p)
        let gross = String(repeating: "a", count: 9000)
        try mqtt(uhr, ausweich: g).tonSpielen([Klang(.lied(gross))])
        XCTAssertTrue(uhr.eingang.isEmpty, "nichts über MQTT: Die Uhr verwürfe es ohne Antwort")
        XCTAssertEqual(s.zustand.ton.gespielt.count, 1)
        XCTAssertThrowsError(try mqtt(uhr).tonSpielen([Klang(.lied(gross))])) {
            guard case NGFehler.keineAdresseFuerGrosse? = $0 as? NGFehler else { return XCTFail("\($0)") }
        }
    }

    func testFaehigkeitssperreGreiftVorDemSenden() throws {
        let uhr = MQTTUhrDoppelgaenger(praefix: p)
        XCTAssertThrowsError(try mqtt(uhr).tonSpielen([Klang(.lied("x"))],
                                                      faehigkeiten: Geraetefaehigkeiten(ton: Tonfaehigkeiten()))) {
            XCTAssertEqual($0 as? KlangFehler, .nichtGekonnt(faehigkeit: "audio.song"))
        }
        XCTAssertTrue(uhr.eingang.isEmpty)
    }
}
