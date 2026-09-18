import XCTest

/// **Die App hat behauptet, was das Gerät nicht tut.**
///
/// Bis zum 18.09.2026 stand in Hilfe und Vorschau, beim Weg „als Text" lasse
/// die Uhr zu langen Text von selbst durchlaufen, und „Scrolltempo" unter
/// „Einstellungen" bestimme dabei das Tempo. Gemessen wurde am 11.09.2026 das
/// Gegenteil: Selbst geschickter Text läuft auf der Werksfirmware **nicht**,
/// er wird abgeschnitten — auch bei `scrollSpeed` über null, geprüft mit drei
/// Fassungen (`docs/firmware-beobachtungen.md` Nr. 1, Gerätereferenz §4.3).
///
/// Eine falsche Zusage ist schlimmer als eine fehlende: Sie führt dazu, dass
/// man für langen Text den Weg wählt, auf dem er verschwindet.
///
/// Geprüft wird am Wortlaut, weil genau der das Versprechen war.
final class LaufbehauptungTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func swiftDateien(unter ordner: String) -> [String] {
        let basis = Self.wurzel.appendingPathComponent(ordner)
        let inhalt = (try? FileManager.default.contentsOfDirectory(atPath: basis.path)) ?? []
        return inhalt.filter { $0.hasSuffix(".swift") }.sorted().map { "\(ordner)/\($0)" }
    }

    private func quelle(_ pfad: String) throws -> String {
        try String(contentsOf: Self.wurzel.appendingPathComponent(pfad), encoding: .utf8)
    }

    /// Kein sichtbarer Text der App sagt mehr, „Scrolltempo" bestimme das
    /// Tempo einer gesendeten Meldung. Auf der Werksfirmware läuft sie nicht,
    /// und auf AWTRIX NG kommt das Tempo aus der Meldung selbst
    /// (`NGNutzlast.tempo`), nicht aus einer Geräteeinstellung.
    func testKeineAnsichtVersprichtScrolltempoFuerGesendetes() throws {
        for pfad in swiftDateien(unter: "Sources/TC002Ansichten")
            + swiftDateien(unter: "Sources/TC002iOS") {
            let text = try quelle(pfad)
            XCTAssertFalse(text.contains("bestimmt „Scrolltempo“"),
                           "\(pfad) verspricht wieder, „Scrolltempo“ bestimme das Tempo einer Meldung.")
        }
    }

    /// Und die gemeinsame Wegeregel sagt nicht mehr, „als Text" laufe von
    /// selbst durch.
    func testDieWegeregelVersprichtKeinenLauf() throws {
        let text = try quelle("Sources/TC002Ansichten/HilfeInhalt.swift")
        XCTAssertFalse(text.contains("läuft von selbst durch, wenn nötig"),
                       "Die Wegeregel verspricht wieder einen Lauf, den die Werksfirmware nicht leistet.")
        XCTAssertTrue(text.contains("abgeschnitten"),
                      "Die Wegeregel sagt nicht mehr, was wirklich passiert.")
    }

    /// Dafür warnt die Sendeansicht jetzt, wenn der Text auf diesem Weg
    /// voraussichtlich nicht mehr passt — die Warnung, die es dort
    /// ausdrücklich **nicht** gab, weil Laufen als Normalfall galt.
    func testDerTextwegWarntVorDerBreite() throws {
        let text = try quelle("Sources/TC002Ansichten/SendenView.swift")
        XCTAssertTrue(text.contains("Voraussichtlich zu lang"),
                      "Auf dem Weg „als Text“ fehlt die Breitenwarnung.")
    }
}
