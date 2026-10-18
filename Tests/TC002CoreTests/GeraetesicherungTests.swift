import XCTest
@testable import TC002Core

/// Sicherung und Rückspielen über die virtuelle Uhr auf `127.0.0.1`: sammeln, zippen,
/// zurückspielen. Die Formate folgen `backup.js` der Weboberfläche; was die virtuelle
/// Uhr dazu annimmt, steht in ihrem Doc-Comment.
final class GeraetesicherungTests: XCTestCase {
    private var server: [Uhrenserver] = []

    override func tearDown() {
        server.forEach { $0.beenden() }
        server = []
        super.tearDown()
    }

    private func gestartet(_ z: NGUhrzustand) throws -> (Uhrenserver, Geraet) {
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port, zustand: z)
            do {
                try s.starten()
                server.append(s)
                return (s, Geraet(host: "127.0.0.1:\(port)"))
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    private let gif = Data("GIF89a".utf8) + Data([1, 2, 3, 0, 255])
    private let mp3 = Data("ID3".utf8) + Data(repeating: 0x41, count: 12)

    private func vollerZustand() -> NGUhrzustand {
        var z = NGUhrzustand()
        z.mqttPrefix = "demo"
        z.ablage.system = ["wifiSsid": .text("netz-demo"), "wifiPass": .text("geheim-1"),
                           "mqttPass": .text("geheim-2"), "hostname": .text("uhr-demo")]
        z.einstellungen["brightness"] = .zahl(77)
        z.ablage.dateien["/ICONS/a b.gif"] = gif
        z.ablage.dateien["/PALETTES/warm.bin"] = Data([9, 8, 7])
        z.ablage.dateien["/SCRIPTS/hallo.be"] = Data("print('hi')".utf8)
        z.ablage.dateien["/SCRIPTS/hallo/ton.mp3"] = mp3
        z.ablage.dateien["/MP3/gong.mp3"] = mp3
        z.ton.mp3 = ["gong"]
        z.ton.mp3Groessen["gong"] = mp3.count
        z.ton.melodien["ping"] = "ping:d=4,o=5,b=100:c,e"
        z.ablage.iconHerkunft = Data(#"{"icons":[{"name":"a b.gif","hub":"h","slug":"s","sha256":"x"}]}"#.utf8)
        z.ablage.anzeigenfolge = Data(#"{"order":["Time"]}"#.utf8)
        return z
    }

    func testSammelnLiefertDieEintraegeDerWeboberflaeche() throws {
        let (_, g) = try gestartet(vollerZustand())
        let zip = try g.sicherungErstellen(zeit: Date(timeIntervalSince1970: 0))
        let e = try Sicherungszip.lesen(zip)
        XCTAssertEqual(e.map(\.pfad), [
            "manifest.json", "apploop.json", "config/wifi.json", "config/system.json", "config/settings.json",
            "ICONS/a b.gif", "config/icon-origins.json", "MELODIES/ping.txt", "PALETTES/warm.bin",
            "MP3/gong.mp3", "SCRIPTS/hallo.be", "SCRIPTS/hallo/ton.mp3",
        ])
        let vorschau = try Sicherungszip.pruefen(e)
        XCTAssertEqual(vorschau.kategorien, ["wifi", "settings", "icons", "melodies", "palettes", "mp3", "scripts", "apporder"])
        func json(_ pfad: String) throws -> [String: Any] {
            try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(e.first { $0.pfad == pfad }).daten) as? [String: Any])
        }
        let manifest = try json("manifest.json")
        XCTAssertEqual((manifest["device"] as? [String: Any])?["hostname"] as? String, "uhr-demo")
        let wifi = try json("config/wifi.json")
        XCTAssertEqual(wifi["wifiSsid"] as? String, "netz-demo")
        XCTAssertEqual(wifi["wifiPass"] as? String, "geheim-1")
        let system = try json("config/system.json")
        XCTAssertNil(system["wifiSsid"])
        XCTAssertNil(system["wifiPass"])
        XCTAssertEqual(system["mqttPass"] as? String, "geheim-2")
        XCTAssertEqual(try json("config/settings.json")["brightness"] as? Int, 77)
        XCTAssertEqual(e.first { $0.pfad == "ICONS/a b.gif" }?.daten, gif)
        XCTAssertEqual(e.first { $0.pfad == "MELODIES/ping.txt" }.map { String(decoding: $0.daten, as: UTF8.self) },
                       "ping:d=4,o=5,b=100:c,e")
    }

    func testGanzerWegSammelnZippenZurueckspielen() throws {
        let (_, quelle) = try gestartet(vollerZustand())
        let zip = try quelle.sicherungErstellen()

        let (ziel, g) = try gestartet(NGUhrzustand())
        let r = try g.sicherungZurueckspielen(zip, dateiname: "uhr.zip")
        XCTAssertEqual(r.warnungen, [])
        XCTAssertEqual(r.uebersprungen, 0)
        XCTAssertTrue(r.neustartNoetig)
        XCTAssertEqual(r.angewendet["icons"], 1)
        XCTAssertEqual(r.angewendet["iconOrigins"], 1)
        XCTAssertEqual(r.angewendet["melodies"], 1)
        XCTAssertEqual(r.angewendet["palettes"], 1)
        XCTAssertEqual(r.angewendet["mp3"], 2)
        XCTAssertEqual(r.angewendet["scripts"], 1)
        XCTAssertEqual(r.angewendet["appLoop"], 1)
        XCTAssertEqual(r.angewendet["settings"], 1)
        XCTAssertFalse(r.zeilen.isEmpty)

        let z = ziel.zustand
        XCTAssertEqual(z.ablage.dateien, vollerZustand().ablage.dateien)
        XCTAssertEqual(z.ablage.system["wifiPass"], .text("geheim-1"))
        XCTAssertEqual(z.ablage.system["wifiSsid"], .text("netz-demo"))
        XCTAssertEqual(z.mqttPrefix, "demo")
        XCTAssertEqual(z.einstellungen["brightness"], .zahl(77))
        XCTAssertEqual(z.ton.melodien["ping"], "ping:d=4,o=5,b=100:c,e")
        XCTAssertEqual(z.ton.mp3, ["gong"])
        XCTAssertEqual(z.ablage.iconHerkunft, vollerZustand().ablage.iconHerkunft)
        XCTAssertEqual(z.ablage.anzeigenfolge, vollerZustand().ablage.anzeigenfolge)
    }

    func testUhrOhneApploopUndHerkunftLaesstSieAus() throws {
        var z = NGUhrzustand()
        z.ablage.dateien["/ICONS/x.gif"] = gif
        let (_, g) = try gestartet(z)
        let e = try Sicherungszip.lesen(try g.sicherungErstellen())
        XCTAssertFalse(e.contains { $0.pfad == "apploop.json" || $0.pfad == "config/icon-origins.json" })
        XCTAssertEqual(e.first?.pfad, "manifest.json")
    }

    func testUnpassendeEintraegeWerdenMitWarnungUebersprungen() throws {
        let zip = Sicherungszip.schreiben([
            Sicherungszip.manifest(erstellt: Date()),
            .init(pfad: "ICONS/kaputt.gif", daten: Data("kein bild".utf8)),
            .init(pfad: "ICONS/gut.gif", daten: gif),
            .init(pfad: "ICONS/../boese.gif", daten: gif),
            .init(pfad: "sonstwas.bin", daten: Data([1])),
        ])
        let (ziel, g) = try gestartet(NGUhrzustand())
        let r = try g.sicherungZurueckspielen(zip)
        XCTAssertEqual(r.angewendet["icons"], 1)
        XCTAssertEqual(r.uebersprungen, 3)
        XCTAssertEqual(r.warnungen.count, 3)
        XCTAssertFalse(r.neustartNoetig)
        XCTAssertEqual(Array(ziel.zustand.ablage.dateien.keys), ["/ICONS/gut.gif"])
    }

    func testFremdesZipWirdVonDerUhrAbgewiesen() throws {
        let (_, g) = try gestartet(NGUhrzustand())
        let ohneManifest = Sicherungszip.schreiben([.init(pfad: "a.txt", daten: Data("x".utf8))])
        XCTAssertThrowsError(try g.sicherungZurueckspielen(ohneManifest)) {
            guard case GeraetFehler.sicherungAbgewiesen(let grund) = $0 else { return XCTFail("\($0)") }
            XCTAssertEqual(grund, "not an awtrix backup")
        }
        let fremd = Sicherungszip.schreiben([.init(pfad: "manifest.json", daten: Data(#"{"app":"x","backupFormat":1}"#.utf8))])
        XCTAssertThrowsError(try g.sicherungZurueckspielen(fremd)) {
            guard case GeraetFehler.sicherungAbgewiesen = $0 else { return XCTFail("\($0)") }
        }
        XCTAssertThrowsError(try g.sicherungZurueckspielen(Data("kein zip".utf8))) {
            guard case GeraetFehler.sicherungAbgewiesen(let grund) = $0 else { return XCTFail("\($0)") }
            XCTAssertEqual(grund, "not a zip")
        }
    }

    func testAntwortDerUhrWirdGelesen() throws {
        let rumpf = Data(#"{"ok":true,"applied":{"wifi":1,"icons":2,"skipped":1},"warnings":["skipped unknown entry 'x'"]}"#.utf8)
        let r = try XCTUnwrap(Sicherungsergebnis(antwort: rumpf))
        XCTAssertEqual(r.angewendet["icons"], 2)
        XCTAssertEqual(r.warnungen, ["skipped unknown entry 'x'"])
        XCTAssertTrue(r.neustartNoetig)
        XCTAssertNil(Sicherungsergebnis(antwort: Data(#"{"ok":false,"error":"x"}"#.utf8)))
    }

    func testGeheimnisseNurMitSecrets() {
        var z = vollerZustand()
        let ohne = VirtuelleNGUhr.beantworten(.init("GET", "/api/v1/system"), &z)
        let mit = VirtuelleNGUhr.beantworten(.init("GET", "/api/v1/system", abfrage: ["secrets": "1"]), &z)
        XCTAssertFalse(String(decoding: ohne.koerper, as: UTF8.self).contains("geheim"))
        XCTAssertTrue(String(decoding: mit.koerper, as: UTF8.self).contains("geheim-1"))
    }
}
