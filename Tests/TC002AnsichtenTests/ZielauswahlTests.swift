import XCTest

/// Die Empfaengerwahl ist ein Blatt, und alle drei Sendeflaechen nehmen
/// dasselbe.
///
/// Am Telefon stand dafuer ein `Menu` mit einer Zeile je Uhr. Ein Menue
/// schliesst sich nach jedem Antippen — bei vier Uhren oeffnete man es viermal.
/// Der Auftraggeber: *„Bei der Empängerauswahl nicht nach jeder Auswahl gleich
/// schließen sondern ein schließen (x) hinzufügen."* Ein `Blatt` bleibt stehen,
/// bis man es schliesst, und traegt den Weg hinaus selbst.
///
/// Gleicher Weg wie `SlotmenueTests` und `KnopfstilTests`: nachsehen im
/// Quelltext. Der Uebersetzer nimmt beide Fassungen an; sichtbar wird der
/// Unterschied erst am vierten Antippen.
final class ZielauswahlTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

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

    /// Mutation: in einer der drei Ansichten die Uhrenliste wieder von Hand
    /// bauen — baut, uebersetzt, und dieselbe Wahl bedient sich an zwei Stellen
    /// verschieden.
    func testAlleDreiBenutzenDieselbeZielauswahl() throws {
        for datei in ["Sources/TC002iOS/SendeniOS.swift",
                      "Sources/TC002Ansichten/SendenView.swift",
                      "Sources/TC002Ansichten/EditorBereichView.swift"] {
            let text = try quelltext(datei)
            XCTAssertTrue(text.contains("ZielauswahlView(zustand: zustand"),
                          "\(datei) benutzt nicht mehr die gemeinsame Zielauswahl")
            XCTAssertFalse(text.contains("Section(\"Senden an\")"),
                           "\(datei) baut die Uhrenliste wieder selbst")
        }
    }

    /// Die Wahl steht in einem `Blatt`, nicht in einem `Menu`: Nur das Blatt
    /// bleibt beim Anhaken offen und hat einen eigenen Weg hinaus.
    func testDieWahlStehtInEinemBlattUndNichtInEinemMenue() throws {
        let text = try quelltext("Sources/TC002Ansichten/ZielauswahlView.swift")
        XCTAssertTrue(text.contains("Blatt(titel: lok(\"An welche Uhr senden?\")"),
                      "die Zielauswahl steht nicht mehr in einem Blatt — ohne es gibt es "
                      + "keinen Rahmen, der den Weg hinaus selbst mitbringt")
        XCTAssertTrue(text.contains("schliessen: { zeigeBlatt = false }"),
                      "das Blatt hat keinen Weg hinaus mehr")
        XCTAssertFalse(text.contains("Menu {"),
                       "die Zielauswahl ist wieder ein Menü — das schließt sich nach jedem "
                       + "Antippen, und eine Mehrfachauswahl braucht vier Anläufe")
    }
}
