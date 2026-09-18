import XCTest
@testable import TC002Core

/// Die Uhrenliste ist nach Adresse geordnet — und zwar so, wie ein Mensch
/// Adressen liest.
final class UhrenordnungTests: XCTestCase {
    private func uhr(_ host: String) -> Uhr { Uhr(name: host, host: host) }

    /// Ziffernbewusst: Ohne `localizedStandardCompare` stuende `10.0.0.9`
    /// hinter `10.0.0.94`, weil „9" groesser ist als „94"[0].
    func testZiffernWerdenAlsZahlenVerglichen() {
        let sortiert = [uhr("10.0.0.96"), uhr("10.0.0.9"), uhr("10.0.0.94")]
            .nachAdresse().map(\.host)
        XCTAssertEqual(sortiert, ["10.0.0.9", "10.0.0.94", "10.0.0.96"])
    }

    func testNamenUndZahlenGemischt() {
        let sortiert = [uhr("uhr.local"), uhr("10.0.0.2"), uhr("127.0.0.1:8752")]
            .nachAdresse().map(\.host)
        XCTAssertEqual(sortiert, ["10.0.0.2", "127.0.0.1:8752", "uhr.local"])
    }
}
