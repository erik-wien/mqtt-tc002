import Foundation
import XCTest
@testable import TC002Core

final class SicherungszipTests: XCTestCase {
    func testCRC32Pruefwerte() {
        XCTAssertEqual(Sicherungszip.crc32(Data()), 0)
        XCTAssertEqual(Sicherungszip.crc32(Data("123456789".utf8)), 0xCBF4_3926)
        XCTAssertEqual(Sicherungszip.crc32(Data("The quick brown fox jumps over the lazy dog".utf8)), 0x414F_A339)
    }

    func testHinUndZurueckBehaeltReihenfolgeUndBytes() throws {
        let e = [
            Sicherungszip.manifest(erstellt: Date(timeIntervalSince1970: 0)),
            .init(pfad: "ICONS/ä.gif", daten: Data([0, 1, 2, 255])),
            .init(pfad: "apploop.json", daten: Data()),
        ]
        let gelesen = try Sicherungszip.lesen(Sicherungszip.schreiben(e))
        XCTAssertEqual(gelesen, e)
        XCTAssertEqual(gelesen.first?.pfad, "manifest.json")
        XCTAssertEqual(try Sicherungszip.pruefen(gelesen), "1970-01-01T00:00:00.000Z")
    }

    func testFremdgeschriebenesZipMitVerzeichniseintrag() throws {
        let ordner = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: ordner.appendingPathComponent("d"), withIntermediateDirectories: true)
        try Data("hallo".utf8).write(to: ordner.appendingPathComponent("d/a.txt"))
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.currentDirectoryURL = ordner
        p.arguments = ["-0", "-r", "-X", "-q", "o.zip", "d"]
        try p.run()
        p.waitUntilExit()
        let e = try Sicherungszip.lesen(Data(contentsOf: ordner.appendingPathComponent("o.zip")))
        XCTAssertEqual(e, [.init(pfad: "d/a.txt", daten: Data("hallo".utf8))])
    }

    func testFremdesZipUndKaputtesWerdenAbgewiesen() throws {
        let ohne = [Sicherungszip.Eintrag(pfad: "a.txt", daten: Data("x".utf8))]
        XCTAssertThrowsError(try Sicherungszip.pruefen(ohne)) { XCTAssertEqual($0 as? Sicherungszip.Fehler, .keineSicherung) }
        let fremd = Sicherungszip.Eintrag(pfad: "manifest.json", daten: Data(#"{"app":"x","backupFormat":1}"#.utf8))
        XCTAssertThrowsError(try Sicherungszip.pruefen([fremd])) { XCTAssertEqual($0 as? Sicherungszip.Fehler, .fremdeSicherung) }
        let neu = Sicherungszip.Eintrag(pfad: "manifest.json", daten: Data(#"{"app":"awtrix-ng","backupFormat":2}"#.utf8))
        XCTAssertThrowsError(try Sicherungszip.pruefen([neu])) { XCTAssertEqual($0 as? Sicherungszip.Fehler, .fassungUnbekannt(2)) }
        let spaet = [ohne[0], Sicherungszip.manifest(erstellt: Date())]
        XCTAssertThrowsError(try Sicherungszip.pruefen(spaet))
        XCTAssertThrowsError(try Sicherungszip.lesen(Data("kein zip".utf8)))
        var zip = Sicherungszip.schreiben(ohne)
        zip[zip.startIndex + 30 + 5] ^= 0xFF
        XCTAssertThrowsError(try Sicherungszip.lesen(zip)) { XCTAssertEqual($0 as? Sicherungszip.Fehler, .pruefsummeFalsch("a.txt")) }
    }
}
