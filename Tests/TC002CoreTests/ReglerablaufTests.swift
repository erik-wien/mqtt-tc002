import XCTest
@testable import TC002Core

final class ReglerablaufTests: XCTestCase {
    func testZiehenSendetGenauEinmalBeimLoslassen() {
        var a = Reglerablauf()
        a.bearbeitet(true)
        a.aendert(10); a.aendert(20); a.aendert(30)
        XCTAssertNil(a.ruhe(), "während der Berührung sendet nur das Loslassen")
        a.bearbeitet(false)
        XCTAssertEqual(a.loslassen(), 30)
        XCTAssertNil(a.loslassen(), "ein zweites Loslassen sendet nichts")
        XCTAssertNil(a.ruhe())
        XCTAssertEqual(a.phase, .sendend)
    }

    func testTastaturOhneLoslassenSendetNachRuhe() {
        var a = Reglerablauf()
        a.aendert(41.6)
        XCTAssertEqual(a.ruhe(), 42)
        XCTAssertNil(a.ruhe())
    }

    func testBestaetigungUndAusblenden() {
        var a = Reglerablauf()
        a.aendert(5); _ = a.loslassen()
        a.antwort(erfolg: true)
        XCTAssertEqual(a.phase, .bestaetigt)
        a.uhrMeldet()
        XCTAssertEqual(a.phase, .bestaetigt, "das Häkchen bleibt, der Wert der Uhr gilt wieder")
        XCTAssertNil(a.wert)
        a.haekchenFertig()
        XCTAssertEqual(a.phase, .ruhig)
    }

    func testFehlschlagVerwirftDenGezogenenWert() {
        var a = Reglerablauf()
        a.aendert(5); _ = a.loslassen()
        a.antwort(erfolg: false)
        XCTAssertEqual(a.phase, .ruhig)
        XCTAssertNil(a.wert)
    }

    func testSpaeteAntwortStoertNeuesZiehenNicht() {
        var a = Reglerablauf()
        a.aendert(5); _ = a.loslassen()
        a.aendert(9)
        a.antwort(erfolg: true)
        XCTAssertEqual(a.phase, .gezogen)
        XCTAssertEqual(a.wert, 9)
    }

    func testUhrMeldetLaesstLaufendesZiehenStehen() {
        var a = Reglerablauf()
        a.aendert(7)
        a.uhrMeldet()
        XCTAssertEqual(a.wert, 7)
    }

    func testUhrwechselVerwirftAlles() {
        var a = Reglerablauf()
        a.aendert(5); _ = a.loslassen(); a.antwort(erfolg: true)
        a.zuruecksetzen()
        XCTAssertEqual(a, Reglerablauf())
    }
}
