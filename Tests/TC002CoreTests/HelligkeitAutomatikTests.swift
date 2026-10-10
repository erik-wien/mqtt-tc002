import XCTest
@testable import TC002Core

/// `autoBrightness` wirkt nur mit Lichtsensor (`capabilities.sensors.light`):
/// Fähigkeit lesen, Schreiben nur dort erlauben, und die virtuelle Uhr mit Sensor
/// über den echten HTTP-Weg auf `127.0.0.1` — bei eingeschalteter Automatik folgt
/// das Panel dem Sensor, nicht der gespeicherten Helligkeit (gemessen 10. Oktober 2026).
final class HelligkeitAutomatikTests: XCTestCase {
    private var server: Uhrenserver?

    override func tearDown() {
        server?.beenden()
        server = nil
        super.tearDown()
    }

    private func gestartet(sensor: Bool) throws -> (Uhrenserver, Anzeigen, Geraet) {
        var z = NGUhrzustand()
        z.lichtsensor = sensor
        z.einstellungen["autoBrightness"] = .bool(sensor)
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port, zustand: z)
            do {
                try s.starten()
                server = s
                let g = Geraet(host: "127.0.0.1:\(port)")
                return (s, Anzeigen(geraet: g), g)
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    // MARK: - Fähigkeit

    func testLichtsensorWirdGelesenUndFehltAlsNein() {
        func f(_ sensors: String) -> Geraetefaehigkeiten? {
            let json = "{\"effects\":[]" + sensors + "}"
            let objekt = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any]
            return objekt.flatMap { Geraetefaehigkeiten(antwort: $0) }
        }
        XCTAssertEqual(f(",\"sensors\":{\"light\":true}")?.lichtsensor, true)
        XCTAssertEqual(f(",\"sensors\":{\"light\":false}")?.lichtsensor, false)
        XCTAssertEqual(f("")?.lichtsensor, false)
        XCTAssertEqual(f(",\"sensors\":{\"light\":\"ja\"}")?.lichtsensor, false)
    }

    // MARK: - Regel im Kern

    func testAutoBrightnessWirktNurMitSensor() {
        let mit = Geraetefaehigkeiten(lichtsensor: true), ohne = Geraetefaehigkeiten()
        XCTAssertTrue(Geraeteeinstellung.autoBrightness.wirkt(faehigkeiten: mit))
        XCTAssertFalse(Geraeteeinstellung.autoBrightness.wirkt(faehigkeiten: ohne))
        XCTAssertFalse(Geraeteeinstellung.autoBrightness.wirkt(faehigkeiten: nil), "ohne Auskunft gilt: nein")
        for e in Geraeteeinstellung.allCases where e != .autoBrightness {
            XCTAssertTrue(e.wirkt(faehigkeiten: nil), e.rawValue)
        }
    }

    func testSchreibenNurMitSensor() throws {
        var a = Einstellungsaenderung()
        XCTAssertThrowsError(try a.setzen(.autoBrightness, .bool(true), faehigkeiten: Geraetefaehigkeiten())) {
            XCTAssertEqual($0 as? SteuerungsFehler, .wirkungslos("autoBrightness"))
        }
        XCTAssertThrowsError(try Geraeteeinstellungen().aenderung(schluessel: "autoBrightness", wert: "an"))
        try a.setzen(.autoBrightness, .bool(true), faehigkeiten: Geraetefaehigkeiten(lichtsensor: true))
        XCTAssertEqual(try a.json(), "{\"autoBrightness\":true}")
        let b = try Geraeteeinstellungen().aenderung(schluessel: "autoBrightness", wert: "aus",
                                                     faehigkeiten: Geraetefaehigkeiten(lichtsensor: true))
        XCTAssertEqual(try b.json(), "{\"autoBrightness\":false}")
    }

    func testSensorRegeltHelligkeit() throws {
        let an = try Geraeteeinstellungen(daten: Data("{\"autoBrightness\":true,\"brightness\":100}".utf8))
        let aus = try Geraeteeinstellungen(daten: Data("{\"autoBrightness\":false,\"brightness\":100}".utf8))
        let mit = Geraetefaehigkeiten(lichtsensor: true)
        XCTAssertTrue(an.sensorRegeltHelligkeit(faehigkeiten: mit))
        XCTAssertFalse(aus.sensorRegeltHelligkeit(faehigkeiten: mit))
        XCTAssertFalse(an.sensorRegeltHelligkeit(faehigkeiten: Geraetefaehigkeiten()),
                       "ohne Sensor ist der Schlüssel ohne Wirkung, auch wenn er an steht")
    }

    // MARK: - Virtuelle Uhr

    func testMitAutomatikFolgtDasPanelDemSensor() throws {
        let (s, uhr, g) = try gestartet(sensor: true)
        let f = try XCTUnwrap(try g.faehigkeiten())
        XCTAssertTrue(f.lichtsensor)
        try uhr.helligkeit(255, faehigkeiten: f)
        XCTAssertEqual(try g.einstellungen().ganzzahl(.brightness), 255, "gespeichert")
        XCTAssertEqual(try g.anzeigestand().helligkeit, 32, "das Panel bleibt beim Sensor")
        XCTAssertEqual(try g.geraetezustand().helligkeit, 32)

        try uhr.helligkeitAutomatik(false, faehigkeiten: f)
        XCTAssertEqual(try g.anzeigestand().helligkeit, 255, "ohne Automatik gilt der gespeicherte Wert")
        try uhr.helligkeitAutomatik(true, faehigkeiten: f)
        XCTAssertEqual(try g.anzeigestand().helligkeit, s.zustand.sensorHelligkeit)
        XCTAssertEqual(try g.einstellungen().ganzzahl(.brightness), 255)
    }

    func testOhneSensorMeldetDieUhrKeinenSensorUndLehntDieAutomatikAb() throws {
        let (s, uhr, g) = try gestartet(sensor: false)
        let f = try XCTUnwrap(try g.faehigkeiten())
        XCTAssertFalse(f.lichtsensor)
        XCTAssertThrowsError(try uhr.helligkeitAutomatik(true, faehigkeiten: f))
        XCTAssertEqual(s.zustand.einstellungen["autoBrightness"], .bool(false), "nichts ist hinausgegangen")
        try uhr.helligkeit(40, faehigkeiten: f)
        XCTAssertEqual(try g.anzeigestand().helligkeit, 40)
    }
}
