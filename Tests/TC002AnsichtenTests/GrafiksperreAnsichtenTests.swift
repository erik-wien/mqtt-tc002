import XCTest

/// Die Sperre muss dort ankommen, wo gewählt wird. Der Kern weiß seit
/// `Geraetetyp.grafikSperre`, was zu hoch ist, und `AppZustand.grafikSperre`
/// weiß, ob es für die Zieluhren gilt — beides nützt nichts, solange die
/// Auswahl weiter alles anbietet und der Fehler erst beim Senden auffällt.
///
/// Geprüft wird am Quelltext, wie in `KnopfstilTests`: Ob die gesperrte Kachel
/// richtig aussieht, sieht man am Gerät; dass sie überhaupt gesperrt wird,
/// steht hier.
final class GrafiksperreAnsichtenTests: XCTestCase {
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

    /// Beide Iconauswahlen fragen nach der Sperre, statt sie zu erfinden — und
    /// sperren die Kachel damit.
    func testBeideIconauswahlenSperrenDieZuHohenKacheln() throws {
        for pfad in ["Sources/TC002Ansichten/IconAuswahlView.swift",
                     "Sources/TC002iOS/IconsblattiOS.swift"] {
            let quelle = try ohneKommentare(pfad)
            XCTAssertTrue(quelle.contains("sperre("),
                          "\(pfad): fragt gar nicht nach der Sperre.")
            XCTAssertTrue(quelle.contains(".disabled(sperre("),
                          "\(pfad): fragt nach der Sperre, sperrt aber nichts.")
        }
    }

    /// Und die Frage geht an die Zielmenge, nicht an die angesehene Uhr:
    /// Gesendet wird an `ziele()`.
    ///
    /// Am Schreibtisch stellt sie die Sendeansicht und reicht sie ans
    /// Auswahlblatt weiter; am Telefon stellt sie das Icons-Blatt selbst, weil
    /// es den Zustand ohnehin hat — es schickt von dort aus auch. Beides ist
    /// dieselbe Zusicherung, nur an verschiedenen Stellen geschrieben.
    func testDieSperreKommtVonDenZieluhren() throws {
        for pfad in ["Sources/TC002Ansichten/SendenView.swift",
                     "Sources/TC002iOS/IconsblattiOS.swift"] {
            let quelle = try ohneKommentare(pfad)
            XCTAssertTrue(quelle.contains("zustand.grafikSperre(hoehe:"),
                          "\(pfad): fragt die Zieluhren nicht nach der Sperre.")
        }
    }

    /// Die Seite einer 52 × 16 am Telefon darf nicht senden, ohne vorher zu
    /// prüfen, ob die Zieluhr die Höhe überhaupt annimmt.
    func testDieAnzeigeseiteSchicktNichtInsLeere() throws {
        let quelle = try ohneKommentare("Sources/TC002iOS/IconsblattiOS.swift")
        XCTAssertTrue(quelle.contains("zustand.grafikSperre(hoehe: Pixelfeld.hoeheStandard)"),
                      "Die Anzeigeseite fragt nicht, ob eine 16 Zeilen hohe Anzeige überhaupt ankommt.")
        XCTAssertTrue(quelle.contains("sperre != nil"),
                      "Die Anzeigeseite kennt die Sperre, hindert aber nichts.")
    }
}
