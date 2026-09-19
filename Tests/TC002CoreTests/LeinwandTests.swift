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

    /// C2: Hochrechnen ist ein Befehl: Ein 8×8 in einem 16×16 wird
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

    /// Und was nicht hineingehoert, richtet nichts an: kein halb gesetztes
    /// Bild, kein Schritt fuer „Rueckgaengig".
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

extension LeinwandTests {
    /// Verschieben trifft entweder die ganze Animation oder allein das
    /// gewählte Einzelbild.
    func testVerschiebenTrifftWahlweiseNurDasGewaehlteBild() {
        var leinwand = Leinwand(breite: 2, hoehe: 1)
        leinwand.setzen(x: 0, y: 0, farbe: "#FF0000")
        leinwand.anhaengen()
        leinwand.waehlen(1)
        leinwand.setzen(x: 0, y: 0, farbe: "#00FF00")

        var alle = leinwand
        alle.verschieben(dx: 1, dy: 0)
        XCTAssertEqual(alle.bilder[0], [nil, "#FF0000"], "das erste Bild ist nicht mitgewandert")
        XCTAssertEqual(alle.bilder[1], [nil, "#00FF00"], "das zweite Bild ist nicht mitgewandert")

        var eines = leinwand
        eines.verschieben(dx: 1, dy: 0, nurDieses: true)
        XCTAssertEqual(eines.bilder[0], ["#FF0000", nil], "das erste Bild wurde mitverschoben")
        XCTAssertEqual(eines.bilder[1], [nil, "#00FF00"], "das gewählte Bild ist nicht gewandert")
    }
}

// MARK: - Drehen und Spiegeln

extension LeinwandTests {
    /// Eine Vierteldrehung setzt jedes Pixel an seinen Platz — und nicht bloß
    /// irgendwohin: Ein Fehler in der Ecke sieht auf einem 8×8 fast richtig
    /// aus, deshalb ein Punkt abseits der Mitte und beide Richtungen.
    func testDrehenSetztJedesPixelAnSeinenPlatz() {
        var rechts = gemalte()                  // 8×8, (1,2) rot
        XCTAssertTrue(rechts.umformen(.rechtsherum))
        XCTAssertNil(rechts.farbe(x: 1, y: 2))
        XCTAssertEqual(rechts.farbe(x: 5, y: 1), "#FF0000", "im Uhrzeigersinn geht (1,2) nach (5,1)")

        var links = gemalte()
        XCTAssertTrue(links.umformen(.linksherum))
        XCTAssertEqual(links.farbe(x: 2, y: 6), "#FF0000", "gegen den Uhrzeigersinn nach (2,6)")
    }

    /// Vier Vierteldrehungen sind eine ganze — und die Gegenrichtung nimmt
    /// eine Drehung genau zurück.
    func testVierDrehungenErgebenDasAusgangsbild() {
        var l = gemalte()
        l.setzen(x: 0, y: 0, farbe: "#112233")
        l.setzen(x: 7, y: 3, farbe: "#445566")
        let vorher = l.bilder

        for _ in 0..<4 { l.umformen(.rechtsherum) }
        XCTAssertEqual(l.bilder, vorher)

        l.umformen(.rechtsherum)
        XCTAssertNotEqual(l.bilder, vorher, "eine Drehung ändert etwas")
        l.umformen(.linksherum)
        XCTAssertEqual(l.bilder, vorher, "und die Gegenrichtung nimmt sie zurück")
    }

    /// Die Entscheidung, die nicht der Übersetzer trifft: Eine gedrehte
    /// 52 × 16 wäre 16 × 52 und passt auf keine Uhr. Gedreht wird darum gar
    /// nicht, statt stillschweigend 36 Spalten wegzuschneiden.
    func testEineBreiteAnzeigeLaesstSichNichtDrehen() {
        var l = Leinwand(breite: 52, hoehe: 16)
        l.setzen(x: 51, y: 15, farbe: "#FF0000")
        let vorher = l.bilder
        XCTAssertFalse(l.drehbar)
        XCTAssertFalse(l.umformen(.rechtsherum), "gemeldet wird, dass nichts geschehen ist")
        XCTAssertFalse(l.umformen(.linksherum))
        XCTAssertEqual(l.bilder, vorher, "und es ist auch wirklich nichts geschehen")
    }

