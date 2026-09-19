import XCTest

/// Eine stumme Uhr ist kein Fehler, den jemand wegklicken muss.
///
/// Sie ist aus, sie steht woanders, das WLAN schlaeft — daran hat niemand
/// etwas zu berichtigen. Ein Dialog davor legte sich ueber die ganze App und
/// kam bei vier Uhren viermal. Stattdessen ein Zeichen an der Uhr selbst:
/// in der Liste unter „Einstellungen → Uhren" und am Titel der angesehenen.
///
/// Andere Fehler bleiben Meldungen: Eine falsche Adresse oder eine
/// unerwartete Antwort sind etwas, das jemand richtigstellen kann.
///
/// Nachgesehen im Quelltext, Kommentare weg — die Unterscheidung steht in
/// einem `catch`, und ob ein Dialog aufgeht, sieht man sonst erst am Geraet.
final class ErreichbarkeitTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func quelltext(_ pfad: String) throws -> String {
        let roh = try String(contentsOf: Self.wurzel.appendingPathComponent(pfad), encoding: .utf8)
        return roh.split(separator: "\n", omittingEmptySubsequences: false)
            .map { z -> String in
                guard let strich = z.range(of: "//") else { return String(z) }
                return String(z[z.startIndex..<strich.lowerBound])
            }
            .joined(separator: "\n")
    }

    /// Mutation: das `if case` entfernen — baut, uebersetzt, und jede stumme
    /// Uhr wirft wieder ihren Dialog.
    func testEineStummeUhrSetztKeineFehlermeldung() throws {
        let text = try quelltext("Sources/TC002Modell/AppZustand.swift")
        XCTAssertTrue(text.contains("if case GeraetFehler.nichtErreichbar = error {"),
                      "der Abfragefehler wird nicht mehr danach unterschieden, ob die Uhr bloß "
                      + "stumm war — dann steht wieder ein Dialog vor der ganzen App")
        XCTAssertTrue(text.contains("public var erreichbar: [UUID: Bool] = [:]"),
                      "es gibt keinen Zustand je Uhr mehr, an dem das Zeichen hängen könnte")
    }

    /// Das Zeichen haengt an genau diesem Zustand und steht an beiden Orten,
    /// die der Auftraggeber genannt hat: Liste und Titel.
    func testDasZeichenStehtInDerListeUndAmTitel() throws {
        let zeichen = try quelltext("Sources/TC002Ansichten/Erreichbarkeitszeichen.swift")
        XCTAssertTrue(zeichen.contains("zustand.erreichbar[id] == false"),
                      "das Zeichen hängt nicht mehr an der Erreichbarkeit")

        for (datei, wo) in [("Sources/TC002Ansichten/Uhrenliste.swift", "die Liste der Uhren"),
                            ("Sources/TC002Ansichten/Uhrenwahl.swift", "der Titel am Schreibtisch")] {
            XCTAssertTrue(try quelltext(datei).contains("Erreichbarkeitszeichen("),
                          "\(wo) zeigt nicht mehr an, dass eine Uhr nicht geantwortet hat")
        }
        // Am Telefon steht es seit dem Streichen des Titelmenues an derselben
        // Stelle wie am Schreibtisch: neben dem Namen unter der Vorschau.
        XCTAssertTrue(try quelltext("Sources/TC002iOS/SendeniOS.swift")
                        .contains("Erreichbarkeitszeichen(zustand: zustand, id: uhr.id)"),
                      "am Telefon steht neben dem Uhrennamen nicht mehr, dass die Uhr nicht "
                      + "geantwortet hat")
    }
}
