import XCTest
@testable import TC002Core

final class KlangbelegungTests: XCTestCase {
    private let melodien = Tonablage(namen: ["a", "b"], belegteBytes: 118_000, gesamteBytes: 512_000)
    private let mp3 = Tonablage(namen: ["x"], belegteBytes: 1000, gesamteBytes: 2000)

    private func ziel(mp3 spielt: Bool?) -> Klangziel {
        let f = spielt.map { Geraetefaehigkeiten(ton: Tonfaehigkeiten(mp3: $0, rtttl: true)) }
        return Klangziel(id: UUID(), name: "Z", faehigkeiten: f)
    }

    func testBeideArtenZaehlen() {
        let t = Klangbelegung.zusammenfassung(melodien: melodien, mp3: mp3, mp3Spielbar: true)
        XCTAssertTrue(t.hasPrefix("2 Melodien · 1 MP3 · "), t)
        XCTAssertTrue(t.contains(" von "), t)
    }

    func testOhneMP3KeineMP3ImSatz() {
        let t = Klangbelegung.zusammenfassung(melodien: melodien, mp3: Tonablage(namen: []), mp3Spielbar: false)
        XCTAssertFalse(t.contains("MP3"), t)
        XCTAssertTrue(t.hasPrefix("2 Melodien · "), t)
        let mitDatei = Klangbelegung.zusammenfassung(melodien: Tonablage(namen: ["a"]), mp3: mp3, mp3Spielbar: false)
        XCTAssertEqual(mitDatei, "1 Melodien")
    }

    func testNochNichtGelesen() {
        XCTAssertEqual(Klangbelegung.zusammenfassung(melodien: nil, mp3: nil, mp3Spielbar: true), "—")
    }

    func testMP3ZeigenRegel() {
        XCTAssertTrue(Klangeignung.mp3Zeigen(in: []))
        XCTAssertTrue(Klangeignung.mp3Zeigen(in: [ziel(mp3: nil)]), "unbekannt: zeigen")
        XCTAssertTrue(Klangeignung.mp3Zeigen(in: [ziel(mp3: true)]))
        XCTAssertTrue(Klangeignung.mp3Zeigen(in: [ziel(mp3: true), ziel(mp3: false)]), "nur ein Teil kann: zeigen")
        XCTAssertFalse(Klangeignung.mp3Zeigen(in: [ziel(mp3: false), ziel(mp3: false)]))
    }
}
