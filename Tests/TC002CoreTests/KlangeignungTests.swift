import XCTest
@testable import TC002Core

/// Welche Klänge welche Uhr spielt: die Regel hinter den gesperrten Auswahlpunkten,
/// dem Weglassen des Klangs bei gemischten Zielen und der gesperrten MP3-Ablage.
final class KlangeignungTests: XCTestCase {
    private let tc001 = Tonfaehigkeiten(mp3: false, rtttl: true, song: false, speech: false, radio: false,
                                        url: false, effect: false, clip: false, track: false)
    private let tc002 = Tonfaehigkeiten(mp3: true, rtttl: true, song: true, speech: true, radio: true,
                                        url: true, effect: true, clip: true, track: false)
    private let listen = Tonlisten(melodien: ["ping"], mp3: ["gong"])

    private func ziel(_ name: String, _ ton: Tonfaehigkeiten?, listen: Tonlisten? = nil) -> Klangziel {
        Klangziel(id: UUID(), name: name, faehigkeiten: Geraetefaehigkeiten(ton: ton), listen: listen)
    }

    func testAuskunftDerTC001AusDerGemessenenAntwort() throws {
        let antwort: [String: Any] = [
            "effects": ["Fade"], "platform": ["id": "esp32"],
            "audio": ["mp3": false, "rtttl": true, "song": false, "speech": false, "track": false,
                      "radio": false, "url": false, "effect": false, "clip": false]]
        let f = try XCTUnwrap(Geraetefaehigkeiten(antwort: antwort))
        XCTAssertEqual(f.ton, tc001)
        XCTAssertFalse(f.kann(.mp3))
        XCTAssertTrue(f.kann(.melodie))
        XCTAssertTrue(f.kann(.rtttl))
        XCTAssertFalse(f.kann(.sprache))
    }

    func testFehlendeAuskunftIstUnbekanntUndSperrtNichts() throws {
        let ohne = try XCTUnwrap(Geraetefaehigkeiten(antwort: ["effects": ["Fade"]]))
        XCTAssertNil(ohne.ton)
        for art in Klangart.allCases { XCTAssertTrue(ohne.kann(art), "\(art)") }
        // Ein fehlender Schalter in vorhandenem `audio` ist ebenso unbekannt.
        let teil = try XCTUnwrap(Geraetefaehigkeiten(antwort: ["effects": ["Fade"], "audio": ["mp3": false]]))
        XCTAssertFalse(teil.kann(.mp3))
        XCTAssertTrue(teil.kann(.sprache))
        XCTAssertTrue(Geraetefaehigkeiten().kann(.mp3))
    }

    func testEinNameIstMP3OderMelodieNachDenListen() {
        XCTAssertEqual(Klang(.datei("gong")).arten(listen: listen), [.mp3])
        XCTAssertEqual(Klang(.datei("ping")).arten(listen: listen), [.melodie])
        XCTAssertEqual(Klang(.datei("neu")).arten(listen: listen), [.mp3, .melodie])
        XCTAssertEqual(Klang(.datei("neu")).arten(listen: nil), [.mp3, .melodie])
        XCTAssertEqual(Klang(.datei("MELODIES/ping")).arten(listen: nil), [.melodie])
        XCTAssertEqual(Klang(.datei("https://example.com/a.mp3")).arten(listen: nil), [.adresse])
        XCTAssertEqual(Klang(.sender("Fm4")).arten(listen: nil), [.radio])
    }

    func testTC001SpieltMelodienAberKeineMP3() {
        let f = Geraetefaehigkeiten(ton: tc001)
        XCTAssertTrue(Klang(.datei("ping")).gekonnt(von: f, listen: listen))
        XCTAssertFalse(Klang(.datei("gong")).gekonnt(von: f, listen: listen))
        XCTAssertTrue(Klang(.rtttl("a:d=4:c")).gekonnt(von: f))
        XCTAssertFalse(Klang(.sprache("Hi")).gekonnt(von: f))
        // Ein unbekannter Name könnte eine Melodie sein.
        XCTAssertTrue(Klang(.datei("neu")).gekonnt(von: f, listen: listen))
    }

