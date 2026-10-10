import XCTest
import Observation
import TC002Core
@testable import TC002Modell

/// `uhrAnsehen` wird vom Blaetterer aus dem Layout gerufen; dieselbe Uhr noch
/// einmal anzusehen darf nichts melden und nichts schreiben.
@MainActor
final class UhrAnsehenTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "zielIDs"]
    private var sicherung: [String: Any?] = [:]

    private struct LeererSchluesselbund: Schluesselbundzugriff {
        func lesen(_ konto: String) -> String? { nil }
        func setzen(_ wert: String, fuer konto: String) -> Bool { true }
        func vorhanden(_ konto: String) -> Bool { false }
    }

    override func setUp() {
        super.setUp()
        sicherung = Dictionary(uniqueKeysWithValues: schluessel.map { ($0, d.object(forKey: $0)) })
    }

    override func tearDown() {
        for s in schluessel {
            if let w = sicherung[s] ?? nil { d.set(w, forKey: s) } else { d.removeObject(forKey: s) }
        }
        super.tearDown()
    }

    private func zustand() throws -> AppZustand {
        let uhren = (0..<3).map { Uhr(name: "Uhr \($0)", host: "uhr\($0).invalid") }
        d.set(try JSONEncoder().encode(uhren), forKey: "uhren")
        d.set(uhren[1].id.uuidString, forKey: "aktiveID")
        d.removeObject(forKey: "zielIDs")
        return AppZustand(schluesselbund: LeererSchluesselbund(), wolkeGewaehlt: false)
    }

    func testDieselbeUhrAnsehenMeldetNichts() throws {
        let z = try zustand()
        var gemeldet = false
        withObservationTracking { _ = z.aktiveID } onChange: { gemeldet = true }
        z.uhrAnsehen(try XCTUnwrap(z.aktiveID))
        XCTAssertFalse(gemeldet)
    }

    func testAndereUhrAnsehenMeldetUndMerkt() throws {
        let z = try zustand()
        var gemeldet = false
        withObservationTracking { _ = z.aktiveID } onChange: { gemeldet = true }
        let andere = try XCTUnwrap(z.uhren.first { $0.id != z.aktiveID }).id
        z.uhrAnsehen(andere)
        XCTAssertTrue(gemeldet)
        XCTAssertEqual(d.string(forKey: "aktiveID"), andere.uuidString)
    }
}