    /// Spiegeln hat das Formatproblem nicht: Breite und Höhe bleiben, wie sie
    /// sind. Darum auf der breiten Anzeige geprüft.
    func testSpiegelnGehtAuchAufDerBreitenAnzeige() {
        var l = Leinwand(breite: 52, hoehe: 16)
        l.setzen(x: 51, y: 15, farbe: "#FF0000")

        var waagrecht = l
        XCTAssertTrue(waagrecht.umformen(.waagrecht))
        XCTAssertEqual(waagrecht.farbe(x: 0, y: 15), "#FF0000", "links und rechts sind getauscht")

        var senkrecht = l
        XCTAssertTrue(senkrecht.umformen(.senkrecht))
        XCTAssertEqual(senkrecht.farbe(x: 51, y: 0), "#FF0000", "oben und unten sind getauscht")
    }

    /// Zweimal dieselbe Spiegelung ist keine.
    func testZweimalSpiegelnErgibtDasAusgangsbild() {
        var l = gemalte()
        l.setzen(x: 6, y: 1, farbe: "#00FF66")
        let vorher = l.bilder
        for achse in [Leinwand.Umformung.waagrecht, .senkrecht] {
            l.umformen(achse)
            XCTAssertNotEqual(l.bilder, vorher, "\(achse) ändert etwas")
            l.umformen(achse)
            XCTAssertEqual(l.bilder, vorher, "\(achse) zweimal ändert nichts")
        }
    }

    /// Dieselbe Frage wie beim Pfeilkreuz, derselbe Schalter: die ganze
    /// Animation oder allein das gewählte Einzelbild.
    func testUmformenTrifftWahlweiseNurDasGewaehlteBild() {
        var leinwand = Leinwand(breite: 2, hoehe: 1)
        leinwand.setzen(x: 0, y: 0, farbe: "#FF0000")
        leinwand.anhaengen()
        leinwand.waehlen(1)
        leinwand.setzen(x: 0, y: 0, farbe: "#00FF00")

        var alle = leinwand
        alle.umformen(.waagrecht)
        XCTAssertEqual(alle.bilder[0], [nil, "#FF0000"], "das erste Bild wurde nicht mitgespiegelt")
        XCTAssertEqual(alle.bilder[1], [nil, "#00FF00"], "das zweite Bild wurde nicht mitgespiegelt")

        var eines = leinwand
        eines.umformen(.waagrecht, nurDieses: true)
        XCTAssertEqual(eines.bilder[0], ["#FF0000", nil], "das erste Bild wurde mitgespiegelt")
        XCTAssertEqual(eines.bilder[1], [nil, "#00FF00"], "das gewählte Bild blieb, wie es war")
    }
}

// MARK: - Mit Farbe füllen

extension LeinwandTests {
    /// Der Eimer: die zusammenhängende Fläche gleicher Farbe, nicht das ganze
    /// Bild. Ein gemalter Punkt bleibt stehen, wenn ringsum gefüllt wird.
    func testFuellenFaerbtDieZusammenhaengendeFlaeche() {
        var l = gemalte()                       // 8×8, (1,2) rot, sonst durchsichtig
        XCTAssertTrue(l.fuellen(x: 0, y: 0, farbe: "#0000FF"))
        XCTAssertEqual(l.farbe(x: 7, y: 7), "#0000FF", "die Fläche endet nicht am halben Bild")
        XCTAssertEqual(l.farbe(x: 1, y: 2), "#FF0000", "der gemalte Punkt ist überfüllt worden")
        XCTAssertEqual(l.bild.filter { $0 == "#0000FF" }.count, 63)
    }

