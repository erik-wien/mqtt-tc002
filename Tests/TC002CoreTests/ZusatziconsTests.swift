import XCTest
@testable import TC002Core

/// Zusatzicons (`icons[]`): Grenzen, Koordinaten in beiden Wegen, Einbacken mit
/// Bewegung, Vorschau gleich Gesendetem, Größen, Slotgedächtnis und die
/// virtuelle Uhr.
final class ZusatziconsTests: XCTestCase {
    private let tc002 = Anzeigemass(breite: 52, hoehe: 16)
    private let tc001 = Anzeigemass(breite: 32, hoehe: 8)

    /// Ein eigener Ordner je Test: Icons mit Farbe `farbe` auf allen Pixeln der
    /// Spalte `spalte`, sonst leer; `bilder` > 1 ergibt ein bewegtes Icon, dessen
    /// Bilder in der Spalte `spalte + n` leuchten.
    private struct Ablage {
        let ordner = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        var sammlung8: Iconsammlung { Iconsammlung(schreibordner: ordner.appendingPathComponent("8")) }
        var sammlung16: Iconsammlung { Iconsammlung(schreibordner: ordner.appendingPathComponent("16"), kante: 16) }
        var bestaende: () -> [Iconsammlung] { { [sammlung8, sammlung16] } }

        @discardableResult
        func icon(_ nummer: String, kante: Int = 8, farben: [String], zeit: Double = 0.2) throws -> Icon {
            let bilder = farben.enumerated().map { n, farbe -> [String?] in
                var p = [String?](repeating: nil, count: kante * kante)
                for y in 0..<kante { p[y * kante + min(n, kante - 1)] = farbe; p[y * kante + kante - 1] = farbe }
                return p
            }
            return try (kante == 8 ? sammlung8 : sammlung16).sichern(nummer: nummer, name: nummer,
                                                                      bilder: bilder, verzoegerung: zeit)
        }
    }

    // MARK: Koordinaten

    func testSeitenwertRundetAb() {
        XCTAssertEqual(Zusatzicons.seitenwert(5, faktor: 2), 2)
        XCTAssertEqual(Zusatzicons.seitenwert(4, faktor: 2), 2)
        XCTAssertEqual(Zusatzicons.seitenwert(0, faktor: 2), 0)
        XCTAssertEqual(Zusatzicons.seitenwert(-1, faktor: 2), -1, "abgerundet, nicht zur Null hin")
        XCTAssertEqual(Zusatzicons.seitenwert(-4, faktor: 2), -2)
        XCTAssertEqual(Zusatzicons.seitenwert(7, faktor: 1), 7)
        XCTAssertEqual(Zusatzicons.gezeichnet(5, faktor: 2), 4)
        XCTAssertEqual(Zusatzicons.gezeichnet(5, faktor: 1), 5)
    }

    func testBegrenzenKapptAnzahlUndKoordinaten() {
        let sechs = (0..<6).map { Zusatzicon(nummer: "a\($0)", x: 500, y: -3) }
        let b = Zusatzicons.begrenzt(sechs)
        XCTAssertEqual(b.count, 4)
        XCTAssertEqual(b[0].x, 127)
        XCTAssertEqual(b[0].y, 0)
        XCTAssertEqual(Zusatzicons.begrenzt(nil), [])
    }

    // MARK: Auflösen

    func testFehlendesIconUndZuGrossesEntfallen() throws {
        let a = Ablage()
        try a.icon("stern", farben: ["#FF0000"])
        try a.icon("gross", kante: 16, farben: ["#00FF00"])
        let liste = [Zusatzicon(nummer: "stern", x: 1, y: 2), Zusatzicon(nummer: "weg", x: 3, y: 4),
                     Zusatzicon(nummer: "gross", kante: 16, x: 5, y: 6)]
        let auf52 = Zusatzicons.laden(liste, mass: tc002, bestaende: a.bestaende)
        XCTAssertEqual(auf52.map(\.icon.nummer), ["stern", "gross"])
        let auf32 = Zusatzicons.laden(liste, mass: tc001, bestaende: a.bestaende)
        XCTAssertEqual(auf32.map(\.icon.nummer), ["stern"], "ein 16×16 ohne 8×8-Fassung passt nicht in acht Zeilen")
    }

