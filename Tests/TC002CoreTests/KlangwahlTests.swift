import XCTest
@testable import TC002Core

final class KlangwahlTests: XCTestCase {
    func testKeinerUndLeereWahlSindStumm() {
        XCTAssertEqual(Klangwahl().klaenge(nachrichtentext: "Hallo"), [])
        XCTAssertEqual(Klangwahl(art: .uhr).klaenge(nachrichtentext: "Hallo"), [], "kein Name gewählt")
        XCTAssertEqual(Klangwahl(art: .vorlesen).klaenge(nachrichtentext: "  "), [])
    }

    func testVonDerUhrSchicktDenNamenMitLoop() {
        let k = Klangwahl(art: .uhr, name: "ping", wiederholen: true).klaenge(nachrichtentext: "x")
        XCTAssertEqual(k, [Klang(.datei("ping"), wiederholen: true)])
    }

    func testVorlesenNimmtDenEigenenTextSonstDieNachricht() {
        XCTAssertEqual(Klangwahl(art: .vorlesen).klaenge(nachrichtentext: " Hello "), [Klang(.sprache("Hello"))])
        XCTAssertEqual(Klangwahl(art: .vorlesen, sprechtext: "Dinner").klaenge(nachrichtentext: "Hello"),
                       [Klang(.sprache("Dinner"))])
    }

    func testLangerTextWirdAufDieGrenzeGekuerztOhneZeichenzuhalbieren() throws {
        let lang = String(repeating: "ä", count: 400)
        let k = Klangwahl(art: .vorlesen).klaenge(nachrichtentext: lang)
        guard case .sprache(let satz)? = k.first?.quelle else { return XCTFail() }
        XCTAssertLessThanOrEqual(satz.utf8.count, Klangwahl.sprechgrenze)
        XCTAssertEqual(satz, String(repeating: "ä", count: 256))
        try k[0].pruefen(inBenachrichtigung: true)
    }

    func testGesperrteWahlGehtStummHinaus() {
        let ohne = Geraetefaehigkeiten(ton: Tonfaehigkeiten())
        let wahl = Klangwahl(art: .vorlesen)
        XCTAssertFalse(wahl.gekonnt(von: ohne))
        XCTAssertEqual(wahl.wirksam(von: ohne), Klangwahl())
        XCTAssertTrue(wahl.gekonnt(von: nil), "ungeprüft, solange nichts abgefragt ist")
        XCTAssertTrue(Klangwahl(art: .vorlesen).gekonnt(von: Geraetefaehigkeiten(ton: Tonfaehigkeiten(speech: true))))
        XCTAssertFalse(Klangwahl(art: .uhr).gekonnt(von: Geraetefaehigkeiten(ton: Tonfaehigkeiten(speech: true))))
    }

    func testAblageRundlaufUndNachsicht() {
        let w = Klangwahl(art: .uhr, name: "gong", sprechtext: "a", wiederholen: true)
        XCTAssertEqual(Klangwahl(rawValue: w.rawValue), w)
        XCTAssertEqual(Klangwahl(rawValue: "{}"), Klangwahl())
        XCTAssertEqual(Klangwahl(rawValue: #"{"art":"unbekannt"}"#), Klangwahl())
    }

    func testNachrichtwahlTraegtDenKlangInDieOptionen() throws {
        let o = Nachrichtwahl(klang: Klangwahl(art: .vorlesen)).optionen(nachrichtentext: "Hi")
        XCTAssertEqual(o.klang, [Klang(.sprache("Hi"))])
        XCTAssertTrue(Nachrichtwahl().optionen.klang.isEmpty)
        XCTAssertTrue(try NGNutzlast.benachrichtigung(Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "Hi", weg: .text))), o).contains(#""sound":{"speech":"Hi"}"#))
    }
}
