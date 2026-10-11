import XCTest
@testable import TC002Core

/// Antwortet mit einer wählbaren Länge, einmal mit `Content-Length`, einmal
/// stückweise ohne — und zählt, wie viele Byte tatsächlich ausgeliefert wurden.
final class GrenzDoppelgaenger: URLProtocol {
    nonisolated(unsafe) static var laenge = 0
    nonisolated(unsafe) static var mitLaengenangabe = true
    nonisolated(unsafe) static var ausgeliefert = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }

    override func startLoading() {
        Self.ausgeliefert = 0
        let kopf = Self.mitLaengenangabe ? ["Content-Length": "\(Self.laenge)"] : [:]
        let antwort = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: kopf)!
        client?.urlProtocol(self, didReceive: antwort, cacheStoragePolicy: .notAllowed)
        var offen = Self.laenge
        while offen > 0 {
            let n = min(offen, 64 << 10)
            client?.urlProtocol(self, didLoad: Data(repeating: 0x20, count: n))
            Self.ausgeliefert += n
            offen -= n
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class AntwortgrenzeTests: XCTestCase {
    private func geraet() -> Geraet {
        let k = URLSessionConfiguration.ephemeral
        k.protocolClasses = [GrenzDoppelgaenger.self]
        return Geraet(host: "uhr.test", sitzung: URLSession(configuration: k))
    }

    private func pruefeZuGross(_ aufruf: () throws -> Any, grenze: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try aufruf(), file: file, line: line) { fehler in
            guard case GeraetFehler.antwortZuGross(_, let g)? = fehler as? GeraetFehler else {
                return XCTFail("falscher Fehler: \(fehler)", file: file, line: line)
            }
            XCTAssertEqual(g, grenze, file: file, line: line)
            XCTAssertNotNil((fehler as? LocalizedError)?.errorDescription, file: file, line: line)
        }
    }

    func testLaengenangabeUeberDerGrenzeBrichtAb() {
        GrenzDoppelgaenger.laenge = Antwortgrenze.standard + 1
        GrenzDoppelgaenger.mitLaengenangabe = true
        pruefeZuGross({ try geraet().lesen("/api/v1/x") }, grenze: Antwortgrenze.standard)
    }

    func testRumpfOhneLaengenangabeBrichtBeimUeberschreitenAb() {
        GrenzDoppelgaenger.laenge = Antwortgrenze.standard + (200 << 10)
        GrenzDoppelgaenger.mitLaengenangabe = false
        pruefeZuGross({ try geraet().lesen("/api/v1/x") }, grenze: Antwortgrenze.standard)
    }

    func testBildschirmHatEineEigeneKleinereGrenze() {
        GrenzDoppelgaenger.laenge = Antwortgrenze.bildschirm + 1
        GrenzDoppelgaenger.mitLaengenangabe = true
        XCTAssertLessThan(Antwortgrenze.bildschirm, Antwortgrenze.standard)
        pruefeZuGross({ try geraet().bildschirm() }, grenze: Antwortgrenze.bildschirm)
    }

    func testAntwortInDerGrenzeKommtVollstaendigAn() throws {
        GrenzDoppelgaenger.laenge = Antwortgrenze.standard
        GrenzDoppelgaenger.mitLaengenangabe = true
        let daten = try geraet().lesen("/api/v1/x")
        XCTAssertEqual(daten.count, Antwortgrenze.standard)
    }
}
