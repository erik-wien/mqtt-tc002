import XCTest

/// Der Nachbau des Systemfelds gibt es, weil das Systemfeld bei weißer
/// Farbe einen weißen Fleck auf hellem Grund zeigt und dort nicht mehr als
/// Bedienelement zu erkennen ist. Einen offiziellen Weg, das zu ändern, gibt
/// es nicht: `ColorPicker` hat kein Gegenstück zu `buttonStyle` oder
/// `pickerStyle` (im SDK nachgesehen), und sein `label` steht *neben* dem
/// Feld statt darin.
///
/// Geprüft wird am Quelltext wie in `KnopfstilTests`.
final class FarbkreisTests: XCTestCase {
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

    /// Die Systempalette bleibt der Auslöser: Gezeichnet wird nur das
    /// Gesicht; wer den Kreis anklickt, trifft einen `ColorPicker`.
    func testDerKreisLoestDieSystempaletteAus() throws {
        let quelle = try ohneKommentare("Sources/TC002Ansichten/Farbkreis.swift")
        XCTAssertTrue(quelle.contains("ColorPicker(\"Farbe\", selection: $farbe"),
                      "Der Farbkreis öffnet nicht mehr die Systempalette.")
        XCTAssertTrue(quelle.contains("AngularGradient"),
                      "Der Regenbogenring fehlt — dann ist der Kreis bei Weiß wieder unsichtbar.")
    }

    /// Wo `labelsHidden()` an einem `ColorPicker` steht, bleibt nur das Feld
    /// übrig — bei Weiß nicht mehr als Bedienelement zu erkennen. Ausgenommen
    /// ist der Farbkreis selbst, dort ist das Verstecken der Sinn der Sache.
    func testKeinNacktesSystemfarbfeldInDenSendeansichten() throws {
        for pfad in swiftDateien(unter: "Sources/TC002Ansichten")
            + swiftDateien(unter: "Sources/TC002iOS") {
            guard !pfad.hasSuffix("Farbkreis.swift") else { continue }
            let zeilen = try ohneKommentare(pfad).split(separator: "\n", omittingEmptySubsequences: false)
            for (i, z) in zeilen.enumerated() where z.contains("ColorPicker(") {
                let umgebung = zeilen[i..<min(i + 4, zeilen.count)].joined(separator: "\n")
                XCTAssertFalse(umgebung.contains("labelsHidden()"),
                               "\(pfad):\(i + 1) zeigt ein blankes Systemfarbfeld — bei Weiß unsichtbar. "
                               + "Dafür gibt es `Farbkreis`.")
            }
        }
    }
}
