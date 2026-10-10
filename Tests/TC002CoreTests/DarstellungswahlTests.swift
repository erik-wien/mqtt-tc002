import XCTest
@testable import TC002Core

/// Die Wahl hinter dem Reiter „Darstellung": was daraus je Weg hinausgeht, was
/// gesperrt ist, und dass sie in Platz, Verlauf und Datei überlebt.
final class DarstellungswahlTests: XCTestCase {

    private let uhr = Geraetefaehigkeiten(
        effekte: ["Plasma", "Matrix"], paletteneffekte: ["Plasma"],
        overlays: ["rain"], paletten: ["Lava"], uebergaenge: [])

    private func temp() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    private func alles() -> Darstellungswahl {
        var w = Darstellungswahl()
        w.hintergrundfarbe = "#112233"
        w.effekt = "Plasma"
        w.tempo = 2.5
        w.overlay = "rain"
        w.palette = .name("Lava")
        w.ueberblenden = false
        w.textAusPalette = true
        w.spanne = 8
        w.lauf = 0.5
        return w
    }

    // MARK: - Was hinausgeht

    func testNichtsGewaehltSendetNichts() {
        XCTAssertNil(Darstellungswahl().darstellung(weg: .pixel))
        XCTAssertNil(Darstellungswahl().darstellung(weg: .text))
    }

    func testTextAlsBildSendetWederFarbeNochEffektNochTextmalen() throws {
        let d = try XCTUnwrap(alles().darstellung(weg: .pixel))
        XCTAssertNil(d.hintergrundfarbe)
        XCTAssertNil(d.effekt)
        XCTAssertFalse(d.textfarbeAusPalette)
        XCTAssertNil(d.paletteSpanne)
        XCTAssertNil(d.paletteTempo)
        XCTAssertEqual(d.overlay, "rain")
        XCTAssertEqual(d.palette, .name("Lava"))
        XCTAssertEqual(d.paletteUeberblenden, false)
        XCTAssertEqual(d.effektTempo, 2.5, "das Tempo gilt dem Overlay")
    }

    func testWasDieOberflaecheSendetWeistDerKernNieAlsVerdecktAb() throws {
        let frame = Frame(pixel: Pixelinhalt(breite: 52, hoehe: 16, bilder: [
            Bildraster.Einzelbild(pixel: [String?](repeating: "#FF0000", count: 832), dauer: 1)]),
                          darstellung: alles().darstellung(weg: .pixel))
        XCTAssertNoThrow(try Anzeigen.nutzlast(frame, faehigkeiten: uhr))
    }

