import XCTest
@testable import TC002Ansichten

/// Die Schriftwahl in der Kopfzeile der Schriftprobe.
///
/// Zwei Haelften, und beide werden gebraucht: **was** gezeigt wird
/// (`Schriftwahl.schriften(aus:)`) und dass die Wahl die Messung **nicht**
/// erneut anstoesst. Die zweite prueft der Uebersetzer nicht — ein
/// `.task(id: wahl)` uebersetzt anstandslos und rastert danach bei jedem
/// Wechsel der Wahl anderthalb Sekunden lang neu. Deshalb hier derselbe Weg wie
/// in `PlattformwegeTests`: nachsehen im Quelltext.
final class SchriftwahlTests: XCTestCase {
    private let vorrat = ["Micro 5", "Silkscreen", "Tiny5", "Menlo"]

    /// Die Vorgabe zeigt alles — und in der Reihenfolge des Vorrats.
    func testAlleZeigtDenGanzenVorrat() {
        XCTAssertEqual(Schriftwahl.alle.schriften(aus: vorrat), vorrat)
    }

    /// Und eine Wahl zeigt genau eine Schrift. Faellt das, scrollt man wieder
    /// an allem vorbei.
    func testEineWahlZeigtNurDieseSchrift() {
        XCTAssertEqual(Schriftwahl.nur("Tiny5").schriften(aus: vorrat), ["Tiny5"])
        XCTAssertEqual(Schriftwahl.nur("Menlo").schriften(aus: vorrat), ["Menlo"])
        XCTAssertEqual(Schriftwahl.nur("Micro 5").schriften(aus: vorrat), ["Micro 5"])
    }

    /// Gefiltert, nicht zurueckgegeben: Eine Schrift, die es im Vorrat nicht
    /// gibt, ergibt nichts — sonst stuende in der Ansicht eine Ueberschrift
    /// ohne einen einzigen Block darunter.
    func testWasNichtImVorratStehtErscheintNicht() {
        XCTAssertEqual(Schriftwahl.nur("Comic Sans MS").schriften(aus: vorrat), [])
        XCTAssertEqual(Schriftwahl.alle.schriften(aus: []), [])
    }

    // MARK: - Dass die Wahl nur filtert

    private static let quelle = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // TC002AnsichtenTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // Repo
        .appendingPathComponent("Sources/TC002Ansichten/SchriftprobeView.swift")

    /// Quelltext ohne Kommentare — sonst zaehlt jeder Satz mit, der die Messung
    /// bloss erwaehnt, und diese Datei erwaehnt sie mehrfach.
    private func quelltext() throws -> String {
        let roh = try String(contentsOf: Self.quelle, encoding: .utf8)
        return roh.split(separator: "\n", omittingEmptySubsequences: false)
            .map { zeile -> String in
                guard let strich = zeile.range(of: "//") else { return String(zeile) }
                return String(zeile[zeile.startIndex..<strich.lowerBound])
            }
            .joined(separator: "\n")
    }

    /// Die Messung kostet rund anderthalb Sekunden. Sie laeuft einmal beim
    /// Erscheinen, das Ergebnis haengt in `@State`, und die Wahl sucht daraus
    /// aus. Ein `id:` an der Aufgabe machte daraus eine Messung je Wahl.
    func testDieMessungHaengtAnKeinerWahl() throws {
        let text = try quelltext()
        XCTAssertEqual(text.components(separatedBy: "Schriftprobe.alleMessungen").count - 1, 1,
                       "die Messung darf an genau einer Stelle angestossen werden")
        XCTAssertTrue(text.contains(".task {"),
                      "die Messung gehört in eine Aufgabe ohne Kennung")
        XCTAssertFalse(text.contains(".task(id:"),
                       "eine Kennung an der Aufgabe misst bei jedem Wechsel der Wahl neu")
        XCTAssertFalse(text.contains(".onChange(of: wahl"),
                       "die Wahl filtert — sie stößt nichts an")
    }
}
