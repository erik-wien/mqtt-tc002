import XCTest

/// Anzeige | Nachricht, Lebensdauer und „In der Schleife“ gibt es auf beiden
/// Sendeflächen: Was die eine kann, kann die andere auch (`CLAUDE.md`).
final class NachrichtOberflaecheTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func quelltext(_ pfad: String) throws -> String {
        let roh = try String(contentsOf: Self.wurzel.appendingPathComponent(pfad), encoding: .utf8)
        return roh.split(separator: "\n", omittingEmptySubsequences: false)
            .map { zeile -> String in
                guard let strich = zeile.range(of: "//") else { return String(zeile) }
                return String(zeile[zeile.startIndex..<strich.lowerBound])
            }
            .joined(separator: "\n")
    }

    /// Mutation: eine der beiden Flächen verliert das Segment oder die Regler.
    func testBeideSendeflaechenHabenSegmentUndSperreDerPlaetze() throws {
        for datei in ["Sources/TC002Ansichten/SendenView.swift", "Sources/TC002iOS/SendeniOS.swift"] {
            let text = try quelltext(datei)
            XCTAssertTrue(text.contains("Sendeartwahl(zustand: zustand, art: $art)"), datei)
            XCTAssertTrue(text.contains("gesperrt: art == .nachricht"), "\(datei): Plätze bei „Nachricht“ nicht gesperrt")
            XCTAssertTrue(text.contains("zustand.benachrichtigen("), "\(datei) sendet keine Nachricht")
            XCTAssertTrue(text.contains("lebensdauer: lebensdauerwahl.lebensdauer"), "\(datei) schickt keine Lebensdauer")
        }
    }

    /// Reiter „Zeit“ (Mac, iPad) und Formatblatt (iPhone) tragen beide Abschnitte,
    /// gesperrt statt ausgeblendet.
    func testBeideOrteDerReglerTragenBeideAbschnitte() throws {
        for datei in ["Sources/TC002Ansichten/SendenView.swift", "Sources/TC002iOS/FormatblattiOS.swift"] {
            let text = try quelltext(datei)
            XCTAssertTrue(text.contains("Lebensdauerabschnitt("), datei)
            XCTAssertTrue(text.contains("Nachrichtabschnitt("), datei)
            XCTAssertTrue(text.contains("aktiv: art == .anzeige"), datei)
            XCTAssertTrue(text.contains("aktiv: art == .nachricht"), datei)
        }
    }

    /// „Nach“ und „Dann“ sind bei „Behalten“ gesperrt, nicht versteckt.
    func testBehaltenSperrtNachUndDannStattSieZuVerstecken() throws {
        let text = try quelltext("Sources/TC002Ansichten/Nachrichtbausteine.swift")
        XCTAssertEqual(text.components(separatedBy: ".disabled(behalten)").count - 1, 2)
        XCTAssertTrue(text.contains(".gesperrterStepper(behalten || !aktiv)"), "„Nach“ ist bei „Behalten“ nicht gesperrt")
        XCTAssertFalse(text.contains("if !behalten"), "„Nach“/„Dann“ werden ausgeblendet")
    }

    /// Die Blockreihe aller Flächen reicht „In der Schleife“ an das Menü.
    func testDasBlockmenueSchaltetDieSchleife() throws {
        let text = try quelltext("Sources/TC002Ansichten/Slotleiste.swift")
        XCTAssertTrue(text.contains("anzeigeSchalten("))
        XCTAssertTrue(text.contains("inSchleife: zustand.inSchleife(platz: i)"))
    }
}
