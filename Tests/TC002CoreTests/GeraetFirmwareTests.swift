import XCTest
@testable import TC002Core

/// Das Firmware-Update gegen die virtuelle Uhr auf `127.0.0.1`: hochladen, Fehler,
/// Neustart abwarten. Gegen eine echte Uhr gibt es keine neuere Fassung als 1.2.2;
/// die Antworten folgen der Herstellerdoku (`guides/updating`, `reference/http`).
final class GeraetFirmwareTests: XCTestCase {
    private var server: [Uhrenserver] = []

    override func tearDown() {
        server.forEach { $0.beenden() }
        server = []
        super.tearDown()
    }

    private func gestartet(_ z: NGUhrzustand = NGUhrzustand()) throws -> (Uhrenserver, Geraet) {
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port, zustand: z)
            do {
                try s.starten()
                server.append(s)
                return (s, Geraet(host: "127.0.0.1:\(port)"))
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    private func hochladen(_ g: Geraet, _ paket: Data, name: String = "awtrix-ng-tc002.awup") async throws -> Bool {
        try await g.firmwareHochladen(paket, dateiname: name) { _ in }
    }

    private func abgewiesen(_ g: Geraet, _ paket: Data, name: String = "awtrix-ng-tc002.awup") async -> Firmwarefehler? {
        do { _ = try await hochladen(g, paket, name: name); return nil } catch { return error as? Firmwarefehler }
    }

    // MARK: - Hochladen

    func testTC002NimmtEinNeueresPaketAn() async throws {
        let (s, g) = try gestartet()
        let letzter = Zaehler()
        let applying = try await g.firmwareHochladen(NGFirmware.paket(fassung: "1.3.0", fuellung: 300_000),
                                                    dateiname: "awtrix-ng-tc002.awup") { letzter.setze($0) }
        XCTAssertTrue(applying)
        XCTAssertEqual(letzter.wert, 1, accuracy: 0.0001)
        XCTAssertEqual(s.zustand.firmware.stand, "applying")
    }

    func testEinPaketUeberZweiMebibyteGehtDurch() async throws {
        let (_, g) = try gestartet()
        let gross = NGFirmware.paket(fassung: "1.3.0", fuellung: 3 << 20)
        let applying = try await hochladen(g, gross)
        XCTAssertTrue(applying)
    }

    func testESP32AntwortetNurOk() async throws {
        var z = NGUhrzustand()
        z.firmware.image = "firmware-awtrix-ng.bin"
        let (_, g) = try gestartet(z)
        let applying = try await hochladen(g, NGFirmware.paket(dateiname: "firmware-awtrix-ng.bin", fassung: "1.2.2"),
                                           name: "firmware-awtrix-ng.bin")
        XCTAssertFalse(applying)
    }

    func testNichtNeuer() async throws {
        let (_, g) = try gestartet()
        let a = await abgewiesen(g, NGFirmware.paket(fassung: "1.2.2"))
        let b = await abgewiesen(g, NGFirmware.paket(fassung: "1.1.0"))
        XCTAssertEqual(a, .nichtNeuer)
        XCTAssertEqual(b, .nichtNeuer)
    }

    func testBeschaedigtesPaket() async throws {
        let (_, g) = try gestartet()
        let f = await abgewiesen(g, Data("irgendwas".utf8))
        XCTAssertEqual(f, .paketBeschaedigt)
    }

    func testFalschesZiel() async throws {
        let (_, g) = try gestartet()
        let f = await abgewiesen(g, NGFirmware.paket(ziel: "anderes", fassung: "1.3.0"))
        XCTAssertEqual(f, .falschesZiel)
    }

    func testFalscherChip() async throws {
        var z = NGUhrzustand()
        z.firmware.image = "firmware-awtrix-ng.bin"
        let (_, g) = try gestartet(z)
        let f = await abgewiesen(g, Data("MZ-keine-Firmware".utf8), name: "firmware-awtrix-ng.bin")
        XCTAssertEqual(f, .falscherChip)
    }

    func testEinrichtungsmodus() async throws {
        var z = NGUhrzustand()
        z.firmware.einrichtungsmodus = true
        let (_, g) = try gestartet(z)
        let f = await abgewiesen(g, NGFirmware.paket(fassung: "1.3.0"))
        XCTAssertEqual(f, .einrichtungsmodus)
    }

    func testBelegt() async throws {
        var z = NGUhrzustand()
        z.firmware.belegt = true
        let (_, g) = try gestartet(z)
        let f = await abgewiesen(g, NGFirmware.paket(fassung: "1.3.0"))
        XCTAssertEqual(f, .updateBelegt)
    }

    func testSpeicherNenntDieFehlendenMegabyte() async throws {
        var z = NGUhrzustand()
        z.firmware.platz = 1000
        let (_, g) = try gestartet(z)
        let f = await abgewiesen(g, NGFirmware.paket(fassung: "1.3.0", fuellung: 1_100_000))
        guard case .speicherZuKlein(let angabe)? = f else { return XCTFail("\(String(describing: f))") }
        XCTAssertTrue(angabe.contains("MB"), angabe)
    }

    func testZuGrossFuerDieUhr() async throws {
        let (_, g) = try gestartet()
        let f = await abgewiesen(g, NGFirmware.paket(fassung: "1.3.0", fuellung: (8 << 20) + 10))
        XCTAssertEqual(f, .paketZuGross)
    }

    // MARK: - Neustart abwarten

    private func ohneWarten(_ g: Geraet, erwartet: String, fragen: Int = 10) throws -> Firmwareergebnis {
        try g.neustartAbwarten(erwartet: erwartet, zeit: Firmwarewartezeit(vorlauf: 0, takt: 0, fragen: fragen),
                               schlafen: { _ in })
    }

    func testErfolgNurWennDieNeueFassungAntwortet() async throws {
        let (s, g) = try gestartet()
        _ = try await hochladen(g, NGFirmware.paket(fassung: "1.3.0"))
        // Die alte Fassung antwortet noch einmal, dann fällt die Uhr aus; beides ist kein Erfolg.
        let ergebnis = try await Hintergrund.lauf { try self.ohneWarten(g, erwartet: "1.3.0") }
        XCTAssertEqual(ergebnis.fassung, "1.3.0")
        XCTAssertTrue(ergebnis.bestaetigungAusstehend)
        XCTAssertEqual(s.zustand.firmware.fassung, "1.3.0")
    }

    func testAlteFassungAlleinIstKeinErfolg() async throws {
        var z = NGUhrzustand()
        z.firmware.altAntworten = 100
        let (_, g) = try gestartet(z)
        _ = try await hochladen(g, NGFirmware.paket(fassung: "1.3.0"))
        do {
            _ = try await Hintergrund.lauf { try self.ohneWarten(g, erwartet: "1.3.0", fragen: 4) }
            XCTFail("sollte werfen")
        } catch { XCTAssertEqual(error as? Firmwarefehler, .fassungUnveraendert("1.2.2")) }
    }

    func testUhrDieNichtWiederKommt() async throws {
        var z = NGUhrzustand()
        z.firmware.ausfaelle = 1000
        let (_, g) = try gestartet(z)
        _ = try await hochladen(g, NGFirmware.paket(fassung: "1.3.0"))
        do {
            _ = try await Hintergrund.lauf { try self.ohneWarten(g, erwartet: "1.3.0", fragen: 5) }
            XCTFail("sollte werfen")
        } catch { XCTAssertEqual(error as? Firmwarefehler, .neustartAusgeblieben) }
    }

    func testNeueFassungStartetNicht() async throws {
        var z = NGUhrzustand()
        z.firmware.startScheitert = true
        let (_, g) = try gestartet(z)
        _ = try await hochladen(g, NGFirmware.paket(fassung: "1.3.0"))
        do {
            _ = try await Hintergrund.lauf { try self.ohneWarten(g, erwartet: "1.3.0") }
            XCTFail("sollte werfen")
        } catch {
            guard case .startFehlgeschlagen(let grund)? = error as? Firmwarefehler else { return XCTFail("\(error)") }
            XCTAssertFalse(grund.isEmpty)
        }
    }

    func testWartezeitenWerdenEingehalten() async throws {
        let (_, g) = try gestartet()
        _ = try await hochladen(g, NGFirmware.paket(fassung: "1.3.0"))
        let pausen = Pausen()
        _ = try await Hintergrund.lauf {
            try g.neustartAbwarten(erwartet: "1.3.0", zeit: Firmwarewartezeit(vorlauf: 15, takt: 3, fragen: 10),
                                   schlafen: { pausen.merke($0) })
        }
        XCTAssertEqual(pausen.liste.first, 15)
        XCTAssertTrue(pausen.liste.dropFirst().allSatisfy { $0 == 3 })
        XCTAssertGreaterThan(pausen.liste.count, 1)
    }

    func testGeraetezustandLiestUpdateAngaben() async throws {
        var z = NGUhrzustand()
        z.firmware.stand = "boot-pending"
        let (_, g) = try gestartet(z)
        let stand = try await Hintergrund.lauf { try g.geraetezustand() }
        XCTAssertEqual(stand.updateImage, "awtrix-ng-tc002.awup")
        XCTAssertEqual(stand.updatestand, "boot-pending")
    }
}

final class Pausen: @unchecked Sendable {
    private let sperre = NSLock()
    private var _liste: [TimeInterval] = []
    func merke(_ t: TimeInterval) { sperre.lock(); _liste.append(t); sperre.unlock() }
    var liste: [TimeInterval] { sperre.lock(); defer { sperre.unlock() }; return _liste }
}
