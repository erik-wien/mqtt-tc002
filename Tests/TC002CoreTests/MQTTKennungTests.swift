import XCTest
@testable import TC002Core

/// Die Uhr-UUID kommt über iCloud auf jedes Gerät. Zwei Installationen mit
/// derselben Uhr brauchen verschiedene Client-Kennungen, sonst trennt der
/// Broker die eine, sobald die andere verbindet.
final class MQTTKennungTests: XCTestCase {
    private func installation() throws -> UserDefaults {
        try XCTUnwrap(UserDefaults(suiteName: "kennung-\(UUID().uuidString)"))
    }

    func testZweiInstallationenBekommenFuerDieselbeUhrVerschiedeneKennungen() throws {
        let uhr = UUID()
        let mac = try installation(), ipad = try installation()
        for rolle in [MQTTKennung.Rolle.senden, .horchen, .kurzbefehl] {
            XCTAssertNotEqual(MQTTKennung.fuer(rolle, uhr: uhr, ablage: mac),
                              MQTTKennung.fuer(rolle, uhr: uhr, ablage: ipad), "\(rolle)")
        }
        XCTAssertNotEqual(MQTTKennung.pruefung(ablage: mac), MQTTKennung.pruefung(ablage: ipad))
    }

    func testDieselbeInstallationLiefertStabilDieselbeKennung() throws {
        let uhr = UUID()
        let mac = try installation()
        let erste = MQTTKennung.fuer(.horchen, uhr: uhr, ablage: mac)
        XCTAssertEqual(MQTTKennung.fuer(.horchen, uhr: uhr, ablage: mac), erste)
        XCTAssertEqual(MQTTKennung.geraet(mac), MQTTKennung.geraet(mac))
    }

    /// Senden, Mitlesen und Kurzbefehl derselben Installation und Uhr laufen
    /// gleichzeitig; verschiedene Uhren ebenso.
    func testRollenUndUhrenUnterscheidenSich() throws {
        let mac = try installation()
        let a = UUID(), b = UUID()
        let alle = [MQTTKennung.Rolle.senden, .horchen, .kurzbefehl].flatMap { r in
            [a, b].map { MQTTKennung.fuer(r, uhr: $0, ablage: mac) }
        }
        XCTAssertEqual(Set(alle).count, alle.count)
    }

    /// 23 Zeichen darf jeder Broker verlangen — auch mit dem längsten Zusatz,
    /// den der Kern anhängt.
    func testKennungenBleibenInDen23Zeichen() throws {
        let mac = try installation()
        let zusaetze = ["", "-lesen", "-antwort"]
        for rolle in [MQTTKennung.Rolle.senden, .horchen, .kurzbefehl] {
            for zusatz in zusaetze {
                let k = MQTTKennung.fuer(rolle, uhr: UUID(), ablage: mac) + zusatz
                XCTAssertLessThanOrEqual(k.count, MQTTKennung.hoechstlaenge, k)
            }
        }
        XCTAssertLessThanOrEqual(MQTTKennung.pruefung(ablage: mac).count, MQTTKennung.hoechstlaenge)
    }

    /// Die App baut ihre Kennungen nicht mehr aus der Uhr-UUID allein.
    func testAppUndKurzbefehleNutzenDieGeraetekennung() throws {
        let wurzel = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for pfad in ["Sources/TC002Modell/AppZustand.swift", "Sources/TC002iOS/Kurzbefehle.swift",
                     "Sources/TC002iOS/KurzbefehleBenachrichtigung.swift"] {
            let q = try String(contentsOf: wurzel.appendingPathComponent(pfad), encoding: .utf8)
            XCTAssertFalse(q.contains(#"clientID = "tc002-app"#), pfad)
            XCTAssertFalse(q.contains(#""tc002-app-" +"#), pfad)
            XCTAssertFalse(q.contains(#""tc002-kurz-" +"#), pfad)
            XCTAssertTrue(q.contains("MQTTKennung."), pfad)
        }
    }

    /// Keine Zeichen, die MQTTPaket.pruefen ablehnt, und nicht leer.
    func testKennungenSindZulaessig() throws {
        let mac = try installation()
        let k = MQTTKennung.fuer(.senden, uhr: UUID(), ablage: mac)
        XCTAssertNoThrow(try MQTTPaket.pruefen([k]))
    }
}
