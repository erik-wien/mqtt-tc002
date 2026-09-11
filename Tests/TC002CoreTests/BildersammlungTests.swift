import XCTest
@testable import TC002Core

final class BildersammlungTests: XCTestCase {
    /// Ein frischer, noch nicht angelegter Ordnerpfad unter dem temporaeren
    /// Verzeichnis — anlegen bleibt Sache des Aufrufers bzw. von `sichern`.
    private func temp() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    func testRundlaufUeberDieSammlung() throws {
        let ordner = temp()
        let sammlung = Bildersammlung(ordner: ordner)
        var feld = Pixelfeld()
        feld.setzen(x: 0, y: 0, farbe: "#FF0000")
        feld.setzen(x: 51, y: 15, farbe: "#00FF66")

        let eintrag = try sammlung.sichern(name: "Testbild", feld: feld)
        XCTAssertEqual(eintrag.name, "Testbild")
        XCTAssertEqual(sammlung.alle().map(\.name), ["Testbild"])

        let zurueck = try sammlung.laden(eintrag)
        XCTAssertEqual(zurueck.farbe(x: 0, y: 0), "#FF0000", "oben links bleibt oben links")
        XCTAssertEqual(zurueck.farbe(x: 51, y: 15), "#00FF66", "unten rechts bleibt unten rechts")
        XCTAssertNil(zurueck.farbe(x: 25, y: 8))

        try sammlung.loeschen(eintrag)
        XCTAssertTrue(sammlung.alle().isEmpty)
    }

    func testGleicherNameErsetzt() throws {
        let sammlung = Bildersammlung(ordner: temp())
        var a = Pixelfeld(); a.setzen(x: 1, y: 1, farbe: "#FFFFFF")
        var b = Pixelfeld(); b.setzen(x: 2, y: 2, farbe: "#FFFFFF")
        _ = try sammlung.sichern(name: "gleich", feld: a)
        let zweit = try sammlung.sichern(name: "gleich", feld: b)
        XCTAssertEqual(sammlung.alle().count, 1, "ersetzen, nicht verdoppeln")
        XCTAssertNil(try sammlung.laden(zweit).farbe(x: 1, y: 1))
    }

    func testLeererNameWirdAbgelehnt() {
        let sammlung = Bildersammlung(ordner: temp())
        XCTAssertThrowsError(try sammlung.sichern(name: "  ", feld: Pixelfeld()))
    }
}
