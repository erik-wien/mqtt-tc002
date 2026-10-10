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
            XCTAssertTrue(text.contains("Sendeartwahl(zustand: zustand, art: $art,"), datei)
            XCTAssertTrue(text.contains("gesperrt: art == .nachricht"), "\(datei): Plätze bei „Nachricht“ nicht gesperrt")
            XCTAssertTrue(text.contains("zustand.benachrichtigen("), "\(datei) sendet keine Nachricht")
            XCTAssertTrue(text.contains("lebensdauer: lebensdauerwahl.lebensdauer"), "\(datei) schickt keine Lebensdauer")
        }
    }

    /// Klang, Nachrichtoptionen und Lebensdauer sitzen am Segment, in genau einem
    /// Baustein; weder der Inspektor (Mac, iPad) noch das Formatblatt (iPhone)
    /// trägt sie noch ein zweites Mal.
    func testDieReglerSitzenAmSegmentUndNurDort() throws {
        let baustein = try quelltext("Sources/TC002Ansichten/Nachrichtbausteine.swift")
        XCTAssertTrue(baustein.contains("Lebensdauerabschnitt(behalten: lebensdauer.behalten"))
        XCTAssertTrue(baustein.contains("Nachrichtabschnitt(halten: nachricht.halten"))
        let ton = try quelltext("Sources/TC002Ansichten/Nachrichtbausteine.swift")
        XCTAssertTrue(ton.contains("Klangabschnitt(zustand: zustand, klang: nachricht.klang, aktiv: true"))
        for datei in ["Sources/TC002Ansichten/SendenView.swift", "Sources/TC002iOS/FormatblattiOS.swift"] {
            let text = try quelltext(datei)
            XCTAssertFalse(text.contains("Lebensdauerabschnitt("), datei)
            XCTAssertFalse(text.contains("Nachrichtabschnitt("), datei)
            XCTAssertFalse(text.contains("Klangabschnitt("), datei)
        }
    }

    /// Beide Sendeflächen schicken den Klang mit dem Text der Nachricht, und die
    /// Fernbedienung (Mac, iPad, iPhone-Blatt) trägt den Abschnitt „Ton“.
    func testKlangGehtMitUndDieFernbedienungHatTon() throws {
        for datei in ["Sources/TC002Ansichten/SendenView.swift", "Sources/TC002iOS/SendeniOS.swift"] {
            XCTAssertTrue(try quelltext(datei).contains("optionen(nachrichtentext:"), "\(datei) schickt keinen Klang")
        }
        XCTAssertTrue(try quelltext("Sources/TC002Ansichten/Fernbedienung.swift")
            .contains("Tonabschnitt(zustand: zustand, uhr: uhr, kanon: kanon)"))
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
