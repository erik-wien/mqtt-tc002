import XCTest
@testable import TC002Core

/// Rueckgaengig und Wiederherstellen.
final class LeinwandverlaufTests: XCTestCase {

    private func gemalt(_ farbe: String) -> Leinwand {
        var l = Leinwand(breite: 8, hoehe: 8)
        l.setzen(x: 0, y: 0, farbe: farbe)
        return l
    }

    func testOhneSchrittGehtEsWederZurueckNochVor() {
        var verlauf = Leinwandverlauf()
        XCTAssertFalse(verlauf.kannZurueck)
        XCTAssertFalse(verlauf.kannVor)
        XCTAssertNil(verlauf.zurueck(von: gemalt("#FF0000")))
        XCTAssertNil(verlauf.vor(von: gemalt("#FF0000")))
    }

    func testEinSchrittZurueckUndWiederVor() {
        var verlauf = Leinwandverlauf()
        let vorher = Leinwand(breite: 8, hoehe: 8)
        let nachher = gemalt("#FF0000")
        verlauf.merken(vorher)
        XCTAssertTrue(verlauf.kannZurueck)
        XCTAssertEqual(verlauf.zurueck(von: nachher), vorher)
        XCTAssertFalse(verlauf.kannZurueck)
        XCTAssertTrue(verlauf.kannVor)
        XCTAssertEqual(verlauf.vor(von: vorher), nachher)
        XCTAssertFalse(verlauf.kannVor)
    }

    /// Ein neuer Schritt macht den Weg nach vorn hinfaellig — von hier aus
    /// fuehrt er nicht mehr dorthin.
    func testEinNeuerSchrittWirftDenWegNachVornWeg() {
        var verlauf = Leinwandverlauf()
        verlauf.merken(Leinwand(breite: 8, hoehe: 8))
        _ = verlauf.zurueck(von: gemalt("#FF0000"))
        XCTAssertTrue(verlauf.kannVor)
        verlauf.merken(gemalt("#00FF00"))
        XCTAssertFalse(verlauf.kannVor)
    }

    /// Fuenfzig Schritte, nicht mehr — sonst waechst der Stapel ohne Grenze.
    /// Der aelteste faellt heraus, nicht der juengste.
    func testDerStapelIstBegrenztUndWirftDasAeltesteWeg() {
        var verlauf = Leinwandverlauf()
        for i in 0...Leinwandverlauf.grenze {
            verlauf.merken(gemalt(String(format: "#%06X", i)))
        }
        XCTAssertEqual(verlauf.tiefe, Leinwandverlauf.grenze)
        // Ganz zurueckgehen: Der erste Stand darf nicht mehr auftauchen.
        var stand = gemalt("#FFFFFF")
        var gesehen: [Leinwand] = []
        while let vorheriger = verlauf.zurueck(von: stand) {
            gesehen.append(vorheriger)
            stand = vorheriger
        }
        XCTAssertEqual(gesehen.count, Leinwandverlauf.grenze)
        XCTAssertFalse(gesehen.contains(gemalt("#000000")),
                       "der älteste Schritt hätte herausfallen müssen")
        XCTAssertTrue(gesehen.contains(gemalt("#000001")))
    }

    /// Ein Groessenwechsel ist ein Schritt — und weil `Leinwand` ihre Groesse
    /// selbst traegt, bringt Rueckgaengig sie mit zurueck.
    func testRueckgaengigStelltAuchDieGroesseWiederHer() {
        var verlauf = Leinwandverlauf()
        let anzeige = Leinwandgroesse.anzeige.leereLeinwand
        verlauf.merken(anzeige)
        let zurueck = verlauf.zurueck(von: Leinwandgroesse.icon8.leereLeinwand)
        XCTAssertEqual(zurueck.flatMap(Leinwandgroesse.fuer), .anzeige)
    }

    func testLeerenNimmtBeideRichtungen() {
        var verlauf = Leinwandverlauf()
        verlauf.merken(Leinwand(breite: 8, hoehe: 8))
        _ = verlauf.zurueck(von: gemalt("#FF0000"))
        verlauf.leeren()
        XCTAssertFalse(verlauf.kannZurueck)
        XCTAssertFalse(verlauf.kannVor)
    }
}
