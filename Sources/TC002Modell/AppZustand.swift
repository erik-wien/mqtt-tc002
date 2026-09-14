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
    /// **Warum** eine Uhr nicht am Broker haengt, wenn sie es selbst sagt.
    /// Nur AWTRIX NG tut das (`badCredentials` und dergleichen); bei der
    /// Werksfirmware bleibt es leer.
    public var brokergrund: [UUID: String] = [:]
    /// Was die Uhr selbst als ihre Anzeigen nennt — auf **zwei** Wegen, die
    /// dieselbe Auskunft geben: mitgelesen von `<praefix>/customList` (§3.5)
    /// und erfragt ueber `GET /api/customList` (§5.7). Beides ist die Uhr
    /// selbst, also dieselbe Quelle `.geraet`; der Unterschied ist nur, wer
    /// anfaengt zu reden.
    ///
    /// Kein Eintrag heisst: keine Auskunft — dann gilt `bekannteAnzeigen`, und
    /// die Ansicht sagt, dass sie nur die eigene Buchfuehrung zeigt.
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

    /// **Grabsteine entfernter Uhren** — siehe `Einrichtungsstand.entfernt`.
    /// Ohne sie wird eine Loeschung nie uebertragen, und eine auf einem Geraet
    /// entfernte Uhr kommt vom anderen zurueck.
    public private(set) var grabsteine: [String: Date] = [:] { didSet { grabsteineSichern() } }

    /// Der zuletzt gesicherte Wert — Grundlage dafuer, dass mehrfache Aufrufe
    /// (Fokuswechsel, .onDisappear, Beenden) gefahrlos sind: ein unveraenderter
    /// Wert loest keinen zweiten Schluesselbund-Schreibvorgang aus.
    private var kennwortGesichert: String?

    public func kennwortSichern() {
        guard kennwort != kennwortGesichert else { return }
        guard schluesselbund.setzen(kennwort, fuer: "broker") else {
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
            let meldung = brokerHost.isEmpty
                ? lok("Es ist keine Brokeradresse eingetragen.")
                : lok("Broker-Port muss eine Zahl über 0 sein.")
            brokerStand = .abgelehnt(meldung)
            log(lokf("Broker-Prüfung abgelehnt: %@", meldung))
            return
        }
        brokerStand = .laeuft
        // `let`, nicht `var`: Eine veraenderliche Variable, die in eine
        // nebenlaeufige Closure faellt, ist unter Swift 6 ein Fehler.
        let pruefZugang: MQTTZugang = {
            var z = zugang
            z.clientID = "tc002-app-pruef"
            return z
        }()
        // Blockiert bis zu acht Sekunden — deshalb `Hintergrund`, nicht
        // `Task.detached`: Der kooperative Pool hat so viele Threads wie der
        // Rechner Kerne, und einer davon waere hier acht Sekunden lang belegt.
        // Der `Task` selbst erbt den Hauptakteur von `AppZustand`; alles
        // ausserhalb von `Hintergrund.lauf` laeuft also dort, wo es hingehoert.
        Task { [weak self] in
            do {
                try await Hintergrund.lauf { try MQTTSender().pruefen(zugang: pruefZugang) }
                self?.brokerStand = .angenommen
                self?.log(lok("Broker-Prüfung: angenommen"))
                self?.horchenAbgleichen()
            } catch {
                let meldung = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                self?.brokerStand = .abgelehnt(meldung)
                self?.log(lokf("Broker-Prüfung abgelehnt: %@", meldung))
            }
        }
    }

    private var initialisiert = false

    /// Der Schluesselbund kommt als Vorgabeargument herein — wie `gedaechtnis:`
    /// bei den Slots und `sitzung:` bei den HTTP-Wegen. Die App reicht nichts
    /// mit und bekommt den echten; die Tests geben einen Doppelgaenger.
    private let schluesselbund: Schluesselbundzugriff

    // MARK: iCloud-Abgleich

    /// Die Ablage in der Wolke — dasselbe Vorgabeargument-Muster wie beim
    /// Schluesselbund: Die App bekommt die echte, die Tests einen
    /// Doppelgaenger. **Kein Test fasst iCloud an.**
    private let wolke: Wolkenablage

    /// Ob der Abgleich gewaehlt ist. Geschrieben wird er **nur** ueber
    /// `wolkeUmschalten` — dort haengt der Umzug daran.
    public private(set) var wolkeGewaehlt: Bool
    /// Ob ein Behaelter erreichbar ist. `nil` heisst: noch nicht nachgesehen —
    /// nachgesehen wird erst, wenn die Einstellungen aufgehen, denn die
    /// Auskunft kostet und wird sonst nirgends gebraucht.
    public private(set) var wolkeBereit: Bool?
    /// Waehrend Umzug und Umschalten. Der Schalter bleibt derweil gesperrt:
    /// Zweimal umschalten, waehrend noch kopiert wird, ergaebe einen halben
    /// Bestand.
    public private(set) var wolkeLaeuft = false
    /// Was zuletzt in die Wolke ging. Verhindert das Echo — ohne den
    /// Vergleich schriebe jede uebernommene Aenderung sich selbst zurueck.
    private var zuletztGeschrieben: Data?
    /// Waehrend `standUebernehmen` laeuft: Die `didSet`-Schreiber sollen in die
    /// Einstellungen schreiben, aber nicht in die Wolke zurueck.
    private var uebernimmtGerade = false
    private var wolkenBeobachter: NSObjectProtocol?

    /// `wolkeGewaehlt` kommt als Vorgabeargument herein wie `schluesselbund`
    /// und `wolke`: Die App liest die echte Wahl, die Tests setzen sie, ohne
    /// dafuer die Einstellungen dieser Installation anzufassen.
    public init(schluesselbund: Schluesselbundzugriff = EchterSchluesselbund(),
                wolke: Wolkenablage = EchteWolkenablage(),
                wolkeGewaehlt: Bool = Ablageort.gewaehlt(),
                wolkeBereit: Bool? = nil) {
        self.schluesselbund = schluesselbund
        self.wolke = wolke
        self.wolkeGewaehlt = wolkeGewaehlt
        self.wolkeBereit = wolkeBereit
        let d = UserDefaults.standard
        uhren = (try? JSONDecoder().decode([Uhr].self,
                    from: d.data(forKey: "uhren") ?? Data())) ?? []
        aktiveID = d.string(forKey: "aktiveID").flatMap(UUID.init(uuidString:))
        zielIDs = (try? JSONDecoder().decode(Set<UUID>.self,
                    from: d.data(forKey: "zielIDs") ?? Data())) ?? []
        brokerHost = d.string(forKey: "brokerHost") ?? Einstellungen.Vorgabe.brokerHost
        brokerPort = d.string(forKey: "brokerPort") ?? Einstellungen.Vorgabe.brokerPort
        benutzer   = d.string(forKey: "benutzer") ?? Einstellungen.Vorgabe.benutzer
        kennwort   = schluesselbund.lesen("broker") ?? ""
        let flach = (try? JSONDecoder().decode([String: [String]].self,
                        from: d.data(forKey: "bekannteAnzeigen") ?? Data())) ?? [:]
        // uniquingKeysWith statt uniqueKeysWithValues: UUID(uuidString:) ist gegenueber
        // Gross-/Kleinschreibung nachsichtig, zwei von Hand verbogene Schluessel in
        // unterschiedlicher Schreibweise ergaeben sonst denselben Schluessel und liessen
        // die App beim Start abstuerzen. Der erste Eintrag gewinnt.
        bekannteAnzeigen = Dictionary(
            flach.compactMap { text, liste in UUID(uuidString: text).map { ($0, liste) } },
            uniquingKeysWith: { erster, _ in erster })
        // **Leerraum am Rand der Adresse, aus einer aelteren Fassung.** Der
        // Beobachter an `Uhr.host` trimmt beim Setzen, laeuft beim Decode aber
        // nicht — eine einmal krumm abgelegte Adresse bliebe sonst krumm, und
        // ihr Fehler faellt erst beim Senden auf. Hier und nicht gleich beim
        // Decodieren: Dort sind noch nicht alle Eigenschaften gesetzt, und
        // `uhren[i]` ist schon ein Zugriff auf `self`.
        uhren = uhren.mitSauberenAdressen().nachAdresse()
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
        grabsteine = (try? JSONDecoder().decode([String: Date].self,
                                                from: d.data(forKey: "grabsteine") ?? Data())) ?? [:]
        kennwortGesichert = kennwort
        initialisiert = true
        // Nur wenn der Abgleich gewaehlt ist, wird der Behaelter ueberhaupt
        // gesucht — und dann losgeloest, weil die Suche blockiert.
        Ablageort.vorbereiten()
        wolkeHorchen()
    }

    public func anzeigeGemerkt(_ name: String, fuer id: UUID) {
        var liste = bekannteAnzeigen[id] ?? []
        guard !liste.contains(name) else { return }
        liste.append(name)
        bekannteAnzeigen[id] = liste
    }

    /// Was die Uhr ueber ihre Belegung gesagt hat. Die eine Stelle, an der
    /// `gemeldeteAnzeigen` gefuellt wird — gleich ob die Auskunft mitgelesen
    /// (§3.5) oder erfragt (§5.7) wurde.
    ///
    /// `nil` heisst: Die Uhr hat **nicht** geantwortet. Dann gibt es keine
    /// Tatsache mehr, und die Ansicht faellt auf die eigene Buchfuehrung
    /// zurueck und sagt das auch. Eine unlesbare MQTT-Nutzlast ist etwas
    /// anderes und kommt hier gar nicht erst an — dort bleibt der letzte Stand
    /// stehen (siehe `gemeldet`).
    ///
    /// Es sind **nur Namen**: belegt oder frei ist damit Tatsache, was auf
    /// einem Platz steht, bleibt geraten (`slotzustand`).
    func belegungGemeldet(_ namen: [String]?, fuer id: UUID) {
        guard let uhr = uhren.first(where: { $0.id == id }),
              gemeldeteAnzeigen[id] != namen else { return }
        gemeldeteAnzeigen[id] = namen
        guard let namen else { return }
        log(lokf("%@ meldet: %@", uhr.name,
                 namen.isEmpty ? lok("keine Anzeige") : namen.joined(separator: ", ")))
    }

    /// Fragt die Uhr selbst, welche Anzeigen auf ihr stehen — ueber HTTP, also
    /// ohne Broker und ohne auf eine Nachricht zu warten, die vielleicht nie
    /// kommt.
    ///
    /// Damit ist die Belegung beim Start Tatsache statt Erinnerung, und zwar
    /// auch fuer Anzeigen, die ein fremdes Programm angelegt hat. Die eigene
    /// Buchfuehrung war hier in **beide** Richtungen falsch: ein fremder
    /// Absender erschien als „frei", eine Loeschung ueber Ulanzi Studio als
    /// „belegt".
    ///
    /// Der Fehlschlag geht ins Protokoll, nicht in `fehler`: Beim Start sind
    /// Uhren aus oder noch nicht im Netz, und dafuer gehoert kein
    /// Hinweisfenster aufgezogen.
    ///
    /// `sitzung` ist ein Parameter, damit der Test einen `URLProtocol`
    /// unterschieben kann — wie `gedaechtnis` bei den Slots. Die Oberflaeche
    /// ruft wie bisher `belegungAbfragen(id)`.
    public func belegungAbfragen(_ id: UUID, sitzung: URLSession = .shared) {
        guard let uhr = uhren.first(where: { $0.id == id }), !uhr.host.isEmpty else { return }
        let host = uhr.host, name = uhr.name, gattung = uhr.gattung
        // Blockiert bis zur Antwort der Uhr — und **eine Uhr, die nicht
        // antwortet, blockiert zehn Sekunden**. Genau dafuer gibt es
        // `Hintergrund`: Im kooperativen Pool haetten fuenf eingetragene Uhren,
        // von denen eine tot ist, nacheinander dessen Plaetze belegt.
        Task { [weak self] in
            do {
                let namen = try await Hintergrund.lauf {
                    try Geraet(host: host, sitzung: sitzung, typ: gattung).anzeigennamen()
                }
                self?.belegungGemeldet(namen, fuer: id)
            } catch {
                let grund = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                self?.belegungGemeldet(nil, fuer: id)
                self?.log(lokf("%@ sagt nicht, was auf ihr steht: %@", name, grund))
            }
        }
    }

    /// Dasselbe fuer jede eingerichtete Uhr.
    public func belegungAbfragen(sitzung: URLSession = .shared) {
        for uhr in uhren { belegungAbfragen(uhr.id, sitzung: sitzung) }
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

    /// Was nach einer **bestaetigten** Sendung an Belegung zu buchen ist.
    ///
    /// Ueber MQTT genuegte bisher die eigene Buchfuehrung: Die Uhr
    /// veroeffentlicht ihre `customList` nach einer Aenderung von selbst
    /// (§3.5), die Auskunft kommt also gleich nach. **Ueber HTTP reicht sie
    /// nichts nach** — am 13.09.2026 gemessen: 45 Sekunden gehorcht, mit
    /// einer HTTP-Loeschung mittendrin, und es kam allein `status online`.
    /// Ohne diese Buchung zeigte ein eben ueber HTTP gefuellter Platz „frei",
    /// solange `gemeldeteAnzeigen` steht und den Namen nicht kennt.
    ///
    /// Es ist dabei keine blosse Vermutung: Die Uhr hat die Sendung mit
    /// `{"code":200}` quittiert, sonst waere `anZiele` gar nicht hier.
    /// Ergaenzt wird nur eine **vorhandene** Auskunft — wo keine steht, gilt
    /// ohnehin die eigene Buchfuehrung, und die schreibt `anzeigeGemerkt`.
    func anzeigeBestaetigt(_ name: String, fuer uhr: Uhr) {
        anzeigeGemerkt(name, fuer: uhr.id)
        // **Wann die gemeldete Liste von selbst nachkommt — und wann nicht.**
        // Allein die Werksfirmware ueber MQTT veroeffentlicht ihre `customList`
        // nach einer Aenderung; im HTTP-Betrieb reicht sie nichts nach
        // (gemessen), und eine AWTRIX NG hat ueber MQTT gar keine Liste (§3.5),
        // ihre Belegung ist ein HTTP-Abruf von vorhin. In beiden Faellen zeigte
        // ein eben gefuellter Platz sonst weiter „frei".
        let kommtNach = uhr.wirksameBetriebsart == .mqtt && uhr.gattung == .tc002
        guard !kommtNach,
              var gemeldet = gemeldeteAnzeigen[uhr.id], !gemeldet.contains(name) else { return }
        gemeldet.append(name)
        gemeldeteAnzeigen[uhr.id] = gemeldet
    }

    public func anzeigeVergessen(_ name: String, fuer id: UUID) {
        bekannteAnzeigen[id]?.removeAll { $0 == name }
        // Auch aus der gemeldeten Liste: ob die Uhr ihre `customList` nach dem
        // Loeschen von sich aus erneut veroeffentlicht, ist nicht belegt — bliebe
        // der Name stehen, zeigte die Ansicht eine Anzeige, die es nicht mehr gibt.
        gemeldeteAnzeigen[id]?.removeAll { $0 == name }
    }

    /// Was nach einer **erfolgreichen** Loeschung auf einer Uhr zu buchen ist:
    /// Der Name verschwindet von dieser Uhr, und die Erinnerung an den Platz
    /// wird weggeworfen. Derselbe Grundsatz wie beim Malen (`senden` ohne
    /// `slotOptionen`): Wer einen Platz raeumt, darf dort nicht den vorherigen
    /// Text zuruecklassen — sonst faellt `slotzustand` auf das Gedaechtnis
    /// zurueck und zeigt, was laengst zweifach ueberholt ist, sobald ein
    /// fremder Absender den Platz wieder mit etwas Unlesbarem belegt.
    ///
    /// Nur die fuenf Meldungsplaetze haben ueberhaupt eine Erinnerung; ein frei
    /// gewaehlter Anzeigename (Vorgabe des Werkzeugs: „cli") hat nichts zu
    /// vergessen. Je Uhr, weil die leere Nutzlast auch nur an eine ging.
    /// Schlaegt das Vergessen fehl, bleibt die Loeschung gueltig — nur eine
    /// Protokollzeile haelt es fest, wie in `senden`.
    ///
    /// `gedaechtnis` ist ein Parameter, damit die Tests nicht in die echte
    /// Ablage unter Application Support greifen muessen.
    public func anzeigeGeloescht(_ name: String, fuer uhr: Uhr,
                                 gedaechtnis: Slotgedaechtnis = .gemeinsam) {
        anzeigeVergessen(name, fuer: uhr.id)
        guard let platz = Meldungsplatz.platz(fuerName: name) else { return }
        if !gedaechtnis.vergessen(fuer: uhr.id, platz: platz) {
            log(lokf("%@: alte Regler für Slot %d nicht vergessen", uhr.name, platz))
        }
    }

    public var aktiveUhr: Uhr? { uhren.first { $0.id == aktiveID } }

    /// Ob ueberhaupt etwas eingerichtet ist. Daran haengt, womit die
    /// Oberflaechen beginnen: mit „Senden" oder mit den Einstellungen.
    ///
    /// Eine Uhr muss stehen — und ein Broker nur dann, wenn wenigstens eine
    /// dieser Uhren ihn ueberhaupt benutzt (`Einstellungen.brokerNoetig`).
    /// Fehlt, was gebraucht wird, ist „Senden" eine Sackgasse: kein Ziel,
    /// keine Vorschau, ein Sendeknopf, der nirgendwohin fuehrt (`ziele()` ist
    /// leer, und `anZiele` bricht mit „Keine Uhr eingerichtet" ab).
    ///
    /// **Fuer eine reine HTTP-Einrichtung waere die Brokerbedingung falsch.**
    /// Dort gibt es keinen Broker und braucht es keinen; wer nur ueber HTTP
    /// sendet, stuende sonst beim ersten Start vor einem Formular, das nach
    /// etwas fragt, das seine Uhren nie anfassen.
    ///
    /// Eine reine Frage an die abgelegte Einrichtung: Sie kostet nichts und
    /// dauert nicht. Ob der Broker gerade **antwortet**, wird hier
    /// ausdruecklich nicht gefragt — eine Erreichbarkeitspruefung haelt den
    /// Start genau dann am laengsten auf, wenn niemand antwortet. Dieser Fall
    /// gehoert auf die Sendeansicht, und dort steht er auch schon
    /// (`brokerMeldung` nennt Adresse und Port und verweist auf „Sichern und
    /// pruefen").
    ///
    /// Ein Merker „schon einmal gestartet" waere schlechter als gar keiner:
    /// Wer alle Uhren wieder entfernt oder die Brokeradresse leert, steht in
    /// genau derselben Sackgasse wie beim ersten Start. Ohne Merker stimmt die
    /// Auskunft in beiden Faellen — und sie stimmt auch wieder, sobald
    /// eingetragen ist, was fehlte.
    public var eingerichtet: Bool {
        guard !uhren.isEmpty else { return false }
        return brokerEingetragen || !Einstellungen.brokerNoetig(fuer: uhren)
    }

    /// Ob eine Brokeradresse eingetragen ist.
    ///
    /// Der Wert selbst sagt es, seit `Einstellungen.Vorgabe.brokerHost` leer
    /// ist: Eine frische Installation hat keine Adresse, und nur eine Eingabe
    /// macht daraus eine. Solange die Vorgabe eine erfundene Adresse war,
    /// musste stattdessen der **abgelegte Schluessel** herhalten — er entsteht
    /// erst durch eine Eingabe —, und das war ein Umweg um eine Vorgabe herum,
    /// die es nicht haette geben sollen. Mit ihr faellt er weg.
    private var brokerEingetragen: Bool { !brokerHost.isEmpty }

    /// Die eine Uhr, gegen deren mitgelesenen Slotinhalt und Slotgedaechtnis
    /// die fuenf Slot-Bloecke geprueft werden: die aktive. Ein Platz zaehlt
    /// als belegt, sobald ihn *irgendeine* Zieluhr kennt — welches Bild und
    /// welche gemerkten Regler dann gelten sollen, bliebe bei mehreren
    /// Zieluhren offen. `ziele().first` waere dabei willkuerlich; die aktive
    /// Uhr ist dieselbe, die die Zielauswahl (Mac) und das Titelmenue
    /// (iPhone) zeigen.
    ///
    /// Eigene Benennung statt `aktiveUhr` an drei Stellen, damit die Wahl an
    /// einer Stelle steht: `slotzustand(_:belegt:)` unten und `slotWaehlen`
    /// in den beiden Sendeansichten muessen dieselbe Uhr meinen, sonst zeigt
    /// ein Block die Pixel der einen und stellt die Regler der anderen her.
    public var referenzUhr: Uhr? { aktiveUhr }

    /// Wechselt die angesehene Uhr — und mit ihr das Sendeziel, solange nicht
    /// an mehrere gesendet wird.
    ///
    /// Fuer das Titelmenue der iPhone-Fassung, die **einen** Griff dafuer hat:
    /// Auf 393 Punkten Breite waeren eine Ziel- und eine Ansichtsauswahl
    /// nebeneinander nicht unterzubringen, und eine Uhr anzusehen, an die man
    /// gerade nicht sendet, ist am Telefon kein Fall, den jemand braucht.
    /// Ansehen und Senden sind dort deshalb dieselbe Entscheidung.
    ///
    /// Ausgenommen ist das Senden an mehrere Uhren: Dort bleibt die Zielmenge
    /// stehen, denn die fuenf Bloecke und der Verlauf koennen nur den Stand
    /// **einer** Uhr zeigen — welcher das ist, sagt der Titel.
    ///
    /// Am Mac aendert das nichts: Dort bleiben Zielauswahl und aktive Uhr zwei
    /// Bedienelemente, weil dort Platz fuer beide ist.
    public func uhrAnsehen(_ id: UUID) {
        aktiveID = id
        if !anMehrereUhren { zielIDs = [id] }
    }

    /// Ob an mehr als die angesehene Uhr gesendet wird.
    ///
    /// Kein eigener gesicherter Zustand: Er waere eine zweite Wahrheit neben
    /// `zielIDs` und koennte ihr widersprechen. Das Setzen schreibt darum
    /// `zielIDs` selbst — beim Einschalten alle eingerichteten Uhren, beim
    /// Abschalten die angesehene, damit keine leere Menge entsteht, die
    /// `ziele()` und `Einstellungen.ziele()` verschieden lesen.
    ///
    /// Gelesen wird „mehr als eine", nicht „genau alle": Eine Installation von
    /// vor dem Titelmenue kann eine gemischte Teilmenge stehen haben, und die
    /// gehoert nicht als „eine Uhr" ausgegeben. Wie viele es wirklich sind,
    /// sagt der Titel; der naechste Griff an dieses Menue macht daraus wieder
    /// eine der beiden sauberen Mengen.
    public var anMehrereUhren: Bool {
        get { zielIDs.count > 1 }
        set {
            if newValue {
                zielIDs = Set(uhren.map(\.id))
            } else if let aktiveID {
                zielIDs = [aktiveID]
            }
        }
    }

    /// Was ein Slot-Block zeigt — drei ehrliche Faelle (siehe `Slotzustand`):
    /// frei, wenn kein Name auf dem Platz liegt; sonst die mitgelesenen
    /// Pixel, wenn welche da sind; sonst, falls das Gedaechtnis einen Stand
    /// fuer diesen Platz hat, dieselben Pixel neu gerechnet ueber
    /// `Meldungsbau` — exakt statt aus einem Lauf-GIF zurueckgewonnen.
    ///
    /// **Ohne Pruefsummenvergleich.** Ob die gemerkten Regler auch noch
    /// gelten, ist eine andere Frage (`slotWaehlen` in den Sendeansichten):
    /// Hier geht es allein um die Anzeige, und die darf auch eine Erinnerung
    /// sein — dass sie eine ist, sagt die Hilfe.
    ///
    /// `belegt` kommt von aussen, weil die Ansichten es ohnehin fuer den
    /// Papierkorb brauchen; es ist `belegtePlaetze.contains(platz)`.
    ///
    /// Eine Fassung fuer alle drei Ansichten (Senden Mac, Senden iPhone,
    /// Bilder): Derselbe Platz derselben Uhr soll ueberall dasselbe zeigen.
    public func slotzustand(_ platz: Int, belegt: Bool,
                            gedaechtnis: Slotgedaechtnis = .gemeinsam) -> Slotzustand {
        guard belegt else { return .frei }
        guard let uhr = referenzUhr else { return .unbekannt }
        if let bild = slotInhalt[uhr.id]?[platz] { return .bekannt(bild.pixel) }
        // **Der Riegel fuer AWTRIX NG.** Das Gedaechtnis merkt sich Regler, und
        // `gerastert` macht daraus ein 52×16-Bild in unserer Schrift. Auf einer
        // NG steht der Text in **ihrer** Schrift auf 32×8 — das gerechnete Bild
        // waere nicht eine ungenaue Erinnerung, sondern eine falsche. Ein Block,
        // der es zeigte, behauptete etwas, das niemand belegen kann; „belegt,
        // Inhalt unbekannt" ist weniger und wahr.
        guard uhr.gattung == .tc002 else { return .unbekannt }
        guard let stand = gedaechtnis.gemerkt(fuer: uhr.id, platz: platz),
              let optionen = stand.optionen else { return .unbekannt }
        return .bekannt(gerastert(stand, optionen))
    }

    /// Zwischenspeicher fuer die aus einem gemerkten Stand gerechneten Pixel.
    ///
    /// `Meldungsbau.feld` rastert je Aufruf zwei- bis dreimal und legt dabei
    /// je Zeichen einen `CGContext` an; `slotzustand` laeuft fuenfmal je
    /// Neuzeichnen, und neu gezeichnet wird bei jedem Tastendruck im Textfeld.
    /// Der Gedaechtniszweig ist dabei der Normalfall, nicht die Ausnahme: Er
    /// greift immer, solange nichts mitgelesen wurde — ohne Broker, nach jedem
    /// Start, nach jedem Abriss.
    ///
    /// **Der Schluessel ist der gemerkte Stand selbst, nicht Uhr und Platz.**
    /// Das ist der ganze Grund, warum dieser Speicher nicht veralten kann: Er
    /// beantwortet nur die reine Frage „welche Pixel ergeben diese Regler",
    /// und die hat fuer immer dieselbe Antwort. Wird auf den Platz etwas
    /// anderes gemerkt, ist es ein anderer `Slotstand` und damit ein anderer
    /// Schluessel. Ein Speicher ueber (Uhr, Platz) muesste dagegen bei jeder
    /// Sendung ausdruecklich verworfen werden — genau die Sorte Fehler, die
    /// dieses Vorhaben schon dreimal hatte. Die beiden anderen Stufen liegen
    /// ohnehin davor: Mitgelesene Pixel und ein wieder freier Platz kommen hier
    /// gar nicht an.
    ///
    /// `@ObservationIgnored`, weil dies kein Zustand der App ist, sondern eine
    /// Rechnung: Beobachtet, wuerde das Schreiben aus `body` heraus ein
    /// erneutes Zeichnen ausloesen.
    @ObservationIgnored private var gerastertePixel: [Slotstand: [String?]] = [:]

    /// Die Pixel zu einem gemerkten Stand — gerechnet, wenn noetig, sonst aus
    /// dem Zwischenspeicher darueber.
    private func gerastert(_ stand: Slotstand, _ optionen: Meldungsoptionen) -> [String?] {
        if let fertig = gerastertePixel[stand] { return fertig }
        let pixel = Meldungsbau.feld(optionen, mitIcon: stand.icon != nil,
                                     iconKante: stand.iconKanteOderAcht).punkteRoh
        // Eine Obergrenze, damit eine lange Sitzung ihn nicht unbegrenzt
        // fuellt: Jede Sendung legt einen weiteren Stand an, gebraucht werden
        // fuenf je Uhr. Ganz leeren statt einzeln verdraengen — der naechste
        // Durchlauf rastert die fuenf sichtbaren sofort wieder ein.
        if gerastertePixel.count >= 40 { gerastertePixel.removeAll() }
        gerastertePixel[stand] = pixel
        return pixel
    }

    public func log(_ zeile: String) {
        protokoll.append("\(Self.protokollZeit.string(from: Date())) \(zeile)")
        if protokoll.count > 300 { protokoll.removeFirst(protokoll.count - 300) }
    }

    /// Legt eine Uhr an und fragt sie sofort ab. Der Name kommt aus der Geraetekennung,
    /// laesst sich aber aendern — bei mehreren Uhren ist "Kueche" hilfreicher als eine MAC.
    ///
    /// **`.http` wird ausdruecklich eingetragen, nicht weggelassen.** Daran
    /// haengt die ganze Lesart von `Uhr.betriebsart`: Weil jede von nun an
    /// angelegte Uhr den Schluessel in der Datei hat, kann `nil` allein
    /// „aus einer aelteren Fassung" heissen — und dort gilt MQTT.
    ///
    /// `sitzung` ist wie bei `abfragen` die Naht fuer den Test — die
    /// Oberflaeche ruft `uhrHinzufuegen(host:)`.
    public func uhrHinzufuegen(host: String, sitzung: URLSession = .shared) {
        let erste = uhren.isEmpty
        // `angelegt` traegt den Zeitpunkt, damit ein Grabstein derselben
        // Adresse ueberstimmt werden kann — sonst liesse sich eine einmal
        // entfernte Uhr nie wieder eintragen.
        let neue = Uhr(name: host, host: host, betriebsart: .http, angelegt: Date())
        var ohneGrabstein = grabsteine
        for merkmal in neue.abgleichmerkmale { ohneGrabstein[merkmal] = nil }
        if ohneGrabstein != grabsteine { grabsteine = ohneGrabstein }
        uhren.append(neue)
        // **Nicht bei jeder Adressaenderung**, sondern beim Anlegen, beim
        // Lesen und nach dem Abgleich: Waehrend des Tippens sortiert, spraenge
        // die Zeile unter dem Cursor weg.
        uhren = uhren.nachAdresse()
        if aktiveID == nil { aktiveID = neue.id }
        // Nur bei der allerersten Uhr: sonst traete eine spaeter hinzugefuegte
        // Uhr unversehens der bisherigen Auswahl bei, statt aussen vor zu bleiben.
        if erste { zielIDs.insert(neue.id) }
        abfragen(neue.id, sitzung: sitzung)
    }

    /// `gedaechtnis` ist ein Parameter, damit die Tests nicht in die echte
    /// Ablage unter Application Support greifen muessen — die Oberflaeche
    /// ruft wie bisher `uhrEntfernen(id)`.
    public func uhrEntfernen(_ id: UUID, gedaechtnis: Slotgedaechtnis = .gemeinsam) {
        // **Vor dem Entfernen**, solange die Uhr noch da ist: Ihre Merkmale
        // sind der Grabstein, und ohne den holt das andere Geraet sie beim
        // naechsten Abgleich zurueck.
        if let uhr = uhren.first(where: { $0.id == id }) {
            let jetzt = Date()
            var liste = grabsteine
            for merkmal in uhr.abgleichmerkmale { liste[merkmal] = jetzt }
            grabsteine = liste
        }
        uhren.removeAll { $0.id == id }
        verbunden[id] = nil
        bekannteAnzeigen[id] = nil
        // Auch die Datei auf der Platte: Die Kennung einer entfernten Uhr
        // kommt nicht zurueck, ihre `Slots/<uuid>.json` laege sonst fuer
        // immer da, ohne dass sie noch jemand liest.
        gedaechtnis.vergessen(fuer: id)
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

    /// Die Betriebsart einer Uhr wurde umgestellt. Der Wechsel wirkt sofort:
    /// Wer auf HTTP geht, verliert sein Abonnement (und mit ihm den
    /// Onlinestand und die mitgelesenen Pixel, `abonnementBeenden`); wer auf
    /// MQTT geht, bekommt eines, sobald Praefix und Broker stehen.
    ///
    /// Die Belegung wird danach neu erfragt — sie ist ueber HTTP zu haben,
    /// gleich in welchem Betrieb, und nach dem Abraeumen des Abonnements
    /// stuende sonst nichts mehr da.
    public func betriebsartGeaendert(_ id: UUID, sitzung: URLSession = .shared) {
        // Im HTTP-Betrieb ist „am Broker angemeldet" keine Auskunft mehr ueber
        // etwas, das diese App benutzt — das Haekchen in der Zeile stuende
        // sonst als Rest einer Einrichtung da, die nicht mehr gilt.
        if uhren.first(where: { $0.id == id })?.wirksameBetriebsart == .http {
            verbunden[id] = nil
        }
        horchenAbgleichen()
        belegungAbfragen(id, sitzung: sitzung)
    }

    /// Die Geraeteart wurde von Hand umgestellt.
    ///
    /// Von Hand, weil `abfragen` sie sonst selbst feststellt. Noetig ist der
    /// Griff dort, wo die Feststellung nicht gelingt: Eine AWTRIX NG kann ihre
    /// ganze Schnittstelle hinter eine Anmeldung stellen, und ihr Webport ist
    /// einstellbar.
    ///
    /// **Praefix und MAC gehoeren danach der anderen Firmware.** Sie stehen zu
    /// lassen waere schlimmer als sie zu leeren: Die Werksfirmware haengt die
    /// letzten vier MAC-Stellen an, NG nicht — auf dem stehengebliebenen Thema
    /// hoert kein Geraet, und beide Gattungen schweigen dazu. Derselbe Grund
    /// wie bei `adresseGeaendert`.
    public func geraeteartGeaendert(_ id: UUID, sitzung: URLSession = .shared) {
        guard let i = uhren.firstIndex(where: { $0.id == id }) else { return }
        uhren[i].praefix = ""
        uhren[i].mac = ""
        // Und die Anzeigenbreite: Sie war die der anderen Firmware. Bliebe
        // sie stehen, rechnete die Vorschau mit einem Mass, das dieses Geraet
        // nie hatte.
        uhren[i].panelbreite = nil
        verbunden[id] = nil
        // Mitgelesene Pixel sind Pixel der Werksfirmware. Nach einem Wechsel
        // auf NG zeigten sie einen Stand, den es dort nie gegeben hat.
        slotInhalt[id] = nil
        horchenAbgleichen()
        belegungAbfragen(id, sitzung: sitzung)
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
    ///
    /// `sitzung` ist wie bei `belegungAbfragen` die Naht fuer den Test —
    /// die Oberflaeche ruft `abfragen(id)`.
    public func abfragen(_ id: UUID, sitzung: URLSession = .shared) {
        guard let uhr = uhren.first(where: { $0.id == id }) else { return }
        let host = uhr.host
        let art = uhr.wirksameBetriebsart
        // Der blockierende Teil laeuft auf `Hintergrund`, nicht im kooperativen
        // Pool: Eine Uhr, die nicht antwortet, haelt hier zehn Sekunden. Der
        // `Task` selbst erbt den Hauptakteur, alles danach steht also schon
        // dort, wo es hingehoert.
        Task { [weak self] in
            do {
                let geholt = try await Hintergrund.lauf { () throws -> (Geraetetyp, String, Basisdaten, Int?, Bool?, String?, [String]?) in
                // **Zuerst: was antwortet da ueberhaupt?** Praefix, Belegung
                // und Verbindungsstand stehen bei den beiden Firmwares an
                // verschiedenen Pfaden, und die der einen gibt es bei der
                // anderen nicht. Geraten wuerde hier nichts: `erkannteArt`
                // meldet lieber, dass sie nichts feststellen kann, als eine
                // AWTRIX zur Ulanzi zu erklaeren.
                let gattung = try Geraet(host: host, sitzung: sitzung).erkannteArt()
                let geraet = Geraet(host: host, sitzung: sitzung, typ: gattung)
                // In einem Zug: getrennt geholt kaeme /getBase zweimal dran.
                //
                // Im HTTP-Betrieb ist ein fehlendes Praefix **kein Fehler**:
                // Dort wird kein Thema gebildet, und „Die Uhr hat kein
                // MQTT-Präfix eingestellt" schickte den Leser hinter etwas
                // her, das seine Uhr gar nicht braucht. Dieser eine Zweig
                // holt /getBase ein zweites Mal — er ist die Ausnahme.
                let ergebnis: (praefix: String, basis: Basisdaten, breite: Int?)
                do {
                    ergebnis = try geraet.praefixUndBasis()
                } catch GeraetFehler.keinPraefix where art == .http {
                    ergebnis = ("", try geraet.basis(), nil)
                }
                let praefix = ergebnis.praefix, basis = ergebnis.basis, breite = ergebnis.breite
                // Ob die Uhr am Broker haengt, ist nur im MQTT-Betrieb eine
                // Auskunft ueber etwas, das diese App benutzt.
                let stand = art == .mqtt ? try geraet.brokerstand() : nil
                let steht = stand?.steht
                // Im selben Zug, aber nicht auf demselben Bein: Antwortet die
                // Uhr auf diese eine Frage nicht, ist deshalb die Abfrage von
                // Praefix und Verbindungsstand noch lange nicht gescheitert.
                let namen = try? geraet.anzeigennamen()
                    return (gattung, praefix, basis, breite, steht, stand?.grund, namen)
                }
                let (gattung, praefix, basis, breite, steht, grund, namen) = geholt
                do {
                    guard let self, let i = self.uhren.firstIndex(where: { $0.id == id }) else { return }
                    let gattungGewechselt = self.uhren[i].gattung != gattung
                    // Ausdruecklich eingetragen, auch `.tc002`: Danach steht in
                    // der Datei eine Feststellung und keine Auslassung mehr.
                    self.uhren[i].typ = gattung
                    self.uhren[i].praefix = praefix
                    self.uhren[i].mac = basis.mac
                    // **Nur ueberschreiben, wenn wirklich etwas gemessen
                    // wurde.** Eine Antwort ohne brauchbares `panelWidth`
                    // heisst „nicht beantwortet" und darf eine schon bekannte
                    // Breite nicht gegen die Vorgabe eintauschen.
                    if let breite { self.uhren[i].panelbreite = breite }
                    if gattungGewechselt {
                        self.log(lokf("%@ ist eine %@", self.uhren[i].name, gattung.beschriftung))
                    }
                    // Ohne Praefix bliebe hier ein leerer Name stehen.
                    if self.uhren[i].name == self.uhren[i].host, !praefix.isEmpty {
                        self.uhren[i].name = praefix
                    }
                    self.verbunden[id] = steht
                    // Der Grund steht nur da, wenn es einen gibt — die
                    // Werksfirmware nennt keinen.
                    self.brokergrund[id] = grund
                    if let steht {
                        self.log(lokf("%@: Präfix %@, MQTT %@", self.uhren[i].name, praefix,
                                      steht ? lok("verbunden") : lok("nicht verbunden")))
                    } else {
                        self.log(lokf("%@ hat über HTTP geantwortet", self.uhren[i].name))
                    }
                    // Erst jetzt steht das Praefix — vorher gab es kein Thema, auf das
                    // sich horchen liesse.
                    self.horchenAbgleichen()
                    // Danach, nicht davor: Hat sich das Praefix geaendert, raeumt
                    // `horchenAbgleichen` das alte Abonnement ab und mit ihm die
                    // gemeldete Liste — die eben erfragte Auskunft waere gleich
                    // wieder weg.
                    if let namen { self.belegungGemeldet(namen, fuer: id) }
                }
            } catch {
                self?.verbunden[id] = nil
                self?.fehler = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            }
        }
    }

    /// Der Port wird hier geprueft, nicht erst beim Verbinden: NWEndpoint.Port lehnt die 0
    /// ab und stuerzt bei erzwungenem Auspacken ab. Die leere Adresse ebenso —
    /// seit sie die Vorgabe ist, ist sie der Zustand jeder frischen
    /// Installation, und `NWEndpoint.Host("")` waere ein Ziel, das es nicht
    /// gibt. `Einstellungen.brokerEingerichtet` im Kern prueft beides schon
    /// laenger.
    private var zugang: MQTTZugang? {
        guard !brokerHost.isEmpty, let port = UInt16(brokerPort), port > 0 else { return nil }
        return MQTTZugang(host: brokerHost, port: port,
                          benutzer: benutzer.isEmpty ? nil : benutzer,
                          kennwort: kennwort.isEmpty ? nil : kennwort)
    }

    /// Der Kanal fuer eine Uhr. Welcher es ist, entscheidet `Anzeigen.fuer` —
    /// dieselbe Stelle, aus der auch Werkzeug und Kurzbefehle ihren Kanal
    /// holen, damit die drei nicht auseinanderlaufen.
    public func anzeigen(fuer uhr: Uhr) -> Anzeigen? {
        // Eigene Kennung je Uhr: ein Broker trennt die bestehende Sitzung, sobald
        // dieselbe Kennung erneut verbindet. Mit einer festen Kennung wuerfen sich
        // gleichzeitige Sendungen an mehrere Uhren gegenseitig hinaus.
        let kennung = "tc002-app-" + uhr.id.uuidString.prefix(8).lowercased()
        return Anzeigen.fuer(uhr, brokerzugang: zugang?.mit(clientID: kennung))
    }

    /// Liefert `anzeigen(fuer:)` nichts, fehlt eines von dreien: das Präfix —
    /// die Uhr wurde nie abgefragt —, die Brokeradresse oder ein brauchbarer
    /// Port. Drei verschiedene Ursachen, drei verschiedene Meldungen; eine
    /// Meldung überhaupt, statt stumm zurückzukehren.
    ///
    /// Die leere Adresse ist der Zustand jeder frischen Installation, seit die
    /// Vorgabe leer ist. Ohne eigenen Zweig nennte die Meldung hier den Port,
    /// an dem nichts falsch ist.
    ///
    /// Die drei Sätze gehen als gewöhnliches `String` weiter und werden von
    /// SwiftUI nie nachgeschlagen — deshalb `lok`/`lokf`, und deshalb der Wert
    /// als Platzhalter statt im Schlüssel.
    public func zugangsmeldung(_ uhr: Uhr) -> String {
        // Im HTTP-Betrieb gibt es nur eine Bedingung, und der Broker gehoert
        // nicht dazu: Ohne Adresse gibt es kein Ziel, mit Adresse geht es.
        // Die drei Saetze darunter naehmen den Leser mit auf eine Suche nach
        // einem Praefix, das seine Uhr gar nicht braucht.
        if uhr.wirksameBetriebsart == .http {
            return lokf("Für %@ ist keine Adresse eingetragen. Unter „Einstellungen“ eine eintragen.", uhr.name)
        }
        if uhr.praefix.isEmpty {
            return lokf("%@ wurde noch nicht abgefragt. Unter „Einstellungen“ „Abfragen“ drücken.", uhr.name)
        }
        if brokerHost.isEmpty {
            return lok("Es ist keine Brokeradresse eingetragen. Unter „Einstellungen“ eine eintragen und „Sichern und prüfen“ drücken.")
        }
        return lokf("Der Broker-Port „%@“ ist keine Zahl über 0. Unter „Einstellungen“ richtigstellen und „Sichern und prüfen“ drücken.", brokerPort)
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
        // Eine HTTP-Uhr scheitert nie am Broker — ihn hier zu beschuldigen
        // schickte den Leser an das falsche Ende und faerbte obendrein den
        // Brokerstand rot, obwohl an ihm nichts falsch ist.
        guard uhr.wirksameBetriebsart == .mqtt else { return .uhr(meldung) }
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
    ///
    /// `slotOptionen`/`slotIcon` sind nur gesetzt, wenn diese Sendung zu einem
    /// der fünf Meldungsplätze mit bekannten Reglern gehört (`SendenView`,
    /// `SendeniOS`). Im Bereich „Bilder" (`BilderBereichView`) bleiben sie `nil`, denn ein
    /// gemaltes Bild hat keine Regler, die sich wiederherstellen ließen —
    /// `slotPlatz` kommt aber auch von dort, und genau dann wird die alte
    /// Erinnerung an diesen Platz **weggeworfen**: Wer einen Platz mit etwas
    /// Unmerkbarem überschreibt, darf dort nicht den vorherigen Text
    /// zurücklassen, sonst zeigt der Block nach dem nächsten Start etwas, das
    /// seit dem Malen nicht mehr dort steht.
    ///
    /// Die Dauer kommt aus `slotOptionen.dauer`, kein eigener Parameter: Ein
    /// zweiter, unabhängig übergebener Wert könnte von den tatsächlich
    /// gesendeten Reglern abweichen — die Prüfsumme deckt nur die Pixel ab,
    /// nicht die Dauer, ein Abweichen fiele also nie auf.
    /// Geschrieben wird je erfolgreich erreichter Uhr, nie vorher: Eine
    /// Sendung, die scheitert, darf das Gedächtnis nicht verändern. Schlägt
    /// das Schreiben selbst fehl, bleibt die Sendung trotzdem erfolgreich —
    /// nur eine Protokollzeile hält es fest.
    public func senden(_ frame: Frame, als name: String, slotOptionen: Meldungsoptionen? = nil,
                       slotIcon: String? = nil, slotIconKante: Int = 8,
                       slotPlatz: Int? = nil) async {
        await anZiele({ try $0.zeigen(frame, auf: name) }) { uhr in
            anzeigeBestaetigt(name, fuer: uhr)
            log(lokf("an %@ gesendet: %@", uhr.name, name))
            guard let slotPlatz else { return }
            if let slotOptionen {
                let gemerkt = Slotgedaechtnis.gemeinsam.merken(slotOptionen, icon: slotIcon,
                                                              iconKante: slotIconKante,
                                                              fuer: uhr.id, platz: slotPlatz)
                if !gemerkt {
                    log(lokf("%@: Regler für Slot %d nicht gemerkt", uhr.name, slotPlatz))
                }
            } else if !Slotgedaechtnis.gemeinsam.vergessen(fuer: uhr.id, platz: slotPlatz) {
                log(lokf("%@: alte Regler für Slot %d nicht vergessen", uhr.name, slotPlatz))
            }
        }
    }

    /// Entfernt eine Anzeige von allen gewählten Uhren. Eine leere Nutzlast auf
    /// dem Thema löscht sie — genau null Bytes, nicht "" und nicht {} (§3.2).
    public func loeschen(_ name: String, gedaechtnis: Slotgedaechtnis = .gemeinsam) async {
        await anZiele({ try $0.loeschen(name) }) { uhr in
            anzeigeGeloescht(name, fuer: uhr, gedaechtnis: gedaechtnis)
            log(lokf("auf %@ gelöscht: %@", uhr.name, name))
        }
    }

    /// Die Uhren, an die gesendet wird: die gewaehlten, sofern sie ueberhaupt
    /// beschickbar sind. Ist nichts gewaehlt, ist es die aktive Uhr — sonst
    /// liefe ein Sendeversuch stillschweigend ins Leere.
    ///
    /// Was „beschickbar" heisst, entscheidet die Betriebsart und nicht mehr
    /// allein das Praefix (`Uhr.beschickbar`): Eine HTTP-Uhr braucht keines
    /// und waere unter dem alten Filter stillschweigend uebersprungen worden.
    public func ziele() -> [Uhr] {
        if zielIDs.isEmpty {
            return [aktiveUhr].compactMap { $0 }.filter(\.beschickbar)
        }
        return uhren.filter { zielIDs.contains($0.id) && $0.beschickbar }
    }

    // MARK: - Zuhören

    /// Ein laufendes Abonnement je Uhr, samt der Angaben, unter denen es aufgebaut
    /// wurde: ändert sich Präfix oder Broker, gehört es erneuert.
    private struct Horcher {
        let abonnent: MQTTAbonnent
        let praefix: String
        let brokerkennung: String
        /// Die Gattung gehoert dazu: Die beiden Firmwares veroeffentlichen auf
        /// verschiedenen Themen, ein Abonnement der einen ist fuer die andere
        /// wertlos.
        let gattung: Geraetetyp
    }

    /// Ob diese Uhr ueberhaupt einen Zuhoerer bekommt. Nur MQTT-Uhren: Im
    /// HTTP-Betrieb gaebe es nichts mitzuhoeren — die Uhr reicht ihre eigenen
    /// HTTP-Vorgaenge nicht ueber den Broker weiter (gemessen, siehe
    /// `Betriebsart`), und ein Abonnement auf ihre Themen lieferte allein das
    /// `status`-Wort. Ein Broker, der „nebenbei als Ohr" diente, ist damit
    /// widerlegt und nicht bloss ungenutzt.
    private func gehoertZumHorchen(_ uhr: Uhr) -> Bool {
        uhr.wirksameBetriebsart == .mqtt && !uhr.praefix.isEmpty
    }
    private var horcher: [UUID: Horcher] = [:]
    private var horchtGerade: [UUID: Bool] = [:]
    private var horchenErlaubt = false

    /// Alles, dessen Änderung ein bestehendes Abonnement ungültig macht.
    private var brokerkennung: String { "\(brokerHost)|\(brokerPort)|\(benutzer)|\(kennwort)" }

    /// Beginnt zuzuhören. Ausdrücklich und nicht aus `init` heraus: ein AppZustand
    /// allein — etwa im Test — darf keine Verbindung aufbauen.
    ///
    /// `sitzung` reicht nur bis zur HTTP-Abfrage der Belegung durch — dieselbe
    /// Naht wie bei `belegungAbfragen`, damit der Test den Start ohne Broker
    /// ohne Netz fuehren kann.
    public func horchenStarten(sitzung: URLSession = .shared) {
        horchenErlaubt = true
        horchenAbgleichen()
        // Und die Uhren gleich selbst fragen, was auf ihnen steht: Mitlesen
        // bringt erst dann etwas, wenn die Uhr von sich aus etwas sagt, und das
        // kann ausbleiben. Die Auskunft ueber HTTP ist sofort da und braucht
        // keinen Broker.
        belegungAbfragen(sitzung: sitzung)
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
            // Auch eine auf HTTP umgestellte Uhr wird hier ungueltig: Ihr
            // Abonnement gehoert abgeraeumt, sonst zeigten die Bloecke weiter
            // mitgelesene Pixel, die mit dem Kanal nichts mehr zu tun haben.
            guard uhr == nil || !gehoertZumHorchen(uhr!)
                    || uhr?.praefix != vorhanden.praefix
                    || uhr?.gattung != vorhanden.gattung
                    || vorhanden.brokerkennung != kennung else { continue }
            abonnementBeenden(id, vorhanden)
        }
        guard let zugang else { return }
        for uhr in uhren where gehoertZumHorchen(uhr) && horcher[uhr.id] == nil {
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
            let abonnent = MQTTAbonnent(zugang: eigener, themen: Self.themen(fuer: uhr))
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
            horcher[id] = Horcher(abonnent: abonnent, praefix: uhr.praefix,
                                  brokerkennung: kennung, gattung: uhr.gattung)
        }
    }

    /// Worauf bei dieser Uhr gehorcht wird — je Gattung etwas anderes, und der
    /// Unterschied ist mehr als eine Schreibweise.
    ///
    /// Die Werksfirmware veroeffentlicht ihre **Anzeigenliste** von selbst
    /// (`customList`); bei AWTRIX NG gibt es die ueber MQTT ausdruecklich
    /// nicht (§3.5), sie kommt dort allein ueber HTTP
    /// (`belegungAbfragen`). Dafuer gibt NG etwas, das die Werksfirmware nie
    /// angeboten hat: eine **Antwort** auf jedes Kommando
    /// (`<Thema>/result`, §3.4) — und die faellt unter dasselbe Muster wie das
    /// Mitlesen, wird also mitabonniert und beim Lesen am Suffix
    /// auseinandergehalten.
    ///
    /// `static`, damit der Test die Themen ohne Broker nachrechnen kann.
    static func themen(fuer uhr: Uhr) -> [String] {
        switch uhr.gattung {
        case .tc002:
            return ["\(uhr.praefix)/customList", "\(uhr.praefix)/status",
                    "\(uhr.praefix)/custom/#"]
        case .awtrixNG:
            return [NGThema.erreichbarkeit(praefix: uhr.praefix),
                    NGThema.anzeigenMuster(praefix: uhr.praefix)]
        }
    }

    /// Was von der Uhr hereinkommt. Das Thema entscheidet, nicht die Reihenfolge:
    /// beide Abonnements laufen über dieselbe Verbindung.
    ///
    /// Nicht `private`, damit der Test es ohne Broker aufrufen kann: Was eine
    /// eintreffende Nachricht mit `slotInhalt` macht, ist die einzige Stelle,
    /// an der ein Block behaupten könnte, etwas zu zeigen, das längst
    /// überschrieben ist — dafür gibt es sonst keine Naht.
    func gemeldet(thema: String, nutzlast: Data, fuer id: UUID,
                  gedaechtnis: Slotgedaechtnis = .gemeinsam) {
        guard let uhr = uhren.first(where: { $0.id == id }) else { return }
        guard uhr.gattung == .tc002 else {
            return ngGemeldet(thema: thema, nutzlast: nutzlast, uhr: uhr, gedaechtnis: gedaechtnis)
        }
        switch thema {
        case "\(uhr.praefix)/customList":
            // nil heißt unlesbar — dann lieber den letzten Stand behalten, als ihn
            // durch eine leere Liste zu ersetzen, die etwas anderes behauptet.
            // Deshalb hier abgefangen und nicht an `belegungGemeldet`
            // weitergereicht: Dort heißt nil „die Uhr hat nicht geantwortet".
            guard let namen = Anzeigen.namenAusCustomList(nutzlast) else { return }
            belegungGemeldet(namen, fuer: id)
        case "\(uhr.praefix)/status":
            let text = String(data: nutzlast, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let online = text == "online"
            guard geraetOnline[id] != online else { return }
            geraetOnline[id] = online
            log(online ? lokf("%@ meldet sich online", uhr.name) : lokf("%@ meldet sich offline", uhr.name))
        default:
            // `custom/#` liefert jede Anzeige auf dieser Uhr, gleich von wem —
            // auch unter Namen, die diese App nie vergibt (ein fremder Absender,
            // `mqtttc002 senden --name wetter`). Nur unsere fuenf Slotnamen
            // (`meldung1`…`meldung5`) betreffen `slotInhalt`; „Bilder" schickt
            // ebenfalls an genau die (`BilderBereichView.senden`).
            let vorsilbe = "\(uhr.praefix)/custom/"
            guard thema.hasPrefix(vorsilbe) else { return }
            let name = String(thema.dropFirst(vorsilbe.count))
            guard let platz = Meldungsplatz.platz(fuerName: name) else { return }
            if let pixel = Anzeigen.pixelAusCustomNutzlast(nutzlast) {
                slotInhalt[id, default: [:]][platz] = Slotbild(pixel: pixel)
            } else if nutzlast.isEmpty {
                // Die verlaesslichste Auskunft, die es hier ueberhaupt gibt: Genau
                // null Bytes auf dem Thema loeschen die Anzeige auf der Uhr
                // (`Anzeigen.loeschen`, §3.2) — gleich, wer sie geschickt hat,
                // diese App, das Werkzeug, ein Kurzbefehl oder ein fremdes
                // Werkzeug. Der Platz ist damit wieder leer, und das ist mehr als
                // „Inhalt unbekannt": Der Name gehoert aus der Belegung heraus und
                // die Erinnerung weggeworfen, sonst zeigte der Block eine
                // Erinnerung an einen leeren Platz. Ob die Uhr ihre `customList`
                // danach von selbst erneut veroeffentlicht, ist nicht belegt
                // (siehe `anzeigeVergessen`) — also nicht darauf warten.
                slotInhalt[id]?[platz] = nil
                anzeigeGeloescht(name, fuer: uhr, gedaechtnis: gedaechtnis)
            } else {
                // Nicht zerlegbar (Lauf-GIF oder Geraeteschrift, siehe
                // `pixelAusCustomNutzlast`) sagt zweierlei: Dort liegt etwas
                // Neues, und wir kennen es nicht. Den alten Eintrag
                // stehenzulassen hiesse, einen Stand zu behaupten, den der Block
                // nachweislich nicht mehr hat. Die Belegung bleibt dagegen
                // stehen — auf dem Platz liegt ja etwas. Geloescht greift von
                // selbst die naechste Stufe von `slotzustand`: fuer eigene
                // Sendungen das Gedaechtnis, fuer fremde „unbekannt".
                slotInhalt[id]?[platz] = nil
            }
        }
    }

    /// Was von einer AWTRIX NG hereinkommt.
    ///
    /// **Drei Sorten Nachricht statt dreier Themen** (`themen(fuer:)`):
    ///
    /// - `<P>/availability` sagt online oder offline — dasselbe wie
    ///   `<praefix>/status` der Werksfirmware, nur mit einem zweiten Wort und
    ///   als brokerseitiges Last Will, also auch dann, wenn die Uhr den Stecker
    ///   verliert.
    /// - `<P>/cmd/apps/pushed/<name>/result` ist die Antwort auf ein Kommando —
    ///   **das, was die Werksfirmware nie hatte.** Erfolg bleibt still; eine
    ///   Abweisung wird eine sichtbare Zeile, sonst stuende sie nirgends.
    /// - `<P>/cmd/apps/pushed/<name>` ist die Sendung selbst, mitgelesen, gleich
    ///   von wem.
    ///
    /// **Ein Bild wird daraus nicht.** Die Nutzlast von NG ist Text und Regler,
    /// keine Pixel; ein daraus gerechnetes 52×16-Bild waere unsere Schrift auf
    /// unserer Hoehe und nicht das, was auf einer 32×8-Anzeige steht. Der Block
    /// sagt deshalb „belegt, Inhalt unbekannt" — das ist weniger, aber wahr.
    private func ngGemeldet(thema: String, nutzlast: Data, uhr: Uhr,
                            gedaechtnis: Slotgedaechtnis) {
        let id = uhr.id
        if thema == NGThema.erreichbarkeit(praefix: uhr.praefix) {
            let text = String(data: nutzlast, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let online = text == "online"
            guard geraetOnline[id] != online else { return }
            geraetOnline[id] = online
            log(online ? lokf("%@ meldet sich online", uhr.name) : lokf("%@ meldet sich offline", uhr.name))
            return
        }
        let vorsilbe = NGThema.anzeige(praefix: uhr.praefix, name: "")
        guard thema.hasPrefix(vorsilbe) else { return }
        let rest = String(thema.dropFirst(vorsilbe.count))

        if rest.hasSuffix("/result") {
            let name = String(rest.dropLast("/result".count))
            switch NGNutzlast.ergebnis(nutzlast) {
            case .gelungen, .unlesbar: return
            case .abgewiesen(let grund):
                // Sichtbar und nicht nur im Protokoll: Diese Antwort ist der
                // einzige Ort, an dem eine abgewiesene Sendung ueberhaupt
                // auftaucht — auf der MQTT-Ebene war alles in Ordnung.
                let meldung = lokf("%@ hat „%@“ abgewiesen: %@", uhr.name, name, grund)
                fehler = meldung
                log(meldung)
            }
            return
        }

        guard let platz = Meldungsplatz.platz(fuerName: rest) else { return }
        // Genau null Bytes loeschen bei NG dieselbe Anzeige wie bei der
        // Werksfirmware (§3.2) — die verlaesslichste Auskunft, die es hier gibt.
        guard !nutzlast.isEmpty else {
            slotInhalt[id]?[platz] = nil
            anzeigeGeloescht(rest, fuer: uhr, gedaechtnis: gedaechtnis)
            return
        }
        slotInhalt[id]?[platz] = nil
        anzeigeBestaetigt(rest, fuer: uhr)
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
            // Ohne Broker ist mitgelesen nichts mehr — der Onlinestand und der
            // Slotinhalt kommen nur von dort und sind damit weg. Die Belegung
            // dagegen weiß die Uhr selbst, und die ist über HTTP weiter zu
            // fragen. Erst wenn auch sie nicht antwortet, wirft
            // `belegungGemeldet(nil)` die Auskunft weg und die Ansicht fällt auf
            // die eigene Buchführung — ungefragt wegzuwerfen hieße, beim Start
            // ohne Broker genau die Erinnerung zu zeigen, die diese Abfrage
            // ersetzen soll.
            geraetOnline[id] = nil
            slotInhalt[id] = nil
            belegungAbfragen(id)
            log(lokf("hört bei %@ nicht mehr mit: %@", uhr.name, grund ?? lok("Verbindung weg")))
        }
    }

    private func uhrenSichern() {
        guard initialisiert, let daten = try? JSONEncoder().encode(uhren) else { return }
        UserDefaults.standard.set(daten, forKey: "uhren")
        wolkeSchreiben()
    }

    private func zielIDsSichern() {
        guard initialisiert, let daten = try? JSONEncoder().encode(zielIDs) else { return }
        UserDefaults.standard.set(daten, forKey: "zielIDs")
        wolkeSchreiben()
    }

    /// UserDefaults kennt keine UUID-Schluessel — deshalb als JSON ueber die
    /// Zeichenketten-Fassung der Kennungen.
    private func grabsteineSichern() {
        guard initialisiert else { return }
        guard let daten = try? JSONEncoder().encode(grabsteine) else { return }
        UserDefaults.standard.set(daten, forKey: "grabsteine")
        wolkeSchreiben()
    }

    private func anzeigenSichern() {
        guard initialisiert else { return }
        let flach = Dictionary(uniqueKeysWithValues:
            bekannteAnzeigen.map { ($0.key.uuidString, $0.value) })
        guard let daten = try? JSONEncoder().encode(flach) else { return }
        UserDefaults.standard.set(daten, forKey: "bekannteAnzeigen")
        wolkeSchreiben()
    }

    private func merke(_ wert: String?, _ schluessel: String) {
        guard initialisiert else { return }
        UserDefaults.standard.set(wert, forKey: schluessel)
        wolkeSchreiben()
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
    /// zum Zuhören gibt — und die Belegung wird neu erfragt: `inDenHintergrund`
    /// hat sie mit dem Abonnement weggeräumt, und in der Zwischenzeit kann
    /// jemand anderes auf die Uhr geschrieben haben.
    public func ausDemHintergrund(sitzung: URLSession = .shared) {
        horchenAbgleichen()
        belegungAbfragen(sitzung: sitzung)
    }

    // MARK: - iCloud-Abgleich

    /// Die eigene Einrichtung als ein Stueck.
    public var eigenerStand: Einrichtungsstand {
        Einrichtungsstand(
            uhren: uhren,
            zielIDs: uhren.map(\.id).filter { zielIDs.contains($0) },
            brokerHost: brokerHost, brokerPort: brokerPort, benutzer: benutzer,
            bekannteAnzeigen: Dictionary(
                bekannteAnzeigen.map { ($0.key.uuidString, $0.value) },
                uniquingKeysWith: { erster, _ in erster }),
            entfernt: grabsteine.isEmpty ? nil : grabsteine)
    }

    /// Uebernimmt einen zusammengefuehrten Stand.
    ///
    /// Die `didSet`-Schreiber laufen dabei mit und legen alles in
    /// `UserDefaults` ab — **genau dadurch folgt das Kommandozeilenwerkzeug
    /// dem Abgleich, ohne selbst je die Wolke anzufassen.** Es liest weiter
    /// die Einstellungen der App; sie sind jetzt nur eben die abgeglichenen.
    /// Ein zweiter Leser in der Wolke braeuchte seine eigene Berechtigung, und
    /// er saehe zwischen zwei Abgleichen etwas anderes als die App.
    ///
    /// `uebernimmtGerade` haelt derweil den Rueckweg zu: Sonst schriebe jede
    /// uebernommene Aenderung sich selbst wieder in die Wolke.
    func standUebernehmen(_ stand: Einrichtungsstand) {
        uebernimmtGerade = true
        defer { uebernimmtGerade = false }
        if uhren != stand.uhren { uhren = stand.uhren.nachAdresse() }
        let ziele = Set(stand.zielIDs)
        if zielIDs != ziele { zielIDs = ziele }
        if brokerHost != stand.brokerHost { brokerHost = stand.brokerHost }
        if brokerPort != stand.brokerPort { brokerPort = stand.brokerPort }
        if benutzer != stand.benutzer { benutzer = stand.benutzer }
        let anzeigen = Dictionary(
            stand.bekannteAnzeigen.compactMap { text, liste in
                UUID(uuidString: text).map { ($0, liste) }
            },
            uniquingKeysWith: { erster, _ in erster })
        if bekannteAnzeigen != anzeigen { bekannteAnzeigen = anzeigen }
        let uebrig = stand.entfernt ?? [:]
        if grabsteine != uebrig { grabsteine = uebrig }
        // Die aktive Uhr kann mit dem Stand verschwunden sein.
        if let id = aktiveID, !uhren.contains(where: { $0.id == id }) { aktiveID = uhren.first?.id }
        if aktiveID == nil { aktiveID = uhren.first?.id }
    }

    /// Legt die eigene Einrichtung in die Wolke — wenn sie gewaehlt ist, wenn
    /// sich etwas geaendert hat und wenn sie hineinpasst.
    private func wolkeSchreiben() {
        guard wolkeGewaehlt, !uebernimmtGerade, initialisiert else { return }
        guard let daten = eigenerStand.alsDaten else { return }
        guard daten != zuletztGeschrieben else { return }
        guard daten.count <= Einrichtungsstand.hoechstmass else {
            fehler = lok("Die Einrichtung ist zu groß für den iCloud-Abgleich.")
            return
        }
        zuletztGeschrieben = daten
        wolke.schreiben(daten)
    }

    /// Nimmt, was in der Wolke steht, und fuehrt es mit dem eigenen Stand
    /// zusammen.
    func wolkeLesen() {
        guard wolkeGewaehlt, let daten = wolke.lesen(),
              let fern = try? JSONDecoder().decode(Einrichtungsstand.self, from: daten)
        else { return }
        let zusammen = Einrichtungsstand.zusammengefuehrt(oertlich: eigenerStand, fern: fern)
        standUebernehmen(zusammen)
        // Was beim Zusammenfuehren dazugekommen ist, gehoert zurueck in die
        // Wolke — sonst kennte das andere Geraet die hier eingetragene Uhr nie.
        zuletztGeschrieben = daten
        wolkeSchreiben()
    }

    private func wolkeHorchen() {
        guard wolkeGewaehlt, wolkenBeobachter == nil else { return }
        wolkenBeobachter = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.wolkeLesen() }
            }
        wolke.anstossen()
        wolkeLesen()
    }

    private func wolkeNichtMehrHorchen() {
        if let wolkenBeobachter { NotificationCenter.default.removeObserver(wolkenBeobachter) }
        wolkenBeobachter = nil
    }

    /// Ob der Schalter anzufassen ist.
    ///
    /// Gesperrt, solange umgeschaltet oder nachgesehen wird — und dann, wenn
    /// kein Behaelter da ist und der Abgleich ohnehin aus ist: Ein Schalter,
    /// der von selbst zurueckspringt, erklaert nichts. **Nicht** gesperrt ist
    /// der umgekehrte Fall, Abgleich an und Behaelter weg — sonst saesse man
    /// darin fest.
    public var wolkenschalterGesperrt: Bool {
        wolkeLaeuft || wolkeBereit == nil || (wolkeBereit == false && !wolkeGewaehlt)
    }

    /// Sieht nach, ob ein Behaelter erreichbar ist. Blockiert, laeuft deshalb
    /// losgeloest — und wird erst gerufen, wenn die Einstellungen aufgehen.
    public func wolkeBereitPruefen() {
        guard wolkeBereit == nil, !wolkeLaeuft else { return }
        // `behaelterErmitteln` blockiert — daher `Hintergrund` statt des
        // kooperativen Pools.
        Task { [weak self] in
            let bereit = await Hintergrund.lauf { Ablageort.behaelterErmitteln() != nil }
            self?.wolkeBereit = bereit
        }
    }

    /// Schaltet den Abgleich um — mitsamt dem Umzug. Blockiert, laeuft deshalb
    /// losgeloest; der Schalter bleibt derweil gesperrt.
    public func wolkeUmschalten(_ an: Bool) {
        guard !wolkeLaeuft else { return }
        wolkeLaeuft = true
        // Umschalten laeuft koordiniert gegen den iCloud-Behaelter und kopiert
        // dabei den ganzen Bestand — das kann dauern und blockiert die ganze
        // Zeit. Im kooperativen Pool waere das der denkbar schlechteste Ort.
        Task { [weak self] in
            let ergebnis = await Hintergrund.lauf { Ablageort.umschalten(an) }
            self?.wolkeUmgeschaltet(ergebnis)
        }
    }

    private func wolkeUmgeschaltet(_ ergebnis: Umschaltergebnis) {
        wolkeLaeuft = false
        wolkeBereit = ergebnis.bereit
        wolkeGewaehlt = ergebnis.gewaehlt
        if ergebnis.bilanz.kopiert > 0 {
            log(lokf("iCloud: %d Dateien übernommen", ergebnis.bilanz.kopiert))
        }
        if ergebnis.bilanz.fehlgeschlagen > 0 {
            fehler = lokf("%d Dateien ließen sich nicht kopieren.", ergebnis.bilanz.fehlgeschlagen)
        }
        if ergebnis.gewaehlt {
            Ablageort.gemeinsam.herunterladenAnstossen()
            wolkeHorchen()
        } else {
            wolkeNichtMehrHorchen()
            zuletztGeschrieben = nil
        }
    }
}
