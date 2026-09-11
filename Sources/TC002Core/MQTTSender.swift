import Foundation
import Network

public struct MQTTZugang: Sendable {
    public var host: String
    public var port: UInt16
    public var benutzer: String?
    public var kennwort: String?
    public var clientID: String

    public init(host: String, port: UInt16 = 1883, benutzer: String?,
                kennwort: String?, clientID: String = "tc002-app") {
        self.host = host; self.port = port
        self.benutzer = benutzer; self.kennwort = kennwort; self.clientID = clientID
    }
}

/// Verbinden, CONNACK lesen, eine Nachricht senden, trennen. Mehr braucht die App nicht.
/// Das CONNACK ist der einzige Punkt, an dem der Broker uns einen Fehler nennen kann —
/// eine abgelehnte Veroeffentlichung bleibt bei Version 3.1.1 stumm.
public struct MQTTSender {
    private let frist: TimeInterval

    public init(frist: TimeInterval = 8) { self.frist = frist }

    public func senden(_ nutzlast: Data, an thema: String, zugang: MQTTZugang) throws {
        let verbindung = NWConnection(
            host: NWEndpoint.Host(zugang.host),
            port: NWEndpoint.Port(rawValue: zugang.port)!,
            using: .tcp)

        let bereit = DispatchSemaphore(value: 0)
        var verbindungsfehler: String?
        verbindung.stateUpdateHandler = { zustand in
            switch zustand {
            case .ready: bereit.signal()
            case .failed(let f): verbindungsfehler = f.localizedDescription; bereit.signal()
            case .waiting(let f): verbindungsfehler = f.localizedDescription; bereit.signal()
            default: break
            }
        }
        verbindung.start(queue: .global())
        defer { verbindung.cancel() }

        guard bereit.wait(timeout: .now() + frist) == .success else { throw MQTTFehler.zeitueberschreitung }
        if let verbindungsfehler { throw MQTTFehler.nichtVerbunden(verbindungsfehler) }

        try sendeRoh(verbindung, MQTTPaket.connect(clientID: zugang.clientID,
                                                   benutzer: zugang.benutzer,
                                                   kennwort: zugang.kennwort))
        let antwort = try lies(verbindung, mindestens: 4)
        guard let code = MQTTPaket.connackCode(antwort) else { throw MQTTFehler.nichtVerbunden("keine gültige Antwort") }
        guard code == 0 else { throw MQTTFehler.abgelehnt(code: code) }

        try sendeRoh(verbindung, MQTTPaket.publish(thema: thema, nutzlast: nutzlast))
        try sendeRoh(verbindung, MQTTPaket.disconnect())
    }

    private func sendeRoh(_ v: NWConnection, _ daten: Data) throws {
        let fertig = DispatchSemaphore(value: 0)
        var fehler: NWError?
        v.send(content: daten, completion: .contentProcessed { fehler = $0; fertig.signal() })
        guard fertig.wait(timeout: .now() + frist) == .success else { throw MQTTFehler.zeitueberschreitung }
        if let fehler { throw MQTTFehler.nichtVerbunden(fehler.localizedDescription) }
    }

    private func lies(_ v: NWConnection, mindestens: Int) throws -> Data {
        let fertig = DispatchSemaphore(value: 0)
        var ergebnis = Data()
        var fehler: NWError?
        v.receive(minimumIncompleteLength: mindestens, maximumLength: 64) { d, _, _, f in
            if let d { ergebnis = d }
            fehler = f
            fertig.signal()
        }
        guard fertig.wait(timeout: .now() + frist) == .success else { throw MQTTFehler.zeitueberschreitung }
        if let fehler { throw MQTTFehler.nichtVerbunden(fehler.localizedDescription) }
        return ergebnis
    }
}
