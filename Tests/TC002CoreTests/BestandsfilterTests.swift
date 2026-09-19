import XCTest
@testable import TC002Core

/// Der Filter über alle drei Größen. Er beantwortet dieselben drei Fragen wie
/// `Iconfilter`, nur über `Editoreintrag` — und genau daran hängt, dass ein
/// Blatt, das 8 × 8, 16 × 16 und 52 × 16 zugleich zeigt, sie auch zugleich
/// einschränken kann.
final class BestandsfilterTests: XCTestCase {
    private func eintrag(_ groesse: Leinwandgroesse, _ name: String,
                         nummer: String? = nil) -> Editoreintrag {
        Editoreintrag(groesse: groesse, name: name, nummer: nummer,
                      datei: URL(fileURLWithPath: "/tmp/\(groesse.rawValue)-\(name).gif"))
    }

    private var bestand: [Editoreintrag] {
        [eintrag(.icon8, "Herz", nummer: "2981"),
         eintrag(.icon16, "Laterne"),
         eintrag(.anzeige, "Sonnenuntergang", nummer: "77")]
    }

    func testOhneEinschraenkungBleibtAllesStehen() {
        let filter = Bestandsfilter()
        XCTAssertFalse(filter.schraenktEin)
        XCTAssertEqual(bestand.gefiltert(filter, bewegt: { _ in false }).count, 3)
    }

    func testDieGroesseWaehltEineDerDreiGruppen() {
        for groesse in Leinwandgroesse.allCases {
            let uebrig = bestand.gefiltert(Bestandsfilter(groesse: groesse), bewegt: { _ in false })
            XCTAssertEqual(uebrig.map(\.groesse), [groesse],
                           "Der Filter auf \(groesse.beschriftung) lässt etwas anderes stehen.")
        }
    }

    /// Die Suche greift auf Name und Nummer — auch auf die Werknummer einer
    /// 52 × 16, nicht nur auf die LaMetric-Nummer eines 8 × 8.
    func testDieSucheFindetNameUndNummer() {
        XCTAssertEqual(bestand.gefiltert(Bestandsfilter(suche: "lat"), bewegt: { _ in false })
                        .map(\.name), ["Laterne"])
        XCTAssertEqual(bestand.gefiltert(Bestandsfilter(suche: "77"), bewegt: { _ in false })
                        .map(\.name), ["Sonnenuntergang"])
    }

    func testNurBewegteFragtDieGereichteFunktion() {
        let uebrig = bestand.gefiltert(Bestandsfilter(nurBewegte: true),
                                       bewegt: { $0.groesse == .anzeige })
        XCTAssertEqual(uebrig.map(\.name), ["Sonnenuntergang"])
    }

    /// Alle drei Fragen zusammen, und in dieser Reihenfolge — sonst zeigte
    /// „nur bewegte“ in einer Größengruppe etwas aus einer anderen.
    func testDieDreiFragenWirkenZusammen() {
        let filter = Bestandsfilter(suche: "e", groesse: .icon8, nurBewegte: true)
        XCTAssertTrue(filter.schraenktEin)
        XCTAssertEqual(bestand.gefiltert(filter, bewegt: { _ in true }).map(\.name), ["Herz"])
        XCTAssertTrue(bestand.gefiltert(filter, bewegt: { _ in false }).isEmpty)
    }

    /// Jede der drei Fragen allein macht das Zurücksetzen fällig, und es räumt
    /// alle drei ab.
    func testZuruecksetzenRaeumtAlleDreiFragen() {
        for var filter in [Bestandsfilter(suche: "x"), Bestandsfilter(groesse: .anzeige),
                           Bestandsfilter(nurBewegte: true)] {
            XCTAssertTrue(filter.schraenktEin)
            filter.zuruecksetzen()
            XCTAssertFalse(filter.schraenktEin)
            XCTAssertEqual(filter, Bestandsfilter())
        }
    }

    /// Leerzeichen sind keine Einschränkung — sonst stünde das Zurücksetzen
    /// da, nachdem jemand das Suchfeld geleert hat.
    func testLeerzeichenAlleinSchraenktNichtEin() {
        XCTAssertFalse(Bestandsfilter(suche: "   ").schraenktEin)
    }
}
