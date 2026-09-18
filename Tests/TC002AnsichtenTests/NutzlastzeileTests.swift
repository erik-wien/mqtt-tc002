import XCTest
@testable import TC002Ansichten

/// Die Nutzlastzeile gibt es einmal, für „Senden" und für den Editor.
///
/// Zwei Fassungen nebeneinander wären zwei Schwellen, die auseinanderlaufen —
/// und genau das war der Anlass: Im Editor fehlte die Warnung ganz, obwohl ein
/// 16×52-Laufbild mit vielen Einzelbildern schneller groß wird als ein langer
/// Text. Der Übersetzer sagt dazu nichts, eine zweite Fassung übersetzt
/// anstandslos; deshalb derselbe Weg wie in `PlattformwegeTests`: nachsehen im
/// Quelltext.
final class NutzlastzeileTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Quelltext ohne Kommentare — sonst zählte jeder Satz mit, der die
    /// Schwelle bloß erwähnt, und diese Dateien erwähnen sie.
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

    /// Unter der ersten vollen Kilobyte steht keine Zahl — eine Nachkommastelle
    /// wäre genauer, als die Sache ist. Darüber wird abgerundet.
    ///
    /// In Tests gibt es kein Bündel, `lok` fällt auf den deutschen Wortlaut
    /// zurück; genau der steht hier.
    func testDieGroessenangabeSpringtBeiDerErstenVollenKilobyte() {
        XCTAssertEqual(Nutzlastzeile.groesse(0), "unter 1 KB Nutzlast")
        XCTAssertEqual(Nutzlastzeile.groesse(1023), "unter 1 KB Nutzlast")
        XCTAssertEqual(Nutzlastzeile.groesse(1024), "rund 1 KB Nutzlast")
        // Das gemessene Lauf-GIF aus der Gerätereferenz.
        XCTAssertEqual(Nutzlastzeile.groesse(23_000), "rund 22 KB Nutzlast")
    }

    /// Gewarnt wird erst über der Schwelle, nicht schon darauf — und das
    /// gemessene Lauf-GIF von 23 KB löst noch nichts aus.
    func testGewarntWirdErstUeberDerSchwelle() {
        XCTAssertEqual(Nutzlastzeile.heikelAb, 60_000)
        XCTAssertFalse(23_000 > Nutzlastzeile.heikelAb,
                       "ein gewöhnliches Lauf-GIF von 23 KB darf nicht warnen — die Uhr nimmt es")
    }

    /// B6. Beide Stellen benutzen dieselbe Zeile, und keine von beiden
    /// kennt die Schwelle selbst. Stünde die Zahl noch einmal in einer Ansicht,
    /// wäre es wieder eine zweite Fassung daneben.
    func testBeideStellenBenutzenDieselbeZeile() throws {
        for datei in ["Sources/TC002Ansichten/SendenView.swift",
                      "Sources/TC002Ansichten/EditorBereichView.swift"] {
            let text = try quelltext(datei)
            XCTAssertTrue(text.contains("Nutzlastzeile("),
                          "\(datei) zeigt die Nutzlast nicht mehr über die gemeinsame Zeile")
            XCTAssertFalse(text.contains("60_000"),
                           "\(datei) trägt die Schwelle wieder selbst — dann laufen zwei auseinander")
            XCTAssertFalse(text.contains("auffällig große Nutzlast"),
                           "\(datei) baut die Warnung wieder selbst statt sie zu benutzen")
        }
    }
}
