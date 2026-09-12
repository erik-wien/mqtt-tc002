import Foundation
import Observation
import TC002Core

// `Uhr` liegt im Kern (`Einstellungen.swift`), weil das Kommandozeilenwerkzeug
// dieselbe Liste liest — die Codable-Form ist damit ein Dateiformat.

@Observable
@MainActor
public final class AppZustand {
    public var uhren: [Uhr] { didSet { uhrenSichern() } }
    public var aktiveID: UUID? { didSet { merke(aktiveID?.uuidString, "aktiveID") } }
    /// An welche Uhren gesendet wird. Ueberlebt den Neustart, weil es eine
    /// Entscheidung ist und keine Momentaufnahme.
    ///
    /// `Einstellungen.ziele` (Kern, fuer Werkzeug und Kurzbefehle) liest eine
    /// leere Menge als "alle", `ziele()` weiter unten dagegen als "die aktive
    /// Uhr" — zwei verschiedene Lesarten desselben leeren Zustands. Statt eine
    /// davon umzudefinieren, halten `init`, `uhrHinzufuegen` und
    /// `uhrEntfernen` diese Menge nichtleer, solange ueberhaupt Uhren
    /// eingerichtet sind — dann stimmen beide Leser trivial ueberein.
    public var zielIDs: Set<UUID> { didSet { zielIDsSichern() } }
    /// Nicht gesichert: der Verbindungsstand ist eine Momentaufnahme, keine Einstellung.
    public var verbunden: [UUID: Bool] = [:]
    /// Was die Uhr selbst als ihre Anzeigen meldet (`<praefix>/customList`, §3.5).
    /// Kein Eintrag heisst: noch nichts empfangen — dann gilt `bekannteAnzeigen`.
    public var gemeldeteAnzeigen: [UUID: [String]] = [:]
    /// Was die Uhr ueber sich selbst meldet (`<praefix>/status`, §3.4).
    public var geraetOnline: [UUID: Bool] = [:]
    /// Was zuletzt auf einem Slot zu sehen war — mitgelesen von `<praefix>/custom/#`,
    /// nicht von der Uhr erfragt (sie verraet den Inhalt selbst nicht). Live-Strom,
    /// kein Gedaechtnis: nur, was waehrend dieser Verbindung gesendet wurde.
    public var slotInhalt: [UUID: [Int: Slotbild]] = [:]

    public var brokerHost: String { didSet { merke(brokerHost, "brokerHost"); brokerStand = .unbekannt } }
    public var brokerPort: String { didSet { merke(brokerPort, "brokerPort"); brokerStand = .unbekannt } }
    public var benutzer: String { didSet { merke(benutzer, "benutzer"); brokerStand = .unbekannt } }
    /// Ohne Schluesselbund-Schreibvorgang im didSet: jeder Schreibvorgang loeschte den
    /// Eintrag und legte ihn neu an — das gehoert nicht an jeden Tastendruck.
    /// `kennwortSichern()` ruft, wer die Eingabe abschliesst.
    public var kennwort: String { didSet { brokerStand = .unbekannt } }

    public enum Brokerstand: Equatable {
        case unbekannt
        case laeuft
        case angenommen
        case abgelehnt(String)
    }

    /// Nicht gesichert: eine Momentaufnahme der letzten Pruefung, keine Einstellung.
    /// Jede Aenderung an Adresse, Port, Konto oder Kennwort setzt sie zurueck, damit
    /// kein veraltetes „angenommen“ stehenbleibt.
    public var brokerStand: Brokerstand = .unbekannt

    /// Jede Fehlermeldung geht an zwei Stellen: in den Hinweis, der sofort auffaellt,
    /// und ins Protokoll, wo sie auch nach dem Wegklicken nachlesbar bleibt.
    public var fehler: String? {
        didSet {
            if let fehler, fehler != oldValue { log(fehler) }
        }
    }
    public var protokoll: [String] = []
    private static let protokollZeit: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    /// Was die App selbst angelegt hat — der Rückfall, solange die Uhr ihre eigene
    /// Liste noch nicht gemeldet hat (`gemeldeteAnzeigen`). Je Uhr getrennt:
    /// „Löschen“ schickt die leere Nutzlast nur
    /// an eine Uhr, und nach einem Versand „an alle“ bliebe die Anzeige auf den
    /// übrigen stehen — und blockiert dort alles Weitere —, während die App sie
    /// vergessen hätte.
    public var bekannteAnzeigen: [UUID: [String]] { didSet { anzeigenSichern() } }

