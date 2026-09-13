import XCTest

/// Der Formatinspektor der Sendeansicht — aus der iPad-Rueckmeldung vom
/// 13.09.2026 (S1).
///
/// Wie in `MindestmasseTests` und `PlattformwegeTests` wird hier der Quelltext
/// gelesen, nicht der Uebersetzer befragt: Ein Farbwaehler in einer eigenen
/// Zeile uebersetzt genauso anstandslos wie einer in der Stil-Zeile. Der
/// Uebersetzer hat zu dieser Frage nichts zu sagen.
///
/// Das iPhone (`SendeniOS`) ist absichtlich nicht mitgeaendert: Fett,
/// Grossbuchstaben und Farbe liegen dort schon nebeneinander in der
/// schiebbaren Formatpille — eine Stil-Zeile gibt es gar nicht.
final class SendefeldTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // TC002AnsichtenTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // Repo

    /// Quelltext ohne Kommentare — sonst zaehlte jeder Satz mit, der das
    /// Gemeinte bloss erwaehnt, und die Kommentare in `SendenView` erwaehnen
    /// die Farbe mehrfach.
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

    /// Der Rumpf eines `{ … }`-Blocks, der auf `kopf` folgt — ueber
    /// Klammernzaehlung, damit „steht drin" wirklich „steht drin" heisst und
    /// nicht „steht irgendwo weiter unten in der Datei".
    private func block(nach kopf: String, in text: String) -> String? {
        guard let start = text.range(of: kopf) else { return nil }
        guard let auf = text[start.upperBound...].firstIndex(of: "{") else { return nil }
        var tiefe = 0
        var i = auf
        while i < text.endIndex {
            if text[i] == "{" { tiefe += 1 }
            if text[i] == "}" {
                tiefe -= 1
                if tiefe == 0 { return String(text[text.index(after: auf)..<i]) }
            }
            i = text.index(after: i)
        }
        return nil
    }

    /// S1: Der Farbwaehler gehoert in dieselbe Zeile wie „Fett" und
    /// „Grossbuchstaben", nicht in eine eigene Zeile darunter.
    func testDerFarbwaehlerStehtInDerStilZeile() throws {
        let text = try quelltext("Sources/TC002Ansichten/SendenView.swift")
        guard let stil = block(nach: #"LabeledContent("Stil")"#, in: text) else {
            return XCTFail("die Stil-Zeile gibt es nicht mehr")
        }
        XCTAssertTrue(stil.contains("ColorPicker("),
                      "der Farbwähler steht nicht in der Stil-Zeile")
        XCTAssertTrue(stil.contains(#"Image(systemName: "bold")"#),
                      "„Fett“ steht nicht mehr in der Stil-Zeile")
        XCTAssertTrue(stil.contains(#"Image(systemName: "capslock")"#),
                      "„Großbuchstaben“ steht nicht mehr in der Stil-Zeile")
        XCTAssertFalse(text.contains(#"LabeledContent("Farbe")"#),
                       "die Farbe hat wieder eine eigene Zeile bekommen")
    }
}
