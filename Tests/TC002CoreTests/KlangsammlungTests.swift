import XCTest
@testable import TC002Core

/// Klangsammlung, RTTTL-Prüfung und Abgleich — der Plan als reine Rechnung und
/// der ganze Weg gegen die virtuelle Uhr auf `127.0.0.1`. Die MP3-Dateien sind
/// ein paar erzeugte Byte mit `ID3`-Kopf.
final class KlangsammlungTests: XCTestCase {
    private var server: Uhrenserver?
    private var ordner: URL!

    override func setUp() {
        super.setUp()
        ordner = FileManager.default.temporaryDirectory.appendingPathComponent("klaenge-\(UUID().uuidString)")
    }

    override func tearDown() {
        server?.beenden(); server = nil
        try? FileManager.default.removeItem(at: ordner)
        super.tearDown()
    }

    private func mp3(_ n: Int = 10) -> Data { Data("ID3".utf8) + Data(repeating: 0x41, count: n - 3) }
    private var sammlung: Klangsammlung { Klangsammlung(ordner: ordner) }

    // MARK: - RTTTL

    func testRtttlGueltig() throws {
        XCTAssertEqual(try Rtttl.geprueft("  ping:d=4,o=5,b=100:c,8d#,16p,4e.6,f5.\n"),
                       "ping:d=4,o=5,b=100:c,8d#,16p,4e.6,f5.")
        XCTAssertNoThrow(try Rtttl.geprueft(":d=4,o=5,b=100:c"), "Namensteil darf fehlen")
        XCTAssertNoThrow(try Rtttl.geprueft("x::c"), "Einstellungen dürfen fehlen")
    }

    func testRtttlFehler() {
        func fehler(_ s: String) -> RtttlFehler? {
            do { _ = try Rtttl.geprueft(s); return nil } catch { return error as? RtttlFehler }
        }
        XCTAssertEqual(fehler(""), .leer)
        XCTAssertEqual(fehler("a:d=4:c\nb"), .mehrereZeilen)
        XCTAssertEqual(fehler("kaputt"), .teileFalsch)
        XCTAssertEqual(fehler("a:d=4:"), .keineNoten)
        XCTAssertEqual(fehler("a:x=4:c"), .einstellung("x=4"))
        XCTAssertEqual(fehler("a:d=vier:c"), .einstellung("d=vier"))
        XCTAssertEqual(fehler("a:d=4:c,zz"), .note("zz"))
        XCTAssertEqual(fehler("a:d=4:7c"), .note("7c"))
        XCTAssertEqual(fehler("a:d=4:" + String(repeating: "c,", count: 300)), .zuLang(512))
        XCTAssertNotNil(RtttlFehler.teileFalsch.errorDescription)
    }

    func testNamensvorschlagUndNamensteil() {
        XCTAssertEqual(Rtttl.namensvorschlag("Super Mario:d=4:c"), "Super-Mario")
        XCTAssertEqual(Rtttl.namensvorschlag(":d=4:c"), "melodie")
        XCTAssertEqual(Rtttl.namensvorschlag(String(repeating: "a", count: 40) + ":d=4:c").count, 24)
        XCTAssertEqual(Rtttl.mitName("alt:d=4,o=5:c", name: "neu"), "neu:d=4,o=5:c")
        XCTAssertEqual(Rtttl.mitName(":d=4:c", name: "neu"), "neu:d=4:c")
    }

    // MARK: - Sammlung

    func testMelodieSichernSchreibtNamenUm() throws {
        let k = try sammlung.melodieSichern(name: "ping", rtttl: "Anders:d=4,o=5,b=100:c")
        XCTAssertEqual(k.rtttl, "ping:d=4,o=5,b=100:c")
        XCTAssertEqual(sammlung.melodien().map(\.name), ["ping"])
        XCTAssertEqual(try String(contentsOf: ordner.appendingPathComponent("ping.txt"), encoding: .utf8),
                       "ping:d=4,o=5,b=100:c")
    }

