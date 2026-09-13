import XCTest

/// Der Formatinspektor und das Eingabefeld der Sendeansicht — beides aus der
/// iPad-Rueckmeldung vom 13.09.2026 (S1, S2, S3).
///
/// Wie in `MindestmasseTests` und `PlattformwegeTests` wird hier der Quelltext
/// gelesen, nicht der Uebersetzer befragt: Ein Farbwaehler in einer eigenen
/// Zeile uebersetzt genauso anstandslos wie einer in der Stil-Zeile, und ein
/// Eingabefeld ohne Rahmen ebenfalls. Der Uebersetzer hat zu diesen drei Fragen
/// nichts zu sagen.
///
/// Das iPhone (`SendeniOS`) ist absichtlich nicht mitgeaendert: Es hat weder
/// eine Stil-Zeile — Fett, Grossbuchstaben und Farbe liegen dort nebeneinander
/// in der schiebbaren Formatpille — noch ein rahmenloses Feld. Nur der Rahmen
/// wird hier auch fuers Telefon festgehalten, weil er dort der Grund ist,
/// warum S2 das iPad traf und nicht beide.
final class SendefeldTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // TC002AnsichtenTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // Repo

    /// Quelltext ohne Kommentare — sonst zaehlte jeder Satz mit, der das
    /// Gemeinte bloss erwaehnt, und die Kommentare in `SendenView` erwaehnen
    /// sowohl die Farbe als auch `.roundedBorder`.
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

    /// S2/S3: Beide Zweige des `ViewThatFits` zeigen dasselbe Feld. Stuende
    /// `TextField("Text", …)` zweimal da, koennten Rahmen und Schriftgroesse
    /// auseinanderlaufen, ohne dass es jemandem auffiele — je nach Fensterbreite
    /// saehe man mal das eine, mal das andere.
    func testDasEingabefeldStehtNurEinmalImQuelltext() throws {
        let text = try quelltext("Sources/TC002Ansichten/SendenView.swift")
        let treffer = text.components(separatedBy: #"TextField("Text", text: $text)"#).count - 1
        XCTAssertEqual(treffer, 1,
                       "das Eingabefeld ist wieder mehrfach geschrieben — Rahmen und Größe laufen auseinander")
    }

    /// S3: Das Feld traegt eine ausdrueckliche Groesse. Ohne sie bekaeme es die
    /// Systemvorgabe — am Mac 13 Punkt, am iPad 17.
    func testDasEingabefeldTraegtEineEigeneSchriftgroesse() throws {
        let text = try quelltext("Sources/TC002Ansichten/SendenView.swift")
        guard let feld = block(nach: "private var textFeld: some View", in: text) else {
            return XCTFail("das Eingabefeld steht nicht mehr in `textFeld`")
        }
        XCTAssertTrue(feld.contains(".font(.title2)"),
                      "das Eingabefeld ist wieder auf die Systemgröße zurückgefallen")
    }

    /// S2, zweite Fassung: Der Rahmen gilt **beiden** Schreibtischen.
    ///
    /// Bis 13.09.2026 stand er hinter `#if os(macOS)` — die Annahme war, die
    /// Mac-Vorgabe zeichne ohnehin einen. Am abgenommenen Bildschirmfoto war
    /// zu sehen, dass sie es in dieser Fläche nicht tut: Das Feld stand dort
    /// so unsichtbar wie am iPad. Seither ein Aufruf für beide
    /// (`Eingabefeld.swift`).
    ///
    /// Geprüft wird darum beides — dass die Fassung da ist, und dass sie in
    /// **keinem** Plattformzweig steht. Der zweite Teil ist der eigentliche:
    /// Ein Zweig übersetzt auf beiden Geräten und fällt auf dem falschen
    /// stumm aus.
    func testDerRahmenGiltFuerBeideSchreibtische() throws {
        let roh = try String(contentsOf: Self.wurzel
            .appendingPathComponent("Sources/TC002Ansichten/SendenView.swift"), encoding: .utf8)
        var nurEinZweig = false
        var treffer: [Bool] = []
        for zeile in roh.split(separator: "\n", omittingEmptySubsequences: false) {
            let nackt = zeile.trimmingCharacters(in: .whitespaces)
            if nackt.hasPrefix("#if ") { nurEinZweig = true; continue }
            if nackt == "#else" { continue }
            if nackt == "#endif" { nurEinZweig = false; continue }
            let ohneKommentar: String
            if let strich = zeile.range(of: "//") {
                ohneKommentar = String(zeile[zeile.startIndex..<strich.lowerBound])
            } else {
                ohneKommentar = String(zeile)
            }
            if ohneKommentar.contains(".eingabefeld()") { treffer.append(nurEinZweig) }
        }
        XCTAssertEqual(treffer.count, 2,
                       ".eingabefeld() kommt in SendenView.swift nicht genau zweimal vor "
                       + "(Meldungsfeld und Dauer) — eines der beiden steht wieder ohne Fassung da")
        XCTAssertFalse(treffer.contains(true),
                       "die Fassung steht wieder in einem Plattformzweig — sie gilt beiden Schreibtischen")
    }

    /// Warum S2 nur das iPad traf: Das Telefon setzt seinen Rahmen selbst.
    /// Bleibt das so, bleibt auch die Begruendung oben wahr.
    func testDasTelefonHatSeinenRahmenSchon() throws {
        let text = try quelltext("Sources/TC002iOS/SendeniOS.swift")
        guard let eingabe = block(nach: "private var eingabe: some View", in: text) else {
            return XCTFail("das Eingabefeld des iPhones heißt nicht mehr `eingabe`")
        }
        XCTAssertTrue(eingabe.contains(".textFieldStyle(.roundedBorder)"),
                      "dem iPhone ist der Rahmen seines Eingabefelds abhanden gekommen")
    }
}
