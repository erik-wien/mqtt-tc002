import XCTest
@testable import TC002Ansichten

/// Die Breite der Seitenleiste. Auf jedem Bildschirmfoto vom iPad stand
/// „Einstel-lungen" — umgebrochen, weil 170 Punkte dort nicht reichen.
///
/// Gemessen wird der laengste Eintrag mit CoreText an der Systemschrift; diese
/// Tests halten fest, dass die Zahl in `Seitenleiste` zu dieser Messung passt
/// und nicht wieder unter sie faellt.
final class SeitenleisteTests: XCTestCase {

    /// Symbolspalte, Abstand, Text und beide Zeilenraender muessen hineinpassen —
    /// sonst bricht der Eintrag um.
    func testDerLaengsteEintragPasstInEineZeile() {
        let gebraucht = Seitenleiste.zeilenrand + Seitenleiste.symbolspalte
            + Seitenleiste.symbolAbstand + Seitenleiste.laengsterEintrag
            + Seitenleiste.zeilenrand
        XCTAssertLessThanOrEqual(gebraucht, Seitenleiste.breite,
                                 "„Einstellungen“ bricht wieder um")
    }

    /// Und eine Stufe groessere Systemschrift bringt sie nicht sofort wieder
    /// zum Umbrechen — das war der Grund, ueber die gemessenen 176 hinauszugehen.
    func testEineSchriftstufeGroesserPasstAuchNoch() {
        let gebraucht = Seitenleiste.zeilenrand + Seitenleiste.symbolspalte
            + Seitenleiste.symbolAbstand
            + Seitenleiste.laengsterEintrag + Seitenleiste.eineSchriftstufe
            + Seitenleiste.zeilenrand
        XCTAssertLessThanOrEqual(gebraucht, Seitenleiste.breite,
                                 "bei der nächsten Textgröße bricht es wieder um")
    }

    /// Die Messung selbst: 170 reichten nicht, und genau das soll die Zahl
    /// festhalten. Ohne diese Zusicherung koennte jemand `laengsterEintrag`
    /// kleinrechnen und beide Tests gruen bekommen, ohne dass die Leiste
    /// breiter wuerde.
    func testDieAlteBreiteWaereZuSchmalGewesen() {
        let gebraucht = Seitenleiste.zeilenrand + Seitenleiste.symbolspalte
            + Seitenleiste.symbolAbstand + Seitenleiste.laengsterEintrag
            + Seitenleiste.zeilenrand
        XCTAssertGreaterThan(gebraucht, 170,
                             "dann hätte es bei 170 gar nicht umgebrochen — die Messung stimmt nicht")
    }

    /// Und die Fensterforderung am Mac muss mitwachsen: Seitenleiste plus die
    /// gemessenen 600 Punkte Detailspalte plus Inspektor.
    func testDieMacFensterbreiteTraegtDieBreitereLeiste() {
        XCTAssertGreaterThanOrEqual(1140, Seitenleiste.breite + 600 + 340,
                                    "das Fenster schneidet am Mac wieder eine der beiden Leisten an")
    }
}
