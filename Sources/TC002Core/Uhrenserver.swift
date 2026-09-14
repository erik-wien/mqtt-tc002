import Foundation
import Network

/// **Das Beiwerk zur virtuellen Uhr**: ein winziger HTTP-Dienst, der auf einem
/// Port des eigenen Rechners zuhört und jede Anfrage an `Virtuelleuhr`
/// weiterreicht.
///
/// Hier steht nur Netz und Bytes. Was eine Uhr auf welche Anfrage antwortet,
/// steht in `Virtuelleuhr` — und ist dort ohne Steckdose geprüft.
///
/// **HTTP/1.1, eine Anfrage je Verbindung.** Nach der Antwort wird geschlossen
/// (`Connection: close`). Das ist die einfachste Form, die `URLSession`
/// anstandslos mitmacht, und spart die Buchführung über offene Verbindungen —
/// bei einer Uhr, die auf demselben Rechner steht, kostet der Aufbau nichts.
public final class Uhrenserver: @unchecked Sendable {
    /// Die Vorgabe. Fest und nicht vom Betriebssystem vergeben: Die Adresse
    /// steht als `127.0.0.1:8752` in den Einstellungen, und die sollen nach
    /// einem Neustart noch stimmen.
    public static let vorgabePort: UInt16 = 8752

    private let port: NWEndpoint.Port
    private let schlange = DispatchQueue(label: "cloud.eriks.mqtt-tc002.virtuelle-uhr")
    private var lauscher: NWListener?
    private let sperre = NSLock()
    private var _zustand: Uhrzustand

    /// Wird nach jeder Anfrage aufgerufen, die etwas verändert hat — auf dem
    /// Hauptthread, damit die Anzeige sich daran hängen kann.
    public var beiAenderung: ((Uhrzustand) -> Void)?

    public init(port: UInt16 = Uhrenserver.vorgabePort, zustand: Uhrzustand = Uhrzustand()) {
        self.port = NWEndpoint.Port(rawValue: port) ?? 8752
        self._zustand = zustand
    }

    public var zustand: Uhrzustand {
        sperre.lock(); defer { sperre.unlock() }
        return _zustand
    }

    public var laeuft: Bool {
        sperre.lock(); defer { sperre.unlock() }
        return lauscher != nil
    }

    /// Startet den Dienst. Wirft, wenn der Port belegt ist — dann läuft
    /// entweder schon eine virtuelle Uhr oder etwas Fremdes hört dort zu, und
    /// beides ist eine Auskunft, keine Kleinigkeit zum Verschlucken.
    public func starten() throws {
        sperre.lock()
        let schonDa = lauscher != nil
        sperre.unlock()
        guard !schonDa else { return }

        let einstellungen = NWParameters.tcp
        einstellungen.allowLocalEndpointReuse = true
        // Nur der eigene Rechner. Eine virtuelle Uhr, die im Hausnetz zu sehen
        // ist, hat dort nichts verloren.
        einstellungen.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: port)
        let neu = try NWListener(using: einstellungen)
        neu.newConnectionHandler = { [weak self] verbindung in
            self?.bedienen(verbindung)
        }
        neu.start(queue: schlange)
        sperre.lock(); lauscher = neu; sperre.unlock()
    }

    public func beenden() {
        sperre.lock()
        let alt = lauscher
        lauscher = nil
        sperre.unlock()
        alt?.cancel()
    }

    // MARK: - Eine Verbindung

    private func bedienen(_ verbindung: NWConnection) {
        verbindung.start(queue: schlange)
        lesen(verbindung, bisher: Data())
    }

    private func lesen(_ verbindung: NWConnection, bisher: Data) {
        verbindung.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] teil, _, fertig, fehler in
            guard let self else { return }
            var daten = bisher
            if let teil { daten.append(teil) }
            if fehler != nil { verbindung.cancel(); return }

            if let anfrage = Self.zerlegen(daten) {
                self.antworten(verbindung, auf: anfrage)
                return
            }
            if fertig { verbindung.cancel(); return }
            self.lesen(verbindung, bisher: daten)
        }
    }

    private func antworten(_ verbindung: NWConnection, auf anfrage: Virtuelleuhr.Anfrage) {
        sperre.lock()
        let antwort = Virtuelleuhr.beantworten(anfrage, &_zustand)
        let neuerZustand = _zustand
        sperre.unlock()

        if let beiAenderung {
            DispatchQueue.main.async { beiAenderung(neuerZustand) }
        }

        var kopf = "HTTP/1.1 \(antwort.status) \(antwort.status == 200 ? "OK" : "Not Found")\r\n"
        kopf += "Content-Type: application/json\r\n"
        kopf += "Content-Length: \(antwort.koerper.count)\r\n"
        kopf += "Connection: close\r\n\r\n"
        var hinaus = Data(kopf.utf8)
        hinaus.append(antwort.koerper)
        verbindung.send(content: hinaus, completion: .contentProcessed { _ in
            verbindung.cancel()
        })
    }

    // MARK: - Bytes zu einer Anfrage

    /// `nil` heisst: noch nicht vollstaendig, weiterlesen.
    ///
    /// Gelesen wird genau so viel, wie diese App verschickt: Anfragezeile,
    /// Kopfzeilen, und ein Rumpf, dessen Laenge in `Content-Length` steht.
    /// Stueckweise uebertragene Rumpfe (`chunked`) gibt es hier nicht —
    /// `URLSession` schickt `Content-Length`.
    static func zerlegen(_ daten: Data) -> Virtuelleuhr.Anfrage? {
        let trenner = Data("\r\n\r\n".utf8)
        guard let ende = daten.range(of: trenner) else { return nil }
        let kopfteil = String(decoding: daten[daten.startIndex..<ende.lowerBound], as: UTF8.self)
        var zeilen = kopfteil.components(separatedBy: "\r\n")
        guard !zeilen.isEmpty else { return nil }
        let erste = zeilen.removeFirst().components(separatedBy: " ")
        guard erste.count >= 2 else { return nil }

        var laenge = 0
        for zeile in zeilen {
            let teile = zeile.components(separatedBy: ":")
            guard teile.count >= 2,
                  teile[0].lowercased().trimmingCharacters(in: .whitespaces) == "content-length"
            else { continue }
            laenge = Int(teile[1].trimmingCharacters(in: .whitespaces)) ?? 0
        }
        let rumpf = daten[ende.upperBound...]
        guard rumpf.count >= laenge else { return nil }

        // Pfad und Abfrage sauber auseinandernehmen — ein Anzeigename darf
        // alles enthalten, was jemand eintippt, und steht darum kodiert da.
        let teile = URLComponents(string: "http://uhr" + erste[1])
        let abfrage = (teile?.queryItems ?? []).reduce(into: [String: String]()) { ergebnis, feld in
            ergebnis[feld.name] = feld.value ?? ""
        }
        return Virtuelleuhr.Anfrage(erste[0], teile?.path ?? erste[1],
                                    abfrage: abfrage,
                                    koerper: Data(rumpf.prefix(laenge)))
    }
}
