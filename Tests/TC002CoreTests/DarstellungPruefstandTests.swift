import XCTest
@testable import TC002Core

/// Die Darstellung über den echten HTTP-Weg: `Anzeigen` → `Geraet` → Port auf
/// `127.0.0.1` → `VirtuelleNGUhr`. Kein Byte verlässt den Rechner.
final class DarstellungPruefstandTests: XCTestCase {
    private var server: Uhrenserver?

    override func tearDown() {
        server?.beenden()
        server = nil
        super.tearDown()
    }

    private func gestartet() throws -> (Uhrenserver, Geraet, Anzeigen) {
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port)
            do {
                try s.starten()
                server = s
                let g = Geraet(host: "127.0.0.1:\(port)")
                return (s, g, Anzeigen(geraet: g))
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    private func text(_ d: Darstellung) -> Frame {
        Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "x", weg: .text)), darstellung: d)
    }

    private func roh(_ g: Geraet, _ json: String) -> GeraetFehler? {
        do { try g.anzeigeSetzen(json, name: "t"); return nil } catch { return error as? GeraetFehler }
    }

    func testDieUhrNenntIhreListen() throws {
        let (_, g, _) = try gestartet()
        let f = try XCTUnwrap(g.faehigkeiten())
        XCTAssertEqual(f.effekte.count, 19)
        XCTAssertEqual(f.overlays.count, 6)
        XCTAssertEqual(f.paletten.count, 8)
        XCTAssertEqual(f.paletteneffekte.count, 16)
    }

    func testEineDarstellungKommtAnUndWirdAufgehoben() throws {
        let (s, g, uhr) = try gestartet()
        let f = try g.faehigkeiten()
        let d = Darstellung(effekt: "plasma", effektTempo: 3, overlay: "Rain", palette: .name("lava"),
                            paletteTempo: 1)
        try uhr.zeigen(text(d), auf: "t", faehigkeiten: f)
        let n = try XCTUnwrap(s.zustand.apps.first { $0.name == "t" }?.nutzlast)
        guard case .objekt(let o) = n else { return XCTFail("kein Objekt") }
        XCTAssertEqual(o["effect"], .text("Plasma"))
        XCTAssertEqual(o["overlay"], .text("rain"))
        XCTAssertEqual(o["palette"], .text("Lava"))
        XCTAssertEqual(o["effectSpeed"], .zahl(3))
    }

    func testEineGrafikKommtAn() throws {
        let (s, _, uhr) = try gestartet()
        let g = Grafikinhalt(diagramm: .linie([1, 2, 3]), diagrammfarbe: .palette, fortschritt: 50)
        try uhr.zeigen(Frame(darstellung: Darstellung(palette: .farben(["#FF0000", "#00FF00"])), grafik: g), auf: "t")
        guard case .objekt(let o)? = s.zustand.apps.first(where: { $0.name == "t" })?.nutzlast else { return XCTFail() }
        XCTAssertEqual(o["lineChart"], .liste([.zahl(1), .zahl(2), .zahl(3)]))
        XCTAssertEqual(o["chartColor"], .text("palette"))
        XCTAssertEqual(o["progress"], .zahl(50))
        XCTAssertNil(o["text"])
    }

    func testEineBenachrichtigungMitOverlayKommtAn() throws {
        let (s, _, uhr) = try gestartet()
        try uhr.benachrichtigen(text(Darstellung(overlay: "snow")))
        XCTAssertEqual(s.zustand.benachrichtigungen.first?.nutzlast["overlay"], .text("snow"))
    }

    /// Was die Uhr abweist, wie die Doku es beschreibt (§5.8): `422`, `field` = der Schlüssel.
    func testDieUhrWeistAbWieNG() throws {
        let (_, g, _) = try gestartet()
        for (json, feld) in [
            (#"{"effect":"Nope"}"#, "effect"),
            (#"{"overlay":"hail"}"#, "overlay"),
            (#"{"palette":"Nope"}"#, "palette"),
            (#"{"palette":[]}"#, "palette"),
            (##"{"palette":["#FF0000",{"color":"#00FF00","pos":5}]}"##, "palette"),
            (##"{"palette":[{"color":"#00FF00","pos":101}]}"##, "palette"),
            (#"{"palette":5}"#, "palette"),
            (#"{"backgroundColor":"rot"}"#, "backgroundColor"),
            (#"{"chartColor":"rot"}"#, "chartColor"),
            (#"{"progressColor":[1,2]}"#, "progressColor"),
            (#"{"progressTrackColor":"palette"}"#, "progressTrackColor"),
            (#"{"barChart":"viele"}"#, "barChart"),
        ] {
            guard case .ngAbgewiesen(let status, let code, let f)? = roh(g, json) else {
                XCTFail("nicht abgewiesen: \(json)"); continue
            }
            XCTAssertEqual(status, 422, json)
            XCTAssertEqual(code, "validationFailed", json)
            XCTAssertEqual(f, feld, json)
        }
    }

    func testDieUhrNimmtAn_WasDieDokuAnnimmt() throws {
        let (_, g, _) = try gestartet()
        for json in [
            #"{"effect":"plasma"}"#,                       // Schreibweise egal
            #"{"effect":""}"#,
            #"{"effect":5}"#,                              // falscher Typ: übergangen
            #"{"effectSpeed":0}"#,                         // klemmt auf 0.1
            #"{"effectSpeed":99}"#,
            #"{"effectSpeed":"schnell"}"#,
            #"{"palette":null}"#,
            #"{"palette":""}"#,
            ##"{"palette":["#F00","00FF00"]}"##,
            ##"{"palette":[{"color":"#F00","pos":0},{"color":[0,0,255],"pos":100}]}"##,
            #"{"chartColor":"palette","barChart":[1,"x",3]}"#,
            #"{"progress":150,"progressColor":"palette","progressTrackColor":"333"}"#,
            #"{"lineChart":[1]}"#,
        ] {
            XCTAssertNil(roh(g, json), json)
        }
    }
}
