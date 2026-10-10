import XCTest
@testable import TC002Core

/// Das Modell eines Layouts: die Bytes, die hinausgehen, und was vorher
/// abgewiesen wird (`docs/awtrix-ng-protokoll.md` §9).
final class KastenlayoutTests: XCTestCase {
    /// Drei Regionen, wie das Beispiel der Doku zu 5a: Text, Fortschritt, Zeichnung.
    static let dreiRegionen = Kastenlayout(regionen: [
        Layoutregion(kennung: "titel", kasten: Kasten(x: 0, y: 0, breite: 52, hoehe: 8),
                     inhalt: .text(Layouttext("HALLO", lauf: .ruhend)), farbe: .farbe("#00AAFF")),
        Layoutregion(kennung: "balken", kasten: Kasten(x: 0, y: 8, breite: 26, hoehe: 4),
                     inhalt: .fortschritt(50), farbe: .farbe("#00FF00"), fortschrittsgrund: "#202020"),
        Layoutregion(kennung: "marke", kasten: Kasten(x: 30, y: 8, breite: 22, hoehe: 8),
                     inhalt: .zeichnung([.flaeche(x: 0, y: 0, breite: 22, hoehe: 8, farbe: "#FF0000"),
                                         .pixel(x: 0, y: 0, farbe: "#0000FF")])),
    ])

    private func region(_ k: String, _ kasten: Kasten = Kasten(x: 0, y: 0, breite: 8, hoehe: 8),
                        _ inhalt: Layoutinhalt = .fortschritt(10)) -> Layoutregion {
        Layoutregion(kennung: k, kasten: kasten, inhalt: inhalt)
    }

    private func fehler(_ l: Kastenlayout, mass: Anzeigemass = .vorgabe,
                        _ f: Geraetefaehigkeiten? = nil) -> LayoutFehler? {
        do { try l.pruefen(mass: mass, faehigkeiten: f); return nil } catch { return error as? LayoutFehler }
    }

    // MARK: - Bytes