    func testNamenregeln() throws {
        XCTAssertThrowsError(try sammlung.melodieSichern(name: "mit leer", rtttl: "a:d=4:c"))
        XCTAssertThrowsError(try sammlung.melodieSichern(name: String(repeating: "m", count: 25), rtttl: "a:d=4:c"))
        XCTAssertNoThrow(try sammlung.melodieSichern(name: String(repeating: "m", count: 24), rtttl: "a:d=4:c"))
        XCTAssertThrowsError(try sammlung.mp3Sichern(name: "ä", daten: mp3()))
        XCTAssertNoThrow(try sammlung.mp3Sichern(name: String(repeating: "m", count: 32), daten: mp3()))
        XCTAssertThrowsError(try sammlung.mp3Sichern(name: String(repeating: "m", count: 33), daten: mp3()))
        XCTAssertThrowsError(try sammlung.mp3Sichern(name: "kein", daten: Data("text".utf8))) {
            XCTAssertEqual($0 as? KlangFehler, .keinMP3)
        }
        XCTAssertThrowsError(try sammlung.mp3Sichern(name: "gross", daten: mp3(Geraet.mp3Hoechstgroesse + 1)))
    }

    func testNameGiltFuerMelodieUndMP3Gemeinsam() throws {
        try sammlung.melodieSichern(name: "x", rtttl: "a:d=4:c")
        XCTAssertThrowsError(try sammlung.mp3Sichern(name: "x", daten: mp3())) {
            XCTAssertEqual($0 as? SammlungFehler, .nameBelegt("x"))
        }
        try sammlung.mp3Sichern(name: "y", daten: mp3())
        XCTAssertThrowsError(try sammlung.melodieSichern(name: "y", rtttl: "a:d=4:c"))
    }

    func testUmbenennenUndLoeschen() throws {
        let m = try sammlung.melodieSichern(name: "alt", rtttl: "alt:d=4:c")
        try sammlung.umbenennen(m, nach: "neu")
        XCTAssertEqual(sammlung.melodien().map(\.name), ["neu"])
        XCTAssertEqual(sammlung.klang("neu")?.rtttl, "neu:d=4:c")
        let d = try sammlung.mp3Sichern(name: "ton", daten: mp3())
        XCTAssertThrowsError(try sammlung.umbenennen(d, nach: "neu"), "Name belegt")
        try sammlung.umbenennen(d, nach: "ton2")
        XCTAssertEqual(sammlung.mp3().map(\.name), ["ton2"])
        try sammlung.loeschen(try XCTUnwrap(sammlung.klang("ton2")))
        XCTAssertTrue(sammlung.mp3().isEmpty)
    }

    func testAnDerSammlungErscheintNurGueltiges() throws {
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        try Data("kaputt".utf8).write(to: ordner.appendingPathComponent("schlecht.txt"))
        try Data("x".utf8).write(to: ordner.appendingPathComponent("fremd.pdf"))
        XCTAssertTrue(sammlung.alle().isEmpty)
    }

    func testUebernehmenVonEinerUhr() throws {
        try sammlung.melodieSichern(name: "gleich", rtttl: "gleich:d=4:c")
        try sammlung.melodieSichern(name: "anders", rtttl: "anders:d=4:c")
        try sammlung.mp3Sichern(name: "datei", daten: mp3())
        let liste = Tonablage(namen: ["neu", "gleich", "anders", "datei", "ohnetext", "kaputt"],
                              texte: ["neu": "neu:d=8:e", "gleich": "gleich:d=4:c", "anders": "anders:d=8:d",
                                      "datei": "datei:d=4:c", "kaputt": "kaputt"])
        let b = sammlung.uebernehmen(melodien: liste)
        XCTAssertEqual(b.neu, ["neu"])
        XCTAssertEqual(b.gleich, ["gleich"])
        XCTAssertEqual(b.uebersprungen.map(\.name), ["anders", "datei", "ohnetext", "kaputt"])
        XCTAssertEqual(sammlung.klang("anders")?.rtttl, "anders:d=4:c", "die Sammlung ist das Original")
        let c = sammlung.uebernehmen(melodien: liste, ersetzen: true)
        XCTAssertEqual(c.ersetzt, ["anders"])
        XCTAssertEqual(sammlung.klang("anders")?.rtttl, "anders:d=8:d")
    }

    // MARK: - Plan

    private func klang(_ n: String, _ a: Sammlungsart, _ g: Int, rtttl: String? = nil) -> Sammlungsklang {
        Sammlungsklang(name: n, art: a, groesse: g, datei: URL(fileURLWithPath: "/nichts/\(n)"), rtttl: rtttl)
    }

