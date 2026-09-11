import XCTest
import Network
@testable import TC002Core

final class MQTTSenderTests: XCTestCase {
    /// Nimmt eine Verbindung an, antwortet mit CONNACK und sammelt alles Empfangene.
    private final class Lauscher {
        var port: UInt16 = 0
        private let listener: NWListener
        private let sperre = NSLock()
        private var _empfangen = Data()
        var empfangen: Data { sperre.lock(); defer { sperre.unlock() }; return _empfangen }

        init(connackCode: UInt8) throws {
            listener = try NWListener(using: .tcp, on: .any)
            listener.newConnectionHandler = { [weak self] verbindung in
                verbindung.start(queue: .global())
                func lies() {
                    verbindung.receive(minimumIncompleteLength: 1, maximumLength: 4096) { d, _, _, _ in
                        if let d, !d.isEmpty {
                            self?.sperre.lock(); self?._empfangen.append(d); self?.sperre.unlock()
                            if d[d.startIndex] == 0x10 {          // CONNECT gesehen
                                verbindung.send(content: Data([0x20, 0x02, 0x00, connackCode]),
                                                completion: .idempotent)
                            }
                            lies()
                        }
                    }
                }
                lies()
            }
            let bereit = DispatchSemaphore(value: 0)
            listener.stateUpdateHandler = { if case .ready = $0 { bereit.signal() } }
            listener.start(queue: .global())
            guard bereit.wait(timeout: .now() + 5) == .success,
                  let p = listener.port?.rawValue else {
                throw MQTTFehler.zeitueberschreitung
            }
            port = p
        }
        func stoppen() { listener.cancel() }
    }

    func testSendetConnectUndPublish() throws {
        let lauscher = try Lauscher(connackCode: 0)
        defer { lauscher.stoppen() }
        let zugang = MQTTZugang(host: "127.0.0.1", port: lauscher.port,
                                benutzer: "pixdeck", kennwort: "geheim", clientID: "tc002-app")

        try MQTTSender().senden(Data("HI".utf8), an: "awtrix_a86b/custom/test", zugang: zugang)

        let hex = lauscher.empfangen.map { String(format: "%02x", $0) }.joined()
        XCTAssertTrue(hex.hasPrefix("1026"), "beginnt mit CONNECT")
        XCTAssertTrue(hex.contains("301b0017"), "enthält das PUBLISH")
    }

    func testFalschesKennwortWirdGemeldet() throws {
        let lauscher = try Lauscher(connackCode: 4)
        defer { lauscher.stoppen() }
        let zugang = MQTTZugang(host: "127.0.0.1", port: lauscher.port,
                                benutzer: "x", kennwort: "falsch", clientID: "tc002-app")

        XCTAssertThrowsError(try MQTTSender().senden(Data("HI".utf8), an: "t", zugang: zugang)) { fehler in
            guard case MQTTFehler.abgelehnt(let code) = fehler else { return XCTFail("falscher Fehler") }
            XCTAssertEqual(code, 4)
            XCTAssertTrue((fehler as? LocalizedError)?.errorDescription?.contains("Kennwort") == true)
        }
    }

    func testUnerreichbarerBrokerHaengtNicht() {
        let zugang = MQTTZugang(host: "127.0.0.1", port: 1, benutzer: nil,
                                kennwort: nil, clientID: "tc002-app")
        let start = Date()
        XCTAssertThrowsError(try MQTTSender(frist: 2).senden(Data("x".utf8), an: "t", zugang: zugang))
        XCTAssertLessThan(Date().timeIntervalSince(start), 8, "endet innerhalb der Frist")
    }
}
