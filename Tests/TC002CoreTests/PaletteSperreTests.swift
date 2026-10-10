import XCTest
@testable import TC002Core

/// Eine Palette färbt Effekt, Overlay und „Text aus Palette“ (§5.5). Im
/// Bildweg sind Effekt und Text malen gesperrt; ohne Overlay hat die Palette
/// dort nichts zu färben und wird weder angeboten noch gesendet.
final class PaletteSperreTests: XCTestCase {
    private func wahl(overlay: String? = nil, effekt: String? = nil, textAusPalette: Bool = false) -> Darstellungswahl {
        var w = Darstellungswahl()
        w.palette = .name("Ocean")
        w.eigenePalette = Eigenepalette()
        w.ueberblenden = false
        w.overlay = overlay
        w.effekt = effekt
        w.textAusPalette = textAusPalette
        return w
    }

    func testImBildwegOhneOverlayIstDiePaletteGesperrt() {
        XCTAssertTrue(Darstellungsregeln(weg: .pixel, wahl: wahl()).paletteGesperrt)
        XCTAssertTrue(Darstellungsregeln(weg: .pixel, wahl: wahl(effekt: "plasma", textAusPalette: true)).paletteGesperrt,
                      "Effekt und Text malen sind im Bildweg selbst gesperrt und zählen nicht")
    }

    func testImBildwegGibtEinOverlayDiePaletteFrei() {
        XCTAssertFalse(Darstellungsregeln(weg: .pixel, wahl: wahl(overlay: "rain")).paletteGesperrt)
    }

    func testMitDerSchriftDerUhrIstDiePaletteImmerFrei() {
        XCTAssertFalse(Darstellungsregeln(weg: .text, wahl: wahl()).paletteGesperrt)
    }

    /// Eine gesperrte Palette geht nicht hinaus: weder `palette` noch
    /// `paletteBlend` noch `textColor: palette`.
    func testGesperrtePaletteStehtNichtInDerNutzlast() throws {
        let o = Meldungsoptionen(text: "Hi", weg: .pixel, darstellung: wahl())
        XCTAssertNil(o.darstellung?.darstellung(weg: .pixel), "nichts übrig, was zu senden wäre")
        let rahmen = try Meldungsbau.rahmen(o, icon: nil, sammlung: Iconsammlung(schreibordner:
            URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)))
        let json = try Anzeigen.nutzlast(rahmen)
        XCTAssertFalse(json.contains("palette"), json)
        XCTAssertFalse(json.contains("paletteBlend"), json)
    }

    func testMitOverlayGehtDiePaletteImBildwegHinaus() throws {
        let d = try XCTUnwrap(wahl(overlay: "rain").darstellung(weg: .pixel))
        XCTAssertEqual(d.overlay, "rain")
        XCTAssertNotNil(d.palette)
    }

    func testMitDerSchriftDerUhrGehtSieHinausUndMaltDenText() throws {
        let d = try XCTUnwrap(wahl(textAusPalette: true).darstellung(weg: .text))
        XCTAssertNotNil(d.palette)
        XCTAssertTrue(d.textfarbeAusPalette)
        let json = try NGNutzlast.anzeige(Meldungsoptionen(text: "Hi", weg: .text), textfarbeAusPalette: true)
        XCTAssertTrue(json.contains(#""textColor":"palette""#))
    }

    func testPaletteWirktErstMitEffektOverlayOderTextMalen() {
        XCTAssertFalse(Darstellungsregeln(weg: .text, wahl: wahl()).paletteWirkt(faehigkeiten: nil))
        XCTAssertTrue(Darstellungsregeln(weg: .text, wahl: wahl(textAusPalette: true)).paletteWirkt(faehigkeiten: nil))
        XCTAssertTrue(Darstellungsregeln(weg: .text, wahl: wahl(effekt: "Plasma")).paletteWirkt(faehigkeiten: nil))
        XCTAssertTrue(Darstellungsregeln(weg: .pixel, wahl: wahl(overlay: "snow")).paletteWirkt(faehigkeiten: nil))
    }
}
