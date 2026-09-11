import Foundation
import Observation
import TC002Core

/// Eine eingerichtete Uhr. Praefix und MAC ermittelt die App selbst beim Abfragen —
/// sie werden nie von Hand eingetragen.
struct Uhr: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var host: String
    var praefix: String = ""
    var mac: String = ""
}

@Observable
@MainActor
final class AppZustand {
    var uhren: [Uhr] { didSet { uhrenSichern() } }
    var aktiveID: UUID? { didSet { merke(aktiveID?.uuidString, "aktiveID") } }
    /// Nicht gesichert: der Verbindungsstand ist eine Momentaufnahme, keine Einstellung.
    var verbunden: [UUID: Bool] = [:]

    var brokerHost: String { didSet { merke(brokerHost, "brokerHost") } }
    var brokerPort: String { didSet { merke(brokerPort, "brokerPort") } }
    var benutzer: String { didSet { merke(benutzer, "benutzer") } }
    var kennwort: String { didSet { Schluesselbund.setzen(kennwort, fuer: "broker") } }

    var fehler: String?
    var protokoll: [String] = []

    /// Die Uhr verrät nicht, welche Anzeigen sie kennt — die App merkt sich, was sie
    /// selbst angelegt hat.
    var bekannteAnzeigen: [String] {
        didSet { UserDefaults.standard.set(bekannteAnzeigen, forKey: "bekannteAnzeigen") }
    }

    private var initialisiert = false

    init() {
        let d = UserDefaults.standard
        uhren = (try? JSONDecoder().decode([Uhr].self,
                    from: d.data(forKey: "uhren") ?? Data())) ?? []
        aktiveID = d.string(forKey: "aktiveID").flatMap(UUID.init(uuidString:))
        brokerHost = d.string(forKey: "brokerHost") ?? "192.168.1.10"
        brokerPort = d.string(forKey: "brokerPort") ?? "1883"
        benutzer   = d.string(forKey: "benutzer") ?? "pixdeck"
        kennwort   = Schluesselbund.lesen("broker") ?? ""
        bekannteAnzeigen = d.stringArray(forKey: "bekannteAnzeigen") ?? []
        if aktiveID == nil { aktiveID = uhren.first?.id }
        initialisiert = true
    }

    func anzeigeGemerkt(_ name: String) {
        guard !bekannteAnzeigen.contains(name) else { return }
        bekannteAnzeigen.append(name)
    }

    var aktiveUhr: Uhr? { uhren.first { $0.id == aktiveID } }

    func log(_ zeile: String) {
        protokoll.append(zeile)
        if protokoll.count > 300 { protokoll.removeFirst(protokoll.count - 300) }
    }

    /// Legt eine Uhr an und fragt sie sofort ab. Der Name kommt aus der Geraetekennung,
    /// laesst sich aber aendern — bei mehreren Uhren ist "Kueche" hilfreicher als eine MAC.
    func uhrHinzufuegen(host: String) {
        let neue = Uhr(name: host, host: host)
        uhren.append(neue)
        if aktiveID == nil { aktiveID = neue.id }
        abfragen(neue.id)
    }

    func uhrEntfernen(_ id: UUID) {
        uhren.removeAll { $0.id == id }
        verbunden[id] = nil
        if aktiveID == id { aktiveID = uhren.first?.id }
    }

    /// Holt Praefix, MAC und Verbindungsstand vom Geraet.
    func abfragen(_ id: UUID) {
        guard let uhr = uhren.first(where: { $0.id == id }) else { return }
        let host = uhr.host
        Task.detached { [weak self] in
            do {
                let geraet = Geraet(host: host)
                let praefix = try geraet.themenPraefix()
                let basis = try geraet.basis()
                let steht = try geraet.verbunden()
                await MainActor.run { [weak self] in
                    guard let self, let i = self.uhren.firstIndex(where: { $0.id == id }) else { return }
                    self.uhren[i].praefix = praefix
                    self.uhren[i].mac = basis.mac
                    if self.uhren[i].name == self.uhren[i].host { self.uhren[i].name = praefix }
                    self.verbunden[id] = steht
                    self.log("\(self.uhren[i].name): Präfix \(praefix), MQTT \(steht ? "verbunden" : "nicht verbunden")")
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.verbunden[id] = nil
                    self?.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                }
            }
        }
    }

    /// Der Port wird hier geprueft, nicht erst beim Verbinden: NWEndpoint.Port lehnt die 0
    /// ab und stuerzt bei erzwungenem Auspacken ab.
    private var zugang: MQTTZugang? {
        guard let port = UInt16(brokerPort), port > 0 else { return nil }
        return MQTTZugang(host: brokerHost, port: port,
                          benutzer: benutzer.isEmpty ? nil : benutzer,
                          kennwort: kennwort.isEmpty ? nil : kennwort)
    }

    func anzeigen(fuer uhr: Uhr) -> Anzeigen? {
        guard !uhr.praefix.isEmpty, var zugang else { return nil }
        // Eigene Kennung je Uhr: ein Broker trennt die bestehende Sitzung, sobald
        // dieselbe Kennung erneut verbindet. Mit einer festen Kennung wuerfen sich
        // gleichzeitige Sendungen an mehrere Uhren gegenseitig hinaus.
        zugang.clientID = "tc002-app-" + uhr.id.uuidString.prefix(8).lowercased()
        return Anzeigen(sender: MQTTSender(), zugang: zugang, praefix: uhr.praefix)
    }

    /// Ziel einer Sendung: die aktive Uhr, oder alle eingerichteten.
    func ziele(alle: Bool) -> [Uhr] {
        alle ? uhren.filter { !$0.praefix.isEmpty }
             : [aktiveUhr].compactMap { $0 }.filter { !$0.praefix.isEmpty }
    }

    private func uhrenSichern() {
        guard initialisiert, let daten = try? JSONEncoder().encode(uhren) else { return }
        UserDefaults.standard.set(daten, forKey: "uhren")
    }

    private func merke(_ wert: String?, _ schluessel: String) {
        guard initialisiert else { return }
        UserDefaults.standard.set(wert, forKey: schluessel)
    }
}
