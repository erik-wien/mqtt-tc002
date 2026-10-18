import XCTest
@testable import TC002Core

/// Ein Doppelgänger für GitHub: Er beantwortet jede Anfrage mit dem, was `antwort`
/// liefert. Nichts verlässt den Rechner.
final class GitHubDoppelgaenger: URLProtocol {
    enum Antwort {
        case rumpf(Int, [String: String], Data)
        case weiter(String)
        case fehler
    }
    nonisolated(unsafe) static var antwort: (URLRequest) -> Antwort = { _ in .fehler }
    nonisolated(unsafe) static var gesehen: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }

    override func startLoading() {
        Self.gesehen.append(request)
        switch Self.antwort(request) {
        case .rumpf(let status, let kopf, let daten):
            var k = kopf
            k["Content-Length"] = "\(daten.count)"
            let a = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: k)!
            client?.urlProtocol(self, didReceive: a, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: daten)
            client?.urlProtocolDidFinishLoading(self)
        case .weiter(let ziel):
            let a = HTTPURLResponse(url: request.url!, statusCode: 302, httpVersion: "HTTP/1.1",
                                    headerFields: ["Location": ziel])!
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: URL(string: ziel)!), redirectResponse: a)
            // Verweigert der Aufrufer die Weiterleitung, endet der Abruf mit dieser Antwort.
            client?.urlProtocol(self, didReceive: a, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        case .fehler:
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        }
    }
    override func stopLoading() {}

    static func sitzung() -> URLSession {
        let k = URLSessionConfiguration.ephemeral
        k.protocolClasses = [GitHubDoppelgaenger.self]
        return URLSession(configuration: k)
    }
}

final class FirmwareversionTests: XCTestCase {
    private func v(_ s: String) -> Firmwareversion { Firmwareversion(s)! }

    func testZahlenWerdenNachWertGeordnet() {
        XCTAssertLessThan(v("1.2.2"), v("1.10.0"))
        XCTAssertLessThan(v("1.2.2"), v("v1.2.3"))
        XCTAssertEqual(v("1.2"), v("1.2.0"))
        XCTAssertEqual(v("v1.2.2+abc"), v("1.2.2"))
    }

    func testVorabfassungLiegtVorDerFassung() {
        XCTAssertLessThan(v("1.3.0-beta.1"), v("1.3.0"))
        XCTAssertLessThan(v("1.2.2"), v("1.3.0-beta.1"))
        XCTAssertLessThan(v("1.3.0-beta.2"), v("1.3.0-beta.10"))
        XCTAssertLessThan(v("1.3.0-alpha"), v("1.3.0-beta"))
        XCTAssertLessThan(v("1.3.0-1"), v("1.3.0-alpha"))
        XCTAssertLessThan(v("1.3.0-beta"), v("1.3.0-beta.1"))
        XCTAssertFalse(v("1.3.0") < v("1.3.0-rc.1"))
    }

    func testUnlesbaresIstNil() {
        for s in ["", "abc", "1..2", "1.x", "1.2-", "-1"] { XCTAssertNil(Firmwareversion(s), s) }
    }
}

final class FirmwarefehlerTests: XCTestCase {
    /// Jeder Code der Doku (`guides/updating`, `reference/errors`) hat eine eigene Meldung.
    func testJederCodeHatEineEigeneMeldung() {
        let faelle: [(Int, String, Firmwarefehler)] = [
            (409, "notNewer", .nichtNeuer), (400, "invalidPackage", .paketBeschaedigt),
            (400, "wrongTarget", .falschesZiel), (400, "wrongChip", .falscherChip),
            (409, "updateBusy", .updateBelegt), (403, "forbidden", .einrichtungsmodus),
            (403, "forbiddenOrigin", .fremdeHerkunft), (413, "payloadTooLarge", .paketZuGross),
            (413, "insufficientMemory", .zuWenigArbeitsspeicher), (500, "internalError", .schreibenFehlgeschlagen),
            (400, "badRequest", .keinPaketErkannt), (401, "unauthorized", .anmeldungFehlt),
        ]
        var texte = Set<String>()
        for (status, code, erwartet) in faelle {
            let f = Firmwarefehler.aus(status: status, code: code, message: nil)
            XCTAssertEqual(f, erwartet, code)
            let text = f.errorDescription ?? ""
            XCTAssertFalse(text.isEmpty, code)
            XCTAssertTrue(texte.insert(text).inserted, "doppelter Text bei \(code)")
        }
    }

