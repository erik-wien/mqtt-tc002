import Foundation
import Network

/// Zerlegt den TCP-Strom in einzelne MQTT-Pakete.
///
/// TCP liefert keine Pakete, sondern einen Strom: zwei MQTT-Nachrichten koennen
/// in einem Lesevorgang ankommen, eine ueber zwei verteilt sein. Deshalb wird
/// gesammelt und erst herausgegeben, was vollstaendig da ist — abzulesen an der
/// Restlaenge, die selbst schon mehrere Bytes lang sein kann.
struct Paketstrom {
    private var puffer = Data()

    mutating func aufnehmen(_ daten: Data) -> [Data] {
        puffer.append(daten)
        var pakete: [Data] = []
        while puffer.count >= 2 {
            guard let (rest, laengenBytes) = MQTTPaket.restlaengeGelesen(puffer, ab: 1) else {
                // Mehr als vier Laengenbytes gibt es nicht. Ist die Laenge nach
                // fuenf Bytes noch nicht lesbar, ist der Strom kaputt — weiter zu
                // puffern hiesse, ihn unbegrenzt wachsen zu lassen.
                if puffer.count >= 5 { puffer.removeAll() }
                break
            }
            let gesamt = 1 + laengenBytes + rest
            guard puffer.count >= gesamt else { break }
            pakete.append(Data(puffer.prefix(gesamt)))
            puffer.removeFirst(gesamt)
        }
        return pakete
    }
}

/// Bleibt am Broker und hoert zu. Anders als `MQTTSender`, der nach dem Senden
/// gleich wieder auflegt, zaehlt hier gerade die stehende Verbindung: die Uhr
/// veroeffentlicht ihre Anzeigenliste und ihren Zustand, wann es ihr passt — wer
/// nicht verbunden ist, verpasst es ersatzlos.
///
/// Alles laeuft auf einer eigenen seriellen Warteschlange; auch die
/// Rueckmeldungen kommen von dort. Ein Aufrufer mit eigener Isolierung — etwa
/// `AppZustand` — muss selbst zuruecksteuern.
public final class MQTTAbonnent: @unchecked Sendable {
    private let zugang: MQTTZugang
    private let themen: [String]
    private let warteschlange = DispatchQueue(label: "tc002.abonnent")

    /// Kuerzer als die im CONNECT vereinbarten 60 Sekunden: der Broker wirft die
    /// Verbindung nach dem Anderthalbfachen der Frist hinaus, und ein verspaeteter
    /// Ping faellt sonst nur dadurch auf, dass nichts mehr ankommt.
    private static let pingAbstand: TimeInterval = 30
    /// Wachsender Abstand, aber gedeckelt — ein abgestuerzter Broker darf weder
    /// in einer engen Schleife angerufen noch fuer immer aufgegeben werden.
    private static let wartezeiten: [TimeInterval] = [2, 4, 8, 30]

    private var verbindung: NWConnection?
    private var strom = Paketstrom()
    private var pingUhr: DispatchSourceTimer?
    private var neuversuch: DispatchWorkItem?
    private var versuche = 0
    private var laeuft = false

    /// Wird bei jeder eintreffenden Nachricht gerufen, auf einer eigenen Warteschlange.
    public var beiNachricht: ((_ thema: String, _ nutzlast: Data) -> Void)?
    /// Wird gerufen, wenn die Verbindung steht oder abreisst.
    public var beiZustand: ((_ verbunden: Bool, _ grund: String?) -> Void)?

    public init(zugang: MQTTZugang, themen: [String]) {
        self.zugang = zugang
        self.themen = themen
    }

    public func starten() {
        warteschlange.async { [self] in
            guard !laeuft else { return }
            laeuft = true
            versuche = 0
            verbinden()
        }
    }

    public func beenden() {
        warteschlange.async { [self] in
            laeuft = false
            abbauen()
        }
    }

    // MARK: - Verbindung

