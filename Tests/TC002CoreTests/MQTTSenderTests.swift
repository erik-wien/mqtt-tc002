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
        private let publishGesehen = DispatchSemaphore(value: 0)
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
                            if d[d.startIndex] == 0x30 {          // PUBLISH gesehen
                                self?.publishGesehen.signal()
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

        /// Wartet, bis der Lauscher ein PUBLISH gesehen hat (statt sofort mitten im
        /// nebenlaeufigen Empfang zu lesen). `senden()` kehrt bereits zurueck, sobald
        /// die Bytes abgeschickt sind — nicht, sobald der Lauscher sie eingesammelt hat.
        func wartetAufPublish(frist: TimeInterval = 5) -> Bool {
            publishGesehen.wait(timeout: .now() + frist) == .success
        }
    }

    func testSendetConnectUndPublish() throws {
        let lauscher = try Lauscher(connackCode: 0)
        defer { lauscher.stoppen() }
        let zugang = MQTTZugang(host: "127.0.0.1", port: lauscher.port,
                                benutzer: "pixdeck", kennwort: "geheim", clientID: "tc002-app")

        try MQTTSender().senden(Data("HI".utf8), an: "awtrix_a86b/custom/test", zugang: zugang)

        XCTAssertTrue(lauscher.wartetAufPublish(), "PUBLISH ist beim Lauscher angekommen")
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

    /// Der erste Grund ist der, auf den der Aufrufer gewartet hat — spaetere
    /// Zustandswechsel duerfen ihn nicht ueberschreiben.
    func testFehlerfachBehaeltDenErstenGrund() {
        let fach = Fehlerfach()
        XCTAssertNil(fach.gemeldet)
        fach.melden("zuerst")
        fach.melden("danach")
        XCTAssertEqual(fach.gemeldet, "zuerst")
    }

    /// Die Wettlaufstelle: der stateUpdateHandler schreibt auf einer eigenen
    /// Warteschlange, waehrend der Aufrufer liest. Beides zugleich darf weder den
    /// Wert verlieren noch abstuerzen.
    func testFehlerfachVertraegtGleichzeitigesSchreibenUndLesen() {
        let fach = Fehlerfach()
        DispatchQueue.concurrentPerform(iterations: 128) { i in
            if i.isMultiple(of: 2) { fach.melden("Grund \(i)") } else { _ = fach.gemeldet }
        }
        XCTAssertNotNil(fach.gemeldet)
    }

    func testUnerreichbarerBrokerHaengtNicht() {
        let zugang = MQTTZugang(host: "127.0.0.1", port: 1, benutzer: nil,
                                kennwort: nil, clientID: "tc002-app")
        let start = Date()
        XCTAssertThrowsError(try MQTTSender(frist: 2).senden(Data("x".utf8), an: "t", zugang: zugang))
        XCTAssertLessThan(Date().timeIntervalSince(start), 8, "endet innerhalb der Frist")
    }
}
