import XCTest

/// **Die Wahl der Betriebsart muss es auf beiden Oberflächen geben.**
///
/// Sie ist keine Kleinigkeit, sondern entscheidet, ob eine Uhr überhaupt
/// beschickt werden kann: Eine HTTP-Uhr braucht kein Präfix und keinen
/// Broker, eine MQTT-Uhr beides. Gäbe es die Wahl nur am Mac, käme jemand am
/// Telefon aus einer Einrichtung nicht mehr heraus, die dort nicht trägt —
/// und säße vor einem Sendeknopf, der nirgendwohin führt.
///
/// Gleicher Weg wie `PlattformwegeTests` und `KnopfstilTests`: nachsehen im
/// Quelltext. Eine Oberfläche lässt sich ohne Gerät nicht anders prüfen, und
/// der Übersetzer hat dazu nichts zu sagen — ein Picker, den jemand beim
/// Bauen der zweiten Fassung vergisst, fällt sonst nirgends auf.
final class BetriebsartTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func quelle(_ pfad: String) throws -> String {
        try String(contentsOf: Self.wurzel.appendingPathComponent(pfad), encoding: .utf8)
    }

    /// Beide Einstellungsansichten — die des Schreibtischs (Mac und iPad) und
    /// die des Telefons — bieten die Wahl an, und beide schreiben sie über
    /// `betriebsartGeaendert` zurück. Ohne diesen Aufruf bliebe ein
    /// Abonnement stehen, das es nach dem Wechsel nicht mehr geben darf.
    func testBeideEinstellungsansichtenBietenDieWahlAn() throws {
        for pfad in ["Sources/TC002Ansichten/VerbindungView.swift",
                     "Sources/TC002iOS/VerbindungiOS.swift"] {
            let text = try quelle(pfad)
            XCTAssertTrue(text.contains("Picker(\"Betriebsart\""),
                          "\(pfad) bietet die Betriebsart nicht zur Wahl an")
            XCTAssertTrue(text.contains("Betriebsart.http") && text.contains("Betriebsart.mqtt"),
                          "\(pfad) bietet nicht beide Fälle an")
            XCTAssertTrue(text.contains("zustand.betriebsartGeaendert("),
                          "\(pfad) schreibt die Wahl, ohne sie wirksam zu machen")
        }
    }

    /// Der Unterschied ist ein **Tausch**, und beide Hälften davon stehen
    /// nebeneinander in derselben Zeile: was HTTP kann und was MQTT kann.
    /// Nur eine Hälfte zu nennen wäre eine Empfehlung, keine Auskunft — und
    /// die Vorgabe ist ohnehin schon gesetzt.
    func testDerHinweisNenntBeideHaelftenDesTauschs() throws {
        for pfad in ["Sources/TC002Ansichten/VerbindungView.swift",
                     "Sources/TC002iOS/VerbindungiOS.swift"] {
            let text = try quelle(pfad)
            XCTAssertTrue(text.contains("HTTP meldet zurück, ob die Uhr die Anzeige angenommen hat. MQTT meldet das nie, liest dafür mit, was andere an dieselbe Uhr schicken."),
                          "\(pfad) nennt den Tausch nicht oder nur halb")
        }
    }
}
