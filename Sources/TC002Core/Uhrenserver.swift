import Foundation
import Network

/// Das Beiwerk zur virtuellen Uhr: ein winziger HTTP-Dienst, der auf einem
/// Port des eigenen Rechners zuhört und jede Anfrage an `VirtuelleNGUhr`
/// weiterreicht.
///
/// Hier steht nur Netz und Bytes. Was eine Uhr auf welche Anfrage antwortet,
/// steht in `VirtuelleNGUhr` — und ist dort ohne Steckdose geprüft.
///
/// HTTP/1.1, eine Anfrage je Verbindung. Nach der Antwort wird geschlossen
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
    private var _zustand: NGUhrzustand

    /// Wird nach jeder Anfrage aufgerufen, die etwas verändert hat — auf dem
    /// Hauptthread, damit die Anzeige sich daran hängen kann.
    public var beiAenderung: ((NGUhrzustand) -> Void)?

    public init(port: UInt16 = Uhrenserver.vorgabePort, zustand: NGUhrzustand = NGUhrzustand()) {
        self.port = NWEndpoint.Port(rawValue: port) ?? 8752
        self._zustand = zustand
    }

    public var zustand: NGUhrzustand {
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

            switch Self.einlesen(daten) {
            case .abweisen(let antwort):
                self.senden(verbindung, antwort)
                return
            case .fertig(let anfrage):
                self.antworten(verbindung, auf: anfrage)
                return
            case .mehr:
                break
            }
            if fertig { verbindung.cancel(); return }
            self.lesen(verbindung, bisher: daten)
        }
    }

    private func antworten(_ verbindung: NWConnection, auf anfrage: Virtuelleuhr.Anfrage) {
        sperre.lock()
        let antwort = VirtuelleNGUhr.beantworten(anfrage, &_zustand)
        let neuerZustand = _zustand
        sperre.unlock()

        if let beiAenderung {
            DispatchQueue.main.async { beiAenderung(neuerZustand) }
        }
        senden(verbindung, antwort)
    }

    private func senden(_ verbindung: NWConnection, _ antwort: Virtuelleuhr.Antwort) {
        var kopf = "HTTP/1.1 \(antwort.status) \(Self.grund(antwort.status))\r\n"
        kopf += "Content-Type: \(antwort.inhaltstyp)\r\n"
        kopf += "Content-Length: \(antwort.koerper.count)\r\n"
        kopf += "Connection: close\r\n\r\n"
        var hinaus = Data(kopf.utf8)
        hinaus.append(antwort.koerper)
        verbindung.send(content: hinaus, completion: .contentProcessed { _ in
            verbindung.cancel()
        })
    }

    private static func grund(_ status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 413: return "Payload Too Large"
        case 415: return "Unsupported Media Type"
        case 422: return "Unprocessable Entity"
        case 507: return "Insufficient Storage"
        default: return "Error"
        }
    }

    // MARK: - Bytes zu einer Anfrage

    /// Der Kopfbereich (Anfragezeile und Kopfzeilen) ist hoechstens so gross.
    static let maxKopf = 16 * 1024

    enum Lesestand {
        /// Noch nicht vollstaendig, weiterlesen.
        case mehr
        /// Die Anfrage sprengt eine Grenze oder ist nicht eindeutig; die
        /// Antwort geht hinaus, danach wird geschlossen.
        case abweisen(Virtuelleuhr.Antwort)
        case fertig(Virtuelleuhr.Anfrage)
    }

    private static func zeichenDesTokens(_ b: UInt8) -> Bool {
        (b >= 48 && b <= 57) || (b >= 65 && b <= 90) || (b >= 97 && b <= 122)
            || "!#$%&'*+-.^_`|~".utf8.contains(b)
    }

    /// Liest eine Anfrage — Kopf, Grenzen und Rumpf in einem Zug, damit die
    /// Groessenpruefung und das Einlesen des Rumpfes denselben, einmal
    /// ermittelten `Content-Length` benutzen.
    ///
    /// Eindeutigkeit vor Grosszuegigkeit: Zwei verschiedene Leser derselben
    /// Anfrage duerfen nicht verschiedene Laengen sehen. Abgewiesen mit `400`
    /// wird deshalb
    ///
    /// - ein Kopf ohne Ende ueber `maxKopf`, ein Kopf nicht aus UTF-8;
    /// - eine Zeile ohne Doppelpunkt, ein Kopfname mit Zeichen ausserhalb des
    ///   HTTP-Token-Zeichensatzes (auch Leerraum vor dem Doppelpunkt);
    /// - mehr als ein `Content-Length`, auch mit gleichem Wert;
    /// - ein `Content-Length`, das nicht nur aus Ziffern besteht;
    /// - `Transfer-Encoding`: Stueckweise uebertragene Rumpfe kann die
    ///   virtuelle Uhr nicht lesen.
    ///
    /// Ein `Content-Length` ueber `VirtuelleNGUhr.maxRumpf` ist sofort `413`.
    static func einlesen(_ daten: Data) -> Lesestand {
        let zuGross = VirtuelleNGUhr.fehler(413, "payloadTooLarge", "payload too large")
        let schlecht = VirtuelleNGUhr.fehler(400, "badRequest", "bad request")
        guard let ende = daten.range(of: Data("\r\n\r\n".utf8)) else {
            return daten.count > maxKopf ? .abweisen(schlecht) : .mehr
        }
        let kopfLaenge = daten.distance(from: daten.startIndex, to: ende.lowerBound)
        guard kopfLaenge <= maxKopf,
              let kopfteil = String(data: daten[daten.startIndex..<ende.lowerBound], encoding: .utf8)
        else { return .abweisen(schlecht) }

        var zeilen = kopfteil.components(separatedBy: "\r\n")
        let erste = zeilen.removeFirst().components(separatedBy: " ")
        guard erste.count >= 2 else { return .abweisen(schlecht) }

        var kopf: [String: String] = [:]
        var laengenangaben: [String] = []
        for zeile in zeilen {
            guard let doppelpunkt = zeile.firstIndex(of: ":") else { return .abweisen(schlecht) }
            let rohName = zeile[..<doppelpunkt]
            guard !rohName.isEmpty, rohName.utf8.allSatisfy(zeichenDesTokens) else { return .abweisen(schlecht) }
            let name = rohName.lowercased()
            let wert = zeile[zeile.index(after: doppelpunkt)...].trimmingCharacters(in: .whitespaces)
            if name == "transfer-encoding" { return .abweisen(schlecht) }
            if name == "content-length" { laengenangaben.append(wert) }
            kopf[name] = wert
        }
        if laengenangaben.count > 1 { return .abweisen(schlecht) }
        var laenge = 0
        if let angabe = laengenangaben.first {
            guard !angabe.isEmpty, angabe.count <= 18, angabe.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
                  let zahl = Int(angabe) else { return .abweisen(schlecht) }
            guard zahl <= VirtuelleNGUhr.maxRumpf else { return .abweisen(zuGross) }
            laenge = zahl
        }
        let rumpf = daten[ende.upperBound...]
        guard rumpf.count >= laenge else { return .mehr }

        // Pfad und Abfrage sauber auseinandernehmen — ein Anzeigename darf
        // alles enthalten, was jemand eintippt, und steht darum kodiert da.
        let teile = URLComponents(string: "http://uhr" + erste[1])
        let abfrage = (teile?.queryItems ?? []).reduce(into: [String: String]()) { ergebnis, feld in
            ergebnis[feld.name] = feld.value ?? ""
        }
        return .fertig(Virtuelleuhr.Anfrage(erste[0], teile?.path ?? erste[1],
                                            abfrage: abfrage,
                                            koerper: Data(rumpf.prefix(laenge)), kopf: kopf))
    }

    /// `nil` heisst: noch nicht vollstaendig oder abgewiesen.
    static func zerlegen(_ daten: Data) -> Virtuelleuhr.Anfrage? {
        if case .fertig(let anfrage) = einlesen(daten) { return anfrage }
        return nil
    }

    /// Die Antwort, mit der eine Anfrage vor dem vollstaendigen Empfang
    /// abgewiesen wird — `nil`, wenn sie weiterzulesen oder fertig ist.
    static func vorabpruefung(_ daten: Data) -> Virtuelleuhr.Antwort? {
        if case .abweisen(let antwort) = einlesen(daten) { return antwort }
        return nil
    }
}