    /// Der zuletzt gesicherte Wert — Grundlage dafuer, dass mehrfache Aufrufe
    /// (Fokuswechsel, .onDisappear, Beenden) gefahrlos sind: ein unveraenderter
    /// Wert loest keinen zweiten Schluesselbund-Schreibvorgang aus.
    private var kennwortGesichert: String?

    public func kennwortSichern() {
        guard kennwort != kennwortGesichert else { return }
        guard Schluesselbund.setzen(kennwort, fuer: "broker") else {
            fehler = lok("Das Kennwort ließ sich nicht im Schlüsselbund sichern.")
            return
        }
        kennwortGesichert = kennwort
    }

    /// Sichert die Broker-Angaben ausdruecklich und fragt den Broker, ob er sie
    /// annimmt. Ohne das erfaehrt man einen Tippfehler im Kennwort erst dann,
    /// wenn eine Sendung stillschweigend nicht ankommt.
    public func brokerSichernUndPruefen() {
        kennwortSichern()
        guard let zugang else {
            let meldung = lok("Broker-Port muss eine Zahl über 0 sein.")
            brokerStand = .abgelehnt(meldung)
            log(lokf("Broker-Prüfung abgelehnt: %@", meldung))
            return
        }
        brokerStand = .laeuft
        Task.detached { [weak self] in
            // Blockiert bis zu acht Sekunden — nicht auf dem Hauptthread.
            var pruefZugang = zugang
            pruefZugang.clientID = "tc002-app-pruef"
            do {
                try MQTTSender().pruefen(zugang: pruefZugang)
                await MainActor.run { [weak self] in
                    self?.brokerStand = .angenommen
                    self?.log(lok("Broker-Prüfung: angenommen"))
                    self?.horchenAbgleichen()
                }
            } catch {
                let meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                await MainActor.run { [weak self] in
                    self?.brokerStand = .abgelehnt(meldung)
                    self?.log(lokf("Broker-Prüfung abgelehnt: %@", meldung))
                }
            }
        }
    }

    private var initialisiert = false

