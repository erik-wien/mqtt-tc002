import XCTest
@testable import TC002Core

/// MP3 hochladen, auflisten und löschen: die virtuelle Uhr als reine Funktion
/// (nach der Messung vom 10. Oktober 2026) und der ganze HTTP-Weg über
/// `Geraet` und einen Port auf `127.0.0.1`. Die Testdaten sind ein paar Byte mit
/// `ID3`-Kopf.
final class MP3HochladenTests: XCTestCase {
    private var server: Uhrenserver?

    override func tearDown() {
        server?.beenden()
        server = nil
        super.tearDown()
    }

    private let grenze = "XGRENZEX"
    private func mp3(_ n: Int = 10) -> Data { Data("ID3".utf8) + Data(repeating: 0x41, count: n - 3) }

    private func multipart(dateiname: String, inhalt: Data, feld: String = "file") -> Virtuelleuhr.Anfrage {
        var k = Data("--\(grenze)\r\nContent-Disposition: form-data; name=\"\(feld)\"; filename=\"\(dateiname)\"\r\nContent-Type: audio/mpeg\r\n\r\n".utf8)
        k.append(inhalt)
        k.append(Data("\r\n--\(grenze)--\r\n".utf8))
        return Virtuelleuhr.Anfrage("POST", "/api/v1/audio/mp3", koerper: k,
                                    kopf: ["content-type": "multipart/form-data; boundary=\(grenze)"])
    }

    private func antwort(_ a: Virtuelleuhr.Anfrage, _ z: inout NGUhrzustand) -> (Int, String, String) {
        let r = VirtuelleNGUhr.beantworten(a, &z)
        guard case .objekt(let o)? = JSONWert.lesen(r.koerper), case .objekt(let f)? = o["error"] else {
            return (r.status, "", "")
        }
        func text(_ w: JSONWert?) -> String { if case .text(let s)? = w { return s }; return "" }
        return (r.status, text(f["code"]), text(f["message"]))
    }

    // MARK: - Virtuelle Uhr

    func testGemesseneNamen() {
        var z = NGUhrzustand()
        for gut in ["abcdefghijklmnopqrstuvwxyz012345", "Gross_MIX-9", "star_trek"] {
            XCTAssertEqual(antwort(multipart(dateiname: gut + ".mp3", inhalt: mp3()), &z).0, 200, gut)
        }
        for schlecht in ["abcdefghijklmnopqrstuvwxyz0123456.mp3", "mit leer.mp3", "umläut.mp3",
                         "punkt.x.mp3", "ohne"] {
            let (s, c, m) = antwort(multipart(dateiname: schlecht, inhalt: mp3()), &z)
            XCTAssertEqual([String(s), c, m], ["400", "invalidName", "invalid file name"], schlecht)
        }
        XCTAssertEqual(z.ton.mp3.count, 3)
    }

    func testGleicherNameUeberschreibtStill() {
        var z = NGUhrzustand()
        XCTAssertEqual(antwort(multipart(dateiname: "x.mp3", inhalt: mp3(10)), &z).0, 200)
        XCTAssertEqual(antwort(multipart(dateiname: "x.mp3", inhalt: mp3(20)), &z).0, 200)
        XCTAssertEqual(z.ton.mp3, ["x"])
        XCTAssertEqual(z.ton.mp3Groessen["x"], 20)
    }

    func testMelodieGleichenNamensIst409() {
        var z = NGUhrzustand()
        z.ton.melodien["ping"] = "ping:d=4:c"
        let (s, c, m) = antwort(multipart(dateiname: "ping.mp3", inhalt: mp3()), &z)
        XCTAssertEqual([String(s), c, m], ["409", "nameTaken", "name taken"])
    }

    func testKeinMP3Inhalt() {
        var z = NGUhrzustand()
        let (s, c, m) = antwort(multipart(dateiname: "x.mp3", inhalt: Data("kein mp3".utf8)), &z)
        XCTAssertEqual([String(s), c, m], ["415", "unsupportedMediaType", "expected MP3"])
        XCTAssertEqual(antwort(multipart(dateiname: "a.mp3", inhalt: Data([0xFF, 0xFB, 0x90, 0x00])), &z).0, 200,
                       "MPEG-Frame-Sync")
        XCTAssertEqual(antwort(multipart(dateiname: "b.mp3", inhalt: Data([0xFF, 0x10, 0x00])), &z).0, 415)
    }

    func testRumpfOhneMultipartOderOhneTeilFile() {
        var z = NGUhrzustand()
        let roh = Virtuelleuhr.Anfrage("POST", "/api/v1/audio/mp3", koerper: mp3(), kopf: [:])
        XCTAssertEqual(antwort(roh, &z).0, 400)
        XCTAssertEqual(antwort(multipart(dateiname: "x.mp3", inhalt: mp3(), feld: "datei"), &z).0, 400)
    }

