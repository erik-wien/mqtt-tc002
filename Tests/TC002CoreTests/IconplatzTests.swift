import XCTest
@testable import TC002Core

/// Zuschnitt des Icons auf seine Tinte, Abstand je Uhr und die Maße in beiden
/// Wegen (Pixelweg, Schrift der Uhr). Vorschau und Gesendetes rechnen mit
/// denselben Zahlen (`Iconplatz`); hier steht, welche das sind.
final class IconplatzTests: XCTestCase {
    private let tc002 = Anzeigemass(breite: 52, hoehe: 16)
    private let tc001 = Anzeigemass(breite: 32, hoehe: 8)

    private func bild(_ spalten: ClosedRange<Int>, kante: Int = 8, farbe: String = "#FF0000") -> [String?] {
        var p = [String?](repeating: nil, count: kante * kante)
        for y in 0..<kante { for x in spalten { p[y * kante + x] = farbe } }
        return p
    }

    // MARK: Zuschnitt

    func testZuschnittLinksUndRechts() throws {
        let platz = try XCTUnwrap(Iconplatz.vermessen([bild(2...4)], kante: 8))
        XCTAssertEqual(platz.links, 2)
        XCTAssertEqual(platz.breite, 3)
        let z = platz.zuschneiden(bild(2...4))
        XCTAssertEqual(z.count, 3 * 8)
        XCTAssertTrue(z.allSatisfy { $0 == "#FF0000" })
    }

    func testSchwarzZaehltNichtAlsTinte() throws {
        var p = bild(3...3)
        for y in 0..<8 { p[y * 8 + 1] = "#000000"; p[y * 8 + 6] = "#000000" }
        let platz = try XCTUnwrap(Iconplatz.vermessen([p], kante: 8))
        XCTAssertEqual(platz.links, 3)
        XCTAssertEqual(platz.breite, 1)
    }

    func testAnimationNimmtDenGemeinsamenKasten() throws {
        let platz = try XCTUnwrap(Iconplatz.vermessen([bild(1...2), bild(4...5)], kante: 8))
        XCTAssertEqual(platz.links, 1)
        XCTAssertEqual(platz.breite, 5, "von der ersten Spalte des einen bis zur letzten des anderen Bildes")
        let alle = [bild(1...2), bild(4...5)].map { platz.zuschneiden($0) }
        XCTAssertTrue(alle.allSatisfy { $0.count == 5 * 8 })
    }

    func testIconOhneTinteHatKeinenPlatz() {
        XCTAssertNil(Iconplatz.vermessen([[String?](repeating: nil, count: 64)], kante: 8))
        XCTAssertNil(Iconplatz.vermessen([[String?](repeating: "#000000", count: 64)], kante: 8))
    }

    func testDieHoeheBleibt() throws {
        let platz = try XCTUnwrap(Iconplatz.vermessen([bild(0...0, kante: 16)], kante: 16))
        XCTAssertEqual(platz.kante, 16)
        XCTAssertEqual(platz.zuschneiden(bild(0...0, kante: 16)).count, 1 * 16)
    }

    func testVonDateiMitCache() throws {
        let icon = try Testicon.inSpalten(3...4)
        let platz = try XCTUnwrap(Iconplatz.vermessen(icon, abstand: 4))
        XCTAssertEqual(platz.links, 3)
        XCTAssertEqual(platz.breite, 2)
        XCTAssertEqual(platz.abstand, 4)
        XCTAssertEqual(Iconplatz.vermessen(icon, abstand: 4), platz)
    }

    // MARK: Einheit von iconGap

    /// Auf der vergroesserten Seite (26 × 8) zaehlt `iconGap` in Spalten zu
    /// zwei Anzeigepixeln; ungerade Wuensche runden auf, 1 bleibt 1.
    func testLueckeInSpaltenDerSeite() {
        func luecke(_ x: Int, _ f: Int) -> Int { Iconplatz(kante: 8, links: 0, breite: 8, abstand: x).luecke(faktor: f) }
        XCTAssertEqual([0, 1, 2, 3, 4, 5].map { luecke($0, 2) }, [0, 1, 1, 2, 2, 3])
        XCTAssertEqual([0, 1, 2, 3].map { luecke($0, 1) }, [0, 1, 2, 3])
    }

