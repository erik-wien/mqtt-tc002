import XCTest

/// Kein sichtbarer Text der App darf zusagen, ein Geräte-„Scrolltempo“ bestimme
/// das Tempo einer gesendeten Meldung: Es kommt aus der Meldung selbst
/// (`NGNutzlast.tempo`).
///
/// Geprüft wird am Wortlaut, weil genau der die Zusage war.
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

    /// Ein Segmentschalter „als Pixel / als Text" in einer Sendeansicht wäre
    /// die Frage, die niemand beantworten kann, ohne das Gerät zu kennen;
    /// auf einer AWTRIX NG hatte sie obendrein gar keine Wirkung.
    func testKeineSendeansichtBietetDenWegAn() throws {
        for pfad in ["Sources/TC002Ansichten/SendenView.swift",
                     "Sources/TC002iOS/SendeniOS.swift",
                     "Sources/TC002iOS/FormatblattiOS.swift"] {
            let text = try quelle(pfad)
            XCTAssertFalse(text.contains("Picker(\"Weg\""),
                           "\(pfad) bietet den Weg wieder zur Wahl an.")
            XCTAssertFalse(text.contains("selection: $weg"),
                           "\(pfad) bietet den Weg wieder zur Wahl an.")
        }
    }
}