    func testSpeicherNenntDieGroessenDerUhr() {
        // TC002: 409, ESP32-Dokumentation: 507. Maßgeblich ist der Code.
        for status in [409, 507] {
            let f = Firmwarefehler.aus(status: status, code: "insufficientStorage", message: "2.0 MB missing")
            XCTAssertEqual(f, .speicherZuKlein("2.0 MB missing"))
            XCTAssertTrue(f.errorDescription?.contains("2.0 MB missing") == true)
        }
    }

    func testUnbekannterCodeBleibtSichtbar() {
        let f = Firmwarefehler.aus(status: 418, code: "teapot", message: nil)
        XCTAssertTrue(f.errorDescription?.contains("teapot") == true)
        XCTAssertTrue(f.errorDescription?.contains("418") == true)
    }

    func testKeineSendungOderMeldungInDenTexten() {
        let alle: [Firmwarefehler] = [.githubNichtErreichbar, .githubBegrenzt, .githubFehler(500), .freigabeUnbrauchbar,
                                      .installierteFassungUnbekannt, .keinPaketFuerDieseUhr, .ladenAbgebrochen,
                                      .herkunftUnerlaubt, .pruefungFehlgeschlagen, .nichtNeuer, .paketBeschaedigt,
                                      .neustartAusgeblieben, .fassungUnveraendert("1.2.2"), .startFehlgeschlagen("x")]
        for f in alle {
            let t = f.errorDescription ?? ""
            XCTAssertFalse(t.contains("Meldung") || t.contains("Sendung"), t)
        }
    }
}

final class FirmwarelageTests: XCTestCase {
    private func zustand(_ image: String?) throws -> Geraetezustand {
        var o: [String: Any] = ["version": "1.2.2"]
        if let image { o["updateImage"] = image }
        return try Geraetezustand(daten: JSONSerialization.data(withJSONObject: o))
    }

    func testOhneAdresseGesperrtMitGrund() throws {
        XCTAssertEqual(Firmwarelage.fuer(adresse: false, zustand: try zustand("awtrix-ng-tc002.awup")), .ohneAdresse)
        XCTAssertEqual(Firmwarelage.fuer(adresse: false, zustand: nil), .ohneAdresse)
    }

    func testUnbekanntIstErlaubt() {
        XCTAssertEqual(Firmwarelage.fuer(adresse: true, zustand: nil), .bereit)
    }

    func testAeltereFassungOhneUpdateImageIstVerborgen() throws {
        XCTAssertEqual(Firmwarelage.fuer(adresse: true, zustand: try zustand(nil)), .verborgen)
        XCTAssertEqual(Firmwarelage.fuer(adresse: true, zustand: try zustand("irgendwas.bin")), .verborgen)
    }

    func testAlleVierPaketnamenSindBereit() throws {
        for name in Firmwarepakete.erlaubt {
            XCTAssertEqual(Firmwarelage.fuer(adresse: true, zustand: try zustand(name)), .bereit, name)
        }
    }
}

final class FirmwarequelleTests: XCTestCase {
    private let tag = "v1.3.0"
    private let image = "awtrix-ng-tc002.awup"

    override func setUp() {
        super.setUp()
        GitHubDoppelgaenger.gesehen = []
    }

    private func freigabe(tag: String = "v1.3.0", draft: Bool = false, vorab: Bool = false,
                          assets: [[String: Any]]? = nil) -> Data {
        let standard: [[String: Any]] = [
            ["name": image, "size": 100, "state": "uploaded",
             "digest": "sha256:" + String(repeating: "a", count: 64),
             "browser_download_url": "https://github.com/Blueforcer/awtrix-ng/releases/download/\(tag)/\(image)"],
            ["name": "tc002-sources.tar.gz", "size": 5, "state": "uploaded"],
        ]
        let o: [String: Any] = ["tag_name": tag, "draft": draft, "prerelease": vorab,
                                "published_at": "2026-11-01T10:00:00Z",
                                "html_url": "https://github.com/Blueforcer/awtrix-ng/releases/tag/\(tag)",
                                "assets": assets ?? standard]
        return try! JSONSerialization.data(withJSONObject: o)
    }

