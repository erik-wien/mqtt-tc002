import XCTest
@testable import TC002Core

final class RueckruffachTests: XCTestCase {
    func testErgebnisInnerhalbDerFristKommtAn() {
        let fach = Rueckruffach<Int>()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { fach.abgeben(7) }
        XCTAssertEqual(fach.abwarten(frist: 5), 7)
    }

    /// Ein Rückruf nach der Frist schreibt nichts mehr; der Aufrufer hat
    /// `nil` bekommen und bleibt dabei.
    func testSpaeterRueckrufWirdVerworfen() {
        let fach = Rueckruffach<Int>()
        XCTAssertNil(fach.abwarten(frist: 0.05))
        XCTAssertFalse(fach.abgeben(1))
        XCTAssertNil(fach.abwarten(frist: 0.01))
    }

    func testErsterWertZaehlt() {
        let fach = Rueckruffach<Int>()
        XCTAssertTrue(fach.abgeben(1))
        XCTAssertFalse(fach.abgeben(2))
        XCTAssertEqual(fach.abwarten(frist: 1), 1)
    }
}