    func testPruefenWeistEineMP3AufDerTC001Ab() {
        let f = Geraetefaehigkeiten(ton: tc001)
        XCTAssertThrowsError(try Klang(.datei("gong")).pruefen(faehigkeiten: f, listen: listen)) {
            XCTAssertEqual($0 as? KlangFehler, .nichtGekonnt(faehigkeit: "audio.mp3"))
        }
        XCTAssertNoThrow(try Klang(.datei("ping")).pruefen(faehigkeiten: f, listen: listen))
    }

    func testKlangwahlMitNamenFolgtDerArt() {
        let f = Geraetefaehigkeiten(ton: tc001)
        XCTAssertFalse(Klangwahl(art: .uhr, name: "gong").gekonnt(von: f, listen: listen))
        XCTAssertTrue(Klangwahl(art: .uhr, name: "ping").gekonnt(von: f, listen: listen))
        XCTAssertTrue(Klangwahl(art: .uhr).gekonnt(von: f, listen: listen), "ohne Namen genügt eines von beiden")
        XCTAssertFalse(Klangwahl(art: .vorlesen).gekonnt(von: f))
        XCTAssertTrue(Klangwahl(art: .vorlesen).gekonnt(von: Geraetefaehigkeiten(ton: tc002)))
        XCTAssertEqual(Klangwahl(art: .uhr, name: "gong").wirksam(von: f, listen: listen), Klangwahl())
    }

    func testGemischteZieleBekommenDenKlangNurWoErSpielt() {
        let a = ziel("Küche", tc002, listen: listen)
        let b = ziel("Flur", tc001, listen: listen)
        let klaenge = [Klang(.sprache("Hallo"))]
        let v = Klangeignung.verteilen(klaenge, an: [a, b])
        XCTAssertEqual(v.klaenge[a.id], klaenge)
        XCTAssertEqual(v.klaenge[b.id], [])
        XCTAssertEqual(v.uebersprungeneNamen, ["Flur"])
        XCTAssertEqual(Klangeignung.verteilen([], an: [a, b]).uebersprungen, [])
    }

    func testEineListeBehaeltNurDasSpielbare() {
        let b = ziel("Flur", tc001, listen: listen)
        let v = Klangeignung.verteilen([Klang(.datei("gong")), Klang(.datei("ping"))], an: [b])
        XCTAssertEqual(v.klaenge[b.id], [Klang(.datei("ping"))])
        XCTAssertEqual(v.uebersprungeneNamen, ["Flur"])
    }

    func testGemeinsameMengeUndSperrgruende() {
        let a = ziel("Küche", tc002), b = ziel("Flur", tc001)
        XCTAssertEqual(Klangeignung.gemeinsam([a, b]), [.melodie, .rtttl])
        XCTAssertEqual(Klangeignung.gemeinsam([a]), Set(Klangart.allCases))
        XCTAssertEqual(Klangeignung.gemeinsam([]), Set(Klangart.allCases))
        XCTAssertEqual(Klangeignung.ohne(.mp3, in: [a, b]).map(\.name), ["Flur"])
        XCTAssertEqual(Klangeignung.ohne(Klangwahl(art: .vorlesen), in: [a, b]).map(\.name), ["Flur"])
        XCTAssertTrue(Klangeignung.teilweise(Klangwahl(art: .vorlesen), in: [a, b]))
        XCTAssertFalse(Klangeignung.teilweise(Klangwahl(art: .vorlesen), in: [b]))
        XCTAssertFalse(Klangeignung.teilweise(Klangwahl(art: .vorlesen), in: [a]))
    }

    func testUnbekannteUhrWirdNichtAusgesperrt() {
        let u = Klangziel(id: UUID(), name: "Neu")
        XCTAssertEqual(Klangeignung.verteilen([Klang(.sprache("x"))], an: [u]).uebersprungen, [])
        XCTAssertTrue(Klangeignung.mp3Hochladbar(nil))
        XCTAssertTrue(Klangeignung.mp3Hochladbar(Geraetefaehigkeiten()))
        XCTAssertFalse(Klangeignung.mp3Hochladbar(Geraetefaehigkeiten(ton: tc001)))
    }
}
