import XCTest
@testable import TC002Core

/// Die Rechnung hinter dem gemeinsamen Editor. Sie liegt im Kern, damit sie
/// hier geprueft werden kann statt an einer Oberflaeche.
final class LeinwandTests: XCTestCase {

    private func gemalte(_ breite: Int = 8, _ hoehe: Int = 8) -> Leinwand {
        var l = Leinwand(breite: breite, hoehe: hoehe)
        l.setzen(x: 1, y: 2, farbe: "#FF0000")
        return l
    }

    func testEineNeueLeinwandHatGenauEinLeeresBild() {
        let l = Leinwand(breite: 16, hoehe: 16)
        XCTAssertEqual(l.bilder.count, 1)
        XCTAssertEqual(l.bild.count, 256)
        XCTAssertTrue(l.istLeer)
    }

    func testGemaltesIstNichtLeer() {
        XCTAssertFalse(gemalte().istLeer)
        XCTAssertEqual(gemalte().farbe(x: 1, y: 2), "#FF0000")
    }

    /// Ein zweites, leeres Bild macht die Leinwand ebenfalls „nicht leer" —
    /// sonst fragte „Neu" nicht nach und wuerfe eine angefangene Bildleiste weg.
    func testZweiBilderZaehlenAlsNichtLeer() {
        var l = Leinwand(breite: 8, hoehe: 8)
        l.anhaengen()
        XCTAssertFalse(l.istLeer)
    }

    func testAusserhalbGesetzteneWerdenVerworfen() {
        var l = Leinwand(breite: 8, hoehe: 8)
        l.setzen(x: -1, y: 0, farbe: "#FFFFFF")
        l.setzen(x: 8, y: 0, farbe: "#FFFFFF")
        l.setzen(x: 0, y: 8, farbe: "#FFFFFF")
        XCTAssertTrue(l.istLeer)
    }

    func testAnhaengenSchaltetAufDasNeueLeereBildUm() {
        var l = gemalte()
        l.anhaengen()
        XCTAssertEqual(l.bilder.count, 2)
        XCTAssertEqual(l.aktuell, 1)
        XCTAssertNil(l.farbe(x: 1, y: 2), "das angehängte Bild ist leer")
        XCTAssertEqual(l.bilder[0][2 * 8 + 1], "#FF0000", "das erste bleibt, wie es war")
    }

    func testVerdoppelnLegtDieKopieDahinterUndFolgtIhr() {
        var l = gemalte()
        l.anhaengen()          // bilder: [gemalt, leer], aktuell = 1
        l.waehlen(0)
        l.verdoppeln()
        XCTAssertEqual(l.bilder.count, 3)
        XCTAssertEqual(l.aktuell, 1, "die Kopie steht hinter dem Original")
        XCTAssertEqual(l.farbe(x: 1, y: 2), "#FF0000")
        XCTAssertNil(l.bilder[2][2 * 8 + 1], "das vorher zweite ist jetzt das dritte")
    }

    func testEntfernenLaesstDasLetzteBildStehen() {
        var l = gemalte()
        l.entfernen()
        XCTAssertEqual(l.bilder.count, 1, "eine Leinwand ohne Bild gibt es nicht")
        XCTAssertEqual(l.farbe(x: 1, y: 2), "#FF0000")
    }

    func testEntfernenRuecktDieWahlAufDenVorgaenger() {
        var l = Leinwand(breite: 8, hoehe: 8)
        l.anhaengen()
        l.anhaengen()          // drei Bilder, aktuell = 2
        l.entfernen()
        XCTAssertEqual(l.bilder.count, 2)
        XCTAssertEqual(l.aktuell, 1)
    }

    func testTauschenFolgtDemBild() {
        var l = gemalte()
        l.anhaengen()          // [gemalt, leer], aktuell = 1
        l.tauschen(um: -1)
        XCTAssertEqual(l.aktuell, 0)
        XCTAssertNil(l.farbe(x: 1, y: 2), "das leere Bild steht jetzt vorn und ist gewählt")
        XCTAssertEqual(l.bilder[1][2 * 8 + 1], "#FF0000")
    }

