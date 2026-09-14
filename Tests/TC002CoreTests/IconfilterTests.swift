import XCTest
@testable import TC002Core

/// Die Filterleiste der Icon-Auswahl: Suche, Größe, Bewegung.
final class IconfilterTests: XCTestCase {
    private let datei = URL(fileURLWithPath: "/dev/null")

    private func bestand() -> [Icon] {
        [Icon(nummer: "82", name: "Stern", kategorie: "", datei: datei),
         Icon(nummer: "82", name: "Stern groß", kategorie: "", datei: datei, kante: 16),
         Icon(nummer: "12246", name: "Wolke", kategorie: "", datei: datei),
         Icon(nummer: "3579", name: "Regen", kategorie: "", datei: datei, kante: 16)]
    }

    /// Bewegt sind hier die beiden mit gerader Nummer — eine Funktion, keine
    /// Dateileserei.
    private func bewegt(_ icon: Icon) -> Bool { icon.name == "Wolke" || icon.name == "Stern groß" }

    func testOhneAngabenBleibtAllesStehen() {
        let alle = bestand().gefiltert(Iconfilter(), bewegt: bewegt)
        XCTAssertEqual(alle.count, 4)
        XCTAssertFalse(Iconfilter().schraenktEin)
    }

    func testDieGroesseTrenntDieBestaende() {
        let achter = bestand().gefiltert(Iconfilter(kante: 8), bewegt: bewegt)
        XCTAssertEqual(achter.map(\.name), ["Stern", "Wolke"])
        let sechzehner = bestand().gefiltert(Iconfilter(kante: 16), bewegt: bewegt)
        XCTAssertEqual(sechzehner.map(\.name), ["Stern groß", "Regen"])
    }

    func testNurBewegte() {
        let laufend = bestand().gefiltert(Iconfilter(nurBewegte: true), bewegt: bewegt)
        XCTAssertEqual(laufend.map(\.name), ["Stern groß", "Wolke"])
    }

    /// **Die drei wirken zusammen, nicht wahlweise.** Ein bewegtes 16×16 mit
    /// „stern" im Namen ist genau eines.
    func testAlleDreiZusammen() {
        let eng = bestand().gefiltert(Iconfilter(suche: "stern", kante: 16, nurBewegte: true),
                                      bewegt: bewegt)
        XCTAssertEqual(eng.map(\.name), ["Stern groß"])
    }

    /// Die Suche greift auf Name **und** Nummer — dieselbe Regel wie vorher,
    /// hier nur durch den Filter hindurch.
    func testDieSucheGreiftAufNameUndNummer() {
        XCTAssertEqual(bestand().gefiltert(Iconfilter(suche: "12246"), bewegt: bewegt).map(\.name),
                       ["Wolke"])
        XCTAssertEqual(bestand().gefiltert(Iconfilter(suche: "regen"), bewegt: bewegt).map(\.name),
                       ["Regen"])
    }

    /// Eine Oberflaeche, die eine leere Liste erklaeren will, muss wissen, ob
    /// ueberhaupt etwas eingeschraenkt ist.
    func testSchraenktEin() {
        XCTAssertTrue(Iconfilter(suche: "a").schraenktEin)
        XCTAssertTrue(Iconfilter(kante: 8).schraenktEin)
        XCTAssertTrue(Iconfilter(nurBewegte: true).schraenktEin)
        XCTAssertFalse(Iconfilter(suche: "   ").schraenktEin)
    }

    /// **Die Bewegung kommt aus der Datei, nicht aus der Einrichtung.**
    /// `bewegteKennungen` liest sie einmal; der Filter bekommt sie danach
    /// gereicht. Hier mit echten GIFs, damit nicht nur die Verdrahtung
    /// stimmt, sondern auch das Lesen.
    func testBewegteKennungenLiestDieDateien() throws {
        let ordner = FileManager.default.temporaryDirectory
            .appendingPathComponent("iconfilter-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: ordner) }
        let sammlung = Iconsammlung(schreibordner: ordner)

        var eins = [String?](repeating: nil, count: 64); eins[0] = "#FF0000"
        var zwei = [String?](repeating: nil, count: 64); zwei[63] = "#00FF66"
        let lauf = try sammlung.sichern(nummer: "lauf", name: "Lauf",
                                        bilder: [eins, zwei], verzoegerung: 0.2)
        let steht = try sammlung.sichern(nummer: "steht", name: "Steht", pixel: eins)

        let kennungen = [lauf, steht].bewegteKennungen()
        XCTAssertEqual(kennungen, [lauf.kennung])

        let nurLaufende = [lauf, steht].gefiltert(Iconfilter(nurBewegte: true),
                                                  bewegt: { kennungen.contains($0.kennung) })
        XCTAssertEqual(nurLaufende.map(\.name), ["Lauf"])
    }
}