    func testListeNenntEndungUndGroesse() {
        var z = NGUhrzustand()
        _ = antwort(multipart(dateiname: "x.mp3", inhalt: mp3(12)), &z)
        let r = VirtuelleNGUhr.beantworten(Virtuelleuhr.Anfrage("GET", "/api/v1/audio/mp3"), &z)
        guard case .objekt(let o)? = JSONWert.lesen(r.koerper) else { return XCTFail() }
        XCTAssertEqual(o["files"], .liste([.objekt(["name": .text("x.mp3"), "size": .zahl(12)])]))
        XCTAssertEqual(o["scripts"], .liste([]))
        XCTAssertEqual(o["usedBytes"], .zahl(12))
    }

    func testLoeschen() {
        var z = NGUhrzustand()
        _ = antwort(multipart(dateiname: "x.mp3", inhalt: mp3()), &z)
        let weg = VirtuelleNGUhr.beantworten(Virtuelleuhr.Anfrage("DELETE", "/api/v1/audio/mp3/x"), &z)
        XCTAssertEqual(weg.status, 200)
        XCTAssertEqual(JSONWert.lesen(weg.koerper), .objekt(["ok": .bool(true)]))
        XCTAssertTrue(z.ton.mp3.isEmpty)
        XCTAssertEqual(VirtuelleNGUhr.beantworten(Virtuelleuhr.Anfrage("DELETE", "/api/v1/audio/mp3/x"), &z).status, 404)
    }

    func testZuWenigPlatz() {
        var z = NGUhrzustand()
        let r = antwort(multipart(dateiname: "gross.mp3", inhalt: mp3(VirtuelleNGUhr.gesamtSpeicher + 1)), &z)
        XCTAssertTrue(r.0 == 507 || r.0 == 413, "\(r.0)")
    }

    // MARK: - Der ganze Weg

    private func gestartet(melodie: Bool = false) throws -> (Anzeigen, Geraet) {
        var z = NGUhrzustand()
        if melodie { z.ton.melodien["ping"] = "ping:d=4:c" }
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port, zustand: z)
            do {
                try s.starten()
                server = s
                let g = Geraet(host: "127.0.0.1:\(port)")
                return (Anzeigen(geraet: g), g)
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    func testHochladenListenLoeschenUeberHTTP() throws {
        let (anzeigen, g) = try gestartet()
        try anzeigen.mp3Hochladen(name: "Gruesse-aus-Wien", daten: mp3(2000))
        let liste = try anzeigen.mp3Lesen()
        XCTAssertEqual(liste.namen, ["Gruesse-aus-Wien"], "ohne Endung, wie Abspielen sie braucht")
        XCTAssertEqual(liste.groessen["Gruesse-aus-Wien"], 2000)
        XCTAssertEqual(liste.belegteBytes, 2000)
        try g.mp3Hochladen(name: "Gruesse-aus-Wien", daten: mp3(30))
        XCTAssertEqual(try g.mp3Dateien().groessen["Gruesse-aus-Wien"], 30, "still ersetzt")
        try anzeigen.mp3Loeschen(name: "Gruesse-aus-Wien")
        XCTAssertEqual(try anzeigen.mp3Lesen().namen, [])
    }

    func testFehlerWerdenZuMeldungen() throws {
        let (_, g) = try gestartet(melodie: true)
        XCTAssertThrowsError(try g.mp3Hochladen(name: "ping", daten: mp3())) {
            XCTAssertEqual($0 as? KlangFehler, .mp3NameBelegt("ping"))
        }
        XCTAssertThrowsError(try g.mp3Hochladen(name: "x", daten: Data("text".utf8))) {
            XCTAssertEqual($0 as? KlangFehler, .keinMP3)
        }
        XCTAssertThrowsError(try g.mp3Hochladen(name: "mit leer", daten: mp3())) {
            XCTAssertEqual($0 as? KlangFehler, .ungueltigerKlangname("mit leer"))
        }
        XCTAssertThrowsError(try g.mp3Hochladen(name: "x", daten: Data())) {
            XCTAssertEqual($0 as? KlangFehler, .mp3Leer)
        }
        let zuGross = Data(repeating: 0, count: Geraet.mp3Hoechstgroesse + 1)
        XCTAssertThrowsError(try g.mp3Hochladen(name: "x", daten: zuGross)) {
            XCTAssertEqual($0 as? KlangFehler, .mp3ZuGross(bytes: zuGross.count, grenze: Geraet.mp3Hoechstgroesse))
        }
        XCTAssertThrowsError(try g.mp3Loeschen(name: "gibtsnicht")) {
            XCTAssertEqual($0 as? KlangFehler, .mp3Unbekannt("gibtsnicht"))
        }
    }

    func testOhneAdresseNurUeberHTTP() {
        let a = Anzeigen(sender: MQTTUhrDoppelgaenger(praefix: "p"),
                         zugang: MQTTZugang(host: "127.0.0.1", benutzer: nil, kennwort: nil), praefix: "p")
        XCTAssertThrowsError(try a.mp3Hochladen(name: "x", daten: mp3())) {
            XCTAssertEqual($0 as? KlangFehler, .nurUeberHTTP)
        }
    }
}
