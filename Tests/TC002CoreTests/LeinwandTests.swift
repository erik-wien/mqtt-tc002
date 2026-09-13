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

    // MARK: - Das Pfeilkreuz

    func testVerschiebenRuecktJedesPixel() {
        var l = gemalte()                       // 8×8, (1,2) rot
        l.verschieben(dx: 1, dy: 0)
        XCTAssertNil(l.farbe(x: 1, y: 2))
        XCTAssertEqual(l.farbe(x: 2, y: 2), "#FF0000")
        l.verschieben(dx: 0, dy: 1)
        XCTAssertEqual(l.farbe(x: 2, y: 3), "#FF0000")
    }

    /// Der Kern der Entscheidung: umlaufend statt abschneidend. Ohne
    /// Rueckgaengig waere jeder Schritt sonst ein Verlust.
    func testWasHinausgeschobenWirdKommtGegenueberHerein() {
        var l = Leinwand(breite: 8, hoehe: 8)
        l.setzen(x: 7, y: 0, farbe: "#FF0000")
        l.verschieben(dx: 1, dy: 0)
        XCTAssertEqual(l.farbe(x: 0, y: 0), "#FF0000", "rechts hinaus, links herein")

        l.setzen(x: 0, y: 0, farbe: nil)
        l.setzen(x: 0, y: 7, farbe: "#00FF66")
        l.verschieben(dx: 0, dy: 1)
        XCTAssertEqual(l.farbe(x: 0, y: 0), "#00FF66", "unten hinaus, oben herein")
    }

    /// Und deshalb ist jeder Schritt genau umkehrbar.
    func testVierMalHinUndVierMalZurueckErgibtDasAusgangsbild() {
        var l = gemalte()
        l.setzen(x: 0, y: 0, farbe: "#112233")
        l.setzen(x: 7, y: 7, farbe: "#445566")
        let vorher = l.bilder
        for _ in 0..<4 { l.verschieben(dx: 1, dy: -1) }
        XCTAssertNotEqual(l.bilder, vorher, "vier Schritte ändern etwas")
        for _ in 0..<4 { l.verschieben(dx: -1, dy: 1) }
        XCTAssertEqual(l.bilder, vorher, "und die Gegenrichtung nimmt sie genau zurück")
    }

    /// Eine Animation, deren Bilder gegeneinander verrutschen, waere kaputt.
    func testAlleEinzelbilderRueckenGemeinsam() {
        var l = Leinwand(breite: 8, hoehe: 8)
        l.setzen(x: 0, y: 0, farbe: "#FF0000")
        l.anhaengen()
        l.setzen(x: 0, y: 0, farbe: "#00FF66")
        l.verschieben(dx: 1, dy: 0)
        XCTAssertEqual(l.bilder[0][1], "#FF0000")
        XCTAssertEqual(l.bilder[1][1], "#00FF66")
        XCTAssertNil(l.bilder[0][0])
        XCTAssertNil(l.bilder[1][0])
    }

    /// Auch auf der breiten Leinwand, wo Breite und Hoehe verschieden sind.
    func testVerschiebenAufDerGanzenAnzeige() {
        var l = Leinwand(breite: 52, hoehe: 16)
        l.setzen(x: 51, y: 15, farbe: "#FF0000")
        l.verschieben(dx: 1, dy: 1)
        XCTAssertEqual(l.farbe(x: 0, y: 0), "#FF0000")
    }

    /// Ein Schritt um die volle Kante ist kein Schritt.
    func testEinVollerUmlaufAendertNichts() {
        var l = gemalte()
        let vorher = l.bilder
        l.verschieben(dx: 8, dy: 8)
        XCTAssertEqual(l.bilder, vorher)
        l.verschieben(dx: 0, dy: 0)
        XCTAssertEqual(l.bilder, vorher)
    }


    // MARK: - Icon einsetzen (C2)

    /// **C2.** Hochrechnen ist ein Befehl: Ein 8×8 in einem 16×16 wird
    /// verdoppelt — jedes Pixel ein Viererblock, und zwar an der richtigen
    /// Stelle. Ein Faktor, der nur die Zahl vergroessert, aber nicht die
    /// Ecke mitrechnet, saehe fast richtig aus.
    func testEinAchterIconWirdImSechzehnerVerdoppelt() {
        var leinwand = Leinwandgroesse.icon16.leereLeinwand
        var pixel = [String?](repeating: nil, count: 64)
        pixel[1] = "#FF0000"          // x = 1, y = 0
        pixel[8 * 7] = "#00FF00"      // x = 0, y = 7 — die untere Ecke

        XCTAssertTrue(leinwand.iconEinsetzen(pixel, groesse: .icon8))
        for (x, y) in [(2, 0), (3, 0), (2, 1), (3, 1)] {
            XCTAssertEqual(leinwand.farbe(x: x, y: y), "#FF0000", "der Viererblock bei \(x)/\(y)")
        }
        XCTAssertNil(leinwand.farbe(x: 1, y: 0), "links daneben bleibt frei")
        XCTAssertNil(leinwand.farbe(x: 4, y: 0), "rechts daneben bleibt frei")
        XCTAssertEqual(leinwand.farbe(x: 0, y: 14), "#00FF00", "die untere Ecke landet unten")
        XCTAssertEqual(leinwand.farbe(x: 1, y: 15), "#00FF00")
    }

    /// In die Anzeige geht ein Icon in seiner Groesse — ein 8×8 senkrecht
    /// mittig auf Zeile 4, ein 16×16 ueber die volle Hoehe.
    func testInDieAnzeigeGehtEinIconInSeinerGroesse() {
        var leinwand = Leinwandgroesse.anzeige.leereLeinwand
        var acht = [String?](repeating: nil, count: 64)
        acht[0] = "#FF0000"
        XCTAssertTrue(leinwand.iconEinsetzen(acht, groesse: .icon8))
        XCTAssertEqual(leinwand.farbe(x: 0, y: 4), "#FF0000", "ein 8×8 schwimmt senkrecht mittig")
        XCTAssertNil(leinwand.farbe(x: 1, y: 4), "nicht verdoppelt — sonst frisst es die Breite")

        var sechzehn = [String?](repeating: nil, count: 256)
        sechzehn[0] = "#0000FF"
        var zweite = Leinwandgroesse.anzeige.leereLeinwand
        XCTAssertTrue(zweite.iconEinsetzen(sechzehn, groesse: .icon16))
        XCTAssertEqual(zweite.farbe(x: 0, y: 0), "#0000FF", "ein 16×16 füllt die volle Höhe")
    }

    /// Durchsichtige Quellpixel lassen die Flaeche in Ruhe, statt ein
    /// schwarzes Rechteck hineinzuradieren.
    func testDurchsichtigeStellenLassenDieFlaecheUnberuehrt() {
        var leinwand = Leinwandgroesse.anzeige.leereLeinwand
        leinwand.setzen(x: 3, y: 6, farbe: "#00FF66")
        XCTAssertTrue(leinwand.iconEinsetzen([String?](repeating: nil, count: 64), groesse: .icon8))
        XCTAssertEqual(leinwand.farbe(x: 3, y: 6), "#00FF66")
    }

    /// Und was nicht hineingehoert, richtet **nichts** an: kein halb
    /// gesetztes Bild, kein Schritt fuer „Rueckgaengig".
    func testWasNichtHineingehoertVeraendertNichts() {
        var klein = Leinwandgroesse.icon8.leereLeinwand
        XCTAssertFalse(klein.iconEinsetzen([String?](repeating: "#FFFFFF", count: 256),
                                           groesse: .icon16),
                       "ein 16×16 lässt sich nicht in ein 8×8 quetschen")
        XCTAssertTrue(klein.istLeer, "eine abgelehnte Einsetzung hat trotzdem gemalt")

        var gross = Leinwandgroesse.anzeige.leereLeinwand
        XCTAssertFalse(gross.iconEinsetzen([String?](repeating: "#FFFFFF", count: 17),
                                           groesse: .icon8),
                       "ein Raster, das nicht zur genannten Größe passt, wird angenommen")
        XCTAssertTrue(gross.istLeer)
    }

}
