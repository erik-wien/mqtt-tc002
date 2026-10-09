import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import TC002Core

private final class PixelwegMitschreiber: NachrichtSendend {
    var gesendet: [(thema: String, nutzlast: Data)] = []
    func senden(_ nutzlast: Data, an thema: String, zugang: MQTTZugang) throws {
        gesendet.append((thema, nutzlast))
    }
}

/// Der Pixelweg: was die App rastert, kommt pixelgenau auf die Uhr
/// (`docs/awtrix-ng-protokoll.md` §1.1, §6, §8, §9).
final class PixelwegTests: XCTestCase {
    private let leer = [String?](repeating: nil, count: 52 * 16)

    private func bild(_ aenderungen: [Int: String] = [:], dauer: Double = 1) -> Bildraster.Einzelbild {
        var p = leer
        for (i, f) in aenderungen { p[i] = f }
        return Bildraster.Einzelbild(pixel: p, dauer: dauer)
    }

    private func inhalt(_ bilder: [Bildraster.Einzelbild]) -> Pixelinhalt {
        Pixelinhalt(breite: 52, hoehe: 16, bilder: bilder)
    }

    // MARK: - Standbild

    private func gifDaten(_ json: String) throws -> Data {
        let objekt = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        XCTAssertNil(objekt["layout"], "kein Layout: der ESP32 kennt keines")
        XCTAssertNil(objekt["draw"], "kein draw: auf der TC002 2 x 2 vergroessert")
        let uri = try XCTUnwrap(objekt["icon"] as? String)
        XCTAssertTrue(uri.hasPrefix("data:image/gif;base64,"))
        return try XCTUnwrap(Data(base64Encoded: String(uri.dropFirst("data:image/gif;base64,".count))))
    }

    /// Ein Standbild ist ein GIF mit einem Bild in voller Anzeigegroesse, mit
    /// langer Bildzeit.
    func testStandbildIstEinBildGifInVollerGroesse() throws {
        let json = try Pixelweg.nutzlast(inhalt([bild([0: "#FF0000", 52 * 16 - 1: "#0000FF"])]), dauer: nil)
        let daten = try gifDaten(json)
        let quelle = try XCTUnwrap(CGImageSourceCreateWithData(daten as CFData, nil))
        XCTAssertEqual(CGImageSourceGetCount(quelle), 1)
        let e = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(quelle, 0, nil) as? [CFString: Any])
        XCTAssertEqual(e[kCGImagePropertyPixelWidth] as? Int, 52)
        XCTAssertEqual(e[kCGImagePropertyPixelHeight] as? Int, 16)
        let g = e[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        XCTAssertEqual(g?[kCGImagePropertyGIFUnclampedDelayTime] as? Double, Pixelweg.standbildzeit)
        let punkte = try Bildraster.lesenMitZeiten(daten, breite: 52, hoehe: 16)
        XCTAssertEqual(punkte[0].pixel[0], "#FF0000")
        XCTAssertEqual(punkte[0].pixel[52 * 16 - 1], "#0000FF")
        XCTAssertEqual(punkte[0].pixel[1], "#000000")
        XCTAssertFalse(json.contains("durationMs"), "ohne Nutzerdauer gilt die der Uhr")
    }

    /// Die TC001 (32 x 8): dasselbe, im Mass ihrer Anzeige.
    func testStandbildAufEinerTC001HatDasMassDerAnzeige() throws {
        var p = [String?](repeating: nil, count: 32 * 8)
        p[0] = "#FF0000"; p[32 * 8 - 1] = "#00FF00"
        let json = try Pixelweg.nutzlast(
            Pixelinhalt(breite: 32, hoehe: 8, bilder: [Bildraster.Einzelbild(pixel: p, dauer: 1)]), dauer: nil)
        let punkte = try Bildraster.lesenMitZeiten(try gifDaten(json), breite: 32, hoehe: 8)
        XCTAssertEqual(punkte[0].pixel[0], "#FF0000")
        XCTAssertEqual(punkte[0].pixel[32 * 8 - 1], "#00FF00")
    }

    func testStandbildMitDauerSteuertDurationMs() throws {
        let json = try Pixelweg.nutzlast(inhalt([bild()]), dauer: 12)
        let o = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        XCTAssertEqual(o["durationMs"] as? Int, 12000)
    }

