import XCTest
@testable import TC002Core

final class IconFassungTests: XCTestCase {
    private let tc002 = Anzeigemass(breite: 52, hoehe: 16)
    private let tc001 = Anzeigemass(breite: 32, hoehe: 8)

    private var wurzel: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Zwei temporaere Bestaende mit einem Paar (`haus` / `haus-16`) und einem
    /// 16×16 ohne 8×8-Gegenstueck (`labyrinth-16`).
    private func bestaende() throws -> (acht: Iconsammlung, sechzehn: Iconsammlung) {
        let fm = FileManager.default
        let basis = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let o8 = basis.appendingPathComponent("8"), o16 = basis.appendingPathComponent("16")
        try fm.createDirectory(at: o8, withIntermediateDirectories: true)
        try fm.createDirectory(at: o16, withIntermediateDirectories: true)
        try fm.copyItem(at: wurzel.appendingPathComponent("Icons/haus.png"), to: o8.appendingPathComponent("haus.png"))
        try fm.copyItem(at: wurzel.appendingPathComponent("Icons16/haus-16.png"), to: o16.appendingPathComponent("haus-16.png"))
        try fm.copyItem(at: wurzel.appendingPathComponent("Icons16/labyrinth-16.gif"),
                        to: o16.appendingPathComponent("labyrinth-16.gif"))
        return (Iconsammlung(ordner: o8), Iconsammlung(ordner: o16, kante: 16))
    }

    private func icon(_ s: Iconsammlung, _ nummer: String) throws -> Icon {
        try XCTUnwrap(s.alle().first { $0.nummer == nummer })
    }

    func testSechzehnerWirdAufAchtZeilenZumAchter() throws {
        let b = try bestaende()
        let alle = { [b.acht, b.sechzehn] }
        let sechzehn = try icon(b.sechzehn, "haus-16")
        let ersatz = Iconbestaende.passend(sechzehn, fuer: tc001, in: alle)
        XCTAssertEqual(ersatz.nummer, "haus")
        XCTAssertEqual(ersatz.kante, 8)
        XCTAssertNotNil(Iconbestaende.hinweis(gewaehlt: sechzehn, tatsaechlich: ersatz, uhr: "Flur"))
    }

    func testAufDerTC002BleibtWasGewaehltIst() throws {
        let b = try bestaende()
        let alle = { [b.acht, b.sechzehn] }
        let sechzehn = try icon(b.sechzehn, "haus-16")
        let acht = try icon(b.acht, "haus")
        XCTAssertEqual(Iconbestaende.passend(sechzehn, fuer: tc002, in: alle).nummer, "haus-16")
        // Ein 8×8 wird nie durch ein 16×16 ersetzt, auch wenn es eines gibt.
        XCTAssertEqual(Iconbestaende.passend(acht, fuer: tc002, in: alle).nummer, "haus")
        XCTAssertEqual(Iconbestaende.passend(acht, fuer: tc001, in: alle).nummer, "haus")
        XCTAssertNil(Iconbestaende.hinweis(gewaehlt: sechzehn, tatsaechlich: sechzehn, uhr: "Flur"))
    }

    func testOhneAchterFassungBleibtDasGewaehlte() throws {
        let b = try bestaende()
        let alle = { [b.acht, b.sechzehn] }
        let labyrinth = try icon(b.sechzehn, "labyrinth-16")
        XCTAssertEqual(Iconbestaende.passend(labyrinth, fuer: tc001, in: alle).nummer, "labyrinth-16")
    }

    /// Ganzer Weg bis zum Rahmen: Auf der TC001 entsteht mit dem 16×16 dasselbe
    /// Bild wie mit dem 8×8, auf der TC002 bleibt der Unterschied.
    func testRahmenJeUhr() throws {
        let b = try bestaende()
        let alle = { [b.acht, b.sechzehn] }
        let sechzehn = try icon(b.sechzehn, "haus-16")
        let acht = try icon(b.acht, "haus")
        let o = Meldungsoptionen(text: "Post")
        let klein16 = try Meldungsbau.rahmen(o, icon: sechzehn, sammlung: b.acht, mass: tc001, bestaende: alle)
        let klein8 = try Meldungsbau.rahmen(o, icon: acht, sammlung: b.acht, mass: tc001, bestaende: alle)
        XCTAssertEqual(klein16.pixel, klein8.pixel)
        let gross16 = try Meldungsbau.rahmen(o, icon: sechzehn, sammlung: b.acht, mass: tc002, bestaende: alle)
        let gross8 = try Meldungsbau.rahmen(o, icon: acht, sammlung: b.acht, mass: tc002, bestaende: alle)
        XCTAssertNotEqual(gross16.pixel, gross8.pixel)
    }
}
