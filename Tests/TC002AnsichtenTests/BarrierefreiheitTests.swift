import XCTest
@testable import TC002Ansichten

/// Barrierefreiheit, soweit sie sich ohne VoiceOver prüfen lässt (eingang#112).
final class BarrierefreiheitTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Relative Leuchtdichte nach WCAG 2.x.
    private func leuchtdichte(_ rgb: [Double]) -> Double {
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(rgb[0]) + 0.7152 * lin(rgb[1]) + 0.0722 * lin(rgb[2])
    }

    private func kontrast(_ a: [Double], _ b: [Double]) -> Double {
        let (x, y) = (leuchtdichte(a), leuchtdichte(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    func testWarntextHellErreichtAAAufWeissUndGruppengrau() {
        XCTAssertGreaterThanOrEqual(kontrast(Warnfarbe.textHellRGB, [1, 1, 1]), 4.5)
        // Gruppengrau der Formulare (systemGroupedBackground, hell ≈ F2F2F7).
        XCTAssertGreaterThanOrEqual(kontrast(Warnfarbe.textHellRGB, [0.949, 0.949, 0.969]), 4.5)
    }

    func testSymbolfarbenTragenEinWeissesZeichenMitDreiZuEins() {
        XCTAssertGreaterThanOrEqual(kontrast(Warnfarbe.symbolRGB, [1, 1, 1]), 3)
        XCTAssertGreaterThanOrEqual(kontrast(Warnfarbe.erfolgRGB, [1, 1, 1]), 3)
        XCTAssertGreaterThanOrEqual(kontrast(Warnfarbe.symbolRGB, [0, 0, 0]), 3)
    }

    /// Ein Knopf, dessen Beschriftung nur ein Symbol ist, braucht einen Namen
    /// für die Sprachausgabe (`accessibilityLabel`).
    func testSymbolknoepfeHabenEinenAccessibilityLabel() throws {
        var fehlende: [String] = []
        for ordner in ["Sources/TC002Ansichten", "Sources/TC002iOS"] {
            let url = Self.wurzel.appendingPathComponent(ordner)
            for datei in try FileManager.default.contentsOfDirectory(atPath: url.path)
            where datei.hasSuffix(".swift") {
                let text = try String(contentsOf: url.appendingPathComponent(datei), encoding: .utf8)
                let zeilen = text.split(separator: "\n", omittingEmptySubsequences: false)
                    .map { z -> String in
                        guard let r = z.range(of: "//") else { return String(z) }
                        return String(z[z.startIndex..<r.lowerBound])
                    }
                for (i, zeile) in zeilen.enumerated() where zeile.contains("label: {") {
                    let rest = (zeile.components(separatedBy: "label: {").last ?? "")
                        .trimmingCharacters(in: .whitespaces)
                    let naechste = zeilen.dropFirst(i + 1).first?
                        .trimmingCharacters(in: .whitespaces) ?? ""
                    let nurSymbol = rest.hasPrefix("Image(systemName")
                        || (rest.isEmpty && naechste.hasPrefix("Image(systemName"))
                    guard nurSymbol else { continue }
                    let fenster = zeilen[i..<min(i + 14, zeilen.count)].joined(separator: "\n")
                    if !fenster.contains("accessibilityLabel") {
                        fehlende.append("\(datei):\(i + 1)")
                    }
                }
            }
        }
        XCTAssertEqual(fehlende, [], "Symbolknöpfe ohne accessibilityLabel")
    }
}
