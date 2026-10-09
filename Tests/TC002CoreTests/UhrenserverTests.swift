import Network
import XCTest
@testable import TC002Core

/// Das Zerlegen roher Bytes zu einer Anfrage — die einzige Stelle im
/// `Uhrenserver`, die etwas rechnet und nicht bloß Netz ist.
final class UhrenserverZerlegenTests: XCTestCase {
    private func bytes(_ text: String) -> Data { Data(text.utf8) }

    func testEineVollstaendigeAnfrageWirdZerlegt() throws {
        let roh = bytes("PUT /api/v1/apps/pushed/meldung1 HTTP/1.1\r\n"
                        + "Host: 127.0.0.1:8752\r\nContent-Length: 16\r\n\r\n"
                        + #"{"text":"hallo"}"#)
        let a = try XCTUnwrap(Uhrenserver.zerlegen(roh))
        XCTAssertEqual(a.methode, "PUT")
        XCTAssertEqual(a.pfad, "/api/v1/apps/pushed/meldung1")
        XCTAssertEqual(String(decoding: a.koerper, as: UTF8.self), #"{"text":"hallo"}"#)
    }

    /// Unvollständig heißt weiterlesen, nicht raten: Ein Rumpf kommt in
    /// mehreren Paketen; wer beim ersten antwortet, verwirft den Rest.
    func testEinHalberRumpfIstNochKeineAnfrage() {
        let ohneRumpf = bytes("PUT /api/v1/apps/pushed/a HTTP/1.1\r\nContent-Length: 20\r\n\r\n{\"te")
        XCTAssertNil(Uhrenserver.zerlegen(ohneRumpf))
        let ohneKopfende = bytes("GET /api/v1/device HTTP/1.1\r\nHost: x\r\n")
        XCTAssertNil(Uhrenserver.zerlegen(ohneKopfende))
    }

    /// Die Abfrage kommt dekodiert an.
    func testEineKodierteAbfrageWirdDekodiert() throws {
        let roh = bytes("POST /x?name=mein%20Platz HTTP/1.1\r\nContent-Length: 0\r\n\r\n")
        let a = try XCTUnwrap(Uhrenserver.zerlegen(roh))
        XCTAssertEqual(a.abfrage["name"], "mein Platz")
    }

    /// Ohne Rumpf und ohne `Content-Length` — so kommt jedes `GET`.
    func testEinGetOhneRumpf() throws {
        let a = try XCTUnwrap(Uhrenserver.zerlegen(bytes("GET /api/v1/device HTTP/1.1\r\nHost: x\r\n\r\n")))
        XCTAssertEqual(a.methode, "GET")
        XCTAssertEqual(a.pfad, "/api/v1/device")
        XCTAssertTrue(a.koerper.isEmpty)
    }
}

/// Die Grenzen des Dienstes, ueber den echten Weg auf `127.0.0.1`: Eine
/// Anfrage, die mehr verspricht, als der Dienst nimmt, wird abgewiesen, bevor
/// sie gelesen ist.
final class UhrenserverGrenzenTests: XCTestCase {
    private var server: Uhrenserver?

    override func tearDown() {
        server?.beenden()
        server = nil
        super.tearDown()
    }

    private func gestartet() throws -> UInt16 {
        for _ in 0..<20 {
            let port = UInt16.random(in: 20_000...60_000)
            let s = Uhrenserver(port: port)
            do {
                try s.starten()          // kehrt erst zurück, wenn der Dienst annimmt
                server = s
                return port
            } catch { continue }
        }
        throw XCTSkip("kein freier Port")
    }

    /// Schickt rohe Bytes und liest die Antwort bis zum Schliessen.
    private func roh(_ port: UInt16, _ bytes: Data) -> String {
        let verbindung = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        let fertig = expectation(description: "Antwort")
        nonisolated(unsafe) var antwort = Data()
        func lesen() {
            verbindung.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { teil, _, ende, fehler in
                if let teil { antwort.append(teil) }
                if ende || fehler != nil { fertig.fulfill() } else { lesen() }
            }
        }
        verbindung.stateUpdateHandler = { zustand in
            switch zustand {
            case .ready:
                verbindung.send(content: bytes, completion: .contentProcessed { _ in })
                lesen()
            // `.waiting` ist bei NWConnection auch „Verbindung verweigert“ und
            // endet nie von selbst; ohne diesen Zweig bliebe daraus eine
            // Zeitüberschreitung ohne Hinweis auf die Ursache.
            case .waiting, .failed: fertig.fulfill()
            default: break
            }
        }
        verbindung.start(queue: .global())
        wait(for: [fertig], timeout: 5)
        verbindung.cancel()
        return String(decoding: antwort, as: UTF8.self)
    }

    func testEinVersprochenerZuGrosserRumpfWirdSofortMit413Beantwortet() throws {
        let port = try gestartet()
        let antwort = roh(port, Data("PUT /api/v1/apps/pushed/x HTTP/1.1\r\nContent-Type: application/json\r\nContent-Length: 99999999999\r\n\r\n".utf8))
        XCTAssertTrue(antwort.hasPrefix("HTTP/1.1 413"), antwort)
        XCTAssertTrue(antwort.contains("payloadTooLarge"))
    }

    func testNegativeUndUngueltigeLaengenSindVierhundert() throws {
        let port = try gestartet()
        for wert in ["-5", "abc", ""] {
            let antwort = roh(port, Data("PUT /api/v1/apps/pushed/x HTTP/1.1\r\nContent-Length: \(wert)\r\n\r\n".utf8))
            XCTAssertTrue(antwort.hasPrefix("HTTP/1.1 400"), "\(wert): \(antwort)")
        }
    }

    func testEinKopfOhneEndeUeberDerGrenzeWirdAbgewiesen() throws {
        let port = try gestartet()
        let antwort = roh(port, Data(("GET /x HTTP/1.1\r\nX-Fuell: " + String(repeating: "a", count: 40_000)).utf8))
        XCTAssertTrue(antwort.hasPrefix("HTTP/1.1 400"), String(antwort.prefix(80)))
    }

    func testEinRumpfAnDerGrenzeWirdNochGelesen() throws {
        XCTAssertNil(Uhrenserver.vorabpruefung(Data("PUT /x HTTP/1.1\r\nContent-Length: \(VirtuelleNGUhr.maxRumpf)\r\n\r\n".utf8)))
        XCTAssertEqual(Uhrenserver.vorabpruefung(Data("PUT /x HTTP/1.1\r\nContent-Length: \(VirtuelleNGUhr.maxRumpf + 1)\r\n\r\n".utf8))?.status, 413)
        XCTAssertNil(Uhrenserver.vorabpruefung(Data("GET /x HTTP/1.1\r\n".utf8)))
    }

    // MARK: Eindeutigkeit des Kopfes

    private func anfrage(_ kopfzeilen: String) -> String {
        guard let port = try? gestartet() else { XCTFail("kein Dienst"); return "" }
        return roh(port, Data(("PUT /api/v1/apps/pushed/x HTTP/1.1\r\n" + kopfzeilen + "\r\n\r\n").utf8))
    }

    private func pruefeAbgewiesen(_ kopfzeilen: String, _ status: Int = 400,
                                  datei: StaticString = #filePath, zeile: UInt = #line) {
        server?.beenden()
        let antwort = anfrage(kopfzeilen)
        XCTAssertTrue(antwort.hasPrefix("HTTP/1.1 \(status)"), "\(kopfzeilen) -> \(antwort)", file: datei, line: zeile)
        XCTAssertTrue(antwort.contains("\"error\""), antwort, file: datei, line: zeile)
    }

    func testMehrereContentLengthSindAbgewiesen() {
        pruefeAbgewiesen("Content-Length: 5\r\nContent-Length: 6")
        pruefeAbgewiesen("Content-Length: 5\r\ncontent-length: 5")
        pruefeAbgewiesen("Content-Length: 5, 5")
    }

    func testTransferEncodingIstAbgewiesen() {
        pruefeAbgewiesen("Transfer-Encoding: chunked")
        pruefeAbgewiesen("Content-Length: 0\r\nTransfer-Encoding: chunked")
    }

    func testUnzulaessigeKopfnamenSindAbgewiesen() {
        pruefeAbgewiesen("Content-Length : 5")
        pruefeAbgewiesen("Con tent: 5")
        pruefeAbgewiesen("Cöntent: 5")
        pruefeAbgewiesen("Kein-Doppelpunkt")
        pruefeAbgewiesen(": leer")
        pruefeAbgewiesen("X-A: 1\r\n folge: 2")
    }

    func testContentLengthNurZiffern() {
        pruefeAbgewiesen("Content-Length: +5")
        pruefeAbgewiesen("Content-Length: 5 5")
        pruefeAbgewiesen("Content-Length: 0x10")
        pruefeAbgewiesen("Content-Length: 5.0")
        pruefeAbgewiesen("Content-Length: 99999999999999999999")
        pruefeAbgewiesen("Content-Length: 99999999999", 413)
    }

    func testEineEindeutigeAnfrageWirdBeantwortet() throws {
        let port = try gestartet()
        let rumpf = #"{"draw":[["pixel",0,0,"FF0000"]]}"#
        let antwort = roh(port, Data(("PUT /api/v1/apps/pushed/x HTTP/1.1\r\nContent-Type: application/json\r\nContent-Length: \(rumpf.utf8.count)\r\n\r\n" + rumpf).utf8))
        XCTAssertTrue(antwort.hasPrefix("HTTP/1.1 200"), antwort)
        XCTAssertEqual(server?.zustand.apps.map(\.name), ["Time", "Status", "x"])
    }

    func testGroessenpruefungUndEinlesenSehenDenselbenWert() {
        let kopf = "PUT /x HTTP/1.1\r\nContent-Length: 3\r\n\r\n"
        guard case .fertig(let a) = Uhrenserver.einlesen(Data((kopf + "abcdef").utf8)) else {
            return XCTFail("keine Anfrage")
        }
        XCTAssertEqual(String(decoding: a.koerper, as: UTF8.self), "abc")
        if case .mehr = Uhrenserver.einlesen(Data((kopf + "ab").utf8)) {} else { XCTFail("sollte weiterlesen") }
    }
}
