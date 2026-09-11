import XCTest
@testable import TC002Core

final class SchluesselbundTests: XCTestCase {
    private let konto = "test-\(UUID().uuidString)"

    override func tearDown() { Schluesselbund.loeschen(konto) }

    func testSchreibenLesenLoeschen() {
        XCTAssertNil(Schluesselbund.lesen(konto))
        Schluesselbund.setzen("geheim", fuer: konto)
        XCTAssertEqual(Schluesselbund.lesen(konto), "geheim")
        Schluesselbund.setzen("neu", fuer: konto)
        XCTAssertEqual(Schluesselbund.lesen(konto), "neu", "Überschreiben muss gehen")
        Schluesselbund.loeschen(konto)
        XCTAssertNil(Schluesselbund.lesen(konto))
    }
}
