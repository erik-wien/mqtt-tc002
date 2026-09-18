import XCTest

/// Kein sichtbarer Text der App darf zusagen, die Werksfirmware lasse selbst
/// geschickten Text durchlaufen: Gemessen am 11.09.2026 mit drei Fassungen
/// wird er abgeschnitten, auch bei `scrollSpeed` über null
/// (`docs/firmware-beobachtungen.md` Nr. 1, Gerätereferenz §4.3).
///
/// Die Wahl des Wegs gibt es nicht mehr (siehe `SendeWeg` im Kern): Die App
/// rastert jeden Text selbst. Die Hilfe erklärt trotzdem, warum es diese
/// Wahl nicht mehr gibt — dieser Grund darf nicht stillschweigend
/// verschwinden.
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

    /// Und die gemeinsame Wegeregel sagt nicht mehr, „als Text" laufe von
    /// selbst durch — sie führt das Abschneiden jetzt als einen der Gründe
    /// dafür an, dass es diesen Weg in der Oberfläche nicht mehr gibt.
    func testDieWegeregelVersprichtKeinenLauf() throws {
        let text = try quelle("Sources/TC002Ansichten/HilfeInhalt.swift")
        XCTAssertFalse(text.contains("läuft von selbst durch, wenn nötig"),
                       "Die Wegeregel verspricht wieder einen Lauf, den die Werksfirmware nicht leistet.")
        XCTAssertTrue(text.contains("schnitt ihn ab"),
                      "Die Wegeregel sagt nicht mehr, was wirklich passiert.")
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