    /// Eine eingeschlossene Fläche bleibt eingeschlossen: Gefüllt wird innen,
    /// die Wand und alles dahinter bleiben unberührt. Über Eck läuft nichts.
    func testFuellenLaeuftNichtAusEinerEingeschlossenenFlaecheHeraus() {
        var l = Leinwand(breite: 5, hoehe: 5)
        for i in 1...3 {
            l.setzen(x: i, y: 1, farbe: "#FFFFFF")
            l.setzen(x: i, y: 3, farbe: "#FFFFFF")
            l.setzen(x: 1, y: i, farbe: "#FFFFFF")
            l.setzen(x: 3, y: i, farbe: "#FFFFFF")
        }
        XCTAssertTrue(l.fuellen(x: 2, y: 2, farbe: "#0000FF"))
        XCTAssertEqual(l.farbe(x: 2, y: 2), "#0000FF")
        XCTAssertEqual(l.bild.filter { $0 == "#0000FF" }.count, 1, "die Füllung ist durch die Wand gelaufen")
        XCTAssertNil(l.farbe(x: 0, y: 0), "die Ecke draußen wurde mitgefüllt")
    }

    /// Der Rand ist eine Grenze und kein Ausgang: Was am Rand liegt, wird
    /// mitgefüllt, und gerechnet wird nichts jenseits davon.
    func testFuellenHaeltAmRandUndLaesstSichNichtDanebenTippen() {
        var l = Leinwand(breite: 3, hoehe: 3)
        XCTAssertTrue(l.fuellen(x: 2, y: 2, farbe: "#0000FF"))
        XCTAssertEqual(l.bild, [String?](repeating: "#0000FF", count: 9))

        var leer = Leinwand(breite: 3, hoehe: 3)
        XCTAssertFalse(leer.fuellen(x: 3, y: 0, farbe: "#0000FF"), "daneben getippt füllt nichts")
        XCTAssertFalse(leer.fuellen(x: -1, y: 0, farbe: "#0000FF"))
        XCTAssertTrue(leer.istLeer)
    }

    /// Füllen mit der Farbe, die schon da liegt: Ohne diesen Fall passte
    /// jedes gefüllte Feld weiterhin auf die gesuchte Farbe, und der Stapel
    /// liefe endlos. Der Test hinge dann, statt zu scheitern.
    func testFuellenMitDerselbenFarbeTutNichtsUndHaengtNicht() {
        var l = Leinwand(breite: 8, hoehe: 8)
        XCTAssertFalse(l.fuellen(x: 0, y: 0, farbe: nil), "durchsichtig auf durchsichtig")
        l.fuellen(x: 0, y: 0, farbe: "#0000FF")
        let vorher = l.bilder
        XCTAssertFalse(l.fuellen(x: 4, y: 4, farbe: "#0000FF"), "blau auf blau")
        XCTAssertEqual(l.bilder, vorher)
    }

    /// Radieren mit dem Eimer: Durchsichtig ist eine Farbe wie jede andere.
    func testFuellenMitDurchsichtigNimmtDieFlaecheWeg() {
        var l = Leinwand(breite: 4, hoehe: 4)
        l.fuellen(x: 0, y: 0, farbe: "#0000FF")
        l.setzen(x: 0, y: 0, farbe: "#FF0000")
        XCTAssertTrue(l.fuellen(x: 3, y: 3, farbe: nil))
        XCTAssertEqual(l.farbe(x: 0, y: 0), "#FF0000")
        XCTAssertEqual(l.bild.filter { $0 == nil }.count, 15)
    }

    /// Gefüllt wird auf einem Bild, wie gemalt und radiert wird — die übrigen
    /// Einzelbilder bleiben stehen.
    func testFuellenTrifftNurDasBearbeiteteEinzelbild() {
        var l = Leinwand(breite: 2, hoehe: 1)
        l.anhaengen()                           // aktuell = 1
        XCTAssertTrue(l.fuellen(x: 0, y: 0, farbe: "#0000FF"))
        XCTAssertEqual(l.bilder[0], [nil, nil], "das erste Bild wurde mitgefüllt")
        XCTAssertEqual(l.bilder[1], ["#0000FF", "#0000FF"])
    }
}
