import XCTest

/// **Die sichtbare Fassung des Einblendtexts.** Bis hierher hing jede
/// Erklärung im Inspektor an `.help(…)` — am Mac beim Verweilen mit der Maus
/// zu sehen, am iPad ohne Zeiger überhaupt nicht (`Gattungssperre.swift`
/// begründet das, und Punkt 2 des Rückstandsdokuments führte es als offen).
/// `Abschnittskopf` setzt deshalb ein antippbares (?) rechtsbündig neben die
/// Gruppenüberschrift.
///
/// Geprüft wird wie in `KnopfstilTests` am Quelltext, denn hier gibt es
/// nichts zu rechnen: **Dass** die vier Überschriften einen Kopf mit Hilfe
/// tragen, steht im Quelltext, und nur dort fällt es auf, wenn jemand einen
/// Abschnitt umbaut und die Erklärung dabei verliert. Wie das (?) aussieht,
/// prüft das nicht — das sieht man am Gerät.
final class HilfezeichenTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Die vier Gruppenüberschriften, die eine Erklärung tragen müssen, samt
    /// ihrer Datei. Zwei im Sendeinspektor, zwei im Editorinspektor — beide
    /// Ansichten gelten für Mac **und** iPad (`SchreibtischView`).
    /// „Senden als" stand hier bis zum 18.09.2026 mit dazu. Der Abschnitt ist
    /// weg, weil die Wahl weg ist (siehe `SendeWeg` im Kern) — und damit auch
    /// die Frage, die sein (?) beantwortet hätte.
    private static let koepfe = [
        ("Sources/TC002Ansichten/SendenView.swift", "Schrift"),
        ("Sources/TC002Ansichten/EditorBereichView.swift", "Dieses Bild"),
        ("Sources/TC002Ansichten/EditorBereichView.swift", "Hinzufügen"),
    ]

    /// Quelltext ohne Kommentare — sonst genügte ein Satz über einen
    /// Abschnittskopf, um die Prüfung zu bestehen.
    private func ohneKommentare(_ pfad: String) throws -> String {
        let url = Self.wurzel.appendingPathComponent(pfad)
        let roh = try String(contentsOf: url, encoding: .utf8)
        return roh.split(separator: "\n", omittingEmptySubsequences: false).map { z in
            guard let strich = z.range(of: "//") else { return String(z) }
            return String(z[z.startIndex..<strich.lowerBound])
        }.joined(separator: "\n")
    }

    private func roh(_ pfad: String) throws -> String {
        try String(contentsOf: Self.wurzel.appendingPathComponent(pfad), encoding: .utf8)
    }

    private func swiftDateien(unter ordner: String) -> [String] {
        let basis = Self.wurzel.appendingPathComponent(ordner)
        let inhalt = (try? FileManager.default.contentsOfDirectory(atPath: basis.path)) ?? []
        return inhalt.filter { $0.hasSuffix(".swift") }.sorted().map { "\(ordner)/\($0)" }
    }

    // MARK: - Die Prüfungen

    /// Jede der vier Überschriften steht als `Abschnittskopf`, nicht als
    /// blanker `Section("…")` — und trägt damit ihr (?).
    func testDieVierGruppenueberschriftenTragenEineErklaerung() throws {
        for (pfad, titel) in Self.koepfe {
            let quelle = try ohneKommentare(pfad)
            XCTAssertTrue(quelle.contains("Abschnittskopf(\"\(titel)\""),
                          "„\(titel)“ in \(pfad) trägt keinen Abschnittskopf mit Erklärung.")
        }
    }

    /// Ein `Abschnittskopf` ohne `hilfe:` wäre eine Überschrift ohne (?) —
    /// dann bräuchte es ihn gar nicht.
    func testJederAbschnittskopfBekommtEinenText() throws {
        for pfad in swiftDateien(unter: "Sources/TC002Ansichten") {
            let quelle = try ohneKommentare(pfad)
            for zeile in quelle.split(separator: "\n") where zeile.contains("Abschnittskopf(\"") {
                XCTAssertTrue(zeile.contains("hilfe:"),
                              "Abschnittskopf ohne Erklärung in \(pfad): \(zeile.trimmingCharacters(in: .whitespaces))")
            }
        }
    }

    /// **Ein Text, zweimal benutzt.** Die LaMetric-Nummer wird an zwei Stellen
    /// erklärt — im Abschnitt des Bildes und unter „Hinzufügen“ —, und beide
    /// Male mit demselben Wortlaut. Zweimal hingeschrieben wären es zwei
    /// Übersetzungsschlüssel, die auseinanderlaufen können; deshalb eine
    /// Konstante, die genau einmal im Quelltext steht.
    func testDieLaMetricErklaerungStehtNurEinmalDa() throws {
        let anfang = "Icons für solche Uhren werden über LaMetric-Nummern angesprochen."
        var stellen = 0
        for ordner in ["Sources/TC002Ansichten", "Sources/TC002App", "Sources/TC002iOS"] {
            for pfad in swiftDateien(unter: ordner) {
                stellen += try ohneKommentare(pfad).components(separatedBy: anfang).count - 1
            }
        }
        XCTAssertEqual(stellen, 1, "Die LaMetric-Erklärung steht \(stellen)-mal im Quelltext statt einmal.")
    }

    /// Die Überschrift heißt „Dieses Bild“. „Diese Bildgruppe“ war der frühere
    /// Wortlaut und darf nirgends mehr stehen — auch nicht in einem Kommentar,
    /// der auf sie verweist, sonst sucht man später einen Abschnitt, den es
    /// nicht mehr gibt.
    func testDerFruehereWortlautStehtNirgendsMehr() throws {
        for ordner in ["Sources/TC002Ansichten", "Sources/TC002App", "Sources/TC002iOS",
                       "Sources/TC002Modell", "Sources/TC002Core"] {
            for pfad in swiftDateien(unter: ordner) {
                XCTAssertFalse(try roh(pfad).contains("Diese Bildgruppe"),
                               "„Diese Bildgruppe“ steht noch in \(pfad).")
            }
        }
    }
}
