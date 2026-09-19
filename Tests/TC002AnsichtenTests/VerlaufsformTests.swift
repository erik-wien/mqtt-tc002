import XCTest

/// Der Verlauf hat zwei Formen, und welche wohin gehoert, entscheidet die
/// Umgebung.
///
/// Am Telefon ist der ganze Sendebildschirm **eine** `List`: Vorschau und
/// Slotleiste sind Zeilen darin, der Verlauf ein `Section`
/// (`Verlaufsabschnitt`). Eine eigene `List` waere dort die zweite in der
/// ersten — sie bekaeme keine eigene Hoehe, braeuchte deshalb eine feste, und
/// eine feste Hoehe mit wenigen Zeilen verteilt den Rest als Leere. Genau das
/// stand zwischen Slotleiste und Formatpille.
///
/// Am Schreibtisch bleibt `Verlaufsliste` mit ihrer eigenen `List`: Dort ist
/// die Vorschau kein Listeneintrag, sie hat die Werkzeugleiste ueber sich und
/// den Inspektor neben sich.
///
/// Gleicher Weg wie `PlattformwegeTests`/`KnopfstilTests`: nachsehen im
/// Quelltext, Kommentare weg. Der Uebersetzer hat zu dieser Frage nichts zu
/// sagen — beide Formen uebersetzen, und das Loch sieht man erst am Geraet.
final class VerlaufsformTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func quelltext(_ pfad: String) throws -> String {
        let url = Self.wurzel.appendingPathComponent(pfad)
        let roh = try String(contentsOf: url, encoding: .utf8)
        return roh.split(separator: "\n", omittingEmptySubsequences: false)
            .map { zeile -> String in
                guard let strich = zeile.range(of: "//") else { return String(zeile) }
                return String(zeile[zeile.startIndex..<strich.lowerBound])
            }
            .joined(separator: "\n")
    }

    func testDerSendebildschirmDesTelefonsIstEineListe() throws {
        let text = try quelltext("Sources/TC002iOS/SendeniOS.swift")
        XCTAssertTrue(text.contains("Verlaufsabschnitt(zustand:"),
                      "das Telefon holt den Verlauf nicht mehr als Abschnitt in seine eigene Liste")
        XCTAssertFalse(text.contains("Verlaufsliste("),
                       "das Telefon baut wieder eine eigene Liste in seinen Rollbereich — "
                       + "sie bekommt darin keine Hoehe, und unter ihr steht wieder ein Loch")
        XCTAssertFalse(text.contains("ScrollView {"),
                       "die Mitte rollt wieder in einem eigenen Bereich statt als Liste — "
                       + "zwei ineinander rollende Bereiche sind am Finger nicht auseinanderzuhalten")
        XCTAssertFalse(text.contains(".frame(height: 260)"),
                       "die feste Hoehe des Verlaufs ist wieder da")
    }

    func testDerSchreibtischBehaeltSeineEigeneListe() throws {
        let text = try quelltext("Sources/TC002Ansichten/SendenView.swift")
        XCTAssertTrue(text.contains("Verlaufsliste(zustand:"),
                      "am Schreibtisch steht der Verlauf nicht mehr in seiner eigenen Liste — "
                      + "dort ist die Vorschau kein Listeneintrag, ein Abschnitt haette keine Liste, "
                      + "in der er stehen koennte")
    }
}
