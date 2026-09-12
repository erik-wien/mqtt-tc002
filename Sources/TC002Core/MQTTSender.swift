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

/// Damit der Anzeigendienst gegen einen Doppelgaenger geprueft werden kann.
public protocol NachrichtSendend {
    func senden(_ nutzlast: Data, an thema: String, zugang: MQTTZugang) throws
}

/// Traegt einen Verbindungsfehler von der Netzwerk-Warteschlange zum wartenden
/// Aufrufer. Noetig, weil das Semaphor nur das erste `signal()` absichert: der
/// stateUpdateHandler kann danach erneut feuern, waehrend der Aufrufer den Wert
/// schon liest. Schreiben und Lesen laufen deshalb unter demselben Schloss.
final class Fehlerfach: @unchecked Sendable {
    private let sperre = NSLock()
    private var wert: String?

    /// Der erste Grund zaehlt — er ist der, auf den das Semaphor freigegeben hat.
    func melden(_ neu: String) {
        sperre.lock(); defer { sperre.unlock() }
        if wert == nil { wert = neu }
    }

    var gemeldet: String? {
        sperre.lock(); defer { sperre.unlock() }
        return wert
    }
}

/// Verbinden, CONNACK lesen, eine Nachricht senden, trennen. Mehr braucht die App nicht.
/// Das CONNACK ist der einzige Punkt, an dem der Broker uns einen Fehler nennen kann —
/// eine abgelehnte Veroeffentlichung bleibt bei Version 3.1.1 stumm.
public struct MQTTSender {
    private let frist: TimeInterval

    public init(frist: TimeInterval = 8) { self.frist = frist }

    public func senden(_ nutzlast: Data, an thema: String, zugang: MQTTZugang) throws {
        let verbindung = try verbundenUndGeprueft(zugang: zugang)
        defer { verbindung.cancel() }

        try sendeRoh(verbindung, MQTTPaket.publish(thema: thema, nutzlast: nutzlast))
        try sendeRoh(verbindung, MQTTPaket.disconnect())
    }

    /// Verbindet, liest das CONNACK und trennt gleich wieder — ohne etwas zu senden.
    /// Wirft denselben Fehler wie `senden`, also insbesondere `.abgelehnt(code: 4)`
    /// bei falschem Konto oder Kennwort.
    public func pruefen(zugang: MQTTZugang) throws {
        let verbindung = try verbundenUndGeprueft(zugang: zugang)
        verbindung.cancel()
    }

    /// Verbindet, sendet das CONNECT-Paket und prueft das CONNACK. Das ist der
    /// einzige Punkt, an dem der Broker einen Fehler nennen kann — danach ist
    /// Version 3.1.1 stumm. Gibt die offene Verbindung zurueck; der Aufrufer
    /// entscheidet, ob er noch etwas sendet oder sie sofort trennt.
    private func verbundenUndGeprueft(zugang: MQTTZugang) throws -> NWConnection {
        let verbindung = NWConnection(
            host: NWEndpoint.Host(zugang.host),
            port: NWEndpoint.Port(rawValue: zugang.port)!,
            using: .tcp)

        let bereit = DispatchSemaphore(value: 0)
        let fach = Fehlerfach()
        verbindung.stateUpdateHandler = { zustand in
            switch zustand {
            case .ready: bereit.signal()
            case .failed(let f): fach.melden(f.localizedDescription); bereit.signal()
            case .waiting(let f): fach.melden(f.localizedDescription); bereit.signal()
            default: break
            }
        }
        verbindung.start(queue: .global())

        guard bereit.wait(timeout: .now() + frist) == .success else {
            verbindung.cancel()
            throw MQTTFehler.zeitueberschreitung
        }
        // Erst abhaengen, dann lesen: sonst schreibt der Handler noch in denselben
        // Wert, der hier gerade geprueft wird.
        verbindung.stateUpdateHandler = nil
        if let grund = fach.gemeldet {
            verbindung.cancel()
            throw MQTTFehler.nichtVerbunden(grund)
        }

        do {
            try sendeRoh(verbindung, MQTTPaket.connect(clientID: zugang.clientID,
                                                       benutzer: zugang.benutzer,
                                                       kennwort: zugang.kennwort))
            let antwort = try lies(verbindung, mindestens: 4)
            guard let code = MQTTPaket.connackCode(antwort) else { throw MQTTFehler.nichtVerbunden(lok("keine gültige Antwort")) }
            guard code == 0 else { throw MQTTFehler.abgelehnt(code: code) }
        } catch {
            verbindung.cancel()
            throw error
        }

        return verbindung
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

extension MQTTSender: NachrichtSendend {}