    private func suchen(_ antwort: GitHubDoppelgaenger.Antwort, installiert: String = "1.2.2",
                        image: String? = nil) async throws -> Firmwareangebot {
        GitHubDoppelgaenger.antwort = { _ in antwort }
        return try await Firmwarequelle(sitzung: GitHubDoppelgaenger.sitzung())
            .suchen(updateImage: image ?? self.image, installiert: installiert)
    }

    func testNeueresReleaseMitPaketWirdAngeboten() async throws {
        let a = try await suchen(.rumpf(200, [:], freigabe()))
        guard case .verfuegbar(let p) = a else { return XCTFail("\(a)") }
        XCTAssertEqual(p.fassung, "1.3.0")
        XCTAssertEqual(p.tag, "v1.3.0")
        XCTAssertEqual(p.dateiname, image)
        XCTAssertEqual(p.groesse, 100)
        XCTAssertEqual(p.adresse.absoluteString, "https://github.com/Blueforcer/awtrix-ng/releases/download/v1.3.0/\(image)")
        XCTAssertEqual(p.notizen?.host, "github.com")
        // Nur die Freigabeabfrage, ohne Anmeldung.
        XCTAssertEqual(GitHubDoppelgaenger.gesehen.count, 1)
        XCTAssertEqual(GitHubDoppelgaenger.gesehen[0].url, Firmwarequelle.freigabeAdresse)
        XCTAssertNil(GitHubDoppelgaenger.gesehen[0].value(forHTTPHeaderField: "Authorization"))
    }

    func testGleicheFassungIstAktuell() async throws {
        let a = try await suchen(.rumpf(200, [:], freigabe(tag: "v1.2.2")))
        XCTAssertEqual(a, .aktuell(installiert: "1.2.2"))
    }

    func testAeltereFassungIstAktuellAuchOhnePaket() async throws {
        let a = try await suchen(.rumpf(200, [:], freigabe(tag: "v1.1.2", assets: [])))
        XCTAssertEqual(a, .aktuell(installiert: "1.2.2"))
    }

    func testVorabfassungDerUhrKennt1_3_0AlsNeuer() async throws {
        let a = try await suchen(.rumpf(200, [:], freigabe()), installiert: "1.3.0-beta.1")
        guard case .verfuegbar = a else { return XCTFail("\(a)") }
    }

    func testNeuereNummerOhnePaketDieserUhr() async throws {
        let a = try await suchen(.rumpf(200, [:], freigabe(assets: [["name": "tc002-sources.tar.gz", "size": 5]])))
        XCTAssertEqual(a, .keinPaket(fassung: "1.3.0", dateiname: image))
    }

    func testPaketWirdNachDemNamenDerUhrGewaehltNichtGeraten() async throws {
        let bin = "firmware-awtrix-ng.bin"
        let assets: [[String: Any]] = [
            ["name": image, "size": 100, "state": "uploaded", "digest": "sha256:" + String(repeating: "a", count: 64),
             "browser_download_url": "https://github.com/Blueforcer/awtrix-ng/releases/download/v1.3.0/\(image)"],
            ["name": bin, "size": 200, "state": "uploaded", "digest": "sha256:" + String(repeating: "b", count: 64),
             "browser_download_url": "https://github.com/Blueforcer/awtrix-ng/releases/download/v1.3.0/\(bin)"],
        ]
        let a = try await suchen(.rumpf(200, [:], freigabe(assets: assets)), image: bin)
        guard case .verfuegbar(let p) = a else { return XCTFail("\(a)") }
        XCTAssertEqual(p.dateiname, bin)
        XCTAssertEqual(p.groesse, 200)
        XCTAssertEqual(p.sha256, String(repeating: "b", count: 64))
    }

