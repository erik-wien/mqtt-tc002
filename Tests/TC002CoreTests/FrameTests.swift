import XCTest
@testable import TC002Core

final class FrameTests: XCTestCase {
    /// Das Geraet erwartet df als flaches Feld [x, y, breite, hoehe, farbe].
    func testDrawBefehlWirdAlsFlachesFeldKodiert() throws {
        let frame = Frame(draw: [DrawBefehl(x: 2, y: 3, breite: 4, hoehe: 1, farbe: "#00FF66")])
        let json = try frame.alsJSON()
        XCTAssertEqual(json, ##"{"draw":[{"df":[2,3,4,1,"#00FF66"]}]}"##)
    }

    func testLeeresFrameIstLeeresObjekt() throws {
        XCTAssertEqual(try Frame().alsJSON(), "{}")
    }

    /// Anfuehrungszeichen und Rueckwaertsstrich im Text muessen maskiert werden — der
    /// eigentliche Nachweis ist, dass das geparste JSON wieder den urspruenglichen,
    /// unverfaelschten Text liefert.
    func testTextMitAnfuehrungszeichenUndRueckwaertsstrichBleibtUnverfaelscht() throws {
        let text = #"Sag "Hallo" \ Tschuess"#
        let frame = Frame(texte: [Textblock(inhalt: text)])
        let json = try frame.alsJSON()
        let data = try XCTUnwrap(json.data(using: .utf8))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let texte = try XCTUnwrap(obj?["text"] as? [[String: Any]])
        XCTAssertEqual(texte.first?["content"] as? String, text)
    }

    func testZeilenumbruchImTextBleibtParsbar() throws {
        let text = "Erste Zeile\nZweite Zeile"
        let frame = Frame(texte: [Textblock(inhalt: text)])
        let json = try frame.alsJSON()
        let data = try XCTUnwrap(json.data(using: .utf8))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let texte = try XCTUnwrap(obj?["text"] as? [[String: Any]])
        XCTAssertEqual(texte.first?["content"] as? String, text)
    }

    func testBildErzeugtPositionAlsXYFeld() throws {
        let frame = Frame(bilder: [Bild(datenURI: "data:image/png;base64,AA==", x: 3, y: 4)])
        let json = try frame.alsJSON()
        let data = try XCTUnwrap(json.data(using: .utf8))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let bilder = try XCTUnwrap(obj?["image"] as? [[String: Any]])
        XCTAssertEqual(bilder.first?["position"] as? [Int], [3, 4])
    }

    /// Wegwerf-Pruefung der Fixrunde als Dauertest: jede Kombination aus Draw-Befehlen,
    /// Bildern und Text — sowie leer — muss gueltiges JSON ergeben.
    func testAlleKombinationenErgebenGueltigesJSON() throws {
        let draw = [DrawBefehl(x: 0, y: 0, breite: 1, hoehe: 1, farbe: "#FFFFFF")]
        let bilder = [Bild(datenURI: "data:image/png;base64,AA==", x: 1, y: 1)]
        let texte = [Textblock(inhalt: "Hallo \"Welt\"")]

        let frames: [Frame] = [
            Frame(),
            Frame(draw: draw),
            Frame(bilder: bilder),
            Frame(texte: texte),
            Frame(draw: draw, bilder: bilder, texte: texte, dauer: 5),
        ]

        for frame in frames {
            let json = try frame.alsJSON()
            let data = try XCTUnwrap(json.data(using: .utf8))
            XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
        }
    }
}