    func testAbstandWirdBegrenzt() {
        XCTAssertEqual(Iconplatz(kante: 8, links: 0, breite: 8, abstand: 99).abstand, 16)
        XCTAssertEqual(Iconplatz(kante: 8, links: 0, breite: 8, abstand: -3).abstand, 0)
        XCTAssertEqual(Uhr(name: "a", host: "h", iconAbstand: 40).wirksamerIconAbstand, 16)
        XCTAssertEqual(Uhr(name: "a", host: "h").wirksamerIconAbstand, 1)
    }

    // MARK: Pixelweg

    func testTextBeginntGenauAbstandHinterDerTinte() {
        let platz = Iconplatz(kante: 8, links: 3, breite: 2, abstand: 4)
        var o = Meldungsoptionen(text: "Hallo")
        o.waagrecht = .links
        XCTAssertEqual(Meldungsbau.flaecheX(icon: platz), 6)
        XCTAssertEqual(Meldungsbau.versatzX(o, icon: platz), 6)
        XCTAssertEqual(Meldungsbau.flaecheBreite(icon: platz), 46)
    }

    func testMittigStehtDerBlockInDerMitte() {
        let platz = Iconplatz(kante: 8, links: 0, breite: 5, abstand: 2)
        var o = Meldungsoptionen(text: "Hi")
        o.waagrecht = .mittig
        let tb = Meldungsbau.breite(o)
        let block = 5 + 2 + tb
        let beginn = (52 - block) / 2
        XCTAssertEqual(Meldungsbau.iconX(o, icon: platz), beginn)
        XCTAssertEqual(Meldungsbau.versatzX(o, icon: platz), beginn + 7)
    }

    func testRechtsBleibtRechtsUndDasIconLinks() {
        let platz = Iconplatz(kante: 8, links: 0, breite: 5, abstand: 2)
        var o = Meldungsoptionen(text: "Hi")
        o.waagrecht = .rechts
        XCTAssertEqual(Meldungsbau.iconX(o, icon: platz), 0)
        XCTAssertEqual(Meldungsbau.versatzX(o, icon: platz), 7 + (52 - 7 - Meldungsbau.breite(o)))
    }

    func testMittigOhneTextLassztDasIconLinks() {
        let platz = Iconplatz(kante: 8, links: 0, breite: 5, abstand: 2)
        var o = Meldungsoptionen(text: "")
        o.waagrecht = .mittig
        XCTAssertEqual(Meldungsbau.iconX(o, icon: platz), 0)
    }

    func testNurIconRueckenAnDenLinkenRand() throws {
        let icon = try Testicon.inSpalten(3...4)
        let frame = try Meldungsbau.rahmen(Meldungsoptionen(text: ""), icon: icon,
                                           sammlung: Iconsammlung(schreibordner: icon.datei.deletingLastPathComponent()),
                                           mass: tc002)
        let p = try XCTUnwrap(frame.pixel).bilder[0].pixel
        // Iconzeile 4 liegt auf Anzeigezeile 8 (16 Zeilen, 8 Kante).
        XCTAssertEqual(p[8 * 52 + 0], "#FF0000")
        XCTAssertEqual(p[8 * 52 + 1], "#FF0000")
        XCTAssertNil(p[8 * 52 + 2])
    }

    func pruefeTextSteht(mitAbstand abstand: Int) throws {
        let icon = try Testicon.inSpalten(3...4)
        let sammlung = Iconsammlung(schreibordner: icon.datei.deletingLastPathComponent())
        let o = Meldungsoptionen(text: "H")
        let frame = try Meldungsbau.rahmen(o, icon: icon, sammlung: sammlung, mass: tc002, iconAbstand: abstand)
        let p = try XCTUnwrap(frame.pixel).bilder[0].pixel
        let ersteTextspalte = (2..<52).first { x in
            (0..<16).contains { p[$0 * 52 + x] != nil }
        }
        XCTAssertEqual(ersteTextspalte, 2 + abstand)
    }

    func testTextSteht1Und5Pixel() throws {
        try pruefeTextSteht(mitAbstand: 1)
        try pruefeTextSteht(mitAbstand: 5)
    }

    func testAbstandNullKlebtAnDemIcon() throws {
        try pruefeTextSteht(mitAbstand: 0)
    }

