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
}