    func testPlanFehlendAbweichendGleichUndUeberzaehliges() {
        let soll = [klang("neu", .melodie, 10, rtttl: "neu:d=4:c"),
                    klang("anders", .melodie, 10, rtttl: "anders:d=4:c"),
                    klang("gleich", .melodie, 10, rtttl: "gleich:d=4:c"),
                    klang("m-neu", .mp3, 100), klang("m-gross", .mp3, 200), klang("m-gleich", .mp3, 100)]
        let uhr = Uhrenklaenge(melodien: ["anders": "alt:d=8:c", "gleich": "Fremdname:d=4:c", "extra": "extra:d=4:c"],
                               mp3: ["m-gross": 5, "m-gleich": 100, "m-extra": 7])
        let plan = Klangabgleich.planen(sammlung: soll, uhr: uhr)
        XCTAssertEqual(plan.schritte, [.hinzufuegen(soll[0]), .ersetzen(soll[1]), .hinzufuegen(soll[3]), .ersetzen(soll[4])])
        XCTAssertEqual(plan.unveraendert, ["gleich", "m-gleich"], "Namensteil der Uhr zählt nicht")
        XCTAssertTrue(plan.uebersprungen.isEmpty)
        XCTAssertFalse(plan.schritte.contains { $0.klang.name.contains("extra") }, "Überzähliges bleibt")
    }

    func testPlanOhneMP3FaehigkeitUndOhneMelodien() {
        let soll = [klang("m", .melodie, 10, rtttl: "m:d=4:c"), klang("d", .mp3, 100)]
        let tc001 = Geraetefaehigkeiten(ton: Tonfaehigkeiten(mp3: false, rtttl: true))
        let a = Klangabgleich.planen(sammlung: soll, uhr: Uhrenklaenge(faehigkeiten: tc001))
        XCTAssertEqual(a.schritte.map { $0.klang.name }, ["m"])
        XCTAssertEqual(a.uebersprungen, [.init(name: "d", art: .mp3, grund: .faehigkeitFehlt("audio.mp3"))])
        let stumm = Geraetefaehigkeiten(ton: Tonfaehigkeiten(mp3: true, rtttl: false))
        let b = Klangabgleich.planen(sammlung: soll, uhr: Uhrenklaenge(faehigkeiten: stumm))
        XCTAssertEqual(b.schritte.map { $0.klang.name }, ["d"])
        XCTAssertEqual(b.uebersprungen.first?.grund, .faehigkeitFehlt("audio.rtttl"))
    }

    func testPlanPlatz() {
        let soll = [klang("a", .mp3, 600), klang("b", .mp3, 600), klang("c", .melodie, 50, rtttl: "c:d=4:c")]
        let uhr = Uhrenklaenge(belegteBytes: 100, gesamteBytes: 1_000)
        let plan = Klangabgleich.planen(sammlung: soll, uhr: uhr)
        XCTAssertEqual(plan.schritte.map { $0.klang.name }, ["c", "a"])
        XCTAssertEqual(plan.uebersprungen, [.init(name: "b", art: .mp3, grund: .keinPlatz(noetig: 600, frei: 250))])
        // Ersetzen gibt den alten Platz frei.
        let ersatz = Klangabgleich.planen(sammlung: [klang("a", .mp3, 550)],
                                          uhr: Uhrenklaenge(mp3: ["a": 500], belegteBytes: 900, gesamteBytes: 1_000))
        XCTAssertEqual(ersatz.schritte.count, 1)
    }

    func testPlanNameAufUhrBelegtVonAndererArt() {
        let soll = [klang("x", .melodie, 10, rtttl: "x:d=4:c"), klang("y", .mp3, 10)]
        let uhr = Uhrenklaenge(melodien: ["y": "y:d=4:c"], mp3: ["x": 5])
        let plan = Klangabgleich.planen(sammlung: soll, uhr: uhr)
        XCTAssertTrue(plan.schritte.isEmpty)
        XCTAssertEqual(plan.uebersprungen.map(\.grund), [.nameAufUhrBelegt(.mp3), .nameAufUhrBelegt(.melodie)])
    }

    func testMP3OhneGroessenangabeGiltAlsGleich() {
        let plan = Klangabgleich.planen(sammlung: [klang("a", .mp3, 10)], uhr: Uhrenklaenge(mp3: ["a": Int?.none]))
        XCTAssertEqual(plan.unveraendert, ["a"])
    }

    // MARK: - Ganzer Weg gegen die virtuelle Uhr

