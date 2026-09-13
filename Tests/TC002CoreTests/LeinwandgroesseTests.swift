import XCTest
@testable import TC002Core

/// Aus der Groesse folgt alles Weitere. Diese Tests halten fest, dass es
/// wirklich abgeleitet bleibt und nicht doch wieder als Sonderfall in der
/// Oberflaeche steht.
final class LeinwandgroesseTests: XCTestCase {

    func testDieDreiGroessen() {
        XCTAssertEqual(Leinwandgroesse.allCases.map { [$0.breite, $0.hoehe] },
                       [[8, 8], [16, 16], [52, 16]])
    }

    /// Ein 8×8 ist fuer sich keine Anzeige — die Sendezeile gibt es nur bei
    /// 16×52.
    func testNurDieGanzeAnzeigeLaesstSichSenden() {
        XCTAssertFalse(Leinwandgroesse.icon8.sendbar)
        XCTAssertFalse(Leinwandgroesse.icon16.sendbar)
        XCTAssertTrue(Leinwandgroesse.anzeige.sendbar)
    }

    /// Und die Nummer gibt es nur beim kanonischen LaMetric-Icon.
    func testNurDasAchtmalAchtHatEineNummer() {
        XCTAssertTrue(Leinwandgroesse.icon8.mitNummer)
        XCTAssertFalse(Leinwandgroesse.icon16.mitNummer)
        XCTAssertFalse(Leinwandgroesse.anzeige.mitNummer)
    }

    /// „Icon einfuegen" setzt ein 8×8 in eine ganze Anzeige — nicht in ein Icon.
    func testEinIconLaesstSichNurInDieAnzeigeSetzen() {
        XCTAssertEqual(Leinwandgroesse.allCases.filter(\.iconEinfuegbar), [.anzeige])
    }

    func testEineLeinwandFindetIhreGroesse() {
        XCTAssertEqual(Leinwandgroesse.fuer(Leinwand(breite: 8, hoehe: 8)), .icon8)
        XCTAssertEqual(Leinwandgroesse.fuer(Leinwand(breite: 16, hoehe: 16)), .icon16)
        XCTAssertEqual(Leinwandgroesse.fuer(Leinwand(breite: 52, hoehe: 16)), .anzeige)
        // 16×52 statt 52×16: keine der drei. Lieber nichts als das Falsche.
        XCTAssertNil(Leinwandgroesse.fuer(breite: 16, hoehe: 52))
        XCTAssertNil(Leinwandgroesse.fuer(breite: 32, hoehe: 32))
    }

    /// Die leere Leinwand hat die Masse ihrer Groesse — sonst legte ein
    /// Groessenwechsel die falsche an.
    func testDieLeereLeinwandPasstZurGroesse() {
        for groesse in Leinwandgroesse.allCases {
            let leer = groesse.leereLeinwand
            XCTAssertEqual(Leinwandgroesse.fuer(leer), groesse)
            XCTAssertTrue(leer.istLeer)
        }
    }

    /// Die drei Beschriftungen werden ueber eine Variable nachgeschlagen und
    /// stehen darum von Hand in `scripts/texte-sammeln.py`. Aendert sie
    /// jemand hier, faellt die Uebersetzung still aus — dieser Test nennt den
    /// Ort, an dem es mitzuziehen ist.
    func testDieBeschriftungenStehenAuchImSammler() throws {
        let skript = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/texte-sammeln.py")
        let inhalt = try String(contentsOf: skript, encoding: .utf8)
        for groesse in Leinwandgroesse.allCases {
            XCTAssertTrue(inhalt.contains("\"\(groesse.beschriftung)\""),
                          "„\(groesse.beschriftung)“ fehlt in DYNAMISCH — die Übersetzung fällt still aus")
        }
    }
}
