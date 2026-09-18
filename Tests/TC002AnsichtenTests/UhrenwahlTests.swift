import XCTest

/// Ansehen und Senden sind zwei Entscheidungen, und sie haben zwei Griffe:
/// Die angesehene Uhr steht im Titelmenü der Werkzeugleiste (wo das Telefon
/// sie seit je hat und Xcode sein Ziel zeigt), eine Punktreihe unter der
/// Vorschau sagt, wie viele Uhren es gibt und die wievielte man sieht.
///
/// Geprüft wird am Quelltext wie in `KnopfstilTests`: Wie es aussieht, sieht
/// man am Gerät; dass jede Oberfläche beide Griffe hat, steht hier.
final class UhrenwahlTests: XCTestCase {
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

    private func swiftDateien(unter ordner: String) -> [String] {
        let basis = Self.wurzel.appendingPathComponent(ordner)
        let inhalt = (try? FileManager.default.contentsOfDirectory(atPath: basis.path)) ?? []
        return inhalt.filter { $0.hasSuffix(".swift") }.sorted().map { "\(ordner)/\($0)" }
    }

    /// Beide Bereiche des Schreibtischs tragen das Titelmenü, und zwar an der
    /// selben Stelle: `.principal`. Zwei Orte für dieselbe Wahl wären
    /// schlimmer als ein ungünstiger.
    func testBeideSchreibtischbereicheTragenDasTitelmenue() throws {
        for pfad in ["Sources/TC002Ansichten/SendenView.swift",
                     "Sources/TC002Ansichten/EditorBereichView.swift"] {
            let quelle = try ohneKommentare(pfad)
            XCTAssertTrue(quelle.contains("ToolbarItem(placement: .principal)"),
                          "\(pfad): kein Titelmenü in der Werkzeugleiste.")
            XCTAssertTrue(quelle.contains("Uhrenmenue(zustand: zustand)"),
                          "\(pfad): das Titelmenü zeigt nicht die angesehene Uhr.")
        }
    }

    /// Wo eine Vorschau steht, steht auch die Punktreihe — und die Wischgeste
    /// darüber. Auf beiden Oberflächenfamilien: Der Unterschied zwischen
    /// Zeiger und Finger rechtfertigt, dass das eine leichter zu treffen ist
    /// als das andere, nicht dass eines fehlt.
    func testWoEineVorschauStehtLaesstSichDieUhrWechseln() throws {
        for pfad in ["Sources/TC002Ansichten/SendenView.swift",
                     "Sources/TC002iOS/SendeniOS.swift"] {
            let quelle = try ohneKommentare(pfad)
            XCTAssertTrue(quelle.contains("Uhrenpunkte(zustand: zustand)"),
                          "\(pfad): keine Punktreihe unter der Vorschau.")
            XCTAssertTrue(quelle.contains("Uhrenblaetterer(zustand: zustand)"),
                          "\(pfad): über der Vorschau lässt sich nicht blättern.")
        }
    }

    /// Jede Uhr einzeln wählbar, auf jeder Oberfläche: Beide gehen über
    /// `zielUmschalten`, wo die Regel steht, dass die Menge nie leer wird.
    func testJedeOberflaecheKannJedeUhrEinzelnWaehlen() throws {
        for pfad in ["Sources/TC002Ansichten/ZielauswahlView.swift",
                     "Sources/TC002iOS/SendeniOS.swift"] {
            let quelle = try ohneKommentare(pfad)
            XCTAssertTrue(quelle.contains("zielUmschalten("),
                          "\(pfad): wählt Ziele nicht einzeln.")
        }
    }

    /// Der Zweierschalter ist weg — und darf nicht zurückkommen: Er war eine
    /// zweite Wahrheit neben der Zielmenge.
    func testDenZweierschalterGibtEsNichtMehr() throws {
        for pfad in swiftDateien(unter: "Sources/TC002Ansichten")
            + swiftDateien(unter: "Sources/TC002iOS")
            + swiftDateien(unter: "Sources/TC002Modell") {
            XCTAssertFalse(try ohneKommentare(pfad).contains("anMehrereUhren"),
                           "\(pfad) kennt wieder „an alle Uhren“ als eigenen Schalter.")
        }
    }

    /// Keine leere Zielmenge aus der Oberfläche: Sie hätte zwei Bedeutungen —
    /// diese App liest sie als „die angesehene Uhr“, Werkzeug und Kurzbefehle
    /// als alle (`Einstellungen.ziele`).
    func testKeineAnsichtSchreibtEineLeereZielmenge() throws {
        for pfad in swiftDateien(unter: "Sources/TC002Ansichten")
            + swiftDateien(unter: "Sources/TC002iOS") {
            let quelle = try ohneKommentare(pfad)
            XCTAssertFalse(quelle.contains("zielIDs = []"),
                           "\(pfad) schreibt eine leere Zielmenge — die liest das Werkzeug als „alle Uhren“.")
        }
    }
}
