import XCTest
@testable import TC002Core

final class SteuerwerteTests: XCTestCase {
    func testHelligkeitInProzent() {
        XCTAssertEqual(Steuerwerte.helligkeitProzent(roh: 0), 0)
        XCTAssertEqual(Steuerwerte.helligkeitProzent(roh: 128), 50)
        XCTAssertEqual(Steuerwerte.helligkeitProzent(roh: 255), 100)
        XCTAssertEqual(Steuerwerte.helligkeitProzent(roh: 300), 100, "begrenzt")
        XCTAssertEqual(Steuerwerte.helligkeitProzent(roh: -4), 0)
    }

    func testJedeProzentstufeKommtAlsDieselbeStufeZurueck() {
        for p in 0...100 {
            let roh = Steuerwerte.helligkeitRoh(prozent: p)
            XCTAssertTrue((0...255).contains(roh))
            XCTAssertEqual(Steuerwerte.helligkeitProzent(roh: roh), p, "\(p) %")
        }
    }

    func testLaufzeit() {
        XCTAssertEqual(Steuerwerte.laufzeit(sekunden: 42), "42 s")
        XCTAssertEqual(Steuerwerte.laufzeit(sekunden: 300), "5 Min")
        XCTAssertEqual(Steuerwerte.laufzeit(sekunden: 4_440), "1 Std 14 Min")
        XCTAssertEqual(Steuerwerte.laufzeit(sekunden: 2 * 86_400 + 3 * 3_600 + 50), "2 Tg 3 Std")
    }

    func testZifferblaetterHabenDeutscheNamenUndUnbekanntesBleibt() {
        XCTAssertEqual(Einstellungsart.zifferblaetter.map(Steuerwerte.zifferblattName),
                       ["Blatt", "Ring", "Klappzahlen", "Monat", "Groß"])
        XCTAssertEqual(Steuerwerte.zifferblattName("neu"), "neu")
    }
}
