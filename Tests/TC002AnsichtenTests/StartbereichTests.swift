import XCTest
@testable import TC002Ansichten

/// Womit die App beginnt.
///
/// Ohne eingerichtete Uhr und ohne eingetragenen Broker ist „Senden" eine
/// Sackgasse: keine Vorschau, kein Ziel, ein Sendeknopf, der nirgendwohin
/// führt. Beim ersten Start — und genauso, wenn jemand später alles wieder
/// entfernt — stehen deshalb die Einstellungen vorn.
///
/// Zwei Hälften, und beide werden gebraucht: die Entscheidung selbst
/// (`Bereich.start`) und die Frage, ob die Oberflächen sie überhaupt stellen.
/// Die zweite prüft der Übersetzer nicht — ein wieder fest eingetragenes
/// `.senden` übersetzt anstandslos. Deshalb hier derselbe Weg wie in
/// `PlattformwegeTests`: nachsehen im Quelltext.
final class StartbereichTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // TC002AnsichtenTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // Repo

    /// Quelltext ohne Kommentare — sonst zählte jeder Satz mit, der den
    /// Startbereich bloß erwähnt, und dieses Repo erwähnt ihn an mehreren
    /// Stellen.
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

    func testOhneEinrichtungBeginntEsBeiDenEinstellungen() {
        XCTAssertEqual(SchreibtischView.Bereich.start(eingerichtet: false), .einstellungen,
                       "ohne Uhr und ohne Broker führt „Senden“ nirgendwohin")
    }

    func testMitEinrichtungBeginntEsWieBisherBeimSenden() {
        XCTAssertEqual(SchreibtischView.Bereich.start(eingerichtet: true), .senden,
                       "wer eingerichtet ist, soll starten wie vorher")
    }

    /// Mac und iPad: Der Schreibtisch muss den Startbereich erfragen, statt
    /// ihn wieder fest einzutragen.
    func testDerSchreibtischFragtDenStartbereichAb() throws {
        let text = try quelltext("Sources/TC002Ansichten/SchreibtischView.swift")
        XCTAssertTrue(text.contains("Bereich.start(eingerichtet: zustand.eingerichtet)"),
                      "der Schreibtisch entscheidet den Startbereich nicht mehr über Bereich.start")
        XCTAssertFalse(text.range(of: #"var bereich: Bereich\? = "#, options: .regularExpression) != nil,
                       "der Startbereich steht wieder fest im Quelltext")
    }

    /// iPhone: Dort gibt es keine Seitenleiste — der einzige Weg zu den
    /// Einstellungen ist das Zahnrad oben. Das Blatt muss deshalb beim Start
    /// von selbst aufgehen, solange nichts eingerichtet ist.
    func testDasTelefonOeffnetDieEinstellungenWennNichtsEingerichtetIst() throws {
        let text = try quelltext("Sources/TC002iOS/SendeniOS.swift")
        XCTAssertTrue(text.contains("_zeigeEinstellungen = State(initialValue: !zustand.eingerichtet)"),
                      "das Einstellungsblatt geht beim Start nicht mehr von selbst auf")
        XCTAssertFalse(text.contains("var zeigeEinstellungen = false"),
                       "der Anfangswert steht wieder fest auf „zu“")
    }
}
