import XCTest
@testable import TC002Core

/// Die Hilfen der Oberfläche für die Zusatzicons: Ablage als Text, Wahl eines
/// Icons, Höchstzahl.
final class ZusatziconslisteTests: XCTestCase {
    func testTextFormRundetUndKenntKeineUeberlaenge() {
        let l = [Zusatzicon(nummer: "a", x: 1, y: 2), Zusatzicon(nummer: "", x: 3, y: 4)]
        XCTAssertEqual(Zusatzicons.aus(json: Zusatzicons.json(l)), l)
        XCTAssertEqual(Zusatzicons.json([]), "")
        XCTAssertEqual(Zusatzicons.aus(json: ""), [])
        XCTAssertEqual(Zusatzicons.aus(json: "kaputt"), [])
        let sechs = (0..<6).map { Zusatzicon(nummer: "n\($0)") }
        XCTAssertEqual(Zusatzicons.aus(json: Zusatzicons.json(sechs)).count, 4)
    }

    func testHoechstzahl() {
        XCTAssertTrue(Zusatzicons.kannHinzufuegen((0..<3).map { Zusatzicon(nummer: "\($0)") }))
        XCTAssertFalse(Zusatzicons.kannHinzufuegen((0..<4).map { Zusatzicon(nummer: "\($0)") }))
    }

    func testWahlBehaeltDieStelle() throws {
        let icon = try Testicon.anlegen(nummer: "wahl")
        let sammlung = Iconsammlung(schreibordner: icon.datei.deletingLastPathComponent())
        var z = Zusatzicon(nummer: "", x: 9, y: 5)
        XCTAssertNil(Zusatzicons.icon(zu: z, in: [sammlung]))
        Zusatzicons.setzen(icon, in: &z)
        XCTAssertEqual(Zusatzicons.icon(zu: z, in: [sammlung])?.nummer, "wahl")
        XCTAssertEqual([z.x, z.y], [9, 5])
        Zusatzicons.setzen(nil, in: &z)
        XCTAssertNil(Zusatzicons.icon(zu: z, in: [sammlung]))
        XCTAssertEqual([z.x, z.y], [9, 5])
    }

    // MARK: Überlauf

    func testExtremeKoordinatenTrappenNirgends() throws {
        for wert in [Int.max, Int.min, Int.max - 1, Int.min + 1, 0, -1] {
            _ = Zusatzicons.seitenwert(wert, faktor: 2)
            _ = Zusatzicons.seitenwert(wert, faktor: Int.max)
            _ = Zusatzicons.gezeichnet(wert, faktor: 2)
            _ = Zusatzicons.gezeichnet(wert, faktor: Int.max)
            let z = Zusatzicon(nummer: "a", kante: wert, x: wert, y: wert)
            XCTAssertTrue(Zusatzicons.firmwareBereich.contains(z.x))
            XCTAssertTrue(Zusatzicons.firmwareBereich.contains(z.y))
        }
        XCTAssertEqual(Zusatzicons.seitenwert(Int.min, faktor: 2), -32768)
    }

    func testBeschaedigteDateiWirdBeimLesenGeklemmt() throws {
        let json = Data("""
        [{"nummer":"a","x":9223372036854775807,"y":-9223372036854775808,"kante":9223372036854775807}]
        """.utf8)
        let l = try JSONDecoder().decode([Zusatzicon].self, from: json)
        XCTAssertEqual(l[0].x, 65535)
        XCTAssertEqual(l[0].y, -65535)
        XCTAssertEqual(l[0].kanteOderAcht, 64)
        // Auch als Teil eines Slotstands.
        let stand = Data("""
        {"platz":1,"text":"x","weg":"pixel","schrift":"Silkscreen","groesse":8,"fett":false,"grossbuchstaben":false,"rand":1,"abstand":1,"waagrecht":"links","senkrecht":"mittig","farbe":"#00FF66","tempo":"mittel","iconLaeuftMit":false,"pruefsumme":"abc","zusatzicons":[{"nummer":"a","x":9223372036854775807,"y":-9223372036854775808}]}
        """.utf8)
        let s = try JSONDecoder().decode(Slotstand.self, from: stand)
        XCTAssertEqual(s.zusatzicons?.first?.x, 65535)
    }

    func testEinbackenMitExtremenWertenTrapptNicht() throws {
        let icon = try Testicon.anlegen(nummer: "ex")
        let bilder = [Bildraster.Einzelbild(pixel: try Bildraster.lesen(icon.datei, breite: 8, hoehe: 8)[0], dauer: 0.1)]
        for wert in [Int.max, Int.min, 65535, -65535] {
            let p = Zusatzplatz(icon: icon, x: wert, y: wert, bilder: bilder)
            var pixel = [String?](repeating: nil, count: 52 * 16)
            Zusatzicons.aufbringen([p], bildnummern: [Int.max, Int.min], faktor: Int.max, auf: &pixel, breite: 52, hoehe: 16)
            Zusatzicons.aufbringen([p], bildnummern: [Int.min], faktor: 2, auf: &pixel, breite: 52, hoehe: 16)
        }
        var leer: [String?] = []
        Zusatzicons.aufbringen([], bildnummern: [], faktor: 1, auf: &leer, breite: Int.max, hoehe: Int.max)
    }
}
