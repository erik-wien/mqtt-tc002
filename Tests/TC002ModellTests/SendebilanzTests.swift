import XCTest
@testable import TC002Modell

/// Eine Sendung an mehrere Uhren hat drei Ausgänge, nicht zwei.
///
/// Der Auftraggeber: *„Wenn User versucht eine 16er Grafik an eine gemischte
/// Gruppe von TC001 und TC002 zu schicken, bekommt er statt dem grünen Haken
/// einen gelben Haken plus Fehlermeldung in der Nähe, dass die Grafik nur an
/// TC002 geschickt werden konnte."* Ein `Bool` kennt diesen Fall nicht — er
/// hätte „ja“ gesagt und einen grünen Haken gezeigt.
final class SendebilanzTests: XCTestCase {
    func testAlleHabenGenommen() {
        let b = Sendebilanz(erreicht: ["ulanzi", "awtrix"], ziele: 2)
        XCTAssertTrue(b.ganz)
        XCTAssertFalse(b.teilweise)
        XCTAssertFalse(b.nichts)
    }

    /// Der Fall, für den es diesen Typ gibt: die 16 Zeilen hohe Grafik an
    /// eine gemischte Gruppe.
    func testNurMancheHabenGenommen() {
        let b = Sendebilanz(erreicht: ["ulanzi"], ziele: 2)
        XCTAssertFalse(b.ganz, "ein grüner Haken für eine halb angekommene Sendung wäre eine "
                       + "Zusage, die nicht stimmt")
        XCTAssertTrue(b.teilweise)
        XCTAssertFalse(b.nichts)
    }

    /// Kam gar nichts an, bleibt der Pfeil stehen — ein Haken wäre dort in
    /// jeder Farbe falsch, und die Fehlerleiste sagt, woran es lag.
    func testNichtsAngekommen() {
        let b = Sendebilanz(erreicht: [], ziele: 2)
        XCTAssertFalse(b.ganz)
        XCTAssertFalse(b.teilweise)
        XCTAssertTrue(b.nichts)
    }

    /// Ohne Zieluhr gibt es nichts zu melden — und vor allem keinen Haken.
    func testOhneZiele() {
        let b = Sendebilanz(erreicht: [], ziele: 0)
        XCTAssertTrue(b.nichts)
        XCTAssertFalse(b.ganz)
    }
}