    func testDieNutzlastTraegtGenauDieSchluesselDerDoku() throws {
        let json = try Anzeigen.nutzlast(Frame(dauer: 10, layout: Self.dreiRegionen))
        XCTAssertEqual(json, ##"{"layout":{"version":1,"regions":["##
            + ##"{"id":"titel","box":[0,0,52,8],"text":"HALLO","color":"#00AAFF","scroll":{"mode":"static"}},"##
            + ##"{"id":"balken","box":[0,8,26,4],"progress":50,"color":"#00FF00","trackColor":"#202020"},"##
            + ##"{"id":"marke","box":[30,8,22,8],"draw":[["rectFill",0,0,22,8,"#FF0000"],["pixel",0,0,"#0000FF"]]}"##
            + ##"]},"durationMs":10000}"##)
    }

    func testEbeneDesLayoutsTraegtDieDarstellung() throws {
        var l = Self.dreiRegionen
        l.darstellung = Darstellung(hintergrundfarbe: "#101010", overlay: "rain")
        XCTAssertTrue(try Anzeigen.nutzlast(Frame(layout: l)).contains(##"],"backgroundColor":"#101010","overlay":"rain"}}"##))
    }

    func testSymbolUndDiagrammUndFarbteileHabenDieSchluesselDerDoku() throws {
        let l = Kastenlayout(regionen: [
            region("a", Kasten(x: 0, y: 4, breite: 8, hoehe: 8), .icon("sun")),
            region("b", Kasten(x: 9, y: 0, breite: 20, hoehe: 16),
                   .diagramm(Layoutdiagramm(art: .linie, werte: [1, 5, 2], untergrenze: 0, obergrenze: 8))),
            Layoutregion(kennung: "c", kasten: Kasten(x: 30, y: 0, breite: 22, hoehe: 8),
                         inhalt: .text(Layouttext(teile: [.init(text: "A", farbe: "#FF0000"), .init(text: "B")])),
                         waagrecht: .ende, senkrecht: .anfang, schrift: "large"),
        ])
        let json = try Anzeigen.nutzlast(Frame(layout: l))
        XCTAssertTrue(json.contains(#"{"id":"a","box":[0,4,8,8],"icon":"sun"}"#))
        XCTAssertTrue(json.contains(#""chart":{"values":[1,5,2],"type":"line","min":0,"max":8}"#))
        XCTAssertTrue(json.contains(##""text":[{"text":"A","color":"#FF0000"},{"text":"B"}],"align":"end","valign":"start","font":"large""##))
    }

    // MARK: - Pruefen

    func testDreiRegionenSindGueltig() {
        XCTAssertNil(fehler(Self.dreiRegionen))
    }

    func testLeeresLayoutWirdAbgewiesen() {
        XCTAssertEqual(fehler(Kastenlayout(regionen: [])), .keineRegionen)
    }

    func testSechzehnRegionenJa_siebzehnNein() {
        func viele(_ n: Int) -> Kastenlayout {
            Kastenlayout(regionen: (0..<n).map { region("r\($0)", Kasten(x: $0 % 8, y: $0 / 8, breite: 1, hoehe: 1)) })
        }
        XCTAssertNil(fehler(viele(16)))
        XCTAssertEqual(fehler(viele(17)), .zuvieleRegionen(hoechstens: 16))
    }

    /// Ohne `scroll` läuft ein Text (§9.3): Neun solche sind einer zu viel.
    func testAchtLaufendeTexte() {
        func texte(_ n: Int, lauf: Layoutlauf?) -> Kastenlayout {
            Kastenlayout(regionen: (0..<n).map {
                region("t\($0)", Kasten(x: $0, y: 0, breite: 1, hoehe: 8), .text(Layouttext("x", lauf: lauf)))
            })
        }
        XCTAssertNil(fehler(texte(8, lauf: nil)))
        XCTAssertEqual(fehler(texte(9, lauf: nil)), .zuvieleLaufschriften(hoechstens: 8))
        XCTAssertNil(fehler(texte(9, lauf: .ruhend)), "ruhende Texte zählen nicht")
    }

    func testVierIcons() {
        func icons(_ n: Int) -> Kastenlayout {
            Kastenlayout(regionen: (0..<n).map { region("i\($0)", Kasten(x: $0 * 8, y: 0, breite: 8, hoehe: 8), .icon("sun")) })
        }
        XCTAssertNil(fehler(icons(4)))
        XCTAssertEqual(fehler(icons(5)), .zuvieleIcons(hoechstens: 4))
    }

    func testDiagrammwerte() {
        func diagramm(_ n: Int) -> Kastenlayout {
            Kastenlayout(regionen: [region("d", Kasten(x: 0, y: 0, breite: 52, hoehe: 16),
                                           .diagramm(Layoutdiagramm(art: .balken, werte: Array(repeating: 1, count: n))))])
        }
        XCTAssertNil(fehler(diagramm(128)))
        XCTAssertEqual(fehler(diagramm(129)), .zuvieleWerte(region: "d", hoechstens: 128))
    }

    func testMinUndMaxNurZusammenUndGeordnet() {
        func mit(_ u: Int?, _ o: Int?) -> LayoutFehler? {
            fehler(Kastenlayout(regionen: [region("d", Kasten(x: 0, y: 0, breite: 8, hoehe: 8),
                .diagramm(Layoutdiagramm(art: .linie, werte: [1, 2], untergrenze: u, obergrenze: o)))]))
        }
        XCTAssertNil(mit(nil, nil))
        XCTAssertNil(mit(0, 5))
        XCTAssertEqual(mit(0, nil), .diagrammGrenzen(region: "d"))
        XCTAssertEqual(mit(5, 5), .diagrammGrenzen(region: "d"))
    }

    func testKastenMussGanzImDisplayLiegen() {
        let l = Kastenlayout(regionen: [region("a", Kasten(x: 40, y: 0, breite: 13, hoehe: 8))])
        XCTAssertEqual(fehler(l), .kastenAusserhalb(region: "a", breite: 52, hoehe: 16))
        XCTAssertNil(fehler(Kastenlayout(regionen: [region("a", Kasten(x: 40, y: 0, breite: 12, hoehe: 16))])))
        // Dasselbe Layout auf einer 32 × 8: das Maß der Uhr entscheidet.
        XCTAssertEqual(fehler(Self.dreiRegionen, mass: Anzeigemass(breite: 32, hoehe: 8)),
                       .kastenAusserhalb(region: "titel", breite: 32, hoehe: 8))
        XCTAssertNotNil(fehler(Kastenlayout(regionen: [region("n", Kasten(x: -1, y: 0, breite: 4, hoehe: 4))])))
        XCTAssertNotNil(fehler(Kastenlayout(regionen: [region("n", Kasten(x: 0, y: 0, breite: 0, hoehe: 4))])))
    }

    func testKennungenEinmaligUndHoechstens64Byte() {
        XCTAssertEqual(fehler(Kastenlayout(regionen: [region("a"), region("a", Kasten(x: 8, y: 0, breite: 8, hoehe: 8))])),
                       .doppelteKennung("a"))
        XCTAssertEqual(fehler(Kastenlayout(regionen: [region("")])), .ungueltigeKennung(""))
        XCTAssertNil(fehler(Kastenlayout(regionen: [region(String(repeating: "x", count: 64))])))
        XCTAssertNotNil(fehler(Kastenlayout(regionen: [region(String(repeating: "x", count: 65))])))
    }

    func testTextGesamtHoechstens8192Byte() {
        func mit(_ n: Int) -> Kastenlayout {
            Kastenlayout(regionen: [
                region("a", Kasten(x: 0, y: 0, breite: 26, hoehe: 8), .text(Layouttext(String(repeating: "a", count: n), lauf: .ruhend))),
                region("b", Kasten(x: 26, y: 0, breite: 26, hoehe: 8), .text(Layouttext(String(repeating: "b", count: n), lauf: .ruhend)))])
        }
        XCTAssertNil(fehler(mit(4096)))
        XCTAssertEqual(fehler(mit(4097)), .textZuLang(hoechstens: 8192))
    }

    func testEinFeldAnFalscherStelleWirdAbgewiesen() {
        var r = region("a", Kasten(x: 0, y: 0, breite: 8, hoehe: 8), .icon("sun"))
        r.farbe = .farbe("#FF0000")
        XCTAssertEqual(fehler(Kastenlayout(regionen: [r])), .feldPasstNicht(region: "a", feld: "color"))
        var d = region("d", Kasten(x: 0, y: 0, breite: 8, hoehe: 8), .zeichnung([.pixel(x: 0, y: 0, farbe: nil)]))
        d.fortschrittsgrund = "#202020"
        XCTAssertEqual(fehler(Kastenlayout(regionen: [d])), .feldPasstNicht(region: "d", feld: "trackColor"))
    }

    func testPaletteFarbeBrauchtEinePalette() {
        var r = region("a", Kasten(x: 0, y: 0, breite: 8, hoehe: 8), .fortschritt(10))
        r.farbe = .palette
        XCTAssertThrowsError(try Kastenlayout(regionen: [r]).pruefen())
        XCTAssertNoThrow(try Kastenlayout(regionen: [r], darstellung: Darstellung(palette: .name("Ocean"))).pruefen(),
                     "die Palette des Layouts gilt für Regionen ohne eigene")
    }

    func testZeichnungMitSchlechterFarbe() {
        let l = Kastenlayout(regionen: [region("z", Kasten(x: 0, y: 0, breite: 8, hoehe: 8),
                                               .zeichnung([.pixel(x: 0, y: 0, farbe: "rot")]))])
        guard case .zeichnungUngueltig(let r, _)? = fehler(l) else { return XCTFail("\(String(describing: fehler(l)))") }
        XCTAssertEqual(r, "z")
    }

    func testEinGrossesIconWirdAbgewiesen() {
        let uri = "data:image/gif;base64," + String(repeating: "A", count: 7600)
        guard case .iconZuGross? = fehler(Kastenlayout(regionen: [region("i", Kasten(x: 0, y: 0, breite: 8, hoehe: 8), .icon(uri))])) else {
            return XCTFail("zu groß")
        }
        XCTAssertNil(fehler(Kastenlayout(regionen: [region("i", Kasten(x: 0, y: 0, breite: 8, hoehe: 8),
                                                           .icon("data:image/gif;base64," + String(repeating: "A", count: 7508)))])))
    }

    // MARK: - Faehigkeiten der Uhr

    /// Eine Uhr, die kein `layout` meldet (TC001/ESP32), bekommt keines — und
    /// zwar nach ihrer Auskunft, nicht nach Name oder Maß.
    func testEineUhrOhneLayoutsBekommtKeines() throws {
        let esp32 = try XCTUnwrap(Geraetefaehigkeiten(antwort: ["effects": ["Plasma"], "overlays": [String]()]))
        XCTAssertEqual(esp32.layoutUnterstuetzt, false)
        XCTAssertEqual(fehler(Self.dreiRegionen, esp32), .nichtUnterstuetzt)
        XCTAssertThrowsError(try Anzeigen.nutzlast(Frame(layout: Self.dreiRegionen), faehigkeiten: esp32))
    }

    func testEineUhrMitLayoutsUndEigenenGrenzen() throws {
        let tc002 = try XCTUnwrap(Geraetefaehigkeiten(antwort: [
            "effects": ["Plasma"], "layout": true,
            "layouts": ["version": 1, "limits": ["regions": 2, "scrollers": 1, "assets": 1,
                                                  "chartPoints": 4, "textBytes": 10]]]))
        XCTAssertEqual(tc002.layoutUnterstuetzt, true)
        XCTAssertEqual(tc002.layoutGrenzen.regionen, 2)
        XCTAssertEqual(fehler(Self.dreiRegionen, tc002), .zuvieleRegionen(hoechstens: 2))
        XCTAssertNil(fehler(Kastenlayout(regionen: [region("a")]), tc002))
    }

    func testOhneAuskunftBleibtEsOffen() {
        XCTAssertNil(Geraetefaehigkeiten().layoutUnterstuetzt)
        XCTAssertNil(fehler(Self.dreiRegionen, Geraetefaehigkeiten()))
    }

    // MARK: - Rahmen

    func testEinLayoutVertraegtKeinenAnderenInhalt() {
        let meldung = Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "x", weg: .text)),
                            layout: Self.dreiRegionen)
        XCTAssertThrowsError(try Anzeigen.nutzlast(meldung)) { XCTAssertEqual($0 as? LayoutFehler, .mitAnderemInhalt) }
        let mitDarstellung = Frame(darstellung: Darstellung(overlay: "rain"), layout: Self.dreiRegionen)
        XCTAssertThrowsError(try Anzeigen.nutzlast(mitDarstellung))
    }

    func testLebensdauerGehtMit() throws {
        let json = try Anzeigen.nutzlast(Frame(lebensdauer: Lebensdauer(sekunden: 60, ablauf: .entfernen), layout: Self.dreiRegionen))
        XCTAssertTrue(json.hasSuffix(#","lifetimeMs":60000,"lifetimeExpiry":"remove"}"#), json)
    }

    func testEineBenachrichtigungTraegtDasLayout() throws {
        let json = try NGNutzlast.benachrichtigung(Frame(dauer: 5, layout: Self.dreiRegionen), Benachrichtigungsoptionen(name: "n"))
        XCTAssertTrue(json.hasPrefix(#"{"layout":{"version":1"#))
        XCTAssertTrue(json.contains(#""durationMs":5000"#))
        XCTAssertTrue(json.contains(#""name":"n""#))
        XCTAssertFalse(json.contains("lifetimeMs"))
    }
}

/// Die Datei: genau die Schlüssel der Doku, streng gelesen.
final class LayoutdateiTests: XCTestCase {
    func testDasEigeneJSONLiestSichIdentischZurueck() throws {
        let json = try Anzeigen.nutzlast(Frame(dauer: 10, layout: KastenlayoutTests.dreiRegionen))
        let datei = try Layoutdatei.lesen(Data(json.utf8))
        XCTAssertEqual(datei.layout, KastenlayoutTests.dreiRegionen)
        XCTAssertEqual(datei.dauer, 10)
    }

    func testDerBlankeLayoutblockGenuegt() throws {
        let datei = try Layoutdatei.lesen(Data(#"{"version":1,"regions":[{"id":"a","box":[0,0,52,16],"progress":5}]}"#.utf8))
        XCTAssertEqual(datei.layout.regionen.count, 1)
        XCTAssertNil(datei.dauer)
    }

    func testAlleInhalteUndFelderUeberstehenDenKreislauf() throws {
        let l = Kastenlayout(regionen: [
            Layoutregion(kennung: "t", kasten: Kasten(x: 0, y: 0, breite: 20, hoehe: 8),
                         inhalt: .text({
                var t = Layouttext(teile: [.init(text: "a", farbe: "#FF0000"), .init(text: "b")],
                                   lauf: Layoutlauf(modus: "loop", richtung: "right", einlauf: "offscreen",
                                                    wennPassend: "scroll", tempo: 50, haltMs: 10, abstand: 4))
                t.wiederholungen = 2; t.schreibweise = "upper"; t.blinkMs = 100; t.faedeMs = 200
                t.farbeVonAnzeige = "meldung1"
                return t }()), waagrecht: .anfang, senkrecht: .ende, farbe: .palette, schrift: "large",
                         palette: .stellen([.init(farbe: "#FF0000", pos: 0), .init(farbe: "#0000FF", pos: 100)]),
                         paletteUeberblenden: false, paletteSpanne: 3, paletteTempo: 1.5),
            Layoutregion(kennung: "c", kasten: Kasten(x: 0, y: 8, breite: 20, hoehe: 8),
                         inhalt: .diagramm(Layoutdiagramm(art: .balken, werte: [1, -2, 3], untergrenze: -2, obergrenze: 4))),
            Layoutregion(kennung: "z", kasten: Kasten(x: 20, y: 0, breite: 20, hoehe: 8), inhalt: .zeichnung([
                .pixels(farbe: nil, koordinaten: [1, 2, 3, 4]), .linie(x1: 0, y1: 0, x2: 3, y2: 3, farbe: "#FFFFFF"),
                .rahmen(x: 0, y: 0, breite: 2, hoehe: 2, farbe: nil), .kreis(x: 5, y: 5, radius: 2, farbe: nil),
                .kreisflaeche(x: 8, y: 5, radius: 1, farbe: "#00FF00"), .text(x: 0, y: 1, text: "Hi \"du\"", farbe: nil),
                .bild(x: 0, y: 0, breite: 1, hoehe: 1, daten: .farben(["#FFFFFF"])),
                .bild(x: 0, y: 0, breite: 1, hoehe: 1, daten: .rgbBase64("////"))])),
            Layoutregion(kennung: "i", kasten: Kasten(x: 40, y: 0, breite: 8, hoehe: 8), inhalt: .icon("sun"),
                         waagrecht: .mitte),
        ], darstellung: Darstellung(effekt: "Plasma", effektTempo: 2, overlay: "rain",
                                    palette: .farben(["#FF0000", "#00FF00"]), paletteUeberblenden: true,
                                    paletteSpanne: 4, paletteTempo: 0.5))
        try l.pruefen()
        let zurueck = try Layoutdatei.lesen(Data(try Anzeigen.nutzlast(Frame(layout: l)).utf8)).layout
        XCTAssertEqual(zurueck, l)
    }

    func testEinUnbekannterSchluesselHatEinenPfad() {
        func meldung(_ text: String) -> String? {
            do { _ = try Layoutdatei.lesen(Data(text.utf8)); return nil } catch { return "\(error)" }
        }
        XCTAssertTrue(meldung(#"{"layout":{"regions":[]},"text":"x"}"#)?.contains("unbekannterSchluessel(\"text\")") == true)
        XCTAssertTrue(meldung(#"{"regions":[{"id":"a","box":[0,0,1,1],"progress":1,"bunt":1}]}"#)?
            .contains("layout.regions[0].bunt") == true)
        XCTAssertNotNil(meldung(#"{"regions":[{"id":"a","box":[0,0,1,1]}]}"#), "ohne Inhalt")
        XCTAssertNotNil(meldung(#"{"regions":[{"id":"a","box":[0,0,1,1],"progress":1,"icon":"x"}]}"#), "zwei Inhalte")
        XCTAssertNotNil(meldung(#"{"regions":[{"id":"a","box":[0,0,1],"progress":1}]}"#), "box zu kurz")
        XCTAssertNotNil(meldung(#"{"regions":[{"id":"a","box":[0,0,1,1],"progress":1,"color":"rot"}]}"#))
        XCTAssertNotNil(meldung(#"{"layout":{"version":2,"regions":[]}}"#))
        XCTAssertNotNil(meldung("kein json"))
        XCTAssertNotNil(meldung(#"{"layout":{"regions":[]},"durationMs":1500}"#), "nur ganze Sekunden")
    }
}
