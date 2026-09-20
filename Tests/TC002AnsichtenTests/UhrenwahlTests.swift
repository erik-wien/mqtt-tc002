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

    /// **Kein Uhrenmenü in der Werkzeugleiste** — auf keiner der beiden
    /// Schreibtischansichten.
    ///
    /// In der Mitte der Leiste las es sich wie ein zweiter Fenstertitel, und
    /// macOS zieht alles, was hinter dem mittigen Eintrag kommt, in dieselbe
    /// Gruppe: Der Inspektorknopf sass dadurch neben der Mitte statt am Rand.
    /// Im Editor kam dazu, dass der Name dort nur die Slotleiste steuerte,
    /// während „Empfänger" daneben sagt, wohin gesendet wird.
    ///
    /// Der Name steht jetzt **unter der Vorschau**, die er benennt, und wandert
    /// beim Blättern mit. Gewechselt wird über die Punktreihe und über das
    /// Blättern selbst.
    ///
    /// Mutation: das Menü an `.principal` zurückschieben — baut, übersetzt,
    /// und der Inspektorknopf rutscht wieder in die Mitte.
    func testKeineSchreibtischansichtTraegtEinUhrenmenue() throws {
        for pfad in ["Sources/TC002Ansichten/SendenView.swift",
                     "Sources/TC002Ansichten/EditorBereichView.swift"] {
            let quelle = try ohneKommentare(pfad)
            XCTAssertFalse(quelle.contains("Uhrenmenue(zustand: zustand)"),
                           "\(pfad): der Uhrenname steht wieder in der Werkzeugleiste — dort "
                           + "liest er sich als zweiter Titel und schiebt den Inspektorknopf "
                           + "aus dem rechten Rand")
        }
        // Der Name steht **unter** dem Blätterer und nennt die angesehene Uhr,
        // nicht mehr in jeder Seite die ihre. Innen nahm er dem Bereich rund
        // 20 Punkte Höhe weg, und weil dessen Höhe am Seitenverhältnis hängt,
        // wurde der Rahmen um genau diese Punkte schmaler als die Spalte.
        let senden = try ohneKommentare("Sources/TC002Ansichten/SendenView.swift")
        XCTAssertTrue(senden.contains("Text(zustand.referenzUhr?.name ?? \"\")"),
                      "SendenView: die Vorschau ist nicht mehr beschriftet — dann steht nirgends, "
                      + "welche Uhr man gerade ansieht")
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
