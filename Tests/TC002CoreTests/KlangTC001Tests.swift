import XCTest
@testable import TC002Core

/// Die virtuelle Uhr mit dem Tonsatz der TC001 (`NGTon.tc001`), über den echten
/// HTTP-Weg auf `127.0.0.1`: Fähigkeiten lesen, Klang prüfen, MP3 nicht hochladen.
final class KlangTC001Tests: XCTestCase {
    private var server: Uhrenserver?

    override func tearDown() {
        server?.beenden()
        server = nil
        super.tearDown()
    }

    private func gestartet() throws -> (Uhrenserver, Anzeigen, Geraet) {
        var z = NGUhrzustand()
        z.ton.faehigkeiten = NGTon.tc001
        z.ton.mp3 = ["ding"]
        z.ton.melodien = ["ping": "ping:d=4,o=5,b=120:c,e,g"]
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

    func testDieUhrMeldetDenTonsatzDerTC001() throws {
        let (_, _, g) = try gestartet()
        let f = try XCTUnwrap(try g.faehigkeiten())
        XCTAssertEqual(f.ton, Tonfaehigkeiten(mp3: false, rtttl: true, song: false, speech: false, radio: false,
                                              url: false, effect: false, clip: false, track: false))
        XCTAssertFalse(f.kann(.mp3))
        XCTAssertTrue(f.kann(.melodie))
    }

    func testMelodienSpielenMP3Nicht() throws {
        let (s, uhr, g) = try gestartet()
        let f = try XCTUnwrap(try g.faehigkeiten())
        let listen = Tonlisten(melodien: ["ping"], mp3: ["ding"])
        try uhr.tonSpielen([Klang(.datei("ping"))], faehigkeiten: f)
        XCTAssertEqual(s.zustand.ton.gespielt, [.objekt(["file": .text("ping")])])
        // Die Uhr selbst weist die MP3 ab (`unavailable`); die App kommt ihr zuvor.
        XCTAssertThrowsError(try uhr.tonSpielen([Klang(.datei("ding"))]))
        XCTAssertThrowsError(try Klang(.datei("ding")).pruefen(faehigkeiten: f, listen: listen)) {
            XCTAssertEqual($0 as? KlangFehler, .nichtGekonnt(faehigkeit: "audio.mp3"))
        }
        XCTAssertEqual(s.zustand.ton.gespielt.count, 1)
    }

    func testMP3WirdNichtHochgeladen() throws {
        let (s, uhr, g) = try gestartet()
        let f = try XCTUnwrap(try g.faehigkeiten())
        let mp3 = Data("ID3".utf8) + Data(repeating: 1, count: 100)
        XCTAssertThrowsError(try uhr.mp3Hochladen(name: "neu", daten: mp3, faehigkeiten: f)) {
            XCTAssertEqual($0 as? KlangFehler, .mp3NichtSpielbar)
        }
        XCTAssertEqual(s.zustand.ton.mp3, ["ding"], "nichts hochgeladen")
        // Ohne Auskunft (unbekannt) geht es hinaus.
        try uhr.mp3Hochladen(name: "neu", daten: mp3)
        XCTAssertEqual(s.zustand.ton.mp3.sorted(), ["ding", "neu"])
    }

    func testStandardIstDieTC002() throws {
        var z = NGUhrzustand()
        XCTAssertNil(z.ton.faehigkeiten)
        XCTAssertTrue(z.ton.kann("mp3"))
        z.ton.faehigkeiten = NGTon.tc001
        XCTAssertFalse(z.ton.kann("mp3"))
    }
}