    func testLaufschriftReserviertTinteUndAbstand() {
        let platz = Iconplatz(kante: 8, links: 0, breite: 2, abstand: 5)
        var p = [String?](repeating: nil, count: 64)
        for y in 0..<8 { p[y * 8] = "#FF0000"; p[y * 8 + 1] = "#FF0000" }
        let o = Meldungsoptionen(text: "Hallo Welt, hallo Welt, hallo Welt")
        let bilder = Meldungsbau.laufschriftBilder(o, iconBilder: [p], icon: platz, mass: tc002)
        for b in bilder {
            for y in 0..<16 {
                for x in 2..<7 { XCTAssertNil(b.pixel[y * 52 + x], "Spalte \(x) gehoert dem Abstand") }
            }
        }
        XCTAssertTrue(bilder.contains { b in (7..<52).contains { x in (0..<16).contains { b.pixel[$0 * 52 + x] != nil } } })
    }

    // MARK: Schrift der Uhr

    private func nutzlast(abstand: Int, mass: Anzeigemass, icon: Icon, weg: SendeWeg = .text,
                          modus: Iconmodus = .fest) throws -> String {
        var o = Meldungsoptionen(text: "Hi", weg: weg)
        o.iconmodus = modus
        let sammlung = Iconsammlung(schreibordner: icon.datei.deletingLastPathComponent())
        return try Anzeigen.nutzlast(try Meldungsbau.rahmen(o, icon: icon, sammlung: sammlung,
                                                            mass: mass, iconAbstand: abstand))
    }