    private func gestartet(_ z: NGUhrzustand) throws -> Geraet {
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port, zustand: z)
            do { try s.starten(); server = s; return Geraet(host: "127.0.0.1:\(port)") } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    private func befuellen() throws {
        try sammlung.melodieSichern(name: "ping", rtttl: "x:d=4,o=5,b=100:c,d")
        try sammlung.melodieSichern(name: "pong", rtttl: "x:d=8,o=5,b=100:e")
        try sammlung.mp3Sichern(name: "gruss", daten: mp3(40))
    }

    func testAbgleichTC002EndeZuEnde() throws {
        try befuellen()
        var z = NGUhrzustand()
        z.ton.melodien["pong"] = "pong:d=4,o=5,b=100:c"      // weicht ab
        z.ton.melodien["extra"] = "extra:d=4:c"              // bleibt
        z.ton.mp3 = ["mp3-extra"]; z.ton.mp3Groessen["mp3-extra"] = 7
        let g = try gestartet(z)
        let probe = Klangabgleich.abgleichen(sammlung: sammlung.alle(), geraet: g, uhrname: "T", trocken: true)
        XCTAssertEqual(probe.hinzugefuegt.sorted(), ["gruss", "ping"])
        XCTAssertEqual(probe.ersetzt, ["pong"])
        XCTAssertEqual(try g.melodien().namen.sorted(), ["extra", "pong"], "Trockenlauf sendet nichts")

        let e = Klangabgleich.abgleichen(sammlung: sammlung.alle(), geraet: g, uhrname: "T")
        XCTAssertNil(e.fehler)
        XCTAssertEqual(e.hinzugefuegt.sorted(), ["gruss", "ping"])
        XCTAssertEqual(e.ersetzt, ["pong"])
        XCTAssertTrue(e.uebersprungen.isEmpty)
        let melodien = try g.melodien()
        XCTAssertEqual(melodien.namen.sorted(), ["extra", "ping", "pong"], "Überzähliges bleibt")
        XCTAssertEqual(melodien.texte["pong"], "pong:d=8,o=5,b=100:e")
        XCTAssertEqual(melodien.texte["ping"], "ping:d=4,o=5,b=100:c,d")
        let dateien = try g.mp3Dateien()
        XCTAssertEqual(dateien.namen.sorted(), ["gruss", "mp3-extra"])
        XCTAssertEqual(dateien.groessen["gruss"], 40)

        let zweites = Klangabgleich.abgleichen(sammlung: sammlung.alle(), geraet: g, uhrname: "T")
        XCTAssertTrue(zweites.hinzugefuegt.isEmpty && zweites.ersetzt.isEmpty)
        XCTAssertEqual(zweites.unveraendert.sorted(), ["gruss", "ping", "pong"])
    }

    func testAbgleichTC001UeberspringtMP3() throws {
        try befuellen()
        var z = NGUhrzustand()
        z.ton.faehigkeiten = NGTon.tc001
        let g = try gestartet(z)
        let e = Klangabgleich.abgleichen(sammlung: sammlung.alle(), geraet: g, uhrname: "alt")
        XCTAssertEqual(e.hinzugefuegt.sorted(), ["ping", "pong"])
        XCTAssertEqual(e.uebersprungen, [.init(name: "gruss", art: .mp3, grund: .faehigkeitFehlt("audio.mp3"))])
        XCTAssertTrue(try g.mp3Dateien().namen.isEmpty)
    }

    func testAbgleichPlatzUndNichtErreichbar() throws {
        try sammlung.mp3Sichern(name: "gross", daten: mp3(VirtuelleNGUhr.gesamtSpeicher / 4))
        var z = NGUhrzustand()
        z.ton.mp3 = ["voll"]; z.ton.mp3Groessen["voll"] = VirtuelleNGUhr.gesamtSpeicher - 100
        let g = try gestartet(z)
        let e = Klangabgleich.abgleichen(sammlung: sammlung.alle(), geraet: g, uhrname: "T")
        XCTAssertTrue(e.hinzugefuegt.isEmpty)
        guard case .keinPlatz? = e.uebersprungen.first?.grund else { return XCTFail("\(e)") }

        let tot = Klangabgleich.abgleichen(sammlung: sammlung.alle(), geraet: Geraet(host: "127.0.0.1:1"), uhrname: "X")
        XCTAssertNotNil(tot.fehler)
    }
}
