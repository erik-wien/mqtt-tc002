import XCTest
@testable import TC002Core

final class FavoritenTests: XCTestCase {
    private func fav(_ titel: String) -> Favorit {
        Favorit(titel: titel, auftrag: Sendeauftrag(optionen: Meldungsoptionen(text: titel)))
    }

    func testTitelWirdGetrimmt() {
        XCTAssertEqual(Favoriten.gueltigerTitel("  Telco  "), "Telco")
        XCTAssertNil(Favoriten.gueltigerTitel("   "))
    }

    func testAnfuegenAmEnde() {
        let a = fav("A"), b = fav("B")
        XCTAssertEqual(Favoriten.anfuegen(b, an: [a]).map(\.titel), ["A", "B"])
    }

    func testDuplikatDirektHinterOriginal() {
        let a = fav("A"), b = fav("B"), c = fav("C")
        var kopie = b
        kopie = Favorit(titel: Favoriten.kopietitel(b.titel), auftrag: b.auftrag)
        let neu = Favoriten.einfuegen(kopie, hinter: b.id, in: [a, b, c])
        XCTAssertEqual(neu.map(\.titel), ["A", "B", Favoriten.kopietitel("B"), "C"])
        XCTAssertNotEqual(kopie.id, b.id)
    }

    func testEinfuegenHinterUnbekannterIDAmEnde() {
        let a = fav("A"), x = fav("X")
        XCTAssertEqual(Favoriten.einfuegen(x, hinter: UUID(), in: [a]).map(\.titel), ["A", "X"])
    }

    func testErsetzenBehaeltStelle() {
        let a = fav("A"), b = fav("B"), c = fav("C")
        var b2 = b
        b2.titel = "B2"
        XCTAssertEqual(Favoriten.ersetzen(b2, in: [a, b, c]).map(\.titel), ["A", "B2", "C"])
    }

    func testUmbenennen() {
        let a = fav("A"), b = fav("B")
        XCTAssertEqual(Favoriten.umbenennen(b.id, zu: "Neu", in: [a, b]).map(\.titel), ["A", "Neu"])
    }

    func testEntfernen() {
        let a = fav("A"), b = fav("B")
        XCTAssertEqual(Favoriten.entfernen(a.id, aus: [a, b]).map(\.titel), ["B"])
    }

    private func tempOrdner() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    func testAblageRundreise() {
        let ordner = tempOrdner()
        defer { try? FileManager.default.removeItem(at: ordner) }
        let liste = [fav("A"), fav("B")]
        XCTAssertTrue(Favoritenablage(ordner: ordner).sichern(liste))
        XCTAssertEqual(Favoritenablage(ordner: ordner).alle(), liste)
    }

    func testAblageOhneDateiLeer() {
        let ordner = tempOrdner()
        defer { try? FileManager.default.removeItem(at: ordner) }
        XCTAssertEqual(Favoritenablage(ordner: ordner).alle(), [])
    }

    func testAblageMitKaputterDateiLeer() throws {
        let ordner = tempOrdner()
        defer { try? FileManager.default.removeItem(at: ordner) }
        let ablage = Favoritenablage(ordner: ordner)
        try Data("{kaputt".utf8).write(to: ordner.appendingPathComponent("Favoriten.json"))
        XCTAssertEqual(ablage.alle(), [])
    }
}
