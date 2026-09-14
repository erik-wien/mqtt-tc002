import XCTest
@testable import TC002Core

/// **Über MQTT ist das Präfix die Adresse.** Zwei Uhren mit demselben Präfix
/// sind für den Broker eine — aufgefallen am 14.09.2026 an zwei AWTRIX, die
/// beide auf `awtrix` hörten.
final class GeteiltePraefixeTests: XCTestCase {
    private func uhr(_ name: String, praefix: String, art: Betriebsart = .mqtt) -> Uhr {
        var u = Uhr(name: name, host: "10.0.0.1", betriebsart: art)
        u.praefix = praefix
        return u
    }

    func testZweiGleicheFallenAuf() {
        let uhren = [uhr("a", praefix: "awtrix"), uhr("b", praefix: "awtrix"),
                     uhr("c", praefix: "anders")]
        XCTAssertEqual(uhren.geteiltePraefixe(), ["awtrix"])
    }

    func testEinzelneStoerenNicht() {
        XCTAssertEqual([uhr("a", praefix: "eins"), uhr("b", praefix: "zwei")].geteiltePraefixe(), [])
    }

    /// **Im HTTP-Betrieb wird gar kein Thema gebildet** — dort ist ein
    /// geteiltes Präfix folgenlos und darf niemanden beunruhigen.
    func testUeberHttpZaehltEsNicht() {
        let uhren = [uhr("a", praefix: "awtrix", art: .http), uhr("b", praefix: "awtrix", art: .http)]
        XCTAssertEqual(uhren.geteiltePraefixe(), [])
    }

    /// Ein leeres Präfix heißt „noch nicht abgefragt", nicht „dasselbe wie die
    /// andere". Zwei frisch eingetragene Uhren sind keine Doppelgänger.
    func testLeereZaehlenNichtAlsGleich() {
        XCTAssertEqual([uhr("a", praefix: ""), uhr("b", praefix: "")].geteiltePraefixe(), [])
    }

    /// Gemischt: Nur die MQTT-Uhr zählt mit, die HTTP-Uhr daneben nicht.
    func testGemischterBetriebZaehltNurMqtt() {
        let uhren = [uhr("a", praefix: "awtrix"), uhr("b", praefix: "awtrix", art: .http)]
        XCTAssertEqual(uhren.geteiltePraefixe(), [])
    }
}

/// Die Uhrenliste ist nach Adresse geordnet — und zwar so, wie ein Mensch
/// Adressen liest.
final class UhrenordnungTests: XCTestCase {
    private func uhr(_ host: String) -> Uhr { Uhr(name: host, host: host) }

    /// **Ziffernbewusst.** Ohne `localizedStandardCompare` stuende `10.0.0.9`
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
