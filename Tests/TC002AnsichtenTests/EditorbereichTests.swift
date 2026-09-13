import XCTest
@testable import TC002Ansichten

/// Aus „Bilder" und „Icons" ist ein Bereich geworden: „Editor".
///
/// Zwei Hälften, und beide werden gebraucht: die Seitenleiste selbst und die
/// Zusicherung, dass es wirklich **eine** Ansicht mit Unterschieden ist und
/// nicht wieder zwei mit Ähnlichkeiten. Die zweite prüft der Übersetzer nicht —
/// eine zweite, fast gleiche Datei übersetzt anstandslos. Deshalb derselbe Weg
/// wie in `PlattformwegeTests`: nachsehen im Quelltext.
final class EditorbereichTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Quelltext ohne Kommentare — sonst zählte jeder Satz mit, der etwas
    /// bloß erwähnt, und diese Datei erwähnt ihre Vorgänger.
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

    func testDieSeitenleisteHatVierEintraegeUndDarunterDenEditor() {
        XCTAssertEqual(SchreibtischView.Bereich.oben, [.senden, .editor])
        XCTAssertEqual(SchreibtischView.Bereich.unten, [.verlauf, .einstellungen])
        XCTAssertEqual(SchreibtischView.Bereich.allCases.count, 4,
                       "„Bilder“ und „Icons“ sind zu einem Eintrag geworden")
    }

    /// Der Eintrag heißt „Editor" und trägt die Palette — beides ausdrücklich
    /// so verlangt, und beides ließe sich unbemerkt ändern.
    func testDerEintragHeisstEditorUndTraegtDiePalette() {
        XCTAssertEqual(SchreibtischView.Bereich.editor.rawValue, "Editor")
        XCTAssertEqual(SchreibtischView.Bereich.editor.symbol, "paintpalette")
    }

    /// Es gibt genau **einen** Editor. In diesem Projekt ist schon einmal ein
    /// Fehler daraus entstanden, dass es dieselbe Rechnung dreimal gab.
    func testEsGibtNurEineEditoransicht() {
        let fm = FileManager.default
        for weg in ["Sources/TC002Ansichten/IconEditorView.swift",
                    "Sources/TC002Ansichten/BilderBereichView.swift",
                    "Sources/TC002Ansichten/PixelEditor.swift"] {
            XCTAssertFalse(fm.fileExists(atPath: Self.wurzel.appendingPathComponent(weg).path),
                           "\(weg) ist wieder da — es soll eine Ansicht mit Unterschieden sein, nicht zwei mit Ähnlichkeiten")
        }
        XCTAssertTrue(fm.fileExists(atPath: Self.wurzel
            .appendingPathComponent("Sources/TC002Ansichten/EditorBereichView.swift").path))
    }

    /// Die Unterschiede zwischen den drei Größen werden **abgeleitet**
    /// (`Leinwandgroesse`), nicht als Fallunterscheidung in die Ansicht
    /// geschrieben. Genau darum geht es bei diesem Umbau.
    func testDieUnterschiedeWerdenAbgeleitetUndNichtAufgezaehlt() throws {
        let text = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        XCTAssertTrue(text.contains("groesse.sendbar"),
                      "die Sendezeile hängt nicht mehr an der abgeleiteten Eigenschaft")
        XCTAssertTrue(text.contains("groesse.mitNummer"),
                      "das Nummernfeld hängt nicht mehr an der abgeleiteten Eigenschaft")
        XCTAssertTrue(text.contains("groesse.iconEinfuegbar"),
                      "„Icon einfügen“ hängt nicht mehr an der abgeleiteten Eigenschaft")
        for sonderfall in ["groesse == .icon8", "groesse == .icon16", "groesse == .anzeige",
                           "case .icon8:", "case .anzeige:"] {
            XCTAssertFalse(text.contains(sonderfall),
                           "„\(sonderfall)“ ist ein Sonderfall in der Ansicht — er gehört nach Leinwandgroesse")
        }
    }

    /// Die Hilfe zieht mit: Zu jedem Bereich der Seitenleiste muss es einen
    /// gleichnamigen Abschnitt geben. Beim Zusammenlegen von „Bilder" und
    /// „Icons" wären sonst zwei Abschnitte über etwas stehen geblieben, das es
    /// nicht mehr gibt — und die Übersetzungsprüfung merkt davon nichts, sie
    /// sieht nur, ob ein Eintrag da ist.
    func testZuJedemBereichGibtEsEinenHilfeabschnitt() throws {
        let text = try quelltext("Sources/TC002Ansichten/HilfeView.swift")
        for bereich in SchreibtischView.Bereich.allCases {
            XCTAssertTrue(text.contains("= \"\(bereich.rawValue)\""),
                          "die Hilfe hat keinen Abschnitt „\(bereich.rawValue)“")
        }
        XCTAssertFalse(text.contains("case bilder"), "der Abschnitt „Bilder“ steht noch da")
        XCTAssertFalse(text.contains("case icons"), "der Abschnitt „Icons“ steht noch da")
    }
}