    func testEinSechzehnerWirdAufAchtZeilenDurchSeineAchterFassungErsetzt() throws {
        let a = Ablage()
        try a.icon("haus", farben: ["#FF0000"])
        try a.icon("haus-16", kante: 16, farben: ["#00FF00"])
        let p = Zusatzicons.laden([Zusatzicon(nummer: "haus-16", kante: 16, x: 0, y: 0)],
                                  mass: tc001, bestaende: a.bestaende)
        XCTAssertEqual(p.map(\.icon.nummer), ["haus"])
    }

    // MARK: Schrift der Uhr

    private func nutzlast(_ liste: [Zusatzicon], a: Ablage, mass: Anzeigemass, icon: Icon? = nil,
                          text: String = "Hi") throws -> String {
        let o = Meldungsoptionen(text: text, weg: .text, zusatzicons: liste)
        return try Anzeigen.nutzlast(Meldungsbau.rahmen(o, icon: icon, sammlung: a.sammlung8, mass: mass,
                                                        bestaende: a.bestaende))
    }

    private func eintraege(_ json: String) throws -> [[String: Any]] {
        let o = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        return try XCTUnwrap(o["icons"] as? [[String: Any]])
    }

    func testAchterAufDerVergroessertenTC002GehenInSpaltenDerSeiteHinaus() throws {
        let a = Ablage()
        try a.icon("stern", farben: ["#FF0000"])
        let json = try nutzlast([Zusatzicon(nummer: "stern", x: 5, y: 3)], a: a, mass: tc002)
        let e = try eintraege(json)
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e[0]["x"] as? Int, 2, "5 Anzeigepixel = Seitenspalte 2 (abgerundet), gezeichnet bei 4")
        XCTAssertEqual(e[0]["y"] as? Int, 1)
        XCTAssertTrue((e[0]["icon"] as? String)?.hasPrefix("data:image/gif;base64,") == true)
    }

    func testAufDerTC001ZaehltDasPixelSelbst() throws {
        let a = Ablage()
        try a.icon("stern", farben: ["#FF0000"])
        let e = try eintraege(try nutzlast([Zusatzicon(nummer: "stern", x: 5, y: 0)], a: a, mass: tc001))
        XCTAssertEqual(e[0]["x"] as? Int, 5)
    }

    func testEinSechzehnerSchaltetDieVergroesserungAus() throws {
        let a = Ablage()
        try a.icon("stern", farben: ["#FF0000"])
        try a.icon("gross", kante: 16, farben: ["#00FF00"])
        let e = try eintraege(try nutzlast([Zusatzicon(nummer: "stern", x: 5, y: 3),
                                            Zusatzicon(nummer: "gross", kante: 16, x: 20, y: 0)],
                                           a: a, mass: tc002))
        XCTAssertEqual(e[0]["x"] as? Int, 5, "die ganze Anzeige wird 1:1 gezeichnet (`PageZoom::enlarges`)")
        XCTAssertEqual(e[0]["y"] as? Int, 3)
        XCTAssertEqual(e[1]["x"] as? Int, 20)
    }

    func testIconGapRechnetMitDenZusatzicons() throws {
        let a = Ablage()
        let haupt = try Testicon.inSpalten(0...4)
        let hauptSammlung = Iconsammlung(schreibordner: haupt.datei.deletingLastPathComponent())
        try a.icon("gross", kante: 16, farben: ["#00FF00"])
        let o = Meldungsoptionen(text: "Hi", weg: .text, zusatzicons: [Zusatzicon(nummer: "gross", kante: 16)])
        let f = try Meldungsbau.rahmen(o, icon: haupt, sammlung: hauptSammlung, mass: tc002, iconAbstand: 3,
                                       bestaende: a.bestaende)
        XCTAssertEqual(f.herkunft?.iconGap, 3, "ohne Vergrößerung zählt die Luft in Anzeigepixeln")
        let ohne = try Meldungsbau.rahmen(Meldungsoptionen(text: "Hi", weg: .text), icon: haupt,
                                          sammlung: hauptSammlung, mass: tc002, iconAbstand: 3)
        XCTAssertEqual(ohne.herkunft?.iconGap, 2)
    }

    func testDieReihenfolgeDerNutzlastIstFest() throws {
        let a = Ablage()
        try a.icon("stern", farben: ["#FF0000"])
        let hauptIcon = try Testicon.anlegen()
        let json = try Anzeigen.nutzlast(Meldungsbau.rahmen(
            Meldungsoptionen(text: "Hi", weg: .text, dauer: 5, zusatzicons: [Zusatzicon(nummer: "stern")]),
            icon: hauptIcon, sammlung: Iconsammlung(schreibordner: hauptIcon.datei.deletingLastPathComponent()),
            mass: tc002, bestaende: a.bestaende))
        let reihe = ["\"text\"", "\"icon\"", "\"iconMode\"", "\"icons\"", "\"durationMs\""]
        let stellen = try reihe.map { try XCTUnwrap(json.range(of: $0), $0).lowerBound }
        XCTAssertEqual(stellen, stellen.sorted())
    }

    func testOhneZusatziconsBleibtDieNutzlastWieBisher() throws {
        let json = try Anzeigen.nutzlast(Meldungsbau.rahmen(Meldungsoptionen(text: "Hi", weg: .text), icon: nil,
                                                            sammlung: Ablage().sammlung8, mass: tc002))
        XCTAssertFalse(json.contains("icons"))
    }

    func testHoechstensVierUndGrenzenDerFirmware() throws {
        let uri = "data:image/gif;base64,R0lGODlhAQABAAAAACw="
        let sendungen = (0..<6).map { Zusatzsendung(iconDatenURI: uri, x: 70_000, y: -70_000 + $0) }
        let json = try NGNutzlast.anzeige(Meldungsoptionen(text: "x", weg: .text), zusatzicons: sendungen)
        let e = try eintraege(json)
        XCTAssertEqual(e.count, 4)
        XCTAssertEqual(e[0]["x"] as? Int, 65_535)
        XCTAssertEqual(e[0]["y"] as? Int, -65_535)
    }

    func testEinFremdesFormatWirdAbgewiesen() {
        let png = "data:image/png;base64,AAAA"
        XCTAssertThrowsError(try NGNutzlast.anzeige(Meldungsoptionen(text: "x", weg: .text),
                                                    zusatzicons: [Zusatzsendung(iconDatenURI: png, x: 0, y: 0)]))
    }

    // MARK: Pixelweg

    private func pixelbilder(_ o: Meldungsoptionen, a: Ablage, icon: Icon? = nil, mass: Anzeigemass) throws
        -> [Bildraster.Einzelbild] {
        try XCTUnwrap(Meldungsbau.rahmen(o, icon: icon, sammlung: a.sammlung8, mass: mass,
                                         bestaende: a.bestaende).pixel).bilder
    }

    func testEingebackenAnDerStelleInAnzeigepixeln() throws {
        let a = Ablage()
        try a.icon("stern", farben: ["#FF0000"])
        let o = Meldungsoptionen(text: "", zusatzicons: [Zusatzicon(nummer: "stern", x: 5, y: 3)])
        let bilder = try pixelbilder(o, a: a, mass: tc002)
        XCTAssertEqual(bilder.count, 1)
        let p = bilder[0].pixel
        // Spalte 7 des Icons (die rechte Randspalte) liegt auf Anzeigespalte 12.
        for y in 0..<8 { XCTAssertEqual(p[(3 + y) * 52 + 5 + 7], "#FF0000") }
        XCTAssertNil(p[(3 + 8) * 52 + 12], "unterhalb endet es")
        XCTAssertNil(p[2 * 52 + 12])
        XCTAssertNil(p[3 * 52 + 4])
    }

    func testAmRandWirdAbgeschnitten() throws {
        let a = Ablage()
        try a.icon("stern", farben: ["#FF0000"])
        let o = Meldungsoptionen(text: "", zusatzicons: [Zusatzicon(nummer: "stern", x: 50, y: 14)])
        let p = try pixelbilder(o, a: a, mass: tc002)[0].pixel
        XCTAssertEqual(p.count, 52 * 16)
        XCTAssertEqual(p[14 * 52 + 50], "#FF0000", "Spalte 0 des Icons liegt noch auf der Anzeige")
        XCTAssertEqual(p[15 * 52 + 50], "#FF0000")
        XCTAssertNil(p[14 * 52 + 51], "Spalte 1 ist leer, Spalte 7 liegt hinter dem Rand")
    }

    func testSpaetereDeckenFruehereUndDasIconLiegtDarunter() throws {
        let a = Ablage()
        try a.icon("rot", farben: ["#FF0000"])
        try a.icon("gruen", farben: ["#00FF00"])
        let haupt = try Testicon.anlegen(pixel: [String?](repeating: "#0000FF", count: 64))
        let hauptSammlung = Iconsammlung(schreibordner: haupt.datei.deletingLastPathComponent())
        // Beide Zusatzicons auf derselben Stelle über dem normalen Icon.
        let o = Meldungsoptionen(text: "", zusatzicons: [Zusatzicon(nummer: "rot", x: 0, y: 4),
                                                         Zusatzicon(nummer: "gruen", x: 0, y: 4)])
        let p = try XCTUnwrap(Meldungsbau.rahmen(o, icon: haupt, sammlung: hauptSammlung, mass: tc002,
                                                 bestaende: a.bestaende).pixel).bilder[0].pixel
        XCTAssertEqual(p[4 * 52 + 7], "#00FF00", "das letzte Zusatzicon deckt das vorige")
        XCTAssertEqual(p[4 * 52 + 3], "#0000FF", "wo nichts darüber liegt, bleibt das normale Icon")
    }

    func testBewegteIconsLaufenMitEigenenZeitenAufEinerGemeinsamenLeiste() throws {
        let a = Ablage()
        try a.icon("zwei", farben: ["#FF0000", "#FF8800"], zeit: 0.2)
        try a.icon("drei", farben: ["#00FF00", "#00FF88", "#00FFFF"], zeit: 0.3)
        let o = Meldungsoptionen(text: "", zusatzicons: [Zusatzicon(nummer: "zwei", x: 0, y: 0),
                                                         Zusatzicon(nummer: "drei", x: 20, y: 0)])
        let bilder = try pixelbilder(o, a: a, mass: tc002)
        // Schleifen von 0,4 s und 0,9 s: 3,6 s gemeinsam; umgeschaltet wird alle
        // 0,2 s (18 Mal) und alle 0,3 s (12 Mal), 6 Mal zugleich.
        XCTAssertEqual(bilder.count, 24)
        XCTAssertEqual(bilder.reduce(0) { $0 + $1.dauer }, 3.6, accuracy: 1e-9)
        XCTAssertNotEqual(bilder[0].pixel, bilder[1].pixel)
    }

    func testEinStehendesZusatziconMachtKeineAnimation() throws {
        let a = Ablage()
        try a.icon("stern", farben: ["#FF0000"])
        let o = Meldungsoptionen(text: "Hi", zusatzicons: [Zusatzicon(nummer: "stern", x: 40, y: 0)])
        let rahmen = try Meldungsbau.rahmen(o, icon: nil, sammlung: a.sammlung8, mass: tc002, bestaende: a.bestaende)
        XCTAssertFalse(try XCTUnwrap(rahmen.pixel).istBewegt)
    }

    func testLaufendeSchriftTraegtDieZusatzicons() throws {
        let a = Ablage()
        try a.icon("stern", farben: ["#FF0000"])
        let o = Meldungsoptionen(text: "Ein langer Text, der durchlaufen muss", zusatzicons: [Zusatzicon(nummer: "stern", x: 44, y: 8)])
        let bilder = try pixelbilder(o, a: a, mass: tc002)
        XCTAssertGreaterThan(bilder.count, 20)
        XCTAssertTrue(bilder.allSatisfy { $0.pixel[8 * 52 + 51] == "#FF0000" }, "in jedem Einzelbild an derselben Stelle")
    }

    // MARK: Vorschau gleich Gesendetem

    func testDieVorschauImPixelwegIstDasGesendeteBild() throws {
        let a = Ablage()
        try a.icon("zwei", farben: ["#FF0000", "#FF8800"], zeit: 0.2)
        try a.icon("stern", farben: ["#00FF00"])
        let haupt = try Testicon.inSpalten(1...3)
        let hauptSammlung = Iconsammlung(schreibordner: haupt.datei.deletingLastPathComponent())
        let o = Meldungsoptionen(text: "Hi", zusatzicons: [Zusatzicon(nummer: "zwei", x: 30, y: 2),
                                                          Zusatzicon(nummer: "stern", x: 40, y: 7)])
        let gesendet = try XCTUnwrap(Meldungsbau.rahmen(o, icon: haupt, sammlung: hauptSammlung, mass: tc002,
                                                        bestaende: a.bestaende).pixel).bilder
        let vorschau = try XCTUnwrap(Meldungsbau.stehendeBilder(o, icon: haupt, mass: tc002, bestaende: a.bestaende))
        XCTAssertEqual(vorschau, gesendet)
    }

    func testDieLaufschriftDerVorschauIstDieGesendete() throws {
        let a = Ablage()
        try a.icon("stern", farben: ["#00FF00"])
        let o = Meldungsoptionen(text: "Ein langer Text, der durchlaufen muss",
                                 zusatzicons: [Zusatzicon(nummer: "stern", x: 40, y: 7)])
        let gesendet = try pixelbilder(o, a: a, mass: tc002)
        let vorschau = Meldungsbau.laufschriftBilder(o, iconBilder: [], mass: tc002, bestaende: a.bestaende)
        XCTAssertEqual(vorschau, gesendet)
    }

    func testBeiDerSchriftDerUhrZeichnetDieVorschauAnSeitenwertMalFaktor() throws {
        let a = Ablage()
        try a.icon("stern", farben: ["#FF0000"])
        let z = Zusatzicon(nummer: "stern", x: 5, y: 3)
        let o = Meldungsoptionen(text: "", weg: .text, zusatzicons: [z])
        let bild = try XCTUnwrap(Meldungsbau.stehendeBilder(o, icon: nil, mass: tc002, bestaende: a.bestaende))[0].pixel
        let faktor = Geraeteschrift.masstab(o, mitIcon: false, iconKante: 8, mass: tc002)
        XCTAssertEqual(faktor, 2)
        let e = try eintraege(try nutzlast([z], a: a, mass: tc002, text: ""))[0]
        let x = try XCTUnwrap(e["x"] as? Int) * faktor, y = try XCTUnwrap(e["y"] as? Int) * faktor
        // Die Randspalte 0 des 8×8 ist die zweite Punktspalte der Vorschau: Das
        // Icon beginnt genau bei dem, was die Uhr aus `x`/`y` macht, und ist doppelt so groß.
        XCTAssertEqual([x, y], [4, 2])
        XCTAssertEqual(bild[y * 52 + x + 14], "#FF0000", "Spalte 7 des Icons, verdoppelt")
        XCTAssertEqual(bild[y * 52 + x + 15], "#FF0000")
        XCTAssertNil(bild[y * 52 + x + 16])
        XCTAssertNil(bild[y * 52 + x - 1])
        XCTAssertNil(bild[(y - 1) * 52 + x + 14])
        XCTAssertEqual(bild[15 * 52 + x + 14], "#FF0000", "16 Zeilen hoch ab Zeile 2: unten bei Zeile 15 abgeschnitten")
    }

    // MARK: Größe

    func testVieleZusatziconsLassenDieMqttNutzlastUeberlaufenUndGehenUeberHttp() throws {
        let a = Ablage()
        // Rauschen verhindert, dass das GIF klein wird.
        var zufall = SystemRandomNumberGenerator()
        let farben = (0..<30).map { _ in String(format: "#%06X", Int.random(in: 0...0xFFFFFF, using: &zufall)) }
        var liste: [Zusatzicon] = []
        for n in 0..<4 {
            let bilder = (0..<30).map { _ -> [String?] in
                (0..<256).map { _ in farben.randomElement(using: &zufall) }
            }
            try a.sammlung16.sichern(nummer: "r\(n)", name: "r\(n)", bilder: bilder, verzoegerung: 0.1)
            liste.append(Zusatzicon(nummer: "r\(n)", kante: 16, x: n * 12, y: 0))
        }
        let json = try nutzlast(liste, a: a, mass: tc002)
        XCTAssertGreaterThan(json.utf8.count, Pixelweg.mqttGrenze)
        XCTAssertEqual(try Pixelweg.zustellweg(nutzlastBytes: json.utf8.count, themaBytes: 40, betriebsart: .mqtt), .http)
        XCTAssertEqual(try eintraege(json).count, 4)
    }

    // MARK: Dateiformate

    func testOptionenUndStandOhneDasFeldBleibenLesbar() throws {
        let alt = Data(##"{"text":"x","weg":"pixel","schrift":"Silkscreen","groesse":8,"fett":false,"farbe":"#00FF66","grossbuchstaben":false,"waagrecht":"links","senkrecht":"mittig","rand":1,"abstand":1,"tempo":"mittel","iconLaeuftMit":false}"##.utf8)
        let o = try JSONDecoder().decode(Meldungsoptionen.self, from: alt)
        XCTAssertNil(o.zusatzicons)
        let stand = Data(##"{"platz":1,"text":"x","weg":"pixel","schrift":"Silkscreen","groesse":8,"fett":false,"grossbuchstaben":false,"rand":1,"abstand":1,"waagrecht":"links","senkrecht":"mittig","farbe":"#00FF66","tempo":"mittel","iconLaeuftMit":false,"pruefsumme":"abc"}"##.utf8)
        let s = try JSONDecoder().decode(Slotstand.self, from: stand)
        XCTAssertNil(s.zusatzicons)
        XCTAssertNil(s.optionen?.zusatzicons)
    }

    func testOhneZusatziconsSteheKeinSchluesselInDerDatei() throws {
        let o = Meldungsoptionen(text: "x")
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(o), as: UTF8.self).contains("zusatzicons"))
        let leer = Meldungsoptionen(text: "x", zusatzicons: [])
        XCTAssertNil(leer.zusatzicons)
    }

    func testDieOptionenBehaltenDieZusatzicons() throws {
        let o = Meldungsoptionen(text: "x", zusatzicons: [Zusatzicon(nummer: "a", x: 3, y: 4),
                                                          Zusatzicon(nummer: "b", kante: 16, x: 7, y: 8)])
        let zurueck = try JSONDecoder().decode(Meldungsoptionen.self, from: JSONEncoder().encode(o))
        XCTAssertEqual(zurueck, o)
    }

    // MARK: Slotgedächtnis

    private func gedaechtnis() -> Slotgedaechtnis {
        Slotgedaechtnis(ordner: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
    }

    func testDasSlotgedaechtnisMerktDieZusatzicons() throws {
        let g = gedaechtnis()
        let uhr = UUID()
        let liste = [Zusatzicon(nummer: "stern", x: 3, y: 4), Zusatzicon(nummer: "x", kante: 16, x: 9, y: 1)]
        XCTAssertTrue(g.merken(Meldungsoptionen(text: "a", zusatzicons: liste), icon: nil, iconAbstand: 1,
                               fuer: uhr, platz: 1))
        let stand = try XCTUnwrap(g.gemerkt(fuer: uhr, platz: 1))
        XCTAssertEqual(stand.zusatzicons, liste)
        XCTAssertEqual(stand.optionen?.zusatzicons, liste)
    }

    func testEinAndererPlatzLaesstDieZusatzIconsInRuhe() throws {
        // So schreibt das Werkzeug: ohne Zusatzicons, auf einen anderen Platz.
        let g = gedaechtnis()
        let uhr = UUID()
        let liste = [Zusatzicon(nummer: "stern", x: 3, y: 4)]
        g.merken(Meldungsoptionen(text: "a", zusatzicons: liste), icon: nil, iconAbstand: 1, fuer: uhr, platz: 1)
        g.merken(Meldungsoptionen(text: "b"), icon: nil, iconAbstand: 1, fuer: uhr, platz: 2)
        XCTAssertEqual(g.gemerkt(fuer: uhr, platz: 1)?.zusatzicons, liste)
        XCTAssertNil(g.gemerkt(fuer: uhr, platz: 2)?.zusatzicons)
        // Auf demselben Platz ersetzt die Sendung ohne Zusatzicons den Stand.
        g.merken(Meldungsoptionen(text: "c"), icon: nil, iconAbstand: 1, fuer: uhr, platz: 1)
        XCTAssertNil(g.gemerkt(fuer: uhr, platz: 1)?.zusatzicons)
    }

    func testDiePruefsummeDeckenDieZusatzIconsNichtAb() throws {
        let g = gedaechtnis()
        let uhr = UUID()
        g.merken(Meldungsoptionen(text: "a"), icon: nil, iconAbstand: 1, fuer: uhr, platz: 1)
        g.merken(Meldungsoptionen(text: "a", zusatzicons: [Zusatzicon(nummer: "s")]), icon: nil, iconAbstand: 1,
                 fuer: uhr, platz: 2)
        XCTAssertEqual(g.gemerkt(fuer: uhr, platz: 1)?.pruefsumme, g.gemerkt(fuer: uhr, platz: 2)?.pruefsumme)
    }

    // MARK: Zeitleiste

    func testEineLeisteAusStehendemIstEinBild() throws {
        let l = try Zusatzicons.zeitleiste(spuren: [[1.0], [1.0]])
        XCTAssertEqual(l.count, 1)
        XCTAssertEqual(l[0].bilder, [0, 0])
    }

    func testZuLangeGemeinsameLaengeFaelltAufDieLaengsteSchleife() throws {
        // 1,11 s und 1,10 s: gemeinsam 122 s, über der Grenze von 30 s.
        let l = try Zusatzicons.zeitleiste(spuren: [[0.37, 0.37, 0.37], [0.55, 0.55]])
        XCTAssertEqual(l.reduce(0) { $0 + $1.dauer }, 1.11, accuracy: 1e-9)
    }

    // MARK: Virtuelle Uhr

    private let kopf = ["content-type": "application/json"]

    private func push(_ koerper: String, _ z: inout NGUhrzustand) -> VirtuelleNGUhr.Antwort {
        VirtuelleNGUhr.beantworten(.init("PUT", "/api/v1/apps/pushed/z", koerper: Data(koerper.utf8), kopf: kopf), &z)
    }

    private func feld(_ a: VirtuelleNGUhr.Antwort) -> String? {
        guard let o = try? JSONSerialization.jsonObject(with: a.koerper) as? [String: Any],
              let e = o["error"] as? [String: Any] else { return nil }
        return e["field"] as? String
    }

    func testDieVirtuelleUhrPruefetIconsWieDieFirmware() {
        var z = NGUhrzustand()
        let uri = "data:image/gif;base64,R0lGODlhAQABAAAAACw="
        XCTAssertEqual(push(#"{"icons":[{"icon":"a","x":0,"y":65535},{"icon":"b"}]}"#, &z).status, 200)
        XCTAssertEqual(push(#"{"icons":[]}"#, &z).status, 200)
        let fuenf = (0..<5).map { _ in #"{"icon":"\#(uri)"}"# }.joined(separator: ",")
        XCTAssertEqual(feld(push("{\"icons\":[\(fuenf)]}", &z)), "icons")
        XCTAssertEqual(feld(push(#"{"icons":[{"icon":"a"},{"icon":"b","x":65536}]}"#, &z)), "icons[1].x")
        XCTAssertEqual(feld(push(#"{"icons":[{"icon":"a","y":1.5}]}"#, &z)), "icons[0].y")
        XCTAssertEqual(feld(push(#"{"icons":[{"x":1}]}"#, &z)), "icons[0].icon")
        XCTAssertEqual(feld(push(#"{"icons":[{"icon":""}]}"#, &z)), "icons[0].icon")
        XCTAssertEqual(feld(push(#"{"icons":[{"icon":"a","z":1}]}"#, &z)), "icons[0].z")
        XCTAssertEqual(feld(push(#"{"icons":["a"]}"#, &z)), "icons[0]")
        XCTAssertEqual(feld(push(#"{"icons":"a"}"#, &z)), "icons")
    }

    func testDieVirtuelleUhrZeichnetDieNutzlastDerApp() throws {
        let a = Ablage()
        try a.icon("stern", farben: ["#FF0000"])
        var z = NGUhrzustand()
        let json = try nutzlast([Zusatzicon(nummer: "stern", x: 6, y: 2)], a: a, mass: tc002, text: "")
        XCTAssertEqual(push(json, &z).status, 200, json)
        _ = VirtuelleNGUhr.beantworten(.init("PUT", "/api/v1/apps/active", koerper: Data("z".utf8)), &z)
        let bild = VirtuelleNGUhr.bildschirm(z)
        // Verdoppelt, bei Seitenspalte 3 / Zeile 1 = Anzeigepixel 6 / 2: Randspalte 7 liegt auf 6 + 14.
        XCTAssertEqual(bild[2 * 52 + 6 + 14], 0xFF0000)
        XCTAssertEqual(bild[15 * 52 + 6 + 14], 0xFF0000, "ab Zeile 2, 16 Zeilen hoch: bis zum unteren Rand")
        XCTAssertEqual(bild[1 * 52 + 6 + 14], 0)
    }
}
