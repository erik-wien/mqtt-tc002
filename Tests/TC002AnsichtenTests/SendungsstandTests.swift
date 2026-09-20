import XCTest
@testable import TC002Ansichten

/// Die Oberfläche nennt keine Nutzlastgrößen mehr.
///
/// Der Auftraggeber: *„Die einzige Engstelle ist die Uhr selbst. Ich finde wir
/// quaken da auch in der UI viel zu viel herum. Wenn dann gib an, zu wie viel %
/// das RAM der Uhr ausgelastet ist. Aber iCloud und App ist das komplett
/// egal."*
///
/// Genau dieser Prozentsatz ist nicht zu haben, wo er zählte: Die
/// Werksfirmware gibt über sich selbst weder freien Speicher noch eine Grenze
/// heraus (`docs/tc002-protokoll.md`, §5.1 bis §5.4); eine AWTRIX NG meldet
/// zwar `freeHeapBytes` (`docs/awtrix-ng-protokoll.md`, §7.1), nimmt aber kein
/// gemaltes 52×16-Bild an. Übrig bleibt die Zahl der Einzelbilder — eine
/// Aussage über die Meldung, nicht über die Leitung.
///
/// Geprüft wird am Quelltext, wie in `PlattformwegeTests`: Eine
/// wiedereingeführte Kilobyteangabe übersetzt anstandslos.
final class SendungsstandTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Quelltext ohne Kommentare — sonst zählte jeder Satz mit, der die
    /// gestrichene Angabe bloß erwähnt, und diese Dateien erwähnen sie.
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

    /// Die Zahl der Einzelbilder steht im Inspektor, nicht unter dem Bild.
    ///
    /// Erik: *„die info über die anzahl der frames gehört in den
    /// inspector/animation."* Unter der Leinwand zählte sie, was die
    /// Bildleiste daneben ohnehin zeigt; am Sendezeichen stand sie in einem
    /// Einblendtext, den es am Finger nicht gibt.
    func testDieZahlDerEinzelbilderStehtImInspektor() throws {
        let editor = try quelltext("Sources/TC002Ansichten/EditorBereichView.swift")
        XCTAssertTrue(editor.contains("Section(\"Einzelbilder\")")
                      && editor.contains("Text(verbatim: \"\\(leinwand.bilder.count)\")"),
                      "die Anzahl steht nicht mehr in der Karte „Einzelbilder“ des Inspektors")
        let senden = try quelltext("Sources/TC002Ansichten/SendenView.swift")
        XCTAssertTrue(senden.contains("LabeledContent(\"Einzelbilder\")"),
                      "im Abschnitt „Laufschrift“ steht nicht mehr, wie viele Einzelbilder "
                      + "daraus werden")
        XCTAssertFalse(senden.contains("auskunft:"),
                       "die Zahl steht wieder im Einblendtext am Sendezeichen — am Finger gibt "
                       + "es dort kein Verweilen")
    }

    /// Keine Kilobyte, keine Schwelle, keine Warnung — in keiner der drei
    /// Sendeansichten.
    ///
    /// Mutation: die Kilobytezahl in einer davon wieder anhängen — baut,
    /// übersetzt, und die Oberfläche beunruhigt wieder mit einer Zahl, zu der
    /// es keine Bezugsgröße gibt.
    func testKeineAnsichtNenntEineNutzlastgroesse() throws {
        for datei in ["Sources/TC002Ansichten/SendenView.swift",
                      "Sources/TC002Ansichten/EditorBereichView.swift",
                      "Sources/TC002iOS/SendeniOS.swift"] {
            let text = try quelltext(datei)
            for verboten in ["KB", "Nutzlast", "60_000", "utf8.count"] {
                XCTAssertFalse(text.contains(verboten),
                               "\(datei) nennt wieder eine Nutzlastgröße („\(verboten)“)")
            }
        }
    }

}
