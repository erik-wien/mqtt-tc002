import SwiftUI
import XCTest
import TC002Ansichten

/// Was der Farbwähler liefert, landet als Text im Icon, in `@AppStorage` und in
/// der Nutzlast an die Uhr. Mac und Telefon rechnen seit dem Zusammenlegen durch
/// dieselbe Zeile; die Werte hier gelten deshalb für beide.
final class FarbeTests: XCTestCase {
    /// Der Rundlauf "#RRGGBB" → `Color` → "#RRGGBB". Die Ränder gehören dazu:
    /// `#000000` und `#FFFFFF` sind die Stellen, an denen ein fehlendes Klammern
    /// zuerst auffällt.
    ///
    /// Geprüft wird mit Stufen, die das Abschneiden tragen. Dass es andere gibt,
    /// hält `testAbschneidenIstGewollt` fest — nicht jede der 256 Stufen kommt
    /// zeichengleich zurück, und das ist bekannt und gewollt.
    func testHexRundlaufBleibtZeichengleich() throws {
        for hex in ["#000000", "#FFFFFF", "#FF0000", "#00FF00", "#0000FF", "#7F7F7F", "#010203"] {
            let farbe = try XCTUnwrap(Color(hex: hex), "\(hex) muss sich lesen lassen")
            XCTAssertEqual(farbe.hexWert, hex, "Rundlauf für \(hex)")
        }
    }

    /// Die eigentliche Zusicherung hinter dem Rundlauf: abgeschnitten, nicht
    /// gerundet. Ein Anteil, der zwischen zwei Stufen liegt, muss auf die
    /// untere fallen — 17,6 ergibt 0x11, nicht 0x12.
    ///
    /// Rundet hier jemand statt abzuschneiden, weichen die Hexwerte von Mac
    /// und Telefon wieder voneinander ab.
    func testAbschneidenIstGewollt() {
        XCTAssertEqual(Color(red: 17.6 / 255, green: 0, blue: 0).hexWert, "#110000",
                       "17,6 muss auf 17 (0x11) abgeschnitten werden, nicht auf 18 (0x12) gerundet")
        XCTAssertEqual(Color(red: 0, green: 200.9 / 255, blue: 0).hexWert, "#00C800",
                       "200,9 muss auf 200 (0xC8) abgeschnitten werden, nicht auf 201 (0xC9) gerundet")
    }

    // Kein Test auf das Klammern in `stufe`: `CGColor.converted(to:)` liefert
    // bereits Anteile im Umfang, das `min`/`max` ist damit von außen nicht
    // erreichbar. Ein Test darauf war grün, ohne etwas zuzusichern — gemessen,
    // indem die Begrenzung entfernt wurde und er weiter durchlief.

    /// Ohne `#` und mit Kleinbuchstaben gelesen, mit `#` und Großbuchstaben
    /// zurück — beides bekommt der Farbwähler zu sehen.
    func testSchreibweiseWirdVereinheitlicht() throws {
        let farbe = try XCTUnwrap(Color(hex: "ff0000"))
        XCTAssertEqual(farbe.hexWert, "#FF0000")
    }

    func testUngueltigesHexErgibtNil() {
        XCTAssertNil(Color(hex: "#12345"))
        XCTAssertNil(Color(hex: "#GGGGGG"))
        XCTAssertNil(Color(hex: ""))
    }
}