    /// Das Mass: ein Standbild ist klein genug fuer eine MQTT-Nachricht.
    func testStandbildNutzlastPasstInEineMQTTNachricht() throws {
        let n = try Pixelweg.nutzlast(inhalt([bild()]), dauer: nil).utf8.count
        XCTAssertLessThan(n, 2000)
        print("MESSUNG Standbild-Nutzlast 52x16 leer: \(n) Byte")
    }

    func testStandbildGruessGroessen() throws {
        for mass in [Anzeigemass.vorgabe, Anzeigemass(breite: 32, hoehe: 8)] {
            let o = Meldungsoptionen(text: "Grüß", weg: .pixel, schrift: "Silkscreen", groesse: 8)
            let rahmen = try Meldungsbau.rahmen(o, icon: nil, sammlung: sammlung(), mass: mass)
            XCTAssertNotNil(rahmen.pixel)
            let n = try Anzeigen.nutzlast(rahmen).utf8.count
            print("MESSUNG Standbild „Grüß“ \(mass.breite)x\(mass.hoehe): \(n) Byte")
            XCTAssertLessThan(n, Pixelweg.mqttGrenze - 100)
        }
    }

    // MARK: - Bewegtes

    func testBewegtesLaeuftMindestensEinenDurchlauf() throws {
        let zwei = inhalt([bild(dauer: 1.0), bild(dauer: 0.5)])
        func dauerMs(_ d: Int?) throws -> Int {
            let json = try Pixelweg.nutzlast(zwei, dauer: d)
            let o = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
            return try XCTUnwrap(o["durationMs"] as? Int)
        }
        XCTAssertEqual(try dauerMs(nil), 1500, "ohne Nutzerdauer ein Durchlauf, sonst schneidet die Uhr bei 7 s ab")
        XCTAssertEqual(try dauerMs(1), 1500, "eine kuerzere Nutzerdauer schneidet nicht ab")
        XCTAssertEqual(try dauerMs(12), 12000, "eine laengere Nutzerdauer gilt")
    }

    func testEinZuGrossesGifWirdVorDemSendenAbgewiesen() throws {
        // Rauschen laesst sich nicht packen: 512 Bilder sind weit ueber 56 KiB.
        var zufall = SystemRandomNumberGenerator()
        let laut = (0..<Pixelweg.hoechsteBildzahl).map { _ in
            Bildraster.Einzelbild(pixel: (0..<832).map { _ in
                String(format: "#%06X", Int.random(in: 0..<0x1000000, using: &zufall)) }, dauer: 0.08)
        }
        XCTAssertThrowsError(try Pixelweg.nutzlast(inhalt(laut), dauer: nil)) { fehler in
            guard case NGFehler.laufschriftZuLang = fehler else { return XCTFail("war \(fehler)") }
            XCTAssertFalse((fehler as? LocalizedError)?.errorDescription?.isEmpty ?? true)
        }
    }