    public init() {
        let d = UserDefaults.standard
        uhren = (try? JSONDecoder().decode([Uhr].self,
                    from: d.data(forKey: "uhren") ?? Data())) ?? []
        aktiveID = d.string(forKey: "aktiveID").flatMap(UUID.init(uuidString:))
        zielIDs = (try? JSONDecoder().decode(Set<UUID>.self,
                    from: d.data(forKey: "zielIDs") ?? Data())) ?? []
        brokerHost = d.string(forKey: "brokerHost") ?? Einstellungen.Vorgabe.brokerHost
        brokerPort = d.string(forKey: "brokerPort") ?? Einstellungen.Vorgabe.brokerPort
        benutzer   = d.string(forKey: "benutzer") ?? Einstellungen.Vorgabe.benutzer
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
        // Installationen von vor dem Zielmenue haben nie eine ausdrueckliche
        // Auswahl geschrieben: zielIDs blieb leer, obwohl schon Uhren
        // eingerichtet waren. Leer heisst fuer Einstellungen.ziele() "alle",
        // fuer ziele() weiter unten dagegen "die aktive Uhr" — dieselbe
        // Zweideutigkeit wie beim Entfernen der letzten Auswahl. Hier
        // uebernimmt die App dieselbe Lesart wie das Kommandozeilenwerkzeug
        // und die Kurzbefehle: "alle".
        if zielIDs.isEmpty, !uhren.isEmpty { zielIDs = Set(uhren.map(\.id)) }
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

    public func anzeigeGemerkt(_ name: String, fuer id: UUID) {
        var liste = bekannteAnzeigen[id] ?? []
        guard !liste.contains(name) else { return }
        liste.append(name)
        bekannteAnzeigen[id] = liste
    }

    /// Woher die Liste der Anzeigen stammt.
    public enum Anzeigenquelle { case geraet, app }

    /// Was auf einer Uhr steht: was sie selbst meldet, sonst was die App sich
    /// gemerkt hat. Beides zugleich gibt es nicht — die Meldung ist die bessere
    /// Auskunft, sobald es eine gibt.
    public func anzeigenAufUhr(_ id: UUID) -> [String] {
        gemeldeteAnzeigen[id] ?? bekannteAnzeigen[id] ?? []
    }

    /// Wie `anzeigenAufUhr`, aber mit der Herkunft — die Ansicht muss den
    /// Unterschied benennen: das eine ist Tatsache, das andere Erinnerung.
    public func anzeigenDerAktivenMitQuelle() -> (namen: [String], quelle: Anzeigenquelle) {
        guard let id = aktiveID else { return ([], .app) }
        if let gemeldet = gemeldeteAnzeigen[id] { return (gemeldet, .geraet) }
        return (bekannteAnzeigen[id] ?? [], .app)
    }

    public func anzeigeVergessen(_ name: String, fuer id: UUID) {
        bekannteAnzeigen[id]?.removeAll { $0 == name }
        // Auch aus der gemeldeten Liste: ob die Uhr ihre `customList` nach dem
        // Loeschen von sich aus erneut veroeffentlicht, ist nicht belegt — bliebe
        // der Name stehen, zeigte die Ansicht eine Anzeige, die es nicht mehr gibt.
        gemeldeteAnzeigen[id]?.removeAll { $0 == name }
    }

    public var aktiveUhr: Uhr? { uhren.first { $0.id == aktiveID } }

    public func log(_ zeile: String) {
        protokoll.append("\(Self.protokollZeit.string(from: Date())) \(zeile)")
        if protokoll.count > 300 { protokoll.removeFirst(protokoll.count - 300) }
    }

    /// Legt eine Uhr an und fragt sie sofort ab. Der Name kommt aus der Geraetekennung,
    /// laesst sich aber aendern — bei mehreren Uhren ist "Kueche" hilfreicher als eine MAC.
    public func uhrHinzufuegen(host: String) {
        let erste = uhren.isEmpty
        let neue = Uhr(name: host, host: host)
        uhren.append(neue)
        if aktiveID == nil { aktiveID = neue.id }
        // Nur bei der allerersten Uhr: sonst traete eine spaeter hinzugefuegte
        // Uhr unversehens der bisherigen Auswahl bei, statt aussen vor zu bleiben.
        if erste { zielIDs.insert(neue.id) }
        abfragen(neue.id)
    }

    public func uhrEntfernen(_ id: UUID) {
        uhren.removeAll { $0.id == id }
        verbunden[id] = nil
        bekannteAnzeigen[id] = nil
        zielIDs.remove(id)
        // War `id` die einzige gewaehlte Uhr, faellt zielIDs sonst leer —
        // und leer bedeutet fuer Einstellungen.ziele() "alle", fuer
        // ziele() weiter unten dagegen "die aktive Uhr". Sofort wieder
        // alle verbleibenden waehlen haelt beide Lesarten deckungsgleich,
        // statt die Zweideutigkeit erneut herzustellen.
        if zielIDs.isEmpty, !uhren.isEmpty { zielIDs = Set(uhren.map(\.id)) }
        if aktiveID == id { aktiveID = uhren.first?.id }
        horchenAbgleichen()
    }

    /// Eine geaenderte Adresse zeigt womoeglich auf eine andere Uhr. Praefix und MAC
    /// gehoeren dann noch zur alten — blieben sie stehen, wuerde weiter auf das alte
    /// Thema gesendet, an die alte Uhr oder ins Leere, ohne jeden Hinweis.
    public func adresseGeaendert(_ id: UUID) {
        guard let i = uhren.firstIndex(where: { $0.id == id }) else { return }
        guard !uhren[i].praefix.isEmpty || !uhren[i].mac.isEmpty || verbunden[id] != nil else { return }
        uhren[i].praefix = ""
        uhren[i].mac = ""
        verbunden[id] = nil
        horchenAbgleichen()
    }

    /// Holt Praefix, MAC und Verbindungsstand vom Geraet.
    public func abfragen(_ id: UUID) {
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
                    self.log(lokf("%@: Präfix %@, MQTT %@", self.uhren[i].name, praefix,
                                  steht ? lok("verbunden") : lok("nicht verbunden")))
                    // Erst jetzt steht das Praefix — vorher gab es kein Thema, auf das
                    // sich horchen liesse.
                    self.horchenAbgleichen()
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

    public func anzeigen(fuer uhr: Uhr) -> Anzeigen? {
        guard !uhr.praefix.isEmpty, var zugang else { return nil }
        // Eigene Kennung je Uhr: ein Broker trennt die bestehende Sitzung, sobald
        // dieselbe Kennung erneut verbindet. Mit einer festen Kennung wuerfen sich
        // gleichzeitige Sendungen an mehrere Uhren gegenseitig hinaus.
        zugang.clientID = "tc002-app-" + uhr.id.uuidString.prefix(8).lowercased()
        return Anzeigen(sender: MQTTSender(), zugang: zugang, praefix: uhr.praefix)
    }

    /// Liefert `anzeigen(fuer:)` nichts, fehlt entweder das Präfix — die Uhr wurde
    /// nie abgefragt — oder der Broker-Port ist keine brauchbare Zahl. Zwei
    /// verschiedene Ursachen, zwei verschiedene Meldungen; eine Meldung überhaupt,
    /// statt stumm zurückzukehren.
    public func zugangsmeldung(_ uhr: Uhr) -> String {
        if uhr.praefix.isEmpty {
            return "\(uhr.name) wurde noch nicht abgefragt. Unter „Einstellungen“ „Abfragen“ drücken."
        }
        return "Der Broker-Port „\(brokerPort)“ ist keine Zahl über 0. Unter „Einstellungen“ richtigstellen und „Sichern und prüfen“ drücken."
    }

    /// Wessen Schuld war es? Ein Brokerfehler träfe jede Uhr gleichermaßen — ihn
    /// einer einzelnen anzulasten („Küche: Der Broker hat nicht geantwortet.")
    /// schickt den Leser ans falsche Ende und steht bei fünf Zieluhren auch noch
    /// fünfmal da.
    private enum Sendefehler {
        case broker(String)
        case uhr(String)
    }

    private enum Sendeausgang {
        case erfolg(Uhr)
        case gescheitert(Sendefehler)
    }

    /// Ein Brokerfehler in Worten, die zur Abhilfe führen: welcher Broker, was zu
    /// prüfen ist und wo der Knopf sitzt, der genau diese Frage beantwortet. nil
    /// heißt: das war keiner — dann gehört er der Uhr zugeschrieben.
    private func brokerMeldung(_ error: Error) -> String? {
        let adresse = "\(brokerHost):\(brokerPort)"
        switch error {
        case MQTTFehler.zeitueberschreitung:
            return "Der Broker \(adresse) antwortet nicht. Läuft er, und stimmen Adresse und Port? Unter „Einstellungen“ beantwortet das „Sichern und prüfen“."
        case MQTTFehler.nichtVerbunden(let grund):
            return "Der Broker \(adresse) ist nicht erreichbar (\(grund)) Adresse und Port stehen unter „Einstellungen“; „Sichern und prüfen“ sagt, ob er antwortet."
        case MQTTFehler.abgelehnt(let code):
            let konto = benutzer.isEmpty ? "ohne Benutzer" : "„\(benutzer)“"
            if code == 4 || code == 5 {
                return "Der Broker \(adresse) nimmt das Konto \(konto) nicht an. Benutzer und Kennwort stehen unter „Einstellungen“ — „Sichern und prüfen“ zeigt, ob sie stimmen."
            }
            return "Der Broker \(adresse) lehnt die Anmeldung ab: \((error as? LocalizedError)?.errorDescription ?? "Code \(code)") Unter „Einstellungen“ mit „Sichern und prüfen“ nachfassen."
        default:
            return nil
        }
    }

    /// Ordnet einen Fehler der richtigen Partei zu. Bei einem Brokerfehler wandert
    /// die Meldung zugleich in `brokerStand` — sonst behauptete „Einstellungen“
    /// weiter „Der Broker nimmt die Anmeldung an.“, während nichts durchgeht.
    private func einordnen(_ error: Error, uhr: Uhr) -> Sendefehler {
        if let meldung = brokerMeldung(error) {
            brokerStand = .abgelehnt(meldung)
            return .broker(meldung)
        }
        return .uhr("\(uhr.name): \((error as? LocalizedError)?.errorDescription ?? "\(error)")")
    }

    private func zugangsfehler(_ uhr: Uhr) -> Sendefehler {
        let meldung = zugangsmeldung(uhr)
        guard !uhr.praefix.isEmpty else { return .uhr(meldung) }
        brokerStand = .abgelehnt(meldung)
        return .broker(meldung)
    }

    /// Jeder Brokerfehler genau einmal und ohne Uhrnamen, danach die uhrbezogenen
    /// Zeilen mit ihrem Namen — dort ist er ja die entscheidende Angabe.
    private func zusammengefasst(_ fehlschlaege: [Sendefehler]) -> String? {
        var broker: [String] = [], uhrbezogen: [String] = []
        for f in fehlschlaege {
            switch f {
            case .broker(let m): if !broker.contains(m) { broker.append(m) }
            case .uhr(let m): uhrbezogen.append(m)
            }
        }
        let alle = broker + uhrbezogen
        return alle.isEmpty ? nil : alle.joined(separator: "\n")
    }

    /// Für eine einzelne Sendung außerhalb von `anZiele` — dieselbe
    /// Unterscheidung, damit ein Brokerfehler auch dort nicht der Uhr angelastet wird.
    public func melde(_ error: Error, uhr: Uhr) {
        fehler = zusammengefasst([einordnen(error, uhr: uhr)])
    }

    /// Der gemeinsame Rumpf von `senden` und `loeschen`. Ein Zweig je Uhr:
    /// MQTTSender wartet bis zu acht Sekunden, eine unerreichbare Uhr darf die
    /// anderen nicht aufhalten. Fehler landen sichtbar in `fehler`, nicht nur im
    /// Protokoll — sonst ist ein Totalausfall von Erfolg nicht zu unterscheiden.
    private func anZiele(_ tat: @escaping @Sendable (Anzeigen) throws -> Void,
                         erledigt: (Uhr) -> Void) async {
        let ziele = ziele()
        guard !ziele.isEmpty else {
            fehler = lok("Keine Uhr eingerichtet. Unter „Einstellungen“ eine eintragen und abfragen.")
            return
        }
        var fehlschlaege: [Sendefehler] = []
        await withTaskGroup(of: Sendeausgang?.self) { gruppe in
            for uhr in ziele {
                gruppe.addTask { [weak self] in
                    guard let selbst = self else { return nil }
                    guard let anzeigen = await selbst.anzeigen(fuer: uhr) else {
                        return await .gescheitert(selbst.zugangsfehler(uhr))
                    }
                    do {
                        try tat(anzeigen)
                        return .erfolg(uhr)
                    } catch {
                        return await .gescheitert(selbst.einordnen(error, uhr: uhr))
                    }
                }
            }
            // Diese Schleife läuft schon wieder auf dem Hauptactor — die
            // Buchführung gehört deshalb hierher, nicht in den Zweig.
            for await ausgang in gruppe {
                switch ausgang {
                case .erfolg(let uhr): erledigt(uhr)
                case .gescheitert(let f): fehlschlaege.append(f)
                case nil: break
                }
            }
        }
        fehler = zusammengefasst(fehlschlaege)
    }

    /// Schickt einen Rahmen an eine oder alle gewählten Uhren.
    public func senden(_ frame: Frame, als name: String) async {
        await anZiele({ try $0.zeigen(frame, auf: name) }) { uhr in
            anzeigeGemerkt(name, fuer: uhr.id)
            log(lokf("an %@ gesendet: %@", uhr.name, name))
        }
    }

    /// Entfernt eine Anzeige von allen gewählten Uhren. Eine leere Nutzlast auf
    /// dem Thema löscht sie — genau null Bytes, nicht "" und nicht {} (§3.2).
    public func loeschen(_ name: String) async {
        await anZiele({ try $0.loeschen(name) }) { uhr in
            anzeigeVergessen(name, fuer: uhr.id)
            log(lokf("auf %@ gelöscht: %@", uhr.name, name))
        }
    }

    /// Die Uhren, an die gesendet wird: die gewaehlten, sofern sie ein Praefix haben.
    /// Ist nichts gewaehlt, ist es die aktive Uhr — sonst liefe ein Sendeversuch
    /// stillschweigend ins Leere.
    public func ziele() -> [Uhr] {
        if zielIDs.isEmpty {
            return [aktiveUhr].compactMap { $0 }.filter { !$0.praefix.isEmpty }
        }
        return uhren.filter { zielIDs.contains($0.id) && !$0.praefix.isEmpty }
    }

    // MARK: - Zuhören

    /// Ein laufendes Abonnement je Uhr, samt der Angaben, unter denen es aufgebaut
    /// wurde: ändert sich Präfix oder Broker, gehört es erneuert.
    private struct Horcher {
        let abonnent: MQTTAbonnent
        let praefix: String
        let brokerkennung: String
    }
    private var horcher: [UUID: Horcher] = [:]
    private var horchtGerade: [UUID: Bool] = [:]
    private var horchenErlaubt = false

    /// Alles, dessen Änderung ein bestehendes Abonnement ungültig macht.
    private var brokerkennung: String { "\(brokerHost)|\(brokerPort)|\(benutzer)|\(kennwort)" }

    /// Beginnt zuzuhören. Ausdrücklich und nicht aus `init` heraus: ein AppZustand
    /// allein — etwa im Test — darf keine Verbindung aufbauen.
    public func horchenStarten() {
        horchenErlaubt = true
        horchenAbgleichen()
    }

    /// Bricht ein einzelnes Abonnement ab und leert seine Buchführung. Gemeinsamer
    /// Rumpf von `horchenAbgleichen` (dort nur für ungültig gewordene Abonnements)
    /// und `horchenBeenden` (dort für alle).
    private func abonnementBeenden(_ id: UUID, _ horcher: Horcher) {
        horcher.abonnent.beenden()
        self.horcher[id] = nil
        horchtGerade[id] = nil
        gemeldeteAnzeigen[id] = nil
        geraetOnline[id] = nil
        slotInhalt[id] = nil
    }

    /// Bricht alle laufenden Abonnements ab, ohne `horchenErlaubt` zurückzusetzen —
    /// `ausDemHintergrund` ruft danach `horchenAbgleichen()`, das sie neu aufbaut.
    func horchenBeenden() {
        for (id, vorhanden) in horcher {
            abonnementBeenden(id, vorhanden)
        }
    }

    /// Je eingerichteter Uhr mit Präfix ein Abonnent auf ihre beiden Themen, und
    /// keiner für die übrigen. Mehrfach aufrufbar: was schon passt, bleibt stehen —
    /// ein Abgleich soll keine laufende Verbindung abreißen.
    func horchenAbgleichen() {
        guard horchenErlaubt else { return }
        let kennung = brokerkennung
        for (id, vorhanden) in horcher {
            let uhr = uhren.first { $0.id == id }
            guard uhr == nil || uhr?.praefix != vorhanden.praefix
                    || vorhanden.brokerkennung != kennung else { continue }
            abonnementBeenden(id, vorhanden)
        }
        guard let zugang else { return }
        for uhr in uhren where !uhr.praefix.isEmpty && horcher[uhr.id] == nil {
            var eigener = zugang
            // Eigene Kennung wie beim Senden: ein Broker trennt die bestehende
            // Sitzung, sobald dieselbe Kennung erneut verbindet — und gesendet wird
            // ja weiter, während hier zugehört wird.
            eigener.clientID = "tc002-app-horch-" + uhr.id.uuidString.prefix(8).lowercased()
            let id = uhr.id
            // `custom/#` macht die App zum Mitleser: was auf ein Thema
            // veroeffentlicht wird, bekommen alle Abonnenten — gleich ob die
            // Sendung von dieser App, dem Kommandozeilenwerkzeug, einem
            // Kurzbefehl oder einem fremden Werkzeug kam.
            let abonnent = MQTTAbonnent(zugang: eigener,
                                        themen: ["\(uhr.praefix)/customList", "\(uhr.praefix)/status",
                                                 "\(uhr.praefix)/custom/#"])
            // Die Rückmeldungen kommen von der Warteschlange des Abonnenten;
            // AppZustand ist @MainActor-isoliert, also dorthin zurück.
            abonnent.beiNachricht = { thema, nutzlast in
                Task { @MainActor [weak self] in
                    self?.gemeldet(thema: thema, nutzlast: nutzlast, fuer: id)
                }
            }
            abonnent.beiZustand = { steht, grund in
                Task { @MainActor [weak self] in self?.horchzustand(steht, grund, fuer: id) }
            }
            abonnent.starten()
            horcher[id] = Horcher(abonnent: abonnent, praefix: uhr.praefix, brokerkennung: kennung)
        }
    }

    /// Was von der Uhr hereinkommt. Das Thema entscheidet, nicht die Reihenfolge:
    /// beide Abonnements laufen über dieselbe Verbindung.
    private func gemeldet(thema: String, nutzlast: Data, fuer id: UUID) {
        guard let uhr = uhren.first(where: { $0.id == id }) else { return }
        switch thema {
        case "\(uhr.praefix)/customList":
            // nil heißt unlesbar — dann lieber den letzten Stand behalten, als ihn
            // durch eine leere Liste zu ersetzen, die etwas anderes behauptet.
            guard let namen = Anzeigen.namenAusCustomList(nutzlast),
                  gemeldeteAnzeigen[id] != namen else { return }
            gemeldeteAnzeigen[id] = namen
            log(lokf("%@ meldet: %@", uhr.name,
                     namen.isEmpty ? lok("keine Anzeige") : namen.joined(separator: ", ")))
        case "\(uhr.praefix)/status":
            let text = String(data: nutzlast, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let online = text == "online"
            guard geraetOnline[id] != online else { return }
            geraetOnline[id] = online
            log(online ? lokf("%@ meldet sich online", uhr.name) : lokf("%@ meldet sich offline", uhr.name))
        default:
            // `custom/#` liefert auch fremde Anzeigen (z. B. aus „Malen") — nur
            // unsere fuenf Slotnamen (`meldung1`…`meldung5`) betreffen `slotInhalt`.
            let vorsilbe = "\(uhr.praefix)/custom/"
            guard thema.hasPrefix(vorsilbe) else { return }
            let name = String(thema.dropFirst(vorsilbe.count))
            guard let platz = (1...Meldungsplatz.anzahl).first(where: { Meldungsplatz.name(fuer: $0) == name })
            else { return }
            if nutzlast.isEmpty {
                // Leere Nutzlast loescht die Anzeige auf der Uhr (`Anzeigen.loeschen`) —
                // der Slot ist also wieder leer.
                slotInhalt[id]?[platz] = nil
            } else if let pixel = Anzeigen.pixelAusCustomNutzlast(nutzlast) {
                slotInhalt[id, default: [:]][platz] = Slotbild(pixel: pixel, zeitpunkt: Date())
            }
            // Sonst: nicht zerlegbare Nutzlast (Bild-Weg oder Geraeteschrift-Weg) —
            // der zuletzt bekannte Inhalt bleibt stehen, statt ihn durch nichts zu ersetzen.
        }
    }

    /// Nur ins Protokoll, nicht in `fehler`: ein Abriss im Hintergrund darf nicht
    /// mitten in der Arbeit ein Hinweisfenster aufziehen. Und nur bei Änderung —
    /// der Abonnent versucht es von selbst immer wieder.
    private func horchzustand(_ steht: Bool, _ grund: String?, fuer id: UUID) {
        guard let uhr = uhren.first(where: { $0.id == id }), horchtGerade[id] != steht else { return }
        horchtGerade[id] = steht
        if steht {
            log(lokf("hört bei %@ mit", uhr.name))
        } else {
            // Ohne Verbindung ist die gemeldete Liste nur noch Erinnerung — dann
            // soll die Ansicht das auch sagen und auf die eigene Buchführung fallen.
            gemeldeteAnzeigen[id] = nil
            geraetOnline[id] = nil
            slotInhalt[id] = nil
            log(lokf("hört bei %@ nicht mehr mit: %@", uhr.name, grund ?? lok("Verbindung weg")))
        }
    }

    private func uhrenSichern() {
        guard initialisiert, let daten = try? JSONEncoder().encode(uhren) else { return }
        UserDefaults.standard.set(daten, forKey: "uhren")
    }

    private func zielIDsSichern() {
        guard initialisiert, let daten = try? JSONEncoder().encode(zielIDs) else { return }
        UserDefaults.standard.set(daten, forKey: "zielIDs")
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

    /// Die App geht in den Hintergrund. Unter iOS überlebt eine offene
    /// MQTT-Verbindung das nicht: Das System friert den Prozess ein, die
    /// Verbindung stirbt unbemerkt, und beim Zurückkommen hielte sich die App
    /// für verbunden. Also ausdrücklich beenden.
    ///
    /// Auf dem Mac wird das nie gerufen — dort läuft die App weiter.
    public func inDenHintergrund() {
        horchenBeenden()
    }

    /// Die App kommt zurück. Der Zuhörer wird neu aufgebaut, sofern es etwas
    /// zum Zuhören gibt.
    public func ausDemHintergrund() {
        horchenAbgleichen()
    }
}
