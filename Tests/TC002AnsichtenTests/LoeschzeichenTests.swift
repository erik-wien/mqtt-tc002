import XCTest

/// Ein (x) an den Feldern, die man wirklich leert.
///
/// Nicht an allen: Ein Feld, dessen Inhalt man überschreibt statt wegzuwerfen
/// — die Brokeradresse, der Port —, braucht keines. Gemeint sind die, deren
/// Inhalt von Natur aus flüchtig ist: die Nachricht, die Suche, der Name und
/// die Nummer eines Bildes, das man gerade sichert.
///
/// Geprüft wird am Quelltext wie in `KnopfstilTests`. Dass das Zeichen
/// erscheint, sieht man am Gerät; dass es an diesen Feldern überhaupt
/// angefordert wird, steht hier.
final class LoeschzeichenTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Datei, Bindung und wozu das Feld gehört — der letzte Teil steht nur in
    /// der Fehlermeldung, damit die sagt, welche Stelle gemeint ist.
    private static let felder: [(datei: String, bindung: String, wo: String)] = [
        ("Sources/TC002Ansichten/SendenView.swift", "$text", "die Nachricht am Schreibtisch"),
        ("Sources/TC002iOS/SendeniOS.swift", "$text", "die Nachricht am Telefon"),
        ("Sources/TC002Ansichten/IconAuswahlView.swift", "$suche", "Suchen im Icon-Blatt"),
        ("Sources/TC002Ansichten/EditorBereichView.swift", "$name", "„Dieses Bild“ → Name"),
        ("Sources/TC002Ansichten/EditorBereichView.swift", "$nummer", "„Dieses Bild“ → Nummer"),
        ("Sources/TC002Ansichten/EditorBereichView.swift", "$suche", "„Vorhandene“ → Suchen"),
        ("Sources/TC002Ansichten/EditorBereichView.swift", "$lametricNummer", "„Hinzufügen“ → LaMetric-Nummer"),
    ]

    private func ohneKommentare(_ pfad: String) throws -> String {
        let url = Self.wurzel.appendingPathComponent(pfad)
        let roh = try String(contentsOf: url, encoding: .utf8)
        return roh.split(separator: "\n", omittingEmptySubsequences: false).map { z in
            guard let strich = z.range(of: "//") else { return String(z) }
            return String(z[z.startIndex..<strich.lowerBound])
        }.joined(separator: "\n")
    }

    func testDieFluechtigenFelderTragenEinLoeschzeichen() throws {
        for feld in Self.felder {
            let quelle = try ohneKommentare(feld.datei)
            // Ohne die schliessende Klammer: Das Meldungsfeld am Mac reicht
            // zusaetzlich `senden:` und `laeuft:` herein (das ⏎ am rechten
            // Rand). Zugesichert ist die Bindung, an der das Loeschzeichen
            // haengt, nicht die Zahl der Argumente.
            XCTAssertTrue(quelle.contains("eingabefeld(loeschbar: \(feld.bindung)"),
                          "\(feld.wo) (\(feld.bindung)) hat kein Löschzeichen.")
        }
    }

    /// Das gewählte Icon wird nicht geleert, sondern abgewählt — ein eigener
    /// Knopf, kein Textfeld. Ohne Beschriftung: Er steht unmittelbar neben
    /// dem Namen des gewählten Icons, und was er tut, sagt dort das Zeichen.
    /// Gesucht wird der Knopf in der Zeile, nicht die „ohne"-Kachel im Blatt
    /// — die verlangt den Umweg übers Blatt, genau den soll das Zeichen
    /// ersparen. Deshalb hängt die Prüfung am Zeichen und nicht bloß an
    /// `gewaehltesIcon = nil`.
    func testDasGewaehlteIconLaesstSichAbwaehlen() throws {
        let quelle = try ohneKommentare("Sources/TC002Ansichten/IconAuswahlView.swift")
        XCTAssertTrue(quelle.contains("Button { gewaehltesIcon = nil } label:"),
                      "In der Zeile steht kein Knopf, der die Iconwahl zurücknimmt.")
        XCTAssertTrue(quelle.contains("xmark.circle.fill"),
                      "Das Abwählen trägt nicht das Löschzeichen.")
        XCTAssertFalse(quelle.contains("Label(lok(\"Icon entfernen\")"),
                       "Das Abwählen trägt wieder eine Beschriftung — gewollt ist das bloße Zeichen.")
    }

    /// Der Baustein selbst: Ohne Bindung bleibt alles wie bisher. Die
    /// neunzehn vorhandenen Aufrufe sollen sich nicht rühren müssen.
    func testDieFassungOhneBindungBleibtBestehen() throws {
        let quelle = try ohneKommentare("Sources/TC002Ansichten/Eingabefeld.swift")
        XCTAssertTrue(quelle.contains("func eingabefeld() -> some View"),
                      "Die Fassung ohne Löschzeichen gibt es nicht mehr.")
        XCTAssertTrue(quelle.contains("func eingabefeld(loeschbar"),
                      "Die Fassung mit Löschzeichen fehlt.")
    }
}
