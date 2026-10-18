import XCTest
@testable import TC002Core

/// Die Fernbedienungs-Kurzbefehle auf dem echten HTTP-Weg gegen die virtuelle
/// Uhr (`127.0.0.1`): Was ein Kurzbefehl verlangt, muss genau so ankommen — und
/// was eine Uhr nie kann, muss mit einem Fehler zurückkommen, nicht still
/// verpuffen (`docs/funktionen-je-uhr.md`).
final class KurzbefehlsfernbedienungTests: XCTestCase {
    private var server: Uhrenserver?

    override func tearDown() {
        server?.beenden()
        server = nil
        super.tearDown()
    }

    private func gestartet(lichtsensor: Bool) throws -> (Uhrenserver, Anzeigen, Geraetefaehigkeiten) {
        var z = NGUhrzustand()
        z.lichtsensor = lichtsensor
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port, zustand: z)
            do {
                try s.starten()
                server = s
                let g = Geraet(host: "127.0.0.1:\(port)")
                return (s, Anzeigen(geraet: g), try XCTUnwrap(try g.faehigkeiten()))
            } catch let e as XCTSkip { throw e } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    // MARK: - Helligkeit

    func testProzentKommtAlsRohwertAn() throws {
        let (s, anzeigen, f) = try gestartet(lichtsensor: false)
        try Helligkeitswunsch(prozent: 50).anwenden(auf: anzeigen, faehigkeiten: f)
        XCTAssertEqual(s.zustand.einstellungen["brightness"]?.ganzzahl, 128)
    }

    /// Die Antwort an eine Uhr ohne Sensor ist ein Fehler, der sagt, woran es liegt.
    func testAutomatikOhneLichtsensorWirdAbgewiesen() throws {
        let (s, anzeigen, f) = try gestartet(lichtsensor: false)
        XCTAssertThrowsError(try Helligkeitswunsch(automatisch: true).anwenden(auf: anzeigen, faehigkeiten: f)) {
            XCTAssertEqual($0 as? SteuerungsFehler, .wirkungslos("autoBrightness"))
            XCTAssertNotNil(($0 as? LocalizedError)?.errorDescription)
        }
        XCTAssertNotEqual(s.zustand.einstellungen["autoBrightness"], .bool(true))
    }

    /// Ohne Auskunft der Uhr (keine Adresse, nie abgefragt) gilt dasselbe.
    func testAutomatikOhneAuskunftWirdAbgewiesen() throws {
        let (_, anzeigen, _) = try gestartet(lichtsensor: true)
        XCTAssertThrowsError(try Helligkeitswunsch(automatisch: true).anwenden(auf: anzeigen, faehigkeiten: nil))
    }

    func testAutomatikMitLichtsensorWirdGesetzt() throws {
        let (s, anzeigen, f) = try gestartet(lichtsensor: true)
        try Helligkeitswunsch(automatisch: true).anwenden(auf: anzeigen, faehigkeiten: f)
        XCTAssertEqual(s.zustand.einstellungen["autoBrightness"], .bool(true))
    }

    /// Erst die Automatik aus, dann der Wert: Sonst übergeht der Sensor ihn.
    func testWertMitAbgeschalteterAutomatik() throws {
        let (s, anzeigen, f) = try gestartet(lichtsensor: true)
        try Helligkeitswunsch(automatisch: true).anwenden(auf: anzeigen, faehigkeiten: f)
        try Helligkeitswunsch(prozent: 100, automatisch: false).anwenden(auf: anzeigen, faehigkeiten: f)
        XCTAssertEqual(s.zustand.einstellungen["autoBrightness"], .bool(false))
        XCTAssertEqual(s.zustand.einstellungen["brightness"]?.ganzzahl, 255)
    }

    // MARK: - Overlay

    func testUnbekanntesOverlayWirdAbgewiesen() throws {
        let (s, anzeigen, f) = try gestartet(lichtsensor: false)
        XCTAssertThrowsError(try anzeigen.overlay("hagel", faehigkeiten: f)) {
            XCTAssertEqual($0 as? SteuerungsFehler, .unbekannterName(feld: "overlay", wert: "hagel"))
        }
        XCTAssertNil(s.zustand.overlay)
        try anzeigen.overlay("RAIN", faehigkeiten: f)
        XCTAssertEqual(s.zustand.overlay, "rain", "die Schreibweise der Liste der Uhr gilt")
    }

    // MARK: - Moodlight

    func testMoodlightAusDemKurzbefehlKommtAnUndGehtWieder() throws {
        let (s, anzeigen, _) = try gestartet(lichtsensor: false)
        try anzeigen.moodlight(try Kurzbefehlswerte.moodlight(farbe: "#FF0000", kelvin: nil, prozent: 40))
        XCTAssertNotNil(s.zustand.moodlight)
        try anzeigen.moodlightAus()
        XCTAssertNil(s.zustand.moodlight)
    }
}