    func testMitGeraetschriftGeltenAlleReglerUndEinEffektVerdraengtDieFarbe() throws {
        let d = try XCTUnwrap(alles().darstellung(weg: .text))
        XCTAssertEqual(d.effekt, "Plasma")
        XCTAssertNil(d.hintergrundfarbe, "Farbe und Effekt schließen sich aus")
        XCTAssertTrue(d.textfarbeAusPalette)
        XCTAssertEqual(d.paletteSpanne, 8)
        XCTAssertEqual(d.paletteTempo, 0.5)
        let frame = Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "x", weg: .text)),
                          darstellung: d)
        XCTAssertNoThrow(try Anzeigen.nutzlast(frame, faehigkeiten: uhr))
    }

    func testOhneEffektGehtDieHintergrundfarbeUndSchwarzHeisstKeine() throws {
        var w = Darstellungswahl()
        w.hintergrundfarbe = "#112233"
        XCTAssertEqual(w.darstellung(weg: .text)?.hintergrundfarbe, "#112233")
        w.hintergrundfarbe = Darstellungswahl.keinHintergrund
        XCTAssertNil(w.darstellung(weg: .text))
    }

    func testDasTempoGehtNurMitEffektOderOverlay() {
        var w = Darstellungswahl()
        w.tempo = 3
        XCTAssertNil(w.darstellung(weg: .text))
        w.effekt = "Plasma"
        XCTAssertEqual(w.darstellung(weg: .text)?.effektTempo, 3)
        XCTAssertNil(w.darstellung(weg: .pixel), "ein Effekt ist bei Text als Bild gesperrt")
        w.effekt = nil
        w.overlay = "rain"
        XCTAssertEqual(w.darstellung(weg: .pixel)?.effektTempo, 3)
    }

    func testTextAusPaletteOhnePaletteMeldetDenFehlerDesKerns() throws {
        var w = Darstellungswahl()
        w.textAusPalette = true
        let d = try XCTUnwrap(w.darstellung(weg: .text))
        let frame = Frame(herkunft: Meldungsherkunft(optionen: Meldungsoptionen(text: "x", weg: .text)),
                          darstellung: d)
        XCTAssertThrowsError(try Anzeigen.nutzlast(frame, faehigkeiten: uhr)) {
            XCTAssertEqual($0 as? DarstellungsFehler, .paletteFehlt(feld: "textColor"))
        }
    }

    func testEigenePaletteGleichmaessigOderMitPosition() throws {
        var w = Darstellungswahl()
        w.palette = .eigene
        w.eigenePalette = Eigenepalette(stellen: [.init(farbe: "#FF0000", pos: 0), .init(farbe: "#0000FF", pos: 40)])
        XCTAssertEqual(w.darstellung(weg: .text)?.palette, .farben(["#FF0000", "#0000FF"]))
        w.eigenePalette.mitPosition = true
        XCTAssertEqual(w.darstellung(weg: .text)?.palette,
                       .stellen([.init(farbe: "#FF0000", pos: 0), .init(farbe: "#0000FF", pos: 40)]))
    }

    func testEigenePaletteHaeltEinsBisSechzehn() {
        var p = Eigenepalette(stellen: [.init(farbe: "#FF0000", pos: 0)])
        p.entfernen()
        XCTAssertEqual(p.stellen.count, 1)
        for _ in 0..<30 { p.hinzufuegen() }
        XCTAssertEqual(p.stellen.count, 16)
        XCTAssertNoThrow(try p.palette.pruefen(gegen: nil))
        p.mitPosition = true
        p.gleichmaessigVerteilen()
        XCTAssertEqual(p.stellen.first?.pos, 0)
        XCTAssertEqual(p.stellen.last?.pos, 100)
        XCTAssertEqual(Eigenepalette.gleichmaessigeLagen(3), [0, 50, 100])
        XCTAssertNoThrow(try p.palette.pruefen(gegen: nil))
    }

    // MARK: - Was gesperrt ist

    func testDieSperrenFolgenDemWeg() {
        var w = Darstellungswahl()
        let bild = Darstellungsregeln(weg: .pixel, wahl: w)
        XCTAssertTrue(bild.effektGesperrt)
        XCTAssertTrue(bild.farbeGesperrt)
        XCTAssertTrue(bild.textMalenGesperrt)
        XCTAssertTrue(bild.spanneLaufGesperrt)
        XCTAssertTrue(bild.tempoGesperrt)
        let text = Darstellungsregeln(weg: .text, wahl: w)
        XCTAssertFalse(text.effektGesperrt)
        XCTAssertFalse(text.farbeGesperrt)
        XCTAssertFalse(text.textMalenGesperrt)
        XCTAssertTrue(text.spanneLaufGesperrt, "ohne „Text aus Palette“ gibt es nichts zu malen")
        XCTAssertTrue(text.tempoGesperrt)
        w.effekt = "Plasma"
        w.textAusPalette = true
        let mitEffekt = Darstellungsregeln(weg: .text, wahl: w)
        XCTAssertTrue(mitEffekt.farbeGesperrt)
        XCTAssertTrue(mitEffekt.farbeDurchEffekt)
        XCTAssertFalse(mitEffekt.tempoGesperrt)
        XCTAssertFalse(mitEffekt.spanneLaufGesperrt)
        w.effekt = nil
        w.overlay = "rain"
        XCTAssertFalse(Darstellungsregeln(weg: .pixel, wahl: w).tempoGesperrt)
    }

    func testDiePaletteWirktMitOverlayEffektDerSieNutztOderTextAusPalette() {
        var w = Darstellungswahl()
        w.palette = .name("Lava")
        XCTAssertFalse(Darstellungsregeln(weg: .text, wahl: w).paletteWirkt(faehigkeiten: uhr))
        w.effekt = "Matrix"
        XCTAssertFalse(Darstellungsregeln(weg: .text, wahl: w).paletteWirkt(faehigkeiten: uhr))
        w.effekt = "Plasma"
        XCTAssertTrue(Darstellungsregeln(weg: .text, wahl: w).paletteWirkt(faehigkeiten: uhr))
        XCTAssertFalse(Darstellungsregeln(weg: .pixel, wahl: w).paletteWirkt(faehigkeiten: uhr),
                       "bei Text als Bild läuft kein Effekt")
        w.effekt = nil
        w.overlay = "rain"
        XCTAssertTrue(Darstellungsregeln(weg: .pixel, wahl: w).paletteWirkt(faehigkeiten: uhr))
    }

    // MARK: - Ablage

    func testDieWahlUeberlebtDenWegDurchJSON() throws {
        let w = alles()
        XCTAssertEqual(Darstellungswahl(rawValue: w.rawValue), w)
        XCTAssertEqual(Darstellungswahl(rawValue: "{}"), Darstellungswahl(), "fehlende Felder heißen Vorgabe")
        XCTAssertNil(Darstellungswahl(rawValue: "kein json"))
    }

    func testEinSlotstandOhneDarstellungBleibtLesbar() throws {
        let json = """
        {"platz":3,"text":"Bus kommt","weg":"pixel","schrift":"Silkscreen",\
        "groesse":8,"fett":false,"grossbuchstaben":false,"rand":1,"abstand":1,\
        "waagrecht":"links","senkrecht":"oben","farbe":"#00FF66","tempo":"mittel",\
        "iconLaeuftMit":false,"pruefsumme":"abcd1234"}
        """
        let stand = try JSONDecoder().decode(Slotstand.self, from: Data(json.utf8))
        XCTAssertNil(stand.darstellung)
        XCTAssertNil(stand.optionen?.darstellung)
    }

    func testDerPlatzMerktDieDarstellung() throws {
        let g = Slotgedaechtnis(ordner: temp())
        let uhrid = UUID()
        var o = Meldungsoptionen(text: "Küche")
        o.darstellung = alles()
        XCTAssertTrue(g.merken(o, icon: nil, iconKante: 8, fuer: uhrid, platz: 2))
        let stand = try XCTUnwrap(g.gemerkt(fuer: uhrid, platz: 2))
        XCTAssertEqual(stand.darstellung, alles())
        XCTAssertEqual(stand.optionen?.darstellung, alles())
        // Eine neue Sendung ohne Darstellung löscht die alte Erinnerung.
        XCTAssertTrue(g.merken(Meldungsoptionen(text: "Küche"), icon: nil, iconKante: 8, fuer: uhrid, platz: 2))
        XCTAssertNil(g.gemerkt(fuer: uhrid, platz: 2)?.darstellung)
    }

    func testDerVerlaufTraegtDieDarstellungUndAelteresBleibtLesbar() throws {
        var o = Meldungsoptionen(text: "x")
        o.darstellung = alles()
        let e = Verlaufseintrag(platz: 1, uhr: "Küche", optionen: o, iconNummer: nil, iconKante: 8)
        let daten = try JSONEncoder().encode(e)
        XCTAssertEqual(try JSONDecoder().decode(Verlaufseintrag.self, from: daten).optionen.darstellung, alles())
        let alt = try JSONEncoder().encode(Meldungsoptionen(text: "x"))
        XCTAssertFalse(String(decoding: alt, as: UTF8.self).contains("darstellung"))
        XCTAssertNil(try JSONDecoder().decode(Meldungsoptionen.self, from: alt).darstellung)
    }

    func testDerRahmenTraegtDieDarstellungJeNachWeg() throws {
        let sammlung = Iconsammlung(schreibordner: temp())
        var o = Meldungsoptionen(text: "x")
        o.darstellung = alles()
        let bild = try Meldungsbau.rahmen(o, icon: nil, sammlung: sammlung)
        XCTAssertNil(bild.darstellung?.effekt)
        XCTAssertEqual(bild.darstellung?.overlay, "rain")
        o.weg = .text
        XCTAssertEqual(try Meldungsbau.rahmen(o, icon: nil, sammlung: sammlung).darstellung?.effekt, "Plasma")
        o.darstellung = nil
        XCTAssertNil(try Meldungsbau.rahmen(o, icon: nil, sammlung: sammlung).darstellung)
    }
}