    /// Das GIF traegt die Bildzeiten (ganze Hundertstel) und die Pixel; was bei
    /// uns „aus" ist, steht als Schwarz darin.
    func testGifTraegtBildzeitenUndPixel() throws {
        let json = try Pixelweg.nutzlast(inhalt([bild([0: "#FF0000"], dauer: 1.0),
                                                 bild([51 + 52 * 15: "#00FF00"], dauer: 0.5)]), dauer: nil)
        let daten = try gifDaten(json)
        let quelle = try XCTUnwrap(CGImageSourceCreateWithData(daten as CFData, nil))
        XCTAssertEqual(CGImageSourceGetCount(quelle), 2)
        let zeiten = (0..<2).map { i -> Double in
            let e = CGImageSourceCopyPropertiesAtIndex(quelle, i, nil) as? [CFString: Any]
            let g = e?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            return (g?[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? -1
        }
        XCTAssertEqual(zeiten[0], 1.0, accuracy: 0.001)
        XCTAssertEqual(zeiten[1], 0.5, accuracy: 0.001)
        let punkte = try Bildraster.lesenMitZeiten(daten, breite: 52, hoehe: 16)
        XCTAssertEqual(punkte[0].pixel[0], "#FF0000")
        XCTAssertEqual(punkte[0].pixel[1], "#000000", "aus wird Schwarz, nicht durchsichtig")
        XCTAssertEqual(punkte[1].pixel[51 + 52 * 15], "#00FF00")
        XCTAssertEqual(punkte[1].pixel[0], "#000000")
    }

    /// Eine Bildzeit unter 20 ms gibt es nicht; 0 wuerde NG zu 100 ms machen.
    func testBildzeitenUnterZwanzigMillisekundenWerdenZwanzig() {
        XCTAssertEqual(Bildraster.gifZeit(0), 0.02)
        XCTAssertEqual(Bildraster.gifZeit(0.004), 0.02)
        XCTAssertEqual(Bildraster.gifZeit(0.08), 0.08, accuracy: 1e-9)
        XCTAssertEqual(Bildraster.gifZeit(.infinity), 0.1)
        XCTAssertEqual(Bildraster.gifZeit(1e12), 600)
    }

    // MARK: - Grenzen

    func testGrenzenAusFremddatenWerdenVorDemBauenGeprueft() {
        XCTAssertThrowsError(try Pixelweg.nutzlast(inhalt([]), dauer: nil))
        XCTAssertThrowsError(try Pixelweg.nutzlast(
            inhalt(Array(repeating: bild(), count: Pixelweg.hoechsteBildzahl + 1)), dauer: nil))
        XCTAssertThrowsError(try Pixelweg.nutzlast(
            Pixelinhalt(breite: 52, hoehe: 16, bilder: [Bildraster.Einzelbild(pixel: [nil], dauer: 1)]), dauer: nil))
        XCTAssertThrowsError(try Pixelweg.nutzlast(
            Pixelinhalt(breite: 100_000, hoehe: 16, bilder: [bild()]), dauer: nil))
    }

    // MARK: - Die Groessenweiche

    func testZustellwegTabelle() throws {
        let thema = 40
        // MQTT: passt samt Thema genau in 8192, ein Byte mehr nicht.
        XCTAssertEqual(try Pixelweg.zustellweg(nutzlastBytes: 8192 - thema, themaBytes: thema, betriebsart: .mqtt), .mqtt)
        XCTAssertEqual(try Pixelweg.zustellweg(nutzlastBytes: 8193 - thema, themaBytes: thema, betriebsart: .mqtt), .http)
        // HTTP-Betrieb bleibt HTTP, auch klein.
        XCTAssertEqual(try Pixelweg.zustellweg(nutzlastBytes: 100, themaBytes: 0, betriebsart: .http), .http)
        // 2 MiB: gerade noch, dann Fehler fuer beide Betriebsarten.
        XCTAssertEqual(try Pixelweg.zustellweg(nutzlastBytes: Pixelweg.httpGrenze, themaBytes: thema, betriebsart: .mqtt), .http)
        for art in Betriebsart.allCases {
            XCTAssertThrowsError(try Pixelweg.zustellweg(nutzlastBytes: Pixelweg.httpGrenze + 1,
                                                         themaBytes: thema, betriebsart: art)) { fehler in
                guard case NGFehler.zuGross = fehler else { return XCTFail("war \(fehler)") }
            }
        }
    }

    // MARK: - Typische Groessen (Messung)

    private func sammlung() -> Iconsammlung {
        Iconsammlung(schreibordner: FileManager.default.temporaryDirectory
            .appendingPathComponent("pixelweg-" + UUID().uuidString))
    }

    private func gruesse() -> Meldungsoptionen {
        Meldungsoptionen(text: "Grüße aus Wien", schrift: "Silkscreen", groesse: 8, tempo: .mittel)
    }

    func testLaufschriftGruesseAusWienGeheUeberHTTP() throws {
        let rahmen = try Meldungsbau.rahmen(gruesse(), icon: nil, sammlung: sammlung())
        let pixel = try XCTUnwrap(rahmen.pixel)
        XCTAssertTrue(pixel.istBewegt)
        // 80 ms je Bild, wie die Stufe „mittel".
        XCTAssertTrue(pixel.bilder.allSatisfy { abs($0.dauer - 0.08) < 1e-9 })
        let json = try Anzeigen.nutzlast(rahmen)
        let thema = NGThema.anzeige(praefix: "wohnzimmer/uhr", name: "meldung1").utf8.count
        let weg = try Pixelweg.zustellweg(nutzlastBytes: json.utf8.count, themaBytes: thema, betriebsart: .mqtt)
        XCTAssertLessThan(json.utf8.count, Pixelweg.hoechsteGIFBytes * 4 / 3 + 100)
        XCTAssertEqual(weg, .http)
        print("MESSUNG Laufschrift „Grüße aus Wien“: \(pixel.bilder.count) Bilder, \(json.utf8.count) Byte, Weg \(weg)")
    }

    func testAchtBildGifEinesEditorsMessung() throws {
        var bilder: [[String?]] = []
        for i in 0..<8 {
            var p = leer
            for y in 0..<16 { for x in 0..<52 where (x + y + 3 * i) % 5 == 0 { p[y * 52 + x] = "#FF8800" } }
            bilder.append(p)
        }
        let rahmen = try Bildsendung.rahmen(aus: bilder, verzoegerung: 0.2)
        let json = try Anzeigen.nutzlast(rahmen)
        let thema = NGThema.anzeige(praefix: "wohnzimmer/uhr", name: "meldung1").utf8.count
        let weg = try Pixelweg.zustellweg(nutzlastBytes: json.utf8.count, themaBytes: thema, betriebsart: .mqtt)
        print("MESSUNG 8-Bild-Editor-GIF: \(json.utf8.count) Byte, Weg \(weg)")
    }

    // MARK: - Eine Quelle fuer Vorschau und Sendung

    /// Text, der passt, steht still; das gesendete Bild ist das Feld der Vorschau.
    func testGesendetesStandbildIstDasFeldDerVorschau() throws {
        let o = Meldungsoptionen(text: "Wien", schrift: "Silkscreen", groesse: 8)
        XCTAssertTrue(Meldungsbau.passt(o, mitIcon: false))
        let pixel = try XCTUnwrap(Meldungsbau.rahmen(o, icon: nil, sammlung: sammlung()).pixel)
        XCTAssertEqual(pixel.bilder.count, 1)
        XCTAssertEqual(pixel.bilder[0].pixel, Meldungsbau.feld(o.fuerVorschau, mitIcon: false).punkteRoh)
        XCTAssertTrue(pixel.bilder[0].pixel.contains { $0 != nil })
    }

    /// Ein Icon steckt in den Pixeln, an der Stelle der Vorschau.
    func testEinIconSteckInDenPixeln() throws {
        let s = sammlung()
        let icon = try s.sichern(nummer: "t", name: "t", pixel: [String?](repeating: "#FF0000", count: 64))
        let o = Meldungsoptionen(text: "Hi", schrift: "Silkscreen", groesse: 8)
        let pixel = try XCTUnwrap(Meldungsbau.rahmen(o, icon: icon, sammlung: s).pixel)
        let y = Anzeigemass.vorgabe.iconY(kante: 8)
        XCTAssertEqual(pixel.bilder[0].pixel[y * 52], "#FF0000")
        XCTAssertEqual(pixel.bilder[0].pixel[(y + 7) * 52 + 7], "#FF0000")
        XCTAssertNil(pixel.bilder[0].pixel[(y - 1) * 52])
    }

    /// „Als Text" zeichnet NG vergroessert; die Vorschau deutet 2 × 2 an.
    func testVorschauVonAlsTextRechnetInDoppelpixeln() {
        var o = Meldungsoptionen(text: "Hi", weg: .text)
        o.schrift = "Silkscreen"
        let f = Meldungsbau.feld(o.fuerVorschau, mitIcon: false)
        for y in stride(from: 0, to: 16, by: 2) {
            for x in stride(from: 0, to: 52, by: 2) {
                let block = [f.farbe(x: x, y: y), f.farbe(x: x + 1, y: y),
                             f.farbe(x: x, y: y + 1), f.farbe(x: x + 1, y: y + 1)]
                XCTAssertTrue(block.allSatisfy { $0 == block[0] }, "Block \(x),\(y) ist nicht einfarbig")
            }
        }
    }

    // MARK: - Icon beim Text im Geraetefont

    func testIconBeimTextGehtAlsGifDataURLInsFeldIcon() throws {
        let s = sammlung()
        let icon = try s.sichern(nummer: "t", name: "t", pixel: [String?](repeating: "#FF0000", count: 64))
        let o = Meldungsoptionen(text: "Hi", weg: .text)
        let json = try Anzeigen.nutzlast(try Meldungsbau.rahmen(o, icon: icon, sammlung: s))
        XCTAssertTrue(json.contains(#""icon":"data:image/gif;base64,"#), json)
        XCTAssertTrue(json.contains(#""iconMode":"fixed""#))
    }

    /// Eine PNG-Datei im Iconbestand wird zu GIF umgerechnet, statt von NG
    /// abgewiesen zu werden.
    func testEinPngIconWirdZuGifUmgerechnet() throws {
        let ordner = FileManager.default.temporaryDirectory
            .appendingPathComponent("pixelweg-png-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        let datei = ordner.appendingPathComponent("p.png")
        let daten = try XCTUnwrap(CFDataCreateMutable(nil, 0))
        let senke = try XCTUnwrap(CGImageDestinationCreateWithData(daten, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(senke, try Bildraster.cgBild(
            aus: [String?](repeating: "#00FF00", count: 64), breite: 8, hoehe: 8), nil)
        XCTAssertTrue(CGImageDestinationFinalize(senke))
        try (daten as Data).write(to: datei)

        let s = Iconsammlung(schreibordner: ordner)
        let icon = Icon(nummer: "p", name: "p", kategorie: "", datei: datei, kante: 8)
        let uri = try Meldungsbau.iconAlsGIF(icon, sammlung: s)
        XCTAssertTrue(uri.hasPrefix("data:image/gif;base64,"))
        XCTAssertNoThrow(try NGNutzlast.icon(ausDatenURI: uri))
    }

    // MARK: - Der ganze Weg: Sendeweg -> Uhrenserver -> display/screen

    private func serverStarten() throws -> (Uhrenserver, UInt16) {
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port, zustand: NGUhrzustand())
            do {
                try s.starten()
                Thread.sleep(forTimeInterval: 0.05)
                return (s, port)
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    private func bildschirm(_ port: UInt16) throws -> [Int] {
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)/api/v1/display/screen"))
        let antwort = expectation(description: "screen")
        nonisolated(unsafe) var daten: Data?
        URLSession.shared.dataTask(with: url) { d, _, _ in daten = d; antwort.fulfill() }.resume()
        wait(for: [antwort], timeout: 5)
        let objekt = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(daten)) as? [String: Any])
        return try XCTUnwrap(objekt["pixels"] as? [Int])
    }

    private func warteAufBild(_ port: UInt16, bis bedingung: ([Int]) -> Bool) throws -> [Int] {
        var letztes: [Int] = []
        for _ in 0..<50 {
            letztes = try bildschirm(port)
            if bedingung(letztes) { return letztes }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return letztes
    }

    func testStandbildKommtPixelgenauAmPruefstandAn() throws {
        let (server, port) = try serverStarten()
        defer { server.beenden() }
        let rot = 0xFF0000, blau = 0x0000FF
        let rahmen = Frame(pixel: inhalt([bild([0: "#FF0000", 52 * 16 - 1: "#0000FF", 20 + 52 * 7: "#00FF00"])]))
        let anzeigen = Anzeigen(geraet: Geraet(host: "127.0.0.1:\(port)"))
        try anzeigen.zeigen(rahmen, auf: "meldung1")
        try anzeigen.umschalten(auf: "meldung1")

        let p = try warteAufBild(port) { $0.contains(rot) }
        XCTAssertEqual(p.count, 832)
        XCTAssertEqual(p[0], rot)
        XCTAssertEqual(p[1], 0, "nicht verdoppelt: Nachbar bleibt schwarz")
        XCTAssertEqual(p[52], 0)
        XCTAssertEqual(p[831], blau)
        XCTAssertEqual(p[20 + 52 * 7], 0x00FF00)
        XCTAssertEqual(p.filter { $0 != 0 }.count, 3)
    }

    func testGifKommtAmPruefstandAn() throws {
        let (server, port) = try serverStarten()
        defer { server.beenden() }
        let rahmen = Frame(pixel: inhalt([bild([0: "#FF0000", 51: "#00FF00", 52 * 15: "#0000FF"], dauer: 1),
                                          bild([5: "#FFFFFF"], dauer: 1)]))
        let uhr = Anzeigen(geraet: Geraet(host: "127.0.0.1:\(port)"))
        try uhr.zeigen(rahmen, auf: "meldung1")
        try uhr.umschalten(auf: "meldung1")

        let p = try warteAufBild(port) { $0.contains(0xFF0000) }
        XCTAssertEqual(p[0], 0xFF0000)
        XCTAssertEqual(p[51], 0x00FF00)
        XCTAssertEqual(p[52 * 15], 0x0000FF)
        XCTAssertEqual(p[5], 0)
        XCTAssertEqual(p.filter { $0 != 0 }.count, 3)
    }

    /// Was nicht in eine MQTT-Nachricht passt, geht ueber HTTP an dieselbe Uhr
    /// — der Sender bekommt nichts, die Uhr hat das Bild.
    func testZuGrosseAnzeigeFaehrtUeberHTTPAnDieselbeUhr() throws {
        let (server, port) = try serverStarten()
        defer { server.beenden() }
        let rahmen = try Meldungsbau.rahmen(gruesse(), icon: nil, sammlung: sammlung())
        XCTAssertGreaterThan(try Anzeigen.nutzlast(rahmen).utf8.count, Pixelweg.mqttGrenze - 100)
        let sender = PixelwegMitschreiber()
        let anzeigen = Anzeigen(sender: sender,
                                zugang: MQTTZugang(host: "127.0.0.1", benutzer: "u", kennwort: "p"),
                                praefix: "wohnzimmer/uhr",
                                ausweich: Geraet(host: "127.0.0.1:\(port)"))
        try anzeigen.zeigen(rahmen, auf: "meldung1")
        try Anzeigen(geraet: Geraet(host: "127.0.0.1:\(port)")).umschalten(auf: "meldung1")

        XCTAssertTrue(sender.gesendet.isEmpty, "uebers Limit: nichts darf als MQTT hinausgehen")
        // Das erste Bild einer Laufschrift ist leer (der Text laeuft von
        // rechts herein); belegt ist, was die Uhr abgelegt hat.
        let abgelegt = server.zustand.apps.first { $0.name == "meldung1" }
        XCTAssertNotNil(abgelegt, "die Uhr hat die Anzeige nicht bekommen")
        let erste = try gifDaten(try Anzeigen.nutzlast(rahmen))
        XCTAssertEqual(CGImageSourceGetCount(try XCTUnwrap(CGImageSourceCreateWithData(erste as CFData, nil))),
                       rahmen.pixel?.bilder.count)
        XCTAssertEqual(try bildschirm(port).count, 832)
    }

    /// Eine Laufschrift ueber den neuen Weg (GIF als `icon` der Anzeige): Ab
    /// einem Bild mit sichtbarem Text steht dieses Bild auf dem Schirm, in vollen
    /// 52 × 16 trotz `enlargeApps`.
    func testLaufschriftKommtAmPruefstandAn() throws {
        let (server, port) = try serverStarten()
        defer { server.beenden() }
        let rahmen = try Meldungsbau.rahmen(gruesse(), icon: nil, sammlung: sammlung())
        var pixel = try XCTUnwrap(rahmen.pixel)
        pixel.bilder = Array(pixel.bilder.dropFirst(60))
        let erstes = pixel.bilder[0].pixel
        XCTAssertTrue(erstes.contains { $0 != nil }, "Testvoraussetzung: sichtbarer Text")
        let uhr = Anzeigen(geraet: Geraet(host: "127.0.0.1:\(port)"))
        try uhr.zeigen(Frame(pixel: pixel), auf: "meldung1")
        try uhr.umschalten(auf: "meldung1")

        let p = try warteAufBild(port) { $0.contains { $0 != 0 } }
        for (i, farbe) in erstes.enumerated() {
            let soll = farbe.flatMap { Int($0.dropFirst(), radix: 16) } ?? 0
            XCTAssertEqual(p[i], soll, "Pixel \(i)")
        }
    }

    func testKleinesStandbildGehtUeberMQTT() throws {
        let sender = PixelwegMitschreiber()
        let anzeigen = Anzeigen(sender: sender,
                                zugang: MQTTZugang(host: "127.0.0.1", benutzer: "u", kennwort: "p"),
                                praefix: "wohnzimmer/uhr")
        try anzeigen.zeigen(Frame(pixel: inhalt([bild([0: "#FF0000"])])), auf: "meldung2")
        XCTAssertEqual(sender.gesendet.map(\.thema), ["wohnzimmer/uhr/cmd/apps/pushed/meldung2"])
        XCTAssertLessThan(sender.gesendet[0].nutzlast.count + sender.gesendet[0].thema.utf8.count, 8192)
    }

    /// Zu gross fuer MQTT und keine Adresse fuer HTTP: eine klare Meldung vor
    /// dem Senden, nichts geht still verloren.
    func testZuGrossOhneAdresseMeldetSichVorDemSenden() throws {
        let rahmen = try Meldungsbau.rahmen(gruesse(), icon: nil, sammlung: sammlung())
        let sender = PixelwegMitschreiber()
        let anzeigen = Anzeigen(sender: sender,
                                zugang: MQTTZugang(host: "127.0.0.1", benutzer: "u", kennwort: "p"),
                                praefix: "wohnzimmer/uhr")
        XCTAssertThrowsError(try anzeigen.zeigen(rahmen, auf: "meldung1")) { fehler in
            guard case NGFehler.keineAdresseFuerGrosse = fehler else { return XCTFail("war \(fehler)") }
            XCTAssertFalse((fehler as? LocalizedError)?.errorDescription?.isEmpty ?? true)
        }
        XCTAssertTrue(sender.gesendet.isEmpty)
    }
}
