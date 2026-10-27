import XCTest
@testable import TC002Ansichten

/// Die Breite der Seitenleiste, je Plattform eine.
///
/// 170 Punkte brechen am iPad zu „Einstel-lungen" um, 190 zu
/// „Einstellun-gen" (gemessen am 14.09.2026): iPadOS legt um eine
/// Seitenleistenzeile mehr herum, als sich aus den sichtbaren Teilen
/// zusammenzählen lässt.
///
/// Diese Tests prüfen beide Plattformen, gleich auf welcher sie laufen.
/// Eine Zahl, die nur unter `#if os(macOS)` geprüft wird, ist für die
/// iPad-Fassung ungeprüft.
final class SeitenleisteTests: XCTestCase {

    func testDerLaengsteEintragPasstAmMacInEineZeile() {
        XCTAssertLessThanOrEqual(
            Seitenleiste.zeilenverbrauchMac + Seitenleiste.laengsterEintragMac,
            Seitenleiste.breiteMac, "„Einstellungen“ bricht am Mac um")
    }

    func testDerLaengsteEintragPasstAmIPadInEineZeile() {
        XCTAssertLessThanOrEqual(
            Seitenleiste.zeilenverbrauchTouch + Seitenleiste.laengsterEintragTouch,
            Seitenleiste.breiteTouch, "„Einstellungen“ bricht am iPad um")
    }

    /// Und eine Stufe groessere Systemschrift bringt sie nicht sofort wieder
    /// zum Umbrechen.
    func testEineSchriftstufeGroesserPasstAuchNoch() {
        XCTAssertLessThanOrEqual(
            Seitenleiste.zeilenverbrauchMac + Seitenleiste.laengsterEintragMac
                + Seitenleiste.schriftstufeMac,
            Seitenleiste.breiteMac, "am Mac bricht es bei der nächsten Textgröße um")
        XCTAssertLessThanOrEqual(
            Seitenleiste.zeilenverbrauchTouch + Seitenleiste.laengsterEintragTouch
                + Seitenleiste.schriftstufeTouch,
            Seitenleiste.breiteTouch, "am iPad bricht es bei der nächsten Textgröße um")
    }

    /// Ohne diese Zusicherung koennte jemand den Verbrauch kleinrechnen und
    /// die Tests oben gruen bekommen, ohne dass die Leiste breiter wuerde —
    /// die 190 haben am iPad nachweislich nicht gereicht.
    func testDieAlteBreiteWaereAmIPadZuSchmalGewesen() {
        XCTAssertGreaterThan(
            Seitenleiste.zeilenverbrauchTouch + Seitenleiste.laengsterEintragTouch, 190,
            "dann hätte es bei 190 gar nicht umgebrochen — die Messung stimmt nicht")
    }

    /// Und die Fensterforderung am Mac muss die dortige Leiste tragen:
    /// Seitenleiste plus die gemessenen 600 Punkte Detailspalte plus
    /// Inspektor. Die iPad-Breite gehoert hier nicht hinein — auf dem iPad
    /// gibt es kein Fenster zu ziehen.
    func testDieMacFensterbreiteTraegtDieMacLeiste() {
        XCTAssertGreaterThanOrEqual(1140, Seitenleiste.breiteMac + 600 + 340,
                                    "das Fenster schneidet am Mac wieder eine der beiden Leisten an")
    }

    /// Dass `breite` auf dieser Plattform die richtige der beiden Zahlen
    /// nimmt — sonst waere die Fallunterscheidung eine Zierde.
    func testDieGeltendeBreiteIstDieDerPlattform() {
        #if os(macOS)
        XCTAssertEqual(Seitenleiste.breite, Seitenleiste.breiteMac)
        #else
        XCTAssertEqual(Seitenleiste.breite, Seitenleiste.breiteTouch)
        #endif
    }

    func testBereichsreihenfolgeBleibt() {
        XCTAssertEqual(SchreibtischView.Bereich.oben, [.senden, .editor, .klaenge, .uhr])
    }

    func testStandzeichenJeStand() {
        XCTAssertNil(Favoritenzeile.standzeichen(nil))
        XCTAssertEqual(Favoritenzeile.standzeichen(.laeuft), .fortschritt)
        XCTAssertEqual(Favoritenzeile.standzeichen(.ganz), .haken)
        XCTAssertEqual(Favoritenzeile.standzeichen(.teilweise), .warnung)
    }

    func testEingabestandUebernimmtFavoritenstand() {
        let a = UUID(), b = UUID()
        typealias Z = Favoritenzeile
        XCTAssertFalse(Z.eingabestand(laeuft: false, ausgang: .offen, favoritenstaende: [:]).laeuft)
        XCTAssertTrue(Z.eingabestand(laeuft: false, ausgang: .offen, favoritenstaende: [a: .laeuft]).laeuft)
        XCTAssertEqual(Z.eingabestand(laeuft: false, ausgang: .offen, favoritenstaende: [a: .ganz]).ausgang, .ganz)
        XCTAssertEqual(Z.eingabestand(laeuft: false, ausgang: .offen, favoritenstaende: [a: .ganz, b: .teilweise]).ausgang, .teilweise)
        // Der eigene Ausgang hat Vorrang.
        XCTAssertEqual(Z.eingabestand(laeuft: false, ausgang: .teilweise, favoritenstaende: [a: .ganz]).ausgang, .teilweise)
        XCTAssertTrue(Z.eingabestand(laeuft: true, ausgang: .offen, favoritenstaende: [:]).laeuft)
    }
}
