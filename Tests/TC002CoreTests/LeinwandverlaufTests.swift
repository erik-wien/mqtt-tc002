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

// MARK: - Weicht die Leinwand vom Bestand ab?

/// „Ungesichert" heisst nicht „geht beim Beenden verloren" — der
/// Arbeitsstand ueberlebt den Programmlauf ohnehin —, sondern „weicht vom
/// Bestand ab". Genau das entscheidet, ob „Neu", ein Groessenwechsel, ein
/// geoeffnetes Bild oder ein geladenes Icon vorher fragen muessen.
extension LeinwandverlaufTests {

    /// Nie gesichert und etwas darauf: Es liegt nirgends, also weicht es ab.
    /// Eine leere Leinwand dagegen hat nichts zu verlieren.
    ///
    /// Mutation: `guard let gesichert else { return !jetzt.istLeer }` zu
    /// `return false` — dann fragt nach einer gemalten, nie gesicherten
    /// Zeichnung niemand mehr, und sie ist beim naechsten Laden weg.
    func testOhneGesichertenStandWeichtJedeNichtLeereLeinwandAb() {
        let verlauf = Leinwandverlauf()
        XCTAssertFalse(verlauf.weichtAb(Leinwand(breite: 8, hoehe: 8)))
        XCTAssertTrue(verlauf.weichtAb(gemalt("#FF0000")))
    }

    /// Ein eben geoeffnetes Bild ist nicht ungesichert — es liegt genau so im
    /// Bestand. Erst der naechste Strich macht es dazu.
    ///
    /// Mutation: `gesichertMerken` zu einem leeren Rumpf — dann fragt der
    /// Editor nach jedem Oeffnen bei allem weiter nach, und die Rueckfrage,
    /// die immer kommt, wird weggeklickt.
    func testEinGeoeffnetesUndUnveraendertesBildWeichtNichtAb() {
        var verlauf = Leinwandverlauf()
        let geoeffnet = gemalt("#FF0000")
        verlauf.gesichertMerken(geoeffnet)
        XCTAssertFalse(verlauf.weichtAb(geoeffnet))

        var veraendert = geoeffnet
        veraendert.setzen(x: 3, y: 3, farbe: "#00FF00")
        XCTAssertTrue(verlauf.weichtAb(veraendert))
    }

    /// Gefragt wird nicht, ob etwas geschehen ist, sondern ob es jetzt
    /// anders aussieht. Wer seinen Strich zuruecknimmt, steht wieder auf dem
    /// gesicherten Stand.
    ///
    /// Mutation: `weichtAb` zu `kannZurueck || kannVor` — also „es ist etwas
    /// geschehen" statt „es sieht anders aus". Der Test faellt beim
    /// Rueckgaengig: Der Stapel zeigt danach nach vorn, die Leinwand aber
    /// steht wieder genau auf dem gesicherten Stand.
    func testEineRueckgaengigeAenderungZaehltNicht() {
        var verlauf = Leinwandverlauf()
        let gesichert = gemalt("#FF0000")
        verlauf.gesichertMerken(gesichert)

        var jetzt = gesichert
        verlauf.merken(jetzt)
        jetzt.setzen(x: 3, y: 3, farbe: "#00FF00")
        XCTAssertTrue(verlauf.weichtAb(jetzt))

        let zurueck = verlauf.zurueck(von: jetzt)
        XCTAssertEqual(zurueck, gesichert)
        XCTAssertFalse(verlauf.weichtAb(zurueck!))
        // Und der Stapel ist dabei nicht leer — er zeigt jetzt nach vorn.
        XCTAssertTrue(verlauf.kannVor)
    }

    /// Welches Einzelbild gerade bearbeitet wird, steht in keiner Datei; die
    /// Standzeit dagegen schon.
    ///
    /// Mutation: `gleichesBild(wie:)` durch `==` ersetzen — dann gilt ein
    /// Klick auf Bild zwei als Abweichung, und der Editor fragt vor jedem
    /// Oeffnen, obwohl nichts zu verlieren ist.
    func testDasGewaehlteEinzelbildIstKeineAbweichungDieStandzeitSchon() {
        var verlauf = Leinwandverlauf()
        var gesichert = gemalt("#FF0000")
        gesichert.anhaengen()
        gesichert.waehlen(0)
        verlauf.gesichertMerken(gesichert)

        var geblaettert = gesichert
        geblaettert.waehlen(1)
        XCTAssertFalse(verlauf.weichtAb(geblaettert))

        var langsamer = gesichert
        langsamer.verzoegerung += 0.3
        XCTAssertTrue(verlauf.weichtAb(langsamer),
                      "die Standzeit steht in der Datei — sie zu aendern weicht ab")
    }

    /// „Neu" wirft den Weg weg und den Bezug zum Bestand: Danach liegt
    /// eine leere Flaeche auf dem Tisch, die in keiner Datei steht.
    ///
    /// Mutation: `gesichert = nil` aus `leeren()` entfernen — dann gilt nach
    /// „Neu" der alte Stand weiter, und der Editor haelt ein danach gemaltes
    /// Bild fuer gesichert.
    func testLeerenVergisstAuchDenGesichertenStand() {
        var verlauf = Leinwandverlauf()
        let gesichert = gemalt("#FF0000")
        verlauf.gesichertMerken(gesichert)
        verlauf.leeren()
        XCTAssertTrue(verlauf.weichtAb(gesichert))
    }
}
