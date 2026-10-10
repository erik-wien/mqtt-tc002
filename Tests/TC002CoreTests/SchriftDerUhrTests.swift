import XCTest
@testable import TC002Core

/// Der Schalter „Schrift der Uhr" ist `SendeWeg.text`: Alles, was die
/// Oberflaeche daran haengt, steht im Kern und wird hier geprueft.
final class SchriftDerUhrTests: XCTestCase {
    /// Die Schriften muessen angemeldet sein, bevor irgendein Test sie
    /// befragt: Das Ergebnis wird je Schrift gemerkt, und eine Antwort vor der
    /// Anmeldung gilt dann fuer den ganzen Lauf.
    override func setUp() {
        super.setUp()
        Schriftbuendel.anmelden()
    }

    private func temp() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    func testDerSchalterIstDerWeg() {
        var weg = SendeWeg.pixel
        XCTAssertFalse(weg.schriftDerUhr, "Vorgabe: aus")
        weg.schriftDerUhr = true
        XCTAssertEqual(weg, .text)
        weg.schriftDerUhr = false
        XCTAssertEqual(weg, .pixel)
        XCTAssertEqual(Meldungsoptionen(text: "x").weg, .pixel, "neue Meldungen rastert die App")
    }

    /// Silkscreen kennt nur Grossbuchstaben: Auf dem Pixelweg bleibt der
    /// Schalter dort ohne Wirkung. Die Uhr hat Kleinbuchstaben, ihr Schalter
    /// wirkt immer.
    func testGrossbuchstabenWirkenBeiDerSchriftDerUhrImmer() {
        for schrift in ["Silkscreen", "Tiny5", "Menlo"] {
            XCTAssertEqual(AwtrixNG.grossbuchstabenWirken(weg: .pixel, schrift: schrift, groesse: 8),
                           Textraster.kannKleinbuchstaben(schrift: schrift, groesse: 8), schrift)
            XCTAssertTrue(AwtrixNG.grossbuchstabenWirken(weg: .text, schrift: schrift, groesse: 8), schrift)
        }
    }

    /// Die Regeln, die der Weg freigibt (`Darstellungsregeln`), und was
    /// hinausgeht: mit der Schrift der Uhr Hintergrundfarbe und Text aus der
    /// Palette, auf dem Pixelweg nur Overlay und Palette.
    func testDerWegGibtHintergrundEffektUndTextMalenFrei() throws {
        var wahl = Darstellungswahl()
        wahl.hintergrundfarbe = "#112233"
        wahl.textAusPalette = true
        wahl.palette = .name("Ocean")

        let pixel = Darstellungsregeln(weg: .pixel, wahl: wahl)
        XCTAssertTrue(pixel.farbeGesperrt && pixel.effektGesperrt && pixel.textMalenGesperrt)
        let text = Darstellungsregeln(weg: .text, wahl: wahl)
        XCTAssertFalse(text.farbeGesperrt || text.effektGesperrt || text.textMalenGesperrt)

        let o = Meldungsoptionen(text: "Hallo", weg: .text, darstellung: wahl)
        let rahmen = try Meldungsbau.rahmen(o, icon: nil, sammlung: Iconsammlung(schreibordner: temp()))
        XCTAssertNil(rahmen.pixel, "die Uhr setzt den Text, die App schickt kein Bild")
        XCTAssertNotNil(rahmen.herkunft)
        XCTAssertEqual(rahmen.darstellung?.hintergrundfarbe, "#112233")
        XCTAssertEqual(rahmen.darstellung?.textfarbeAusPalette, true)
        let json = try Anzeigen.nutzlast(rahmen)
        XCTAssertTrue(json.contains(#""text":"Hallo""#), json)
        XCTAssertFalse(json.contains("data:image"), "kein GIF auf diesem Weg")
    }

    /// Die Uhr bekommt den Text, wie er eingetippt wurde; die Grossschreibung
    /// bleibt eine Einstellung der Uhr (`textCase`).
    func testGrossschreibungBleibtEineEinstellungDerUhr() throws {
        let an = try NGNutzlast.anzeige(Meldungsoptionen(text: "Grüße", weg: .text, grossbuchstaben: true))
        XCTAssertTrue(an.contains(#""text":"Grüße""#) && an.contains(#""textCase":"upper""#), an)
        let aus = try NGNutzlast.anzeige(Meldungsoptionen(text: "Grüße", weg: .text))
        XCTAssertTrue(aus.contains(#""textCase":"asTyped""#), aus)
    }

    /// Das Slotgedaechtnis traegt den Weg unveraendert: Ein Platz, den die
    /// Uhr in ihrer Schrift zeigt, stellt den Schalter wieder auf „an".
    func testDasSlotgedaechtnisMerktDenWeg() throws {
        let g = Slotgedaechtnis(ordner: temp())
        let uhr = UUID()
        let o = Meldungsoptionen(text: "Kaffee", weg: .text, grossbuchstaben: true)
        XCTAssertTrue(g.merken(o, icon: nil, iconKante: 8, fuer: uhr, platz: 2))

        let stand = try XCTUnwrap(g.gemerkt(fuer: uhr, platz: 2))
        XCTAssertEqual(stand.weg, "text")
        XCTAssertEqual(stand.optionen?.weg, .text)
        XCTAssertEqual(stand.optionen?.grossbuchstaben, true)
    }

    /// Der Schluessel der Oberflaeche ist der, den auch der Kurzbefehl liest.
    func testDieAblageKenntDenSchluesselDesSchalters() throws {
        let d = try XCTUnwrap(UserDefaults(suiteName: "schrift-der-uhr-\(UUID().uuidString)"))
        XCTAssertEqual(Meldungsoptionen.ausAblage(d).weg, .pixel)
        d.set(SendeWeg.text.rawValue, forKey: "senden.weg")
        XCTAssertEqual(Meldungsoptionen.ausAblage(d).weg, .text)
    }
}