    func testUnbekannterPaketnameWirdNichtAngefragt() async {
        GitHubDoppelgaenger.antwort = { _ in .rumpf(200, [:], Data()) }
        do {
            _ = try await Firmwarequelle(sitzung: GitHubDoppelgaenger.sitzung())
                .suchen(updateImage: "irgendwas.bin", installiert: "1.2.2")
            XCTFail("sollte werfen")
        } catch { XCTAssertEqual(error as? Firmwarefehler, .keinPaketFuerDieseUhr) }
        XCTAssertTrue(GitHubDoppelgaenger.gesehen.isEmpty)
    }

    func testUnbrauchbareAngabenWerdenAbgelehnt() async {
        let gut = "https://github.com/Blueforcer/awtrix-ng/releases/download/v1.3.0/\(image)"
        let summe = "sha256:" + String(repeating: "a", count: 64)
        func a(_ aenderung: (inout [String: Any]) -> Void) -> [[String: Any]] {
            var x: [String: Any] = ["name": image, "size": 100, "state": "uploaded", "digest": summe,
                                    "browser_download_url": gut]
            aenderung(&x)
            return [x]
        }
        let faelle: [Data] = [
            freigabe(draft: true), freigabe(vorab: true),
            freigabe(tag: "v1.3.0/../x"),
            freigabe(assets: a { $0["browser_download_url"] = "https://evil.example/\(image)" }),
            freigabe(assets: a { $0["browser_download_url"] = "https://github.com/Other/repo/releases/download/v1.3.0/\(image)" }),
            freigabe(assets: a { $0["digest"] = nil }),
            freigabe(assets: a { $0["digest"] = "sha256:ABC" }),
            freigabe(assets: a { $0["digest"] = "md5:" + String(repeating: "a", count: 64) }),
            freigabe(assets: a { $0["state"] = "open" }),
            freigabe(assets: a { $0["size"] = 0 }),
            freigabe(assets: a { $0["size"] = 9 << 20 }),
            freigabe(assets: a { _ in } + a { _ in }),
            Data("kein json".utf8),
        ]
        for daten in faelle {
            do {
                let r = try await suchen(.rumpf(200, [:], daten))
                XCTFail("sollte werfen: \(r)")
            } catch { XCTAssertEqual(error as? Firmwarefehler, .freigabeUnbrauchbar) }
        }
    }

    func testGrenzenVonGitHub() async {
        for (status, erwartet) in [(403, Firmwarefehler.githubBegrenzt), (429, .githubBegrenzt), (500, .githubFehler(500))] {
            do {
                _ = try await suchen(.rumpf(status, ["x-ratelimit-remaining": "0"], Data()))
                XCTFail("sollte werfen")
            } catch { XCTAssertEqual(error as? Firmwarefehler, erwartet) }
        }
        do {
            _ = try await suchen(.fehler)
            XCTFail("sollte werfen")
        } catch { XCTAssertEqual(error as? Firmwarefehler, .githubNichtErreichbar) }
    }

    func testFassungDerUhrMussLesbarSein() async {
        do {
            _ = try await suchen(.rumpf(200, [:], freigabe()), installiert: "?")
            XCTFail("sollte werfen")
        } catch { XCTAssertEqual(error as? Firmwarefehler, .installierteFassungUnbekannt) }
    }

    // MARK: - Laden

    private func paket(_ daten: Data, summe: String? = nil, groesse: Int? = nil) -> Firmwarepaket {
        Firmwarepaket(fassung: "1.3.0", tag: tag, dateiname: image, groesse: groesse ?? daten.count,
                      sha256: summe ?? Fingerabdruck.sha256(daten),
                      adresse: URL(string: "https://github.com/Blueforcer/awtrix-ng/releases/download/v1.3.0/\(image)")!,
                      notizen: nil)
    }

    private var gutesPaket: Data { NGFirmware.paket(fassung: "1.3.0", fuellung: 200_000) }

    func testLadenPrueftGroesseKopfUndSumme() async throws {
        let daten = gutesPaket
        GitHubDoppelgaenger.antwort = { _ in .rumpf(200, [:], daten) }
        let letzter = Zaehler()
        let geladen = try await Firmwarequelle(sitzung: GitHubDoppelgaenger.sitzung())
            .laden(paket(daten)) { letzter.setze($0) }
        XCTAssertEqual(geladen, daten)
        XCTAssertEqual(letzter.wert, 1)
    }