    func testTauschenUeberDenRandTutNichts() {
        var l = gemalte()
        l.anhaengen()
        l.waehlen(0)
        l.tauschen(um: -1)
        XCTAssertEqual(l.aktuell, 0)
        XCTAssertEqual(l.bilder[0][2 * 8 + 1], "#FF0000", "nichts wurde vertauscht")
    }

    func testBildLeerenLaesstDieUebrigenStehen() {
        var l = gemalte()
        l.verdoppeln()         // zwei gleiche, aktuell = 1
        l.bildLeeren()
        XCTAssertNil(l.farbe(x: 1, y: 2))
        XCTAssertEqual(l.bilder[0][2 * 8 + 1], "#FF0000")
    }

    func testZuruecksetzenGehtAufEinLeeresBild() {
        var l = gemalte()
        l.verzoegerung = 1.5
        l.anhaengen()
        l.zuruecksetzen()
        XCTAssertTrue(l.istLeer)
        XCTAssertEqual(l.aktuell, 0)
        XCTAssertEqual(l.verzoegerung, 0.2)
    }

    func testWaehlenAusserhalbBleibtOhneWirkung() {
        var l = Leinwand(breite: 8, hoehe: 8)
        l.waehlen(7)
        XCTAssertEqual(l.aktuell, 0)
    }

    // MARK: - Das Dateiformat

    func testCodableRundlauf() throws {
        var l = Leinwand(breite: 52, hoehe: 16, verzoegerung: 0.35)
        l.setzen(x: 51, y: 15, farbe: "#00FF66")
        l.anhaengen()
        let daten = try JSONEncoder().encode(l)
        XCTAssertEqual(try JSONDecoder().decode(Leinwand.self, from: daten), l)
    }

    /// Ein gemerkter Stand kann aus einer Fassung mit anderer Groesse stammen
    /// oder von Hand verbogen sein. Unpassende Raster fliegen raus, statt eine
    /// halbe Leinwand zu ergeben.
    func testUnpassendeRasterWerdenVerworfen() throws {
        let json = """
        {"breite":8,"hoehe":8,"bilder":[[],[\(Array(repeating: "null", count: 64).joined(separator: ","))]],"aktuell":1,"verzoegerung":0.5}
        """
        let l = try JSONDecoder().decode(Leinwand.self, from: Data(json.utf8))
        XCTAssertEqual(l.bilder.count, 1, "das leere Raster ist raus")
        XCTAssertEqual(l.aktuell, 0, "der Index zeigte auf ein Bild, das es nicht mehr gibt")
        XCTAssertEqual(l.verzoegerung, 0.5)
    }

    func testOhneBrauchbaresRasterBleibtEineLeereLeinwand() throws {
        let json = #"{"breite":8,"hoehe":8,"bilder":[],"aktuell":0,"verzoegerung":0.2}"#
        let l = try JSONDecoder().decode(Leinwand.self, from: Data(json.utf8))
        XCTAssertEqual(l.bilder.count, 1)
        XCTAssertTrue(l.istLeer)
    }

    func testGroesseNullWirdAbgelehnt() {
        let json = #"{"breite":0,"hoehe":8,"bilder":[],"aktuell":0,"verzoegerung":0.2}"#
        XCTAssertThrowsError(try JSONDecoder().decode(Leinwand.self, from: Data(json.utf8)))
    }

    func testUnpassendeBilderImKonstruktorErgebenNil() {
        XCTAssertNil(Leinwand(breite: 8, hoehe: 8, bilder: []))
        XCTAssertNil(Leinwand(breite: 8, hoehe: 8, bilder: [[String?](repeating: nil, count: 63)]))
        XCTAssertNotNil(Leinwand(breite: 8, hoehe: 8, bilder: [[String?](repeating: nil, count: 64)]))
    }
}