    func testIconGapVergroessertInDoppelpixeln() throws {
        let icon = try Testicon.inSpalten(0...4)
        XCTAssertFalse(try nutzlast(abstand: 1, mass: tc002, icon: icon).contains("iconGap"), "1 ist die Vorgabe der Firmware")
        XCTAssertFalse(try nutzlast(abstand: 2, mass: tc002, icon: icon).contains("iconGap"), "2 Pixel sind eine Spalte")
        XCTAssertTrue(try nutzlast(abstand: 3, mass: tc002, icon: icon).contains(#""iconGap":2"#))
        XCTAssertTrue(try nutzlast(abstand: 8, mass: tc002, icon: icon).contains(#""iconGap":4"#))
        XCTAssertTrue(try nutzlast(abstand: 0, mass: tc002, icon: icon).contains(#""iconGap":0"#))
    }

    func testIconGapNichtVergroessertInAnzeigepixeln() throws {
        let acht = try Testicon.inSpalten(0...4)
        XCTAssertTrue(try nutzlast(abstand: 3, mass: tc001, icon: acht).contains(#""iconGap":3"#))
        let sechzehn = try Testicon.inSpalten(0...4, kante: 16)
        XCTAssertTrue(try nutzlast(abstand: 3, mass: tc002, icon: sechzehn).contains(#""iconGap":3"#),
                      "ein 16×16 schaltet die Anzeige auf das volle Raster")
    }

    func testDasIconGehtZugeschnittenHinaus() throws {
        let icon = try Testicon.inSpalten(2...4)
        let json = try nutzlast(abstand: 1, mass: tc002, icon: icon)
        let marke = #""icon":"data:image/gif;base64,"#
        let start = try XCTUnwrap(json.range(of: marke)).upperBound
        let b64 = String(json[start...].prefix { $0 != "\"" })
        let daten = try XCTUnwrap(Data(base64Encoded: b64))
        let masse = try XCTUnwrap(Bildraster.groesse(daten))
        XCTAssertEqual(masse.breite, 3)
        XCTAssertEqual(masse.hoehe, 8)
    }

    func testEinVolllesIconGehtUnveraendertHinaus() throws {
        let icon = try Testicon.anlegen()
        let sammlung = Iconsammlung(schreibordner: icon.datei.deletingLastPathComponent())
        let frame = try Meldungsbau.rahmen(Meldungsoptionen(text: "x", weg: .text), icon: icon, sammlung: sammlung, mass: tc002)
        XCTAssertEqual(frame.herkunft?.iconDatenURI, try sammlung.datenURI(fuer: icon))
    }

    func testIconOhneTinteGehtNichtMit() throws {
        let icon = try Testicon.anlegen(pixel: [String?](repeating: nil, count: 64))
        let json = try nutzlast(abstand: 3, mass: tc002, icon: icon)
        XCTAssertFalse(json.contains("\"icon\""))
        XCTAssertFalse(json.contains("iconGap"))
    }

    func testVorschauUndNutzlastRechnenMitDerselbenLuecke() {
        // Vergroessert: Breite 5 + Luecke(3 Pixel) = 5 + 2 Spalten, Text bei 7 (14 Pixel).
        let platz = Iconplatz(kante: 8, links: 0, breite: 5, abstand: 3)
        let o = Meldungsoptionen(text: "H", weg: .text)
        let f = Geraeteschrift.feld(o, icon: platz, mass: tc002)
        let belegt = (0..<52).filter { x in (0..<16).contains { f.farbe(x: x, y: $0) != nil } }
        XCTAssertEqual(platz.luecke(faktor: 2), 2)
        XCTAssertEqual(belegt.min(), 2 * (5 + 2), "Breite 5 + Luecke 2 Spalten, je zwei Anzeigepixel")
    }

    func testMittigImRestNebenDemIcon() {
        let platz = Iconplatz(kante: 8, links: 0, breite: 5, abstand: 2)
        var o = Meldungsoptionen(text: "H", weg: .text)
        o.waagrecht = .mittig
        let f = Geraeteschrift.feld(o, icon: platz, mass: tc002)
        let belegt = (0..<52).filter { x in (0..<16).contains { f.farbe(x: x, y: $0) != nil } }
        // Rest ab Spalte 5 + 1 = 6 von 26: H ist 3 breit, (20 - 3) / 2 = 8 -> 14, doppelt 28.
        XCTAssertEqual(belegt.min(), 28)
        XCTAssertEqual(Meldungsbau.iconX(o, icon: platz, mass: tc002), 0)
    }

    // MARK: Auswahl des Iconmodus

    func testPushOnceGehtAlsWortHinaus() throws {
        let icon = try Testicon.inSpalten(0...4)
        XCTAssertTrue(try nutzlast(abstand: 1, mass: tc002, icon: icon, modus: .einmal).contains(#""iconMode":"pushOnce""#))
        XCTAssertTrue(try nutzlast(abstand: 1, mass: tc002, icon: icon, modus: .mit).contains(#""iconMode":"push""#))
        XCTAssertTrue(try nutzlast(abstand: 1, mass: tc002, icon: icon, modus: .fest).contains(#""iconMode":"fixed""#))
    }

    func testAltesBoolWirdFestOderMit() {
        var o = Meldungsoptionen(text: "x")
        o.iconLaeuftMit = true
        XCTAssertEqual(o.iconmodus, .mit)
        o.iconLaeuftMit = false
        XCTAssertEqual(o.iconmodus, .fest)
        o.iconmodus = .einmal
        XCTAssertTrue(o.iconLaeuftMit, "eine ältere Fassung liest 'mitscrollen'")
        o.iconmodus = .fest
        XCTAssertNil(o.iconModus)
    }

    func testEinmalGiltNurMitSchriftDerUhr() {
        XCTAssertFalse(Iconmodus.einmal.wirkt(weg: .pixel))
        XCTAssertEqual(Iconmodus.einmal.wirksam(weg: .pixel), .mit)
        XCTAssertEqual(Iconmodus.einmal.wirksam(weg: .text), .einmal)
        XCTAssertNotNil(Iconmodus.einmal.begruendung(weg: .pixel))
        XCTAssertNil(Iconmodus.einmal.begruendung(weg: .text))
        XCTAssertNil(Iconmodus.fest.begruendung(weg: .pixel))
        var o = Meldungsoptionen(text: "x", weg: .pixel)
        o.iconmodus = .einmal
        XCTAssertEqual(o.wirksamerIconmodus, .mit)
    }

    func testAlteMeldungsoptionenOhneIconModusBleibenLesbar() throws {
        var o = Meldungsoptionen(text: "x")
        o.iconLaeuftMit = true
        var json = String(decoding: try JSONEncoder().encode(o), as: UTF8.self)
        XCTAssertFalse(json.contains("iconModus"), "nil wird nicht geschrieben")
        json = json.replacingOccurrences(of: #""iconLaeuftMit":true"#, with: #""iconLaeuftMit":true"#)
        let zurueck = try JSONDecoder().decode(Meldungsoptionen.self, from: Data(json.utf8))
        XCTAssertEqual(zurueck.iconmodus, .mit)
        o.iconmodus = .einmal
        let neu = try JSONDecoder().decode(Meldungsoptionen.self, from: try JSONEncoder().encode(o))
        XCTAssertEqual(neu.iconmodus, .einmal)
    }

    func testEinmalLaufbilderHabenEinenZweitenDurchlaufOhneIcon() {
        let platz = Iconplatz(kante: 8, links: 0, breite: 8, abstand: 1)
        let icon = [String?](repeating: "#FF0000", count: 64)
        var o = Meldungsoptionen(text: "HALLO WELT UND MEHR", weg: .text)
        o.iconmodus = .mit
        let mit = Meldungsbau.laufschriftBilder(o, iconBilder: [icon], icon: platz, mass: tc002)
        o.iconmodus = .einmal
        let einmal = Meldungsbau.laufschriftBilder(o, iconBilder: [icon], icon: platz, mass: tc002)
        XCTAssertGreaterThan(einmal.count, mit.count)
        XCTAssertEqual(Array(einmal.prefix(mit.count)), mit, "der erste Durchlauf ist der von 'mit'")
        let zweiter = einmal[mit.count...]
        XCTAssertFalse(zweiter.contains { b in (0..<16).contains { y in b.pixel[y * 52 + 0] == "#FF0000" } },
                       "im zweiten Durchlauf ist das Icon weg")
        XCTAssertTrue(zweiter.first?.pixel.contains { $0 != nil } ?? false, "der Text steht am linken Rand")
    }

    // MARK: Uhr und Slotstand

    func testIconAbstandUeberstehtDieDatei() throws {
        let uhr = Uhr(name: "a", host: "h", iconAbstand: 6)
        let zurueck = try JSONDecoder().decode(Uhr.self, from: try JSONEncoder().encode(uhr))
        XCTAssertEqual(zurueck.iconAbstand, 6)
        let alt = #"[{"id":"7C1B3F4E-0000-4000-8000-000000000001","name":"Küche","host":"h","einrichtung":2}]"#
        let gelesen = try JSONDecoder().decode([Uhr].self, from: Data(alt.utf8))[0]
        XCTAssertNil(gelesen.iconAbstand)
        XCTAssertEqual(gelesen.wirksamerIconAbstand, 1)
        let geschrieben = String(decoding: try JSONEncoder().encode(gelesen), as: UTF8.self)
        XCTAssertFalse(geschrieben.contains("iconAbstand"))
    }

    func testSlotstandVonFruehrenBleibtLesbarUndRechnetWieDamals() throws {
        let json = """
        {"platz":3,"text":"Bus","weg":"pixel","schrift":"Silkscreen","groesse":8,"fett":false,\
        "grossbuchstaben":false,"rand":1,"abstand":1,"waagrecht":"links","senkrecht":"oben",\
        "farbe":"#00FF66","tempo":"mittel","iconLaeuftMit":true,"icon":"1673","pruefsumme":"x"}
        """
        let stand = try JSONDecoder().decode(Slotstand.self, from: Data(json.utf8))
        XCTAssertEqual(stand.optionen?.iconmodus, .mit)
        XCTAssertEqual(stand.iconplatz, .voll(kante: 8, abstand: 2), "bis dahin: volles Icon, Text zwei Spalten dahinter")
        XCTAssertEqual(Meldungsbau.flaecheX(icon: stand.iconplatz), 10)
    }

    func testSlotstandMerktBreiteAbstandUndEinmal() throws {
        let g = Slotgedaechtnis(ordner: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
        let uhr = UUID()
        var o = Meldungsoptionen(text: "Hi")
        o.iconmodus = .einmal
        let icon = try Testicon.inSpalten(3...4)
        g.merken(o, icon: icon, iconAbstand: 3, fuer: uhr, platz: 1)
        let stand = try XCTUnwrap(g.gemerkt(fuer: uhr, platz: 1))
        XCTAssertEqual(stand.iconBreite, 2)
        XCTAssertEqual(stand.iconAbstand, 3)
        XCTAssertEqual(stand.iconplatz, Iconplatz(kante: 8, links: 0, breite: 2, abstand: 3))
        XCTAssertEqual(stand.optionen?.iconmodus, .einmal)
        XCTAssertTrue(stand.iconLaeuftMit)
        let erwartet = Meldungsbau.feld(o, icon: Iconplatz(kante: 8, links: 3, breite: 2, abstand: 3)).punkteRoh
        XCTAssertEqual(stand.pruefsumme, Slotgedaechtnis.pruefsumme(pixel: erwartet))
    }
}
