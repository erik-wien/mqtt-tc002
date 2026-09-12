import Foundation
import XCTest
@testable import TC002Core

/// Beweist, dass der Mitleser aus einer echten `custom`-Nutzlast dieselben
/// Pixel gewinnt, die `Meldungsbau.feld(...)` fuer dieselben Optionen liefert
/// — er sieht also dasselbe wie die Uhr, nicht bloss irgendetwas.
final class SlotbildTests: XCTestCase {

    /// Ein leerer Iconordner: die Nutzlast soll die Rechnung abbilden, nicht
    /// den Inhalt eines Icons (wie in `MeldungsbauTests`).
    private func leereSammlung() -> Iconsammlung {
        Iconsammlung(schreibordner: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString))
    }

    /// Der stehende Fall (Text passt, kein Icon): `rahmen(...)` liefert einen
    /// `draw`-Rahmen. Dessen `alsJSON()` ist genau das, was am Thema
    /// `<praefix>/custom/meldungN` ankaeme.
    func testStehenderFallLiefertDieselbenPixelWieFeld() throws {
        let o = Meldungsoptionen(text: "Hallo")
        let frame = try Meldungsbau.rahmen(o, icon: nil, sammlung: leereSammlung())
        let nutzlast = Data(frame.alsJSON().utf8)

        let pixel = Anzeigen.pixelAusCustomNutzlast(nutzlast)

        XCTAssertEqual(pixel, Meldungsbau.feld(o, mitIcon: false).punkteRoh)
    }

    /// Randfall derselben Rechnung: mittige Ausrichtung mit Rand erzeugt
    /// mehrere Rechtecke je Zeile und eine andere Farbe — beides muss ankommen.
    func testMittigMitRandUndFarbe() throws {
        var o = Meldungsoptionen(text: "Grüße")
        o.waagrecht = .mittig
        o.senkrecht = .unten
        o.rand = 2
        o.farbe = "#FF00AA"
        let frame = try Meldungsbau.rahmen(o, icon: nil, sammlung: leereSammlung())
        let nutzlast = Data(frame.alsJSON().utf8)

        let pixel = Anzeigen.pixelAusCustomNutzlast(nutzlast)

        XCTAssertEqual(pixel, Meldungsbau.feld(o, mitIcon: false).punkteRoh)
    }

    /// Eine leere Nutzlast (Loeschen eines Slots) ist nicht zerlegbar — das ist
    /// keine Bildinformation, sondern die Aufforderung, den Eintrag zu entfernen.
    func testLeereNutzlastLiefertNil() {
        XCTAssertNil(Anzeigen.pixelAusCustomNutzlast(Data()))
    }

    /// Der Laufschrift-Weg (Text passt nicht, GIF in `image`) hat keine
    /// `draw`-Rechtecke — fuer den Anfang nicht zerlegbar.
    func testLaufschriftIstNochNichtZerlegbar() throws {
        var o = Meldungsoptionen(text: "Dieser Text ist viel zu lang für zweiundfünfzig Pixel")
        o.tempo = .mittel
        let frame = try Meldungsbau.rahmen(o, icon: nil, sammlung: leereSammlung())
        let nutzlast = Data(frame.alsJSON().utf8)

        XCTAssertNil(Anzeigen.pixelAusCustomNutzlast(nutzlast))
    }

    /// Der Geraeteschrift-Weg (`text`) hat ebenfalls keine `draw`-Rechtecke —
    /// die Uhr setzt die Schrift selbst, die App kennt die Pixel nicht.
    func testGeraeteschriftWegIstNichtZerlegbar() throws {
        var o = Meldungsoptionen(text: "Hallo")
        o.weg = .text
        let frame = try Meldungsbau.rahmen(o, icon: nil, sammlung: leereSammlung())
        let nutzlast = Data(frame.alsJSON().utf8)

        XCTAssertNil(Anzeigen.pixelAusCustomNutzlast(nutzlast))
    }
}