    func testFalschePruefsummeWirdAbgelehnt() async {
        let daten = gutesPaket
        GitHubDoppelgaenger.antwort = { _ in .rumpf(200, [:], daten) }
        do {
            _ = try await Firmwarequelle(sitzung: GitHubDoppelgaenger.sitzung())
                .laden(paket(daten, summe: String(repeating: "0", count: 64))) { _ in }
            XCTFail("sollte werfen")
        } catch { XCTAssertEqual(error as? Firmwarefehler, .pruefungFehlgeschlagen) }
    }

    func testFalscherKopfWirdAbgelehnt() async {
        let daten = Data("kein Paket".utf8) + Data(repeating: 0, count: 100)
        GitHubDoppelgaenger.antwort = { _ in .rumpf(200, [:], daten) }
        do {
            _ = try await Firmwarequelle(sitzung: GitHubDoppelgaenger.sitzung()).laden(paket(daten)) { _ in }
            XCTFail("sollte werfen")
        } catch { XCTAssertEqual(error as? Firmwarefehler, .pruefungFehlgeschlagen) }
    }

    func testZuLangeAntwortWirdAbgelehnt() async {
        let daten = gutesPaket
        GitHubDoppelgaenger.antwort = { _ in .rumpf(200, [:], daten) }
        do {
            _ = try await Firmwarequelle(sitzung: GitHubDoppelgaenger.sitzung())
                .laden(paket(daten, groesse: daten.count - 10)) { _ in }
            XCTFail("sollte werfen")
        } catch { XCTAssertEqual(error as? Firmwarefehler, .pruefungFehlgeschlagen) }
    }

    func testWeiterleitungAufGitHubDateihosterIstErlaubt() async throws {
        let daten = gutesPaket
        GitHubDoppelgaenger.antwort = { anfrage in
            anfrage.url?.host == "github.com"
                ? .weiter("https://release-assets.githubusercontent.com/x/\(self.image)")
                : .rumpf(200, [:], daten)
        }
        let geladen = try await Firmwarequelle(sitzung: GitHubDoppelgaenger.sitzung()).laden(paket(daten)) { _ in }
        XCTAssertEqual(geladen, daten)
    }

    func testWeiterleitungAufFremdenHostBrichtAb() async {
        let daten = gutesPaket
        GitHubDoppelgaenger.antwort = { anfrage in
            anfrage.url?.host == "github.com" ? .weiter("https://evil.example/\(self.image)") : .rumpf(200, [:], daten)
        }
        do {
            _ = try await Firmwarequelle(sitzung: GitHubDoppelgaenger.sitzung()).laden(paket(daten)) { _ in }
            XCTFail("sollte werfen")
        } catch { XCTAssertEqual(error as? Firmwarefehler, .herkunftUnerlaubt) }
        XCTAssertFalse(GitHubDoppelgaenger.gesehen.contains { $0.url?.host == "evil.example" })
    }

    func testErlaubteWeiterleitungsadressen() {
        func ok(_ s: String) -> Bool { Firmwarequelle.weiterleitungErlaubt(URL(string: s)!) }
        XCTAssertTrue(ok("https://github.com/a/b"))
        XCTAssertTrue(ok("https://objects.githubusercontent.com/x"))
        XCTAssertTrue(ok("https://release-assets.githubusercontent.com/x"))
        XCTAssertFalse(ok("http://github.com/a"))
        XCTAssertFalse(ok("https://github.com:8443/a"))
        XCTAssertFalse(ok("https://user:pw@github.com/a"))
        XCTAssertFalse(ok("https://github.com.evil.example/a"))
        XCTAssertFalse(ok("https://raw.githubusercontent.com/x"))
        XCTAssertFalse(ok("https://github.com/a#frag"))
    }
}

final class Zaehler: @unchecked Sendable {
    private let sperre = NSLock()
    private var _wert = 0.0
    func setze(_ w: Double) { sperre.lock(); _wert = w; sperre.unlock() }
    var wert: Double { sperre.lock(); defer { sperre.unlock() }; return _wert }
}
