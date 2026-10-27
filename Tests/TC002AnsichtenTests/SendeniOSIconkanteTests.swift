import XCTest

/// Das Telefon merkt zur Icon-Nummer die Kante, wie der Mac: Der gemeinsame
/// Sendeweg liest beide aus der Ablage, und eine stehengebliebene Kante 16
/// ließe ein später gewähltes 8×8 beim Senden ausfallen.
final class SendeniOSIconkanteTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    func testTelefonSchreibtDieKanteMitDerNummer() throws {
        let text = try String(contentsOf: Self.wurzel.appendingPathComponent("Sources/TC002iOS/SendeniOS.swift"),
                              encoding: .utf8)
        XCTAssertTrue(text.contains(#"@AppStorage("senden.iconkante")"#))
        XCTAssertTrue(text.contains("iconKanteGemerkt = neu?.kante ?? 8"), "die Kante wird nicht mit der Wahl geschrieben")
        XCTAssertTrue(text.contains("kante: iconKanteGemerkt"), "das Nachschlagen beachtet die Kante nicht")
    }
}
