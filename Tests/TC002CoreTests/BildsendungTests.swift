import XCTest
@testable import TC002Core

/// Der Weg von einer Datei des Bilderbestands zu dem, was hinausgeht.
final class BildsendungTests: XCTestCase {
    private func temp() -> URL {
        let ordner = FileManager.default.temporaryDirectory
            .appendingPathComponent("bildsendung-" + UUID().uuidString)
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        return ordner
    }

    private func feld(punkt: (x: Int, y: Int), farbe: String) -> Pixelfeld {
        var f = Pixelfeld()
        f.setzen(x: punkt.x, y: punkt.y, farbe: farbe)
        return f
    }

    /// **Ein Einzelbild geht als `draw`** — Rechtecke, klein und exakt.
    func testEinStehendesBildGehtAlsRechtecke() throws {
        let sammlung = Bildersammlung(ordner: temp())
        let gemaltes = try sammlung.sichern(name: "Einer", feld: feld(punkt: (3, 2), farbe: "#FF8800"))

        let rahmen = try Bildsendung.rahmen(aus: gemaltes.datei)
        XCTAssertEqual(rahmen.draw.count, 1)
        XCTAssertTrue(rahmen.bilder.isEmpty, "ein stehendes Bild braucht kein GIF")
        XCTAssertNil(rahmen.dauer)
    }

    /// **Mehrere gehen als GIF** — Rechtecke kennen keine Zeit.
    func testMehrereEinzelbilderGehenAlsGif() throws {
        let sammlung = Bildersammlung(ordner: temp())
        var eins = [String?](repeating: nil, count: 52 * 16); eins[0] = "#FF0000"
        var zwei = [String?](repeating: nil, count: 52 * 16); zwei[51] = "#00FF66"
        let gemaltes = try sammlung.sichern(name: "Laeufer", bilder: [eins, zwei], verzoegerung: 0.2)

        let rahmen = try Bildsendung.rahmen(aus: gemaltes.datei, dauer: 7)
        XCTAssertTrue(rahmen.draw.isEmpty)
        XCTAssertEqual(rahmen.bilder.count, 1)
        XCTAssertTrue(rahmen.bilder[0].datenURI.hasPrefix("data:image/gif;base64,"))
        XCTAssertEqual(rahmen.dauer, 7)
    }

    /// Eine Datei, die kein Bild ist, wird nicht zu einem leeren Rahmen — sie
    /// wirft. Ein leerer Rahmen loeschte beim Senden die Anzeige.
    func testEineUnlesbareDateiWirft() throws {
        let ordner = temp()
        let datei = ordner.appendingPathComponent("kaputt.gif")
        try Data("kein Bild".utf8).write(to: datei)
        XCTAssertThrowsError(try Bildsendung.rahmen(aus: datei))
    }
}
