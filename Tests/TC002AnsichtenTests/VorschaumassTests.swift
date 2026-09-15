import XCTest

/// **Die beiden Sendeansichten müssen das Maß auch wirklich durchreichen.**
///
/// Der Kern kann es seit `Anzeigemass` — aber ein Parameter mit Vorgabe ist
/// genau deshalb gefährlich: Wer ihn an einer Stelle vergisst, bekommt keinen
/// Übersetzerfehler, sondern wieder 52 × 16. Genau so ist der Fehler
/// entstanden, den dieser Durchgang behebt.
///
/// Geprüft wird am Quelltext, wie in `KnopfstilTests`: Ob die Vorschau danach
/// richtig **aussieht**, sieht man am Gerät; ob sie überhaupt danach fragt,
/// steht hier.
final class VorschaumassTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Die Stellen, an denen die Vorschau rechnet — je Datei die Aufrufe, die
    /// ohne Maß stillschweigend auf die Werksfirmware zurückfielen.
    private static let stellen = [
        "Sources/TC002Ansichten/SendenView.swift",
        "Sources/TC002iOS/SendeniOS.swift",
    ]

    private func ohneKommentare(_ pfad: String) throws -> String {
        let url = Self.wurzel.appendingPathComponent(pfad)
        let roh = try String(contentsOf: url, encoding: .utf8)
        return roh.split(separator: "\n", omittingEmptySubsequences: false).map { z in
            guard let strich = z.range(of: "//") else { return String(z) }
            return String(z[z.startIndex..<strich.lowerBound])
        }.joined(separator: "\n")
    }

    /// Jeder Aufruf von `Meldungsbau.feld`, `passt` und `laufschriftBilder` in
    /// einer Sendeansicht nennt sein Maß.
    func testDieSendeansichtenRechnenAufDemMassDerUhr() throws {
        for pfad in Self.stellen {
            let quelle = try ohneKommentare(pfad)
            for aufruf in ["Meldungsbau.feld(", "Meldungsbau.passt(", "Meldungsbau.laufschriftBilder("] {
                var suchAb = quelle.startIndex
                var gefunden = 0
                while let stelle = quelle.range(of: aufruf, range: suchAb..<quelle.endIndex) {
                    // Der Aufruf kann über zwei Zeilen stehen — deshalb ein
                    // Fenster statt der Zeile.
                    let ende = quelle.index(stelle.upperBound, offsetBy: 220,
                                            limitedBy: quelle.endIndex) ?? quelle.endIndex
                    let fenster = String(quelle[stelle.upperBound..<ende])
                    let bisKlammerZu = fenster.components(separatedBy: ")").first ?? fenster
                    XCTAssertTrue(bisKlammerZu.contains("mass:"),
                                  "\(pfad): \(aufruf) ohne Maß — fällt still auf 52×16 zurück.")
                    gefunden += 1
                    suchAb = stelle.upperBound
                }
                XCTAssertGreaterThan(gefunden, 0, "\(pfad): \(aufruf) kommt gar nicht mehr vor.")
            }
        }
    }

    /// Und sie rastern mit der Näherung, nicht mit der gespeicherten Schrift:
    /// Auf NG ist die Schriftwahl gesperrt, der gemerkte Wert kann trotzdem
    /// „Tiny5, 16 px" sein.
    func testDieSendeansichtenRasternMitDerNaeherung() throws {
        for pfad in Self.stellen {
            let quelle = try ohneKommentare(pfad)
            XCTAssertTrue(quelle.contains("optionen.naeherung(fuer: gattung)"),
                          "\(pfad): rastert die Vorschau ohne `naeherung`.")
        }
    }

    /// **Das vorberechnete GIF darf nicht in der falschen Größe ans Senden
    /// gehen.** Beide Oberflächen können an mehrere Uhren senden (am Mac über
    /// `ZielauswahlView`, am Telefon über „An alle Uhren senden"), während die
    /// Vorschau immer nur einer Uhr gilt. Steht sie auf einer NG, ist ihr GIF
    /// 32 × 8 — einer gleichzeitig beschickten TC002 füllte das ein Viertel
    /// ihrer Anzeige.
    func testDasVorberechneteGifGehtNurInDerSendegroesseMit() throws {
        for pfad in Self.stellen {
            let quelle = try ohneKommentare(pfad)
            XCTAssertTrue(quelle.contains("vorberechnet: mass == .tc002 ? laufschriftURI : nil"),
                          "\(pfad): reicht das vorberechnete GIF ungeprüft ans Senden weiter.")
        }
    }
}
