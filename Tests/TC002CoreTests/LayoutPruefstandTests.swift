import XCTest
@testable import TC002Core

/// Fertig, wenn ein Layout mit drei Regionen gesendet und über `state/screen`
/// zurückgelesen identisch ist (Plan, Sprint 5a). Zwei Wege, beide ohne Netz
/// nach außen: HTTP gegen die virtuelle Uhr auf `127.0.0.1`, MQTT gegen eine
/// virtuelle Uhr, die Nachrichten wie die Firmware beantwortet.
final class LayoutPruefstandTests: XCTestCase {
    private var server: Uhrenserver?
    private let zugang = MQTTZugang(host: "127.0.0.1", benutzer: "u", kennwort: "p")

    override func tearDown() {
        server?.beenden()
        server = nil
        super.tearDown()
    }

    private func http() throws -> (Uhrenserver, Anzeigen, Geraet) {
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port)
            do {
                try s.starten()
                server = s
                let g = Geraet(host: "127.0.0.1:\(port)")
                return (s, Anzeigen(geraet: g), g)
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    private let drei = KastenlayoutTests.dreiRegionen

    /// Was die Firmware nach diesem Layout zeigt, unabhängig vom Senden gerechnet:
    /// die zwei Regionen ohne Schrift Pixel für Pixel, der Text als Menge.
    private func pruefeBild(_ auszug: Bildschirmauszug, file: StaticString = #filePath, line: UInt = #line) {
        func p(_ x: Int, _ y: Int) -> Int { auszug.farbe(x: x, y: y) ?? -1 }
        XCTAssertEqual(auszug.breite, 52, file: file, line: line)
        XCTAssertEqual(auszug.hoehe, 16, file: file, line: line)
        for y in 8..<12 {
            XCTAssertEqual(p(12, y), 0x00FF00, file: file, line: line)
            XCTAssertEqual(p(13, y), 0x202020, file: file, line: line)
        }
        XCTAssertEqual(p(30, 8), 0x0000FF, file: file, line: line)
        XCTAssertEqual(p(51, 15), 0xFF0000, file: file, line: line)
        let text = (0..<8).flatMap { y in (0..<52).map { (x: $0, y: y) } }.filter { p($0.x, $0.y) != 0 }
        XCTAssertFalse(text.isEmpty, file: file, line: line)
        XCTAssertTrue(text.allSatisfy { p($0.x, $0.y) == 0x00AAFF }, file: file, line: line)
    }

    // MARK: - HTTP

    func testEinLayoutKommtUeberHTTPAnUndLaesstSichZuruecklesen() throws {
        let (s, uhr, geraet) = try http()
        let weg = try uhr.zeigen(Frame(layout: drei), auf: "meldung1")
        XCTAssertEqual(weg, .http)
        try uhr.umschalten(auf: "meldung1")

        let gelesen = try geraet.bildschirm()
        pruefeBild(gelesen)
        XCTAssertEqual(gelesen.pixel, VirtuelleNGUhr.bildschirm(s.zustand), "identisch mit dem, was die Uhr zeichnet")
        XCTAssertEqual(try uhr.bildschirmLesen().pixel, gelesen.pixel)
    }

    func testEinLayoutAlsBenachrichtigung() throws {
        let (s, uhr, geraet) = try http()
        try uhr.benachrichtigen(Frame(layout: drei), Benachrichtigungsoptionen(name: "lay"))
        XCTAssertEqual(s.zustand.benachrichtigungen.first?.name, "lay")
        pruefeBild(try geraet.bildschirm())
    }

    func testEinUnpassendesLayoutGehtNichtHinaus() throws {
        let (s, uhr, _) = try http()
        let draussen = Kastenlayout(regionen: [Layoutregion(kennung: "a", kasten: Kasten(x: 50, y: 0, breite: 8, hoehe: 8),
                                                            inhalt: .fortschritt(5))])
        XCTAssertThrowsError(try uhr.zeigen(Frame(layout: draussen), auf: "meldung1"))
        XCTAssertTrue(s.zustand.apps.allSatisfy(\.eingebaut), "nichts abgeschickt")
    }

    /// Das Anzeigemaß der Ziel-Uhr entscheidet über die Kästen.
    func testEineKleineUhrWeistDieKaestenAb() throws {
        let (_, _, g) = try http()
        let klein = Anzeigen(geraet: g, anzeigemass: Anzeigemass(breite: 32, hoehe: 8))
        XCTAssertThrowsError(try klein.zeigen(Frame(layout: drei), auf: "meldung1")) {
            guard case .kastenAusserhalb? = $0 as? LayoutFehler else { return XCTFail("\($0)") }
        }
    }

    // MARK: - MQTT

    private func mqtt(ausweich: Geraet? = nil, uhr: MQTTUhrDoppelgaenger) -> Anzeigen {
        Anzeigen(sender: uhr, zugang: zugang, praefix: uhr.praefix, ausweich: ausweich)
            .quittierend(lauscher: ErgebnisAmDoppelgaenger(uhr: uhr), beiAusbleiben: { _ in XCTFail("keine Antwort") })
    }

    func testEinLayoutKommtUeberMQTTAnUndLaesstSichUeberStateScreenZuruecklesen() throws {
        let uhr = MQTTUhrDoppelgaenger()
        let anzeigen = mqtt(uhr: uhr)

        XCTAssertEqual(try anzeigen.zeigen(Frame(layout: drei), auf: "meldung1"), .mqtt)
        try anzeigen.umschalten(auf: "meldung1")
        XCTAssertEqual(uhr.eingang.map(\.thema), ["wz/uhr/cmd/apps/pushed/meldung1", "wz/uhr/cmd/apps/switch"])

        let gelesen = try anzeigen.bildschirmLesen(lauscher: ThemaAmDoppelgaenger(uhr: uhr))
        XCTAssertEqual(uhr.eingang.last?.thema, "wz/uhr/cmd/screen/get")
        pruefeBild(gelesen)
        XCTAssertEqual(gelesen.pixel, VirtuelleNGUhr.bildschirm(uhr.zustand))
    }

    /// Dieselbe Uhr, derselbe Inhalt: HTTP und MQTT lesen dasselbe Bild.
    func testHTTPUndMQTTLesenDasselbeBild() throws {
        let (_, httpAnzeigen, _) = try http()
        try httpAnzeigen.zeigen(Frame(layout: drei), auf: "meldung1")
        try httpAnzeigen.umschalten(auf: "meldung1")
        let uhr = MQTTUhrDoppelgaenger()
        let m = mqtt(uhr: uhr)
        try m.zeigen(Frame(layout: drei), auf: "meldung1")
        try m.umschalten(auf: "meldung1")
        XCTAssertEqual(try m.bildschirmLesen(lauscher: ThemaAmDoppelgaenger(uhr: uhr)).pixel,
                       try httpAnzeigen.bildschirmLesen().pixel)
    }

    func testEineBenachrichtigungUeberMQTT() throws {
        let uhr = MQTTUhrDoppelgaenger()
        let anzeigen = mqtt(uhr: uhr)
        try anzeigen.benachrichtigen(Frame(layout: drei), Benachrichtigungsoptionen(name: "lay"))
        XCTAssertEqual(uhr.eingang.first?.thema, "wz/uhr/cmd/notify")
        pruefeBild(try anzeigen.bildschirmLesen(lauscher: ThemaAmDoppelgaenger(uhr: uhr)))
    }

    /// Ein Layout über 8192 Byte verwirft die Uhr über MQTT ohne Antwort; die App
    /// schickt diese eine Anzeige darum über HTTP.
    func testEinGrossesLayoutNimmtDenWegUeberHTTP() throws {
        var befehle: [Zeichenbefehl] = []
        for i in 0..<400 { befehle.append(.pixel(x: i % 50, y: i % 14, farbe: "#FF0000")) }
        let gross = Kastenlayout(regionen: [Layoutregion(kennung: "z", kasten: Kasten(x: 0, y: 0, breite: 52, hoehe: 16),
                                                         inhalt: .zeichnung(befehle))])
        XCTAssertGreaterThan(try Anzeigen.nutzlast(Frame(layout: gross)).utf8.count, 8192)

        let (s, _, geraet) = try http()
        let uhr = MQTTUhrDoppelgaenger()
        XCTAssertEqual(try mqtt(ausweich: geraet, uhr: uhr).zeigen(Frame(layout: gross), auf: "meldung1"), .http)
        XCTAssertTrue(uhr.eingang.isEmpty, "nichts über MQTT")
        XCTAssertEqual(s.zustand.apps.last?.name, "meldung1")

        XCTAssertThrowsError(try mqtt(uhr: uhr).zeigen(Frame(layout: gross), auf: "meldung1")) {
            guard case .keineAdresseFuerGrosse? = $0 as? NGFehler else { return XCTFail("\($0)") }
        }
    }

    func testBleibtDieAntwortAusLiestDieAdresse() throws {
        let (s, httpAnzeigen, geraet) = try http()
        try httpAnzeigen.zeigen(Frame(layout: drei), auf: "meldung1")
        try httpAnzeigen.umschalten(auf: "meldung1")
        let stumm = MQTTUhrDoppelgaenger()
        struct Stumm: ThemaLauschend {
            func erwarten(thema: String, zugang: MQTTZugang, frist: TimeInterval,
                          waehrend tat: () throws -> Void) throws -> Data? { try tat(); return nil }
        }
        let mitAdresse = Anzeigen(sender: stumm, zugang: zugang, praefix: "wz/uhr", ausweich: geraet)
        XCTAssertEqual(try mitAdresse.bildschirmLesen(lauscher: Stumm()).pixel, VirtuelleNGUhr.bildschirm(s.zustand))
        let ohne = Anzeigen(sender: stumm, zugang: zugang, praefix: "wz/uhr")
        XCTAssertThrowsError(try ohne.bildschirmLesen(lauscher: Stumm())) {
            guard case .keineBildschirmantwort? = $0 as? NGFehler else { return XCTFail("\($0)") }
        }
    }

    /// Eine Uhr, die die Nutzlast abweist, meldet es auf `/result` (hier: ein
    /// Kasten, den die Firmware nicht annimmt, obwohl die App ihn durchließ).
    func testDieAbweisungDerUhrKommtAlsFehler() throws {
        let uhr = MQTTUhrDoppelgaenger()
        // Die App prüft nach 52 × 16; ein Kasten von 53 Breite kommt gar nicht erst hinaus.
        let anzeigen = Anzeigen(sender: uhr, zugang: zugang, praefix: uhr.praefix, anzeigemass: Anzeigemass(breite: 64, hoehe: 16))
            .quittierend(lauscher: ErgebnisAmDoppelgaenger(uhr: uhr), beiAusbleiben: { _ in XCTFail("keine Antwort") })
        let breit = Kastenlayout(regionen: [Layoutregion(kennung: "a", kasten: Kasten(x: 0, y: 0, breite: 60, hoehe: 8),
                                                         inhalt: .fortschritt(5))])
        XCTAssertThrowsError(try anzeigen.zeigen(Frame(layout: breit), auf: "meldung1")) {
            guard case .abgewiesen(let grund)? = $0 as? NGFehler else { return XCTFail("\($0)") }
            XCTAssertTrue(grund.contains("layout.regions[0].box"), grund)
        }
    }
}

final class BildschirmauszugTests: XCTestCase {
    func testWirdAusDerAntwortDerUhrGelesen() throws {
        let a = try Bildschirmauszug(daten: Data(#"{"width":32,"height":8,"pixels":[\#(Array(repeating: "16711680", count: 256).joined(separator: ","))]}"#.utf8))
        XCTAssertEqual(a.breite, 32)
        XCTAssertEqual(a.farbe(x: 31, y: 7), 0xFF0000)
        XCTAssertNil(a.farbe(x: 32, y: 0))
    }

    func testUnstimmigesWirdAbgewiesen() {
        for text in [#"{"width":52,"height":16,"pixels":[1,2]}"#,
                     #"{"width":2000000000,"height":2000000000,"pixels":[]}"#,
                     #"{"width":32,"height":8}"#, "[]", "kein JSON"] {
            XCTAssertThrowsError(try Bildschirmauszug(daten: Data(text.utf8)), text)
        }
        XCTAssertNil(Bildschirmauszug(breite: 32, hoehe: 8, pixel: [Int](repeating: -1, count: 256)))
    }

    func testAsciiMitLegende() throws {
        var pixel = [Int](repeating: 0, count: 32 * 8)
        pixel[0] = 0x00FF00; pixel[1] = 0xFF0000; pixel[2] = 0x00FF00
        let text = try XCTUnwrap(Bildschirmauszug(breite: 32, hoehe: 8, pixel: pixel)).ascii()
        let zeilen = text.split(separator: "\n").map(String.init)
        XCTAssertEqual(zeilen.count, 8 + 2)
        XCTAssertTrue(zeilen[0].hasPrefix("#A#."))
        XCTAssertEqual(zeilen[1], String(repeating: ".", count: 32))
        XCTAssertEqual(Array(zeilen.suffix(2)), ["# = #00FF00", "A = #FF0000"])
    }
}
