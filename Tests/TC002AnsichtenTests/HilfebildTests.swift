import XCTest
@testable import TC002Ansichten

/// Die Abbildungen der Hilfe werden gezeichnet, nicht aufgenommen — und jede,
/// die es gibt, steht auch irgendwo.
final class HilfebildTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func quelle(_ pfad: String) throws -> String {
        try String(contentsOf: Self.wurzel.appendingPathComponent(pfad), encoding: .utf8)
    }

    private func hilfequellen() throws -> String {
        try ["Sources/TC002Ansichten/HilfeInhalt.swift",
             "Sources/TC002Ansichten/HilfeView.swift",
             "Sources/TC002iOS/HilfeiOS.swift"].map(quelle).joined()
    }

    /// Eine Abbildung, die in keinem Abschnitt vorkommt, wird nie gezeichnet
    /// und fällt trotzdem bei jeder Änderung an der Vorschau mit an.
    func testJedeAbbildungStehtInEinemHilfeabschnitt() throws {
        let text = try hilfequellen()
        for bild in Hilfebild.allCases {
            XCTAssertTrue(text.contains(".abbildung(.\(bild.rawValue))"),
                          "Hilfebild .\(bild.rawValue) kommt in keinem Hilfeabschnitt vor.")
        }
    }

    /// Die Sendezeile zeigt den blauen Sendeknopf im Feld — den gibt es am
    /// Telefon nicht: `SendeniOS` ruft `eingabefeld(loeschbar:)` ohne
    /// `senden:`, dort schickt allein die Eingabetaste (siehe den Kanon in
    /// `.claude/skills/ui-umbau-pruefen`). Eine Abbildung eines Knopfs, den es
    /// nicht gibt, schickt den Leser suchen.
    func testDieTelefonhilfeZeigtNichtDieSendezeileDesSchreibtischs() throws {
        XCTAssertFalse(try quelle("Sources/TC002iOS/HilfeiOS.swift")
                        .contains(".abbildung(.sendezeile)"),
                       "Die iPhone-Hilfe zeichnet einen Sendeknopf, den diese Oberfläche nicht hat.")
        XCTAssertFalse(try quelle("Sources/TC002iOS/SendeniOS.swift")
                        .contains("senden:"),
                       "SendeniOS hat wieder einen Sendeknopf im Feld — dann gehört die Abbildung zurück in die Hilfe.")
    }

    /// Die Abbildungen entstehen aus den Ansichten der App, nicht aus Dateien
    /// im Bündel: Eine aufgenommene Abbildung veraltet still, sobald sich die
    /// Darstellung ändert, und bräuchte je Sprache und Erscheinungsbild eine
    /// eigene.
    func testDieAbbildungenWerdenGezeichnetUndNichtGeladen() throws {
        let text = try quelle("Sources/TC002Ansichten/Hilfebilder.swift")
        for geladen in ["Image(\"", "NSImage(", "UIImage(", "Bundle."] {
            XCTAssertFalse(text.contains(geladen),
                           "Hilfebilder lädt mit „\(geladen)“ eine Bilddatei statt zu zeichnen.")
        }
        XCTAssertTrue(text.contains("VorschauView("),
                      "Die Abbildungen benutzen nicht mehr die Vorschau der App.")
        XCTAssertTrue(text.contains("Slotblock("),
                      "Die Abbildungen benutzen nicht mehr den Block der App.")
    }
}
