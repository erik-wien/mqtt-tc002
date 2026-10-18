import Foundation
import XCTest
import TC002Core
@testable import TC002Modell

/// Doppelgänger für GitHub im Modelltest: Freigabe und Paket kommen aus dem Speicher.
final class GitHubAttrappe: URLProtocol {
    nonisolated(unsafe) static var freigabe = Data()
    nonisolated(unsafe) static var paket = Data()
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var gesehen: [URL] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }
    override func startLoading() {
        let url = request.url!
        Self.gesehen.append(url)
        let daten = url.host == "api.github.com" ? Self.freigabe : Self.paket
        let a = HTTPURLResponse(url: url, statusCode: Self.status, httpVersion: "HTTP/1.1",
                                headerFields: ["Content-Length": "\(daten.count)"])!
        client?.urlProtocol(self, didReceive: a, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: daten)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

/// Das ganze Firmware-Update gegen die virtuelle Uhr auf `127.0.0.1` und eine
/// GitHub-Attrappe: suchen, laden, hochladen, Neustart abwarten.
@MainActor
final class FirmwareupdateZustandTests: XCTestCase {
    private let d = UserDefaults.standard
    private let schluessel = ["uhren", "aktiveID", "bekannteAnzeigen", "zielIDs",
                              "brokerHost", "brokerPort", "benutzer", "protokollAn", "verlaufAn"]
    private var gesichert: [String: Any?] = [:]
    private var server: [Uhrenserver] = []

    override func setUp() {
        super.setUp()
        gesichert = Dictionary(uniqueKeysWithValues: schluessel.map { ($0, d.object(forKey: $0)) })
        GitHubAttrappe.gesehen = []
        GitHubAttrappe.status = 200
    }

    override func tearDown() {
        server.forEach { $0.beenden() }
        server = []
        for schl in schluessel {
            if let wert = gesichert[schl] ?? nil { d.set(wert, forKey: schl) } else { d.removeObject(forKey: schl) }
        }
        super.tearDown()
    }

    private func uhr(_ stand: NGUhrzustand = NGUhrzustand(), host: String? = nil) throws -> (AppZustand, Uhr, Uhrenserver) {
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port, zustand: stand)
            do {
                try s.starten()
                server.append(s)
                let uhr = Uhr(name: "Küche", host: host ?? "127.0.0.1:\(port)", praefix: "", betriebsart: .http)
                d.set(try JSONEncoder().encode([uhr]), forKey: "uhren")
                d.set(uhr.id.uuidString, forKey: "aktiveID")
                d.set(try JSONEncoder().encode(Set([uhr.id])), forKey: "zielIDs")
                let z = AppZustand(schluesselbund: Schluesselbunddoppelgaenger())
                let k = URLSessionConfiguration.ephemeral
                k.protocolClasses = [GitHubAttrappe.self]
                z.firmwarequelle = Firmwarequelle(sitzung: URLSession(configuration: k))
                z.firmwarewartezeit = Firmwarewartezeit(vorlauf: 0, takt: 0.01, fragen: 20)
                return (z, uhr, s)
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    /// Ein Release `v1.3.0` mit einem Paket für `awtrix-ng-tc002.awup`.
    private func release(paket: Data, tag: String = "v1.3.0", summe: String? = nil) {
        let name = "awtrix-ng-tc002.awup"
        let o: [String: Any] = [
            "tag_name": tag, "draft": false, "prerelease": false,
            "html_url": "https://github.com/Blueforcer/awtrix-ng/releases/tag/\(tag)",
            "assets": [["name": name, "size": paket.count, "state": "uploaded",
                        "digest": "sha256:" + (summe ?? Fingerabdruck.sha256(paket)),
                        "browser_download_url": "https://github.com/Blueforcer/awtrix-ng/releases/download/\(tag)/\(name)"]],
        ]
        GitHubAttrappe.freigabe = try! JSONSerialization.data(withJSONObject: o)
        GitHubAttrappe.paket = paket
    }

    func testSuchenFindetDasNeuerePaket() async throws {
        let (z, u, _) = try uhr()
        release(paket: NGFirmware.paket(fassung: "1.3.0"))
        await z.firmwareSuchen(fuer: u.id)
        guard case .verfuegbar(let p)? = z.firmwareablauf[u.id] else { return XCTFail("\(String(describing: z.firmwareablauf[u.id]))") }
        XCTAssertEqual(p.fassung, "1.3.0")
        XCTAssertEqual(p.dateiname, "awtrix-ng-tc002.awup")
        // Nur die Freigabe wurde gelesen, das Paket nicht.
        XCTAssertEqual(GitHubAttrappe.gesehen.map(\.host), ["api.github.com"])
    }

    func testSuchenMitGleicherFassungIstAktuell() async throws {
        let (z, u, _) = try uhr()
        release(paket: NGFirmware.paket(fassung: "1.2.2"), tag: "v1.2.2")
        await z.firmwareSuchen(fuer: u.id)
        XCTAssertEqual(z.firmwareablauf[u.id], .aktuell("1.2.2"))
    }

    func testAktualisierenBisDieNeueFassungAntwortet() async throws {
        let (z, u, s) = try uhr()
        release(paket: NGFirmware.paket(fassung: "1.3.0", fuellung: 100_000))
        await z.firmwareSuchen(fuer: u.id)
        await z.firmwareAktualisieren(fuer: u.id)
        guard case .fertig(let e)? = z.firmwareablauf[u.id] else { return XCTFail("\(String(describing: z.firmwareablauf[u.id]))") }
        XCTAssertEqual(e.fassung, "1.3.0")
        XCTAssertEqual(s.zustand.firmware.fassung, "1.3.0")
        XCTAssertEqual(z.geraetezustand[u.id]?.fassung, "1.3.0")
        XCTAssertNil(z.fehler)
    }

    func testOhneVorherigesSuchenStartetNichts() async throws {
        let (z, u, s) = try uhr()
        release(paket: NGFirmware.paket(fassung: "1.3.0"))
        await z.firmwareAktualisieren(fuer: u.id)
        XCTAssertNil(z.firmwareablauf[u.id])
        XCTAssertEqual(s.zustand.firmware.stand, "idle")
        XCTAssertTrue(GitHubAttrappe.gesehen.isEmpty)
    }

    func testVerfaelschtesPaketGehtNieAnDieUhr() async throws {
        let (z, u, s) = try uhr()
        release(paket: NGFirmware.paket(fassung: "1.3.0"), summe: String(repeating: "0", count: 64))
        await z.firmwareSuchen(fuer: u.id)
        await z.firmwareAktualisieren(fuer: u.id)
        guard case .fehler(let text)? = z.firmwareablauf[u.id] else { return XCTFail("kein Fehler") }
        XCTAssertTrue(text.contains("Prüfsumme"), text)
        XCTAssertEqual(s.zustand.firmware.stand, "idle")
    }

    func testAbweisungDerUhrWirdKlarsprachlich() async throws {
        var stand = NGUhrzustand()
        stand.firmware.einrichtungsmodus = true
        let (z, u, _) = try uhr(stand)
        release(paket: NGFirmware.paket(fassung: "1.3.0"))
        await z.firmwareSuchen(fuer: u.id)
        await z.firmwareAktualisieren(fuer: u.id)
        XCTAssertEqual(z.firmwareablauf[u.id], .fehler(Firmwarefehler.einrichtungsmodus.localizedDescription))
    }

    func testStartFehlerDerNeuenFassung() async throws {
        var stand = NGUhrzustand()
        stand.firmware.startScheitert = true
        let (z, u, _) = try uhr(stand)
        release(paket: NGFirmware.paket(fassung: "1.3.0"))
        await z.firmwareSuchen(fuer: u.id)
        await z.firmwareAktualisieren(fuer: u.id)
        guard case .fehler(let text)? = z.firmwareablauf[u.id] else { return XCTFail("kein Fehler") }
        XCTAssertTrue(text.contains("nicht gestartet"), text)
    }

    func testOhneAdresseKeineAbfrage() async throws {
        let (z, u, _) = try uhr(host: "")
        await z.firmwareSuchen(fuer: u.id)
        guard case .fehler(let text)? = z.firmwareablauf[u.id] else { return XCTFail("kein Fehler") }
        XCTAssertTrue(text.contains("Ohne Adresse"), text)
        XCTAssertTrue(GitHubAttrappe.gesehen.isEmpty)
    }

    func testAeltereFassungOhneUpdateImageWirdNichtAngeboten() async throws {
        // Ohne `updateImage` gibt es kein Paket, das die App raten dürfte.
        var stand = NGUhrzustand()
        stand.firmware.image = ""
        let (z, u, _) = try uhr(stand)
        release(paket: NGFirmware.paket(fassung: "1.3.0"))
        await z.firmwareSuchen(fuer: u.id)
        XCTAssertEqual(z.firmwareablauf[u.id], .fehler(Firmwarefehler.keinPaketFuerDieseUhr.localizedDescription))
        XCTAssertTrue(GitHubAttrappe.gesehen.isEmpty)
    }
}
