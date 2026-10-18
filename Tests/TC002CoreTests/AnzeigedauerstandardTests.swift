import XCTest
@testable import TC002Core

final class AnzeigedauerstandardTests: XCTestCase {
    func testEineUhrNenntIhrenWert() {
        XCTAssertEqual(Anzeigedauerstandard.text(millisekunden: [7000]), "7 s")
    }

    func testGleicheWerteErgebenEineZahl() {
        XCTAssertEqual(Anzeigedauerstandard.text(millisekunden: [7000, 7000]), "7 s")
    }

    func testUnterschiedlicheWerteErgebenEinenBereich() {
        XCTAssertEqual(Anzeigedauerstandard.text(millisekunden: [10_000, 7000, nil]), "7–10 s")
    }

    func testUnbekanntOderNullErgibtKeineZahl() {
        XCTAssertNil(Anzeigedauerstandard.text(millisekunden: []))
        XCTAssertNil(Anzeigedauerstandard.text(millisekunden: [nil, nil]))
        XCTAssertNil(Anzeigedauerstandard.text(millisekunden: [0]))
    }

    func testEineUhrOhneWertZaehltNichtMit() {
        XCTAssertEqual(Anzeigedauerstandard.text(millisekunden: [nil, 5000]), "5 s")
    }
}