    private func verbinden() {
        guard laeuft, verbindung == nil else { return }
        guard let port = NWEndpoint.Port(rawValue: zugang.port) else {
            beiZustand?(false, "Der Broker-Port ist keine gültige Zahl.")
            return
        }
        let v = NWConnection(host: NWEndpoint.Host(zugang.host), port: port, using: .tcp)
        verbindung = v
        strom = Paketstrom()
        v.stateUpdateHandler = { [weak self] zustand in
            guard let self else { return }
            switch zustand {
            case .ready:
                self.sende(MQTTPaket.connect(clientID: self.zugang.clientID,
                                             benutzer: self.zugang.benutzer,
                                             kennwort: self.zugang.kennwort))
            case .failed(let f): self.abgerissen(f.localizedDescription)
            case .waiting(let f): self.abgerissen(f.localizedDescription)
            default: break
            }
        }
        v.start(queue: warteschlange)
        empfangen(v)
    }

    /// Baut alles ab, was zu einer Verbindung gehoert. Danach ist `verbindung`
    /// nil — daran erkennen `abgerissen` und `verbinden`, dass sie nichts doppelt
    /// tun duerfen.
    private func abbauen() {
        pingUhr?.cancel(); pingUhr = nil
        neuversuch?.cancel(); neuversuch = nil
        verbindung?.stateUpdateHandler = nil
        verbindung?.cancel()
        verbindung = nil
        strom = Paketstrom()
    }

    /// Ein Abriss kann aus zwei Richtungen gemeldet werden — Zustandswechsel und
    /// Lesefehler —, gezaehlt wird er nur einmal.
    private func abgerissen(_ grund: String?) {
        guard verbindung != nil else { return }
        abbauen()
        beiZustand?(false, grund)
        guard laeuft else { return }
        let wartezeit = Self.wartezeiten[min(versuche, Self.wartezeiten.count - 1)]
        versuche += 1
        let arbeit = DispatchWorkItem { [weak self] in self?.verbinden() }
        neuversuch = arbeit
        warteschlange.asyncAfter(deadline: .now() + wartezeit, execute: arbeit)
    }

    private func sende(_ daten: Data) {
        verbindung?.send(content: daten, completion: .contentProcessed { [weak self] fehler in
            if let fehler { self?.abgerissen(fehler.localizedDescription) }
        })
    }

    private func empfangen(_ v: NWConnection) {
        v.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] daten, _, beendet, fehler in
            guard let self else { return }
            if let daten, !daten.isEmpty {
                for paket in self.strom.aufnehmen(daten) { self.verarbeiten(paket) }
            }
            if let fehler { self.abgerissen(fehler.localizedDescription); return }
            if beendet { self.abgerissen("Der Broker hat die Verbindung geschlossen."); return }
            // Nach einem Abbau gehoert diese Verbindung nicht mehr uns: weiterzulesen
            // hielte sie am Leben und liesse ihre Nachrichten noch durch.
            guard self.verbindung === v else { return }
            self.empfangen(v)
        }
    }

    private func verarbeiten(_ paket: Data) {
        guard let typ = paket.first else { return }
        switch typ {
        case 0x20:
            guard let code = MQTTPaket.connackCode(paket) else { return }
            guard code == 0 else {
                abgerissen(MQTTFehler.abgelehnt(code: code).errorDescription)
                return
            }
            angemeldet()
        case 0x30:
            guard let (thema, nutzlast) = MQTTPaket.publishGelesen(paket) else { return }
            beiNachricht?(thema, nutzlast)
        case 0x90:
            if let antwort = MQTTPaket.subackGelesen(paket), !antwort.angenommen {
                beiZustand?(false, "Der Broker hat das Abonnement abgelehnt.")
            }
        default:
            break                                   // PINGRESP und alles Weitere
        }
    }

    private func angemeldet() {
        versuche = 0
        // Eine Paketkennung je Thema; 0 ist laut Norm nicht zulaessig.
        for (i, thema) in themen.enumerated() {
            sende(MQTTPaket.subscribe(thema: thema, paketID: UInt16(i + 1)))
        }
        pingStarten()
        beiZustand?(true, nil)
    }

    private func pingStarten() {
        pingUhr?.cancel()
        let uhr = DispatchSource.makeTimerSource(queue: warteschlange)
        uhr.schedule(deadline: .now() + Self.pingAbstand, repeating: Self.pingAbstand)
        uhr.setEventHandler { [weak self] in self?.sende(MQTTPaket.pingreq()) }
        uhr.resume()
        pingUhr = uhr
    }
}
