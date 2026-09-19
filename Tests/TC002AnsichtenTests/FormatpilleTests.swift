import XCTest

/// Die schiebbare Formatpille des Telefons.
///
/// Drei Zusicherungen, die man nur am Geraet sieht und die der Uebersetzer
/// anstandslos durchwinkt:
///
/// - Die Reihenfolge ist nach Haeufigkeit geordnet. Was man am ehesten
///   aendert, steht links und ist ohne Schieben erreichbar.
/// - Die Schriftwahl traegt ein Zeichen mit ihrem Wert, wie das Groessenmenue
///   daneben — nicht den Namen als Wort in Akzentfarbe. Zwischen lauter
///   Symbolen las sich das Wort wie ein Verweis.
/// - Der rechte Rand blendet aus, statt abzuschneiden. Ein halb sichtbares
///   Element sieht aus, als waere der Inhalt zu breit geraten, nicht als
///   koenne man weiterrollen.
final class FormatpilleTests: XCTestCase {
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

    private func pille() throws -> String {
        let text = try quelltext("Sources/TC002iOS/SendeniOS.swift")
        guard let anfang = text.range(of: "private var formatleiste: some View"),
              let ende = text.range(of: "private var eingabe: some View") else {
            XCTFail("`formatleiste` oder `eingabe` gibt es im Quelltext nicht mehr")
            return ""
        }
        return String(text[anfang.lowerBound..<ende.lowerBound])
    }

    /// Icon, Schrift, Groesse, Fett, Grossbuchstaben, Farbe — dann die
    /// Ausrichtungen, Rand, Abstand, und ganz hinten, was ein Blatt oeffnet.
    func testDieReihenfolgeFolgtDerHaeufigkeit() throws {
        let pille = try pille()
        let erwartet = ["zeigeIcons = true", "Picker(\"Schriftart\"", "Picker(\"Größe\"",
                        "isOn: $fett", "isOn: $grossbuchstaben", "Farbkreis(",
                        "Picker(\"Waagrecht\"", "Picker(\"Senkrecht\"",
                        "Picker(\"Rand\"", "Picker(\"Abstand\"",
                        "zeigeFormat = true", "zeigeBilder = true"]
        var stellen: [Int] = []
        for marke in erwartet {
            guard let r = pille.range(of: marke) else {
                return XCTFail("„\(marke)“ steht nicht mehr in der Formatpille")
            }
            stellen.append(pille.distance(from: pille.startIndex, to: r.lowerBound))
        }
        XCTAssertEqual(stellen, stellen.sorted(),
                       "Die Formatpille steht nicht mehr in der Reihenfolge Icon, Schrift, Größe, "
                       + "Fett, Großbuchstaben, Farbe, waagrecht, senkrecht, Rand, Abstand, Format, "
                       + "Bild — die drei, die man am ehesten ändert, müssen ohne Schieben "
                       + "erreichbar bleiben")
    }

    /// Ein Zeichen und ein kurzer Wert, wie beim Groessenmenue daneben.
    func testDieSchriftwahlIstEinSymbolmenue() throws {
        let pille = try pille()
        XCTAssertTrue(pille.contains(#"Label { Text(schrift).font(.caption) } icon: { Image(systemName: "textformat") }"#),
                      "die Schriftwahl trägt wieder den Namen als blankes Wort — zwischen lauter "
                      + "Symbolen liest er sich wie ein Verweis")
        XCTAssertTrue(pille.contains(#"accessibilityLabel(Text(lok("Schriftart")) + Text(" ") + Text(schrift))"#),
                      "die Sprachausgabe nennt die Schrift nicht mehr beim Namen")
    }

    /// Der Rand blendet aus; das Zeichen daneben sagte dasselbe ein zweites
    /// Mal und ist deshalb weg.
    func testDerRechteRandBlendetAusStattAbzuschneiden() throws {
        let pille = try pille()
        XCTAssertTrue(pille.contains(".mask(randverlauf)"),
                      "die Pille endet wieder hart — das letzte Element sieht dann aus, als wäre "
                      + "es zu breit geraten")
        XCTAssertFalse(pille.contains("chevron.compact.right"),
                       "neben dem ausblendenden Rand steht wieder ein Pfeil — zwei Zeichen für "
                       + "dieselbe Aussage")
        let text = try quelltext("Sources/TC002iOS/SendeniOS.swift")
        XCTAssertTrue(text.contains("private var zeigtMehr: Bool"),
                      "niemand misst mehr, ob rechts noch etwas liegt — dann blendet der Rand "
                      + "auch am Ende aus und verspricht etwas, das nicht da ist")
    }
}
