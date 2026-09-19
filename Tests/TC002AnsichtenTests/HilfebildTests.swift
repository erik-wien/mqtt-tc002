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

    /// Die Abbildung der Sendezeile zeigt den blauen Pfeil im Feld. Seit das
    /// Telefon ihn ebenfalls hat — `SendeniOS` ruft denselben Baustein mit
    /// `senden:` —, steht sie in **beiden** Hilfen.
    ///
    /// Beides zusammen geprüft, weil nur das Paar die Aussage trägt: Eine
    /// Abbildung ohne den Knopf schickte den Leser suchen, ein Knopf ohne
    /// Abbildung liesse die Telefonhilfe hinter der Ansicht zurück.
    func testBeideHilfenZeigenDieSendezeileUndBeideHabenSie() throws {
        XCTAssertTrue(try quelle("Sources/TC002iOS/SendeniOS.swift").contains("senden:"),
                      "dem Telefon ist der Sendepfeil im Feld abhanden gekommen")
        for hilfe in ["Sources/TC002Ansichten/HilfeView.swift",
                      "Sources/TC002iOS/HilfeiOS.swift"] {
            XCTAssertTrue(try quelle(hilfe).contains(".abbildung(.sendezeile)"),
                          "\(hilfe) zeigt die Sendezeile nicht mehr, obwohl es sie dort gibt")
        }
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
