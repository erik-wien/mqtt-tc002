import XCTest
@testable import TC002Core

/// Die Namen, die ein Menü bei mehreren Zieluhren anbietet.
final class NamensangebotTests: XCTestCase {
    private let tc001 = Tonfaehigkeiten(mp3: false, rtttl: true, song: false, speech: false, radio: false,
                                        url: false, effect: false, clip: false, track: false)
    private let tc002 = Tonfaehigkeiten(mp3: true, rtttl: true, song: true, speech: true, radio: true,
                                        url: true, effect: true, clip: true, track: false)

    private func ziel(_ name: String, _ ton: Tonfaehigkeiten, _ listen: Tonlisten?) -> Klangziel {
        Klangziel(id: UUID(), name: name, faehigkeiten: Geraetefaehigkeiten(ton: ton), listen: listen)
    }

    func testVereinigtOhneDoppelteSortiert() {
        XCTAssertEqual(Namensangebot.vereinigt([["b", "a"], ["A", "c"], []]), ["a", "b", "c"])
    }

    func testKlangnamenAusDenZielenNurVonUhrenDieSieSpielen() {
        let gross = ziel("gross", tc002, Tonlisten(melodien: ["ping", "alarm"], mp3: ["gong"]))
        let klein = ziel("klein", tc001, Tonlisten(melodien: ["ping", "tick"], mp3: ["nie"]))
        XCTAssertEqual(Klangeignung.melodien(in: [gross, klein]), ["alarm", "ping", "tick"])
        XCTAssertEqual(Klangeignung.mp3(in: [gross, klein]), ["gong"], "die TC001 spielt keine MP3")
        XCTAssertEqual(Klangeignung.mp3(in: [klein]), [])
        XCTAssertEqual(Klangeignung.melodien(in: [ziel("neu", tc002, nil)]), [], "ohne Listen nichts")
    }

    func testEinNameNurAufEinemTeilMeldetDieAnderenAlsNichtSpielbar() {
        let gross = ziel("gross", tc002, Tonlisten(melodien: ["ping"], mp3: ["gong"]))
        let klein = ziel("klein", tc001, Tonlisten(melodien: ["ping", "tick"], mp3: []))
        let ziele = [gross, klein]
        XCTAssertEqual(Klangeignung.ohne(Klangwahl(art: .uhr, name: "tick"), in: ziele).map(\.name), ["gross"])
        XCTAssertEqual(Klangeignung.ohne(Klangwahl(art: .uhr, name: "gong"), in: ziele).map(\.name), ["klein"])
        XCTAssertEqual(Klangeignung.ohne(Klangwahl(art: .uhr, name: "ping"), in: ziele).map(\.name), [])
        XCTAssertTrue(Klangeignung.teilweise(Klangwahl(art: .uhr, name: "tick"), in: ziele))
        let v = Klangeignung.verteilen([Klang(.datei("tick"))], an: ziele)
        XCTAssertEqual(v.uebersprungeneNamen, ["gross"])
    }

    func testPfadeAdressenUndUnbekannteListenBleibenUngeprueft() {
        let z = ziel("gross", tc002, Tonlisten(melodien: ["ping"], mp3: []))
        for name in ["melodies/neu", "mp3/neu", "http://x.example/a.mp3"] {
            XCTAssertEqual(Klangeignung.ohne(Klangwahl(art: .uhr, name: name), in: [z]).count, 0, name)
        }
        let ohneListen = ziel("x", tc002, nil)
        XCTAssertEqual(Klangeignung.ohne(Klangwahl(art: .uhr, name: "irgendwas"), in: [ohneListen]).count, 0)
    }

    func testDarstellungsangebotIstDieVereinigung() {
        let a = Darstellungsziel(name: "gross", faehigkeiten: Geraetefaehigkeiten(
            effekte: ["Fade", "Rainbow"], overlays: ["rain"], paletten: ["Ocean"]))
        let b = Darstellungsziel(name: "klein", faehigkeiten: Geraetefaehigkeiten(
            effekte: ["Fade"], overlays: [], paletten: []))
        let c = Darstellungsziel(name: "unbekannt", faehigkeiten: nil)
        let angebot = Darstellungsangebot(ziele: [a, b, c])
        XCTAssertEqual(angebot.effekte, ["Fade", "Rainbow"])
        XCTAssertEqual(angebot.overlays, ["rain"])
        XCTAssertEqual(angebot.paletten, ["Ocean"])
        XCTAssertEqual(angebot.ohneEffekt("rainbow"), ["klein"], "Groß-/Kleinschreibung zählt nicht; unbefragte Uhr nicht")
        XCTAssertEqual(angebot.ohneOverlay("rain"), ["klein"])
        XCTAssertEqual(angebot.ohnePalette("Ocean"), [], "leere Palettenliste: die Uhr prüft nicht")
    }

    /// Der Hinweis nennt genau die Uhren, die `Darstellung.pruefen` abweist.
    func testHinweisUndPruefungStimmenUeberein() {
        let f = Geraetefaehigkeiten(effekte: ["Fade"], overlays: ["rain"], paletten: ["Ocean"])
        let angebot = Darstellungsangebot(ziele: [Darstellungsziel(name: "x", faehigkeiten: f)])
        var d = Darstellung()
        d.effekt = "Rainbow"
        XCTAssertThrowsError(try d.pruefen(gegen: f))
        XCTAssertEqual(angebot.ohneEffekt("Rainbow"), ["x"])
        d.effekt = "fade"
        XCTAssertNoThrow(try d.pruefen(gegen: f))
        XCTAssertEqual(angebot.ohneEffekt("fade"), [])
    }
}
