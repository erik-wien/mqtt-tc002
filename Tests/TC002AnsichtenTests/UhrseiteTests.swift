import XCTest

/// Je Uhr eine Seite, und jeder Wert darauf gilt **dieser** Uhr.
///
/// Geprüft wird am Quelltext wie in `KnopfstilTests`: Wie es aussieht, sieht
/// man am Gerät; welche Uhr gemeint ist, steht hier.
final class UhrseiteTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func ohneKommentare(_ pfad: String) throws -> String {
        let url = Self.wurzel.appendingPathComponent(pfad)
        let roh = try String(contentsOf: url, encoding: .utf8)
        return roh.split(separator: "\n", omittingEmptySubsequences: false).map { z in
            guard let strich = z.range(of: "//") else { return String(z) }
            return String(z[z.startIndex..<strich.lowerBound])
        }.joined(separator: "\n")
    }

    /// Entfernen fragt nach, und beide Wege fragen dasselbe: die rote Zeile am
    /// Fuß der Seite und das Wischen in der Liste. Ein zweiter Wortlaut wäre
    /// ein zweiter Übersetzungsschlüssel, der auseinanderlaufen kann.
    func testEntfernenFragtNachUndZwarAufBeidenWegen() throws {
        for pfad in ["Sources/TC002Ansichten/Uhrseite.swift",
                     "Sources/TC002Ansichten/Uhrenliste.swift"] {
            XCTAssertTrue(try ohneKommentare(pfad).contains(".uhrentfernenRueckfrage("),
                          "\(pfad) entfernt eine Uhr ohne Rückfrage")
        }
        let liste = try ohneKommentare("Sources/TC002Ansichten/Uhrenliste.swift")
        XCTAssertTrue(liste.contains(".swipeActions("),
                      "in der Liste lässt sich eine Uhr nicht mehr wegwischen")
        let seite = try ohneKommentare("Sources/TC002Ansichten/Uhrseite.swift")
        XCTAssertTrue(seite.contains("Button(Uhrentfernen.knopf, role: .destructive)"),
                      "die Uhrseite hat ihre rote Zeile am Fuß verloren")
        XCTAssertEqual(try ohneKommentare("Sources/TC002Ansichten/Uhrseite.swift")
                        .components(separatedBy: "public static var titel").count - 1, 1,
                       "der Wortlaut der Rückfrage steht nicht mehr genau einmal da")
    }

    /// Die Liste zeigt je Uhr **eine** Zeile und keine Karte mit drei Knöpfen:
    /// Alles, was man mit einer Uhr tut, steht auf ihrer Seite.
    func testDieListeZeigtEineZeileJeUhr() throws {
        let quelle = try ohneKommentare("Sources/TC002Ansichten/Uhrenliste.swift")
        XCTAssertTrue(quelle.contains("NavigationLink(value: uhr.id)"),
                      "die Zeile führt nicht mehr auf die Seite der Uhr")
        for verirrt in ["Button(\"Abfragen\"", "pickerStyle(.segmented)", "Uhrlink("] {
            XCTAssertFalse(quelle.contains(verirrt),
                           "„\(verirrt)“ steht wieder in der Liste statt auf der Uhrseite — "
                           + "damit wächst die Liste wieder zur Wand")
        }
    }
}
