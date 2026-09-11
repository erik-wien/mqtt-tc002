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

    var brokerHost: String { didSet { merke(brokerHost, "brokerHost"); brokerStand = .unbekannt } }
    var brokerPort: String { didSet { merke(brokerPort, "brokerPort"); brokerStand = .unbekannt } }
    var benutzer: String { didSet { merke(benutzer, "benutzer"); brokerStand = .unbekannt } }
    /// Ohne Schluesselbund-Schreibvorgang im didSet: jeder Schreibvorgang loeschte den
    /// Eintrag und legte ihn neu an — das gehoert nicht an jeden Tastendruck.
    /// `kennwortSichern()` ruft, wer die Eingabe abschliesst.
    var kennwort: String { didSet { brokerStand = .unbekannt } }

    enum Brokerstand: Equatable {
        case unbekannt
        case laeuft
        case angenommen
        case abgelehnt(String)
    }

    /// Nicht gesichert: eine Momentaufnahme der letzten Pruefung, keine Einstellung.
    /// Jede Aenderung an Adresse, Port, Konto oder Kennwort setzt sie zurueck, damit
    /// kein veraltetes „angenommen“ stehenbleibt.
    var brokerStand: Brokerstand = .unbekannt

    var fehler: String?
    var protokoll: [String] = []

    /// Die Uhr verrät nicht, welche Anzeigen sie kennt — die App merkt sich, was sie
    /// selbst angelegt hat. Je Uhr getrennt: „Löschen“ schickt die leere Nutzlast nur
    /// an eine Uhr, und nach einem Versand „an alle“ bliebe die Anzeige auf den
    /// übrigen stehen — und blockiert dort alles Weitere —, während die App sie
    /// vergessen hätte.
    var bekannteAnzeigen: [UUID: [String]] { didSet { anzeigenSichern() } }

    /// Der zuletzt gesicherte Wert — Grundlage dafuer, dass mehrfache Aufrufe
    /// (Fokuswechsel, .onDisappear, Beenden) gefahrlos sind: ein unveraenderter
    /// Wert loest keinen zweiten Schluesselbund-Schreibvorgang aus.
    private var kennwortGesichert: String?

    func kennwortSichern() {
        guard kennwort != kennwortGesichert else { return }
        guard Schluesselbund.setzen(kennwort, fuer: "broker") else {
            fehler = "Das Kennwort ließ sich nicht im Schlüsselbund sichern."
            return
        }
        kennwortGesichert = kennwort
    }

    /// Sichert die Broker-Angaben ausdruecklich und fragt den Broker, ob er sie
    /// annimmt. Ohne das erfaehrt man einen Tippfehler im Kennwort erst dann,
    /// wenn eine Sendung stillschweigend nicht ankommt.
    func brokerSichernUndPruefen() {
        kennwortSichern()
        guard let zugang else {
            brokerStand = .abgelehnt("Broker-Port muss eine Zahl über 0 sein.")
            return
        }
        brokerStand = .laeuft
        Task.detached { [weak self] in
            // Blockiert bis zu acht Sekunden — nicht auf dem Hauptthread.
            var pruefZugang = zugang
            pruefZugang.clientID = "tc002-app-pruef"
            do {
                try MQTTSender().pruefen(zugang: pruefZugang)
                await MainActor.run { [weak self] in self?.brokerStand = .angenommen }
            } catch {
                let meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                await MainActor.run { [weak self] in self?.brokerStand = .abgelehnt(meldung) }
            }
        }
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
        let flach = (try? JSONDecoder().decode([String: [String]].self,
                        from: d.data(forKey: "bekannteAnzeigen") ?? Data())) ?? [:]
        // uniquingKeysWith statt uniqueKeysWithValues: UUID(uuidString:) ist gegenueber
        // Gross-/Kleinschreibung nachsichtig, zwei von Hand verbogene Schluessel in
        // unterschiedlicher Schreibweise ergaeben sonst denselben Schluessel und liessen
        // die App beim Start abstuerzen. Der erste Eintrag gewinnt.
        bekannteAnzeigen = Dictionary(
            flach.compactMap { text, liste in UUID(uuidString: text).map { ($0, liste) } },
            uniquingKeysWith: { erster, _ in erster })
        if aktiveID == nil { aktiveID = uhren.first?.id }
        // Aus der Zeit, als die Liste keinen Uhrenbezug hatte: sie meinte die aktive
        // Uhr, also gehört sie dorthin. Sonst bliebe eine stehende Anzeige auf ihr
        // liegen, ohne dass es noch einen Weg gäbe, sie zu löschen.
        if bekannteAnzeigen.isEmpty, let alt = d.stringArray(forKey: "bekannteAnzeigen"),
           let id = aktiveID {
            bekannteAnzeigen[id] = alt
            d.removeObject(forKey: "bekannteAnzeigen")
        }
        kennwortGesichert = kennwort
        initialisiert = true
    }

    func anzeigeGemerkt(_ name: String, fuer id: UUID) {
        var liste = bekannteAnzeigen[id] ?? []
        guard !liste.contains(name) else { return }
        liste.append(name)
        bekannteAnzeigen[id] = liste
    }

    func anzeigenDerAktiven() -> [String] {
        guard let id = aktiveID else { return [] }
        return bekannteAnzeigen[id] ?? []
    }

    func anzeigeVergessen(_ name: String, fuer id: UUID) {
        bekannteAnzeigen[id]?.removeAll { $0 == name }
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
        bekannteAnzeigen[id] = nil
        if aktiveID == id { aktiveID = uhren.first?.id }
    }

    /// Eine geaenderte Adresse zeigt womoeglich auf eine andere Uhr. Praefix und MAC
    /// gehoeren dann noch zur alten — blieben sie stehen, wuerde weiter auf das alte
    /// Thema gesendet, an die alte Uhr oder ins Leere, ohne jeden Hinweis.
    func adresseGeaendert(_ id: UUID) {
        guard let i = uhren.firstIndex(where: { $0.id == id }) else { return }
        guard !uhren[i].praefix.isEmpty || !uhren[i].mac.isEmpty || verbunden[id] != nil else { return }
        uhren[i].praefix = ""
        uhren[i].mac = ""
        verbunden[id] = nil
    }

    /// Holt Praefix, MAC und Verbindungsstand vom Geraet.
    func abfragen(_ id: UUID) {
        guard let uhr = uhren.first(where: { $0.id == id }) else { return }
        let host = uhr.host
        Task.detached { [weak self] in
            do {
                let geraet = Geraet(host: host)
                // In einem Zug: getrennt geholt kaeme /getBase zweimal dran.
                let (praefix, basis) = try geraet.praefixUndBasis()
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

    /// Liefert `anzeigen(fuer:)` nichts, fehlt das Praefix oder der Broker-Port ist
    /// keine brauchbare Zahl. Eine Meldung dafuer, statt stumm zurueckzukehren.
    nonisolated static func zugangsmeldung(_ uhr: Uhr) -> String {
        "\(uhr.name): Zugangsdaten unvollständig — Broker-Port prüfen."
    }

    /// Schickt einen Rahmen an eine oder alle eingerichteten Uhren. Ein Zweig je Uhr:
    /// MQTTSender wartet bis zu acht Sekunden, eine unerreichbare Uhr darf die
    /// anderen nicht aufhalten. Fehler landen sichtbar in `fehler`, nicht nur im
    /// Protokoll — sonst ist ein Totalausfall von Erfolg nicht zu unterscheiden.
    func senden(_ frame: Frame, als name: String, anAlle: Bool) async {
        let ziele = ziele(alle: anAlle)
        guard !ziele.isEmpty else {
            fehler = "Keine Uhr eingerichtet. Unter „Verbindung“ eine eintragen und abfragen."
            return
        }
        var meldungen: [String] = []
        await withTaskGroup(of: String?.self) { gruppe in
            for uhr in ziele {
                gruppe.addTask { [weak self] in
                    guard let anzeigen = await self?.anzeigen(fuer: uhr) else {
                        return AppZustand.zugangsmeldung(uhr)
                    }
                    do {
                        try anzeigen.zeigen(frame, auf: name)
                        await self?.erfolg(uhr: uhr, name: name)
                        return nil
                    } catch {
                        return "\(uhr.name): \((error as? LocalizedError)?.errorDescription ?? "\(error)")"
                    }
                }
            }
            for await m in gruppe { if let m { meldungen.append(m) } }
        }
        fehler = meldungen.isEmpty ? nil : meldungen.joined(separator: "\n")
    }

    private func erfolg(uhr: Uhr, name: String) {
        anzeigeGemerkt(name, fuer: uhr.id)
        log("an \(uhr.name) gesendet: \(name)")
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

    /// UserDefaults kennt keine UUID-Schluessel — deshalb als JSON ueber die
    /// Zeichenketten-Fassung der Kennungen.
    private func anzeigenSichern() {
        guard initialisiert else { return }
        let flach = Dictionary(uniqueKeysWithValues:
            bekannteAnzeigen.map { ($0.key.uuidString, $0.value) })
        guard let daten = try? JSONEncoder().encode(flach) else { return }
        UserDefaults.standard.set(daten, forKey: "bekannteAnzeigen")
    }

    private func merke(_ wert: String?, _ schluessel: String) {
        guard initialisiert else { return }
        UserDefaults.standard.set(wert, forKey: schluessel)
    }
}
