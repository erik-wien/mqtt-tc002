import Foundation

public extension Array where Element == Uhr {
    /// Nach Adresse geordnet — ziffernbewusst: `localizedStandardCompare`
    /// vergleicht Zifferngruppen als Zahlen, sonst stünde `10.0.0.9` hinter
    /// `10.0.0.94`.
    ///
    /// Sortiert wird die abgelegte Liste selbst und nicht bloß die Anzeige:
    /// Dieselbe Reihenfolge gilt dann in den Einstellungen, im Titelmenü, in
    /// der Zielauswahl und im Kommandozeilenwerkzeug.
    func nachAdresse() -> [Uhr] {
        sorted { $0.host.localizedStandardCompare($1.host) == .orderedAscending }
    }

    /// Adressen ohne Leerraum am Rand — beim Lesen, nicht erst beim Setzen.
    ///
    /// `Uhr.host` trimmt in seinem `didSet`, und Beobachter laufen beim
    /// Decodieren nicht: Was eine aeltere Fassung krumm abgelegt hat, bliebe
    /// krumm. Die App heilt es beim Start — das Werkzeug und die Kurzbefehle
    /// lesen aber dieselbe Datei, und zwar moeglicherweise, bevor die App das
    /// naechste Mal laeuft. Deshalb hier, an der Stelle, die alle drei
    /// benutzen.
    func mitSauberenAdressen() -> [Uhr] {
        map { uhr in
            var sauber = uhr
            sauber.host = uhr.host.trimmingCharacters(in: .whitespacesAndNewlines)
            return sauber
        }
    }
}

/// Auf welchem Weg eine Uhr beschickt wird. Je Uhr eine Wahl, kein
/// Programmschalter: In einem Haus kann die eine Uhr unmittelbar erreichbar
/// sein und die naechste nur ueber den Broker.
///
/// Es ist ein Tausch, kein Gewinn (`docs/awtrix-ng-protokoll.md` §3, §4):
///
/// - `.http` antwortet mit einem Status und, bei einer Abweisung, einem
///   Fehlerrumpf — eine gescheiterte Sendung ist als solche zu erkennen. Ein
///   Broker wird nicht gebraucht, ein Praefix auch nicht.
/// - `.mqtt` kennt keinen Rueckkanal fuer eine abgelehnte Veroeffentlichung
///   (QoS 0); die Uhr antwortet auf `<Thema>/result`, und die App liest am
///   Broker mit, was *andere* an dieselbe Uhr schicken.
///
/// Ein Mitlesen ueber HTTP gibt es nicht: Die Uhr reicht HTTP-Vorgaenge nicht
/// ueber MQTT weiter. Ein zusaetzlich eingetragener Broker taugt deshalb nicht
/// als Ohr fuer den HTTP-Betrieb.
public enum Betriebsart: String, Codable, Sendable, CaseIterable {
    case http
    case mqtt
}

/// Eine eingerichtete Uhr. Praefix und MAC ermittelt die App selbst beim
/// Abfragen — sie werden nie von Hand eingetragen.
///
/// Liegt im Kern und nicht in der Oberflaeche, weil das Kommandozeilenwerkzeug
/// dieselbe Liste liest. Die Codable-Form ist damit ein Dateiformat: Wer hier
/// Felder umbenennt, macht die Einstellungen einer laufenden Installation
/// unlesbar.
public struct Uhr: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var name: String
    /// Die Adresse der Uhr — ohne Leerraum am Rand.
    ///
    /// Getrimmt wird beim Setzen und nicht erst beim Senden: Ein Leerzeichen
    /// vorn oder hinten ist unsichtbar und macht aus der Adresse etwas, woraus
    /// sich keine Anfrage bilden laesst (`URL(string:)` sagt dazu `nil`). Erst
    /// beim Senden gemeldet, stuende der Fehler als Fenster mitten in der
    /// Arbeit — fuer einen Fehler, der beim Eintippen entstand und dort auch
    /// hingehoert.
    ///
    /// In der Mitte wird nichts angetastet: Ein Leerzeichen dort ist ebenso
    /// falsch, aber sichtbar, und Namen mit Leerzeichen gibt es (`mein
    /// geraet.local` ist kein gueltiger Hostname, aber das zu entscheiden ist
    /// nicht die Aufgabe eines Trimmers).
    public var host: String {
        didSet {
            // Eine Zuweisung im eigenen `didSet` loest ihn nicht erneut aus.
            let sauber = host.trimmingCharacters(in: .whitespacesAndNewlines)
            if sauber != host { host = sauber }
        }
    }
    public var praefix: String = ""
    public var mac: String = ""
    /// Woran zwei Geräte dieselbe Uhr erkennen.
    ///
    /// Die `id` allein taugt dafür nicht: Die UUID entsteht beim Anlegen auf
    /// dem jeweiligen Gerät. Dieselbe Uhr, auf dem Mac und auf dem iPhone
    /// eingetragen, hat zwei verschiedene — der Abgleich hielt sie für zwei
    /// Uhren und hängte sie aneinander, und Entfernen half nicht: Beim
    /// nächsten Abgleich kamen die Einträge zurück.
    ///
    /// Die `id` wegzuwerfen wäre aber der entgegengesetzte Fehler: Wer auf
    /// einem Gerät die Adresse einer Uhr ändert, hat weiterhin dieselbe Uhr,
    /// und nur die Kennung weiß das noch.
    ///
    /// Darum zählt hier jede Übereinstimmung. Zwei Einträge sind dieselbe
    /// Uhr, wenn sie die Kennung teilen, oder die MAC-Adresse, oder die
    /// Adresse. `Einrichtungsstand.zusammengefuehrt` legt daraus Gruppen — auch
    /// über Ecken: Trifft sich A mit B über die Adresse und B mit C über die
    /// MAC, sind alle drei dieselbe Uhr.
    /// Wann dieser Eintrag angelegt wurde — nur fuer den Abgleich, und nur
    /// dafuer, damit ein Wiederanlegen einen Grabstein schlagen kann
    /// (`Einrichtungsstand.entfernt`). Ohne das gewaenne die Loeschung fuer
    /// immer: Wer eine Uhr entfernt und spaeter wieder eintraegt, saehe sie
    /// beim naechsten Abgleich verschwinden.
    ///
    /// `Optional` — ein nachtraegliches
    /// Pflichtfeld wirft beim Decode und liesse die Uhrenliste leer statt
    /// fehlerhaft. `nil` heisst „von frueher"; ein Grabstein gewinnt dann.
    public var angelegt: Date?

    public var abgleichmerkmale: [String] {
        var merkmale = ["id:\(id.uuidString)"]
        let kennung = mac.lowercased().filter(\.isHexDigit)
        if !kennung.isEmpty { merkmale.append("mac:\(kennung)") }
        let adresse = host.trimmingCharacters(in: .whitespaces).lowercased()
        if !adresse.isEmpty { merkmale.append("host:\(adresse)") }
        return merkmale
    }

    /// Breite der Anzeige in Pixeln, wie die Uhr sie meldet
    /// (`GET /api/v1/capabilities` → `display.width`, §1).
    ///
    /// `Optional`: Ein nachtraeglich hinzugefuegtes Pflichtfeld wirft beim
    /// Decode `keyNotFound`, und weil die Leser mit `try?` lesen, waere die
    /// Folge eine leere Uhrenliste statt einer Meldung. Gelesen wird es
    /// nirgends unmittelbar, sondern ueber `anzeigemass`.
    public var panelbreite: Int?

    /// Hoehe der Anzeige, wie `panelbreite` gemeldet (`display.height`).
    public var panelhoehe: Int?

    /// Die Masse der Anzeige dieser Uhr, in Pixeln. Solange die Uhr nicht
    /// gefragt wurde, gilt die Vorgabe 52 × 16 — als Vorgabe benannt, nicht
    /// als Tatsache ueber diese Uhr: Sobald „Abfragen" gelaufen ist, steht die
    /// gemeldete Groesse da.
    public var anzeigemass: (breite: Int, hoehe: Int) {
        if let b = panelbreite, let h = panelhoehe,
           let mass = AwtrixNG.plausiblesMass(breite: b, hoehe: h) { return mass }
        return (AwtrixNG.vorgabebreite, AwtrixNG.vorgabehoehe)
    }

    /// Der Weg, auf dem diese Uhr beschickt wird — optional aus demselben
    /// Grund: Ein nachtraegliches Pflichtfeld wirft beim Decode
    /// `keyNotFound`, und weil beide Leser (`Einstellungen.gelesen`,
    /// `AppZustand.init`) mit `try?` lesen, waere die Folge keine Meldung,
    /// sondern eine leere Uhrenliste in App und Werkzeug.
    ///
    /// `nil` heisst `.mqtt`, nicht `.http` — und das ist eine Entscheidung
    /// ueber Bestand, keine ueber Vorgaben. Die Vorgabe ist sehr wohl HTTP:
    /// `AppZustand.uhrHinzufuegen` traegt `.http` ausdruecklich ein, jede von
    /// nun an angelegte Uhr hat den Schluessel also in der Datei. `nil` kommt
    /// damit nur in Dateien vor, die eine Fassung vor dieser geschrieben
    /// hat — und jede dieser Uhren ist nachweislich fuer MQTT eingerichtet:
    /// Sie hat ein abgefragtes Praefix, einen eingetragenen Broker und ein
    /// Kennwort im Schluesselbund, und die App hat bisher ausschliesslich
    /// darueber gesendet.
    ///
    /// Wuerde `nil` als `.http` gelesen, wechselte jede bestehende
    /// Installation beim ersten Start nach dem Update stillschweigend den
    /// Kanal: Das Abonnement fiele weg, `slotInhalt` bliebe leer, und alle
    /// fuenf Bloecke fielen auf Erinnerung oder „unbekannt" zurueck — eine
    /// sichtbare Verschlechterung, um die niemand gebeten hat. Umgekehrt
    /// kostet diese Lesart nichts: Wer HTTP will, waehlt es in einem Griff.
    ///
    /// Gelesen wird das Feld nirgends unmittelbar, sondern ueber
    /// `wirksameBetriebsart` — damit die Lesart an genau einer Stelle steht.
    public var betriebsart: Betriebsart?

    /// Was fuer diese Uhr gilt. Der einzige Leser von `betriebsart`.
    public var wirksameBetriebsart: Betriebsart { betriebsart ?? .mqtt }

    /// Ob diese Uhr ueberhaupt beschickt werden kann. Die Bedingung ist je
    /// Betriebsart eine andere, und genau daran ist der alte, einheitliche
    /// Praefix-Filter falsch geworden: Eine HTTP-Uhr braucht kein Praefix —
    /// sie wird unter ihrer Adresse angesprochen, nicht unter einem Thema.
    public var beschickbar: Bool {
        switch wirksameBetriebsart {
        case .http: return !host.isEmpty
        case .mqtt: return !praefix.isEmpty
        }
    }

    public init(id: UUID = UUID(), name: String, host: String,
                praefix: String = "", mac: String = "",
                betriebsart: Betriebsart? = nil, panelbreite: Int? = nil,
                panelhoehe: Int? = nil, angelegt: Date? = nil) {
        self.id = id
        self.name = name
        self.host = host
        self.praefix = praefix
        self.mac = mac
        self.angelegt = angelegt
        self.betriebsart = betriebsart
        self.panelbreite = panelbreite
        self.panelhoehe = panelhoehe
    }

    /// Der Stand der Einrichtung, wie er in der Datei steht. Eine Uhr ohne
    /// diesen Schluessel wurde angelegt, als es noch zwei Geraetearten gab
    /// (`typ` fehlend, `"tc002"` oder `"awtrixNG"`).
    static let einrichtungsstand = 2

    private enum Schluessel: String, CodingKey {
        case id, name, host, praefix, mac, angelegt, betriebsart, panelbreite, panelhoehe
        case einrichtung
    }

    /// Eine Einrichtung aelteren Stands bleibt lesbar, traegt aber zwei Angaben,
    /// die fuer AWTRIX NG nicht stimmen, und beide werden verworfen:
    ///
    /// - Das Themen-Praefix. Die Werksfirmware bildete es aus ihrem
    ///   eingestellten Praefix, `_` und den letzten vier Stellen der MAC;
    ///   bei NG steht dort `mqttPrefix` unveraendert, leer die Geraete-uid
    ///   (§2). Ein Praefix, das nicht stimmt, liesse die App auf ein Thema
    ///   senden, das niemand abonniert, und NG antwortet darauf gar nicht.
    ///   Ohne Praefix ist eine MQTT-Uhr nicht beschickbar (`beschickbar`);
    ///   `AppZustand.abfragen` holt es von der Uhr neu.
    /// - Die Anzeigemasse (32 × 8 einer TC001).
    ///
    /// Unbekannte Schluessel (das fruehere `typ`) uebergeht der Decoder.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Schluessel.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        host = try c.decode(String.self, forKey: .host)
        mac = try c.decodeIfPresent(String.self, forKey: .mac) ?? ""
        angelegt = try c.decodeIfPresent(Date.self, forKey: .angelegt)
        betriebsart = try c.decodeIfPresent(Betriebsart.self, forKey: .betriebsart)
        let aktuell = (try c.decodeIfPresent(Int.self, forKey: .einrichtung) ?? 0) >= Self.einrichtungsstand
        praefix = aktuell ? try c.decodeIfPresent(String.self, forKey: .praefix) ?? "" : ""
        panelbreite = aktuell ? try c.decodeIfPresent(Int.self, forKey: .panelbreite) : nil
        panelhoehe = aktuell ? try c.decodeIfPresent(Int.self, forKey: .panelhoehe) : nil
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Schluessel.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(host, forKey: .host)
        try c.encode(praefix, forKey: .praefix)
        try c.encode(mac, forKey: .mac)
        try c.encodeIfPresent(angelegt, forKey: .angelegt)
        try c.encodeIfPresent(betriebsart, forKey: .betriebsart)
        try c.encodeIfPresent(panelbreite, forKey: .panelbreite)
        try c.encodeIfPresent(panelhoehe, forKey: .panelhoehe)
        try c.encode(Self.einrichtungsstand, forKey: .einrichtung)
    }
}

/// Was die App abgelegt hat, nur zum Lesen.
///
/// Die App selbst fuehrt ihre Einstellungen in `AppZustand` und schreibt sie
/// dort; dieser Typ ist der Weg von aussen hinein — fuer das
/// Kommandozeilenwerkzeug, das dieselbe Einrichtung benutzen soll, statt eine
/// zweite zu verlangen. Deshalb hier ausdruecklich kein Schreiben: zwei
/// Schreiber auf denselben Schluesseln waeren ein Wettlauf, und die laufende
/// App bekaeme von einer Aenderung ohnehin nichts mit.
public struct Einstellungen: Sendable {
    /// Die Buendelkennung der App — zugleich der Name ihres Einstellungsbereichs
    /// und ihres Schluesselbunddienstes.
    public static let kennung = "cloud.eriks.mqtt-tc002"

    /// Was gilt, solange niemand etwas anderes eingetragen hat.
    ///
    /// Steht hier und nicht in der App, weil die App eine unveraenderte Vorgabe
    /// gar nicht erst ablegt: Wer den Port nie angefasst hat, hat keinen
    /// gespeicherten Port — und das Kommandozeilenwerkzeug saehe dann keinen
    /// Broker, obwohl die App laengst sendet.
    ///
    /// Adresse und Benutzer sind leer, und das ist die Vorgabe. Ein
    /// vorausgefuelltes Feld ist schlechter als ein leeres: Man sieht ihm nicht
    /// an, ob dort ein echter Wert steht, und muss ueberschreiben statt
    /// einzutragen. Ein Platzhalter im Feld sagt dasselbe, ohne es zu
    /// behaupten. Nur der Port bleibt belegt — 1883 ist der Standardport von
    /// MQTT und keine Angabe ueber diese Installation.
    public enum Vorgabe {
        public static let brokerHost = ""
        public static let brokerPort = "1883"
        public static let benutzer = ""
    }

    public var brokerHost: String
    public var brokerPort: UInt16
    public var benutzer: String?
    private let kennwortQuelle: @Sendable () -> String?
    public var uhren: [Uhr]
    /// An welche Uhren die App zuletzt senden sollte. Leer heisst „alle".
    public var zielIDs: Set<UUID>

    /// Wird erst beim Zugriff geholt. Eifriges Lesen oeffnet einen
    /// Passwortdialog auch dort, wo gar nichts gesendet wird.
    public var kennwort: String? { kennwortQuelle() }

    public init(brokerHost: String, brokerPort: UInt16, benutzer: String?,
                kennwort: String?, uhren: [Uhr], zielIDs: Set<UUID>) {
        self.brokerHost = brokerHost
        self.brokerPort = brokerPort
        self.benutzer = benutzer
        self.kennwortQuelle = { kennwort }
        self.uhren = uhren
        self.zielIDs = zielIDs
    }

    init(brokerHost: String, brokerPort: UInt16, benutzer: String?,
         kennwortQuelle: @escaping @Sendable () -> String?,
         uhren: [Uhr], zielIDs: Set<UUID>) {
        self.brokerHost = brokerHost
        self.brokerPort = brokerPort
        self.benutzer = benutzer
        self.kennwortQuelle = kennwortQuelle
        self.uhren = uhren
        self.zielIDs = zielIDs
    }

    /// Die Ablage der App, von wo auch immer gelesen wird.
    ///
    /// Zwei Faelle, und beide kommen vor:
    ///
    /// Laeuft das Werkzeug als eigenstaendiges Programm (aus `swift run`, oder
    /// ueber einen Verweis irgendwo im Pfad), ist sein eigener Bereich ein
    /// anderer als der der App — es braucht also ausdruecklich den unter der
    /// Buendelkennung der App.
    ///
    /// Wird es dagegen unmittelbar im Buendel der App aufgerufen, ist
    /// `Bundle.main` genau dieses Buendel, und seine Kennung ist bereits die der
    /// App. Ein Bereich mit dem eigenen Namen ist bei `UserDefaults` aber nicht
    /// vorgesehen: Der Aufruf meldet „does not make sense and will not work" und
    /// liefert eine Ablage, in der nichts steht. Dann ist `.standard` richtig.
    ///
    /// Gefragt ist also, welchen Bereich das laufende Programm als *seinen
    /// eigenen* ansieht — nur damit kann `suiteName` zusammenstossen. Deshalb
    /// steht hier `Bundle.main` und nicht `Programmbuendel`, obwohl beide
    /// sonst dasselbe Buendel meinen.
    /// Nicht `private`: `Ablageort` liest und schreibt hier den Schalter fuer
    /// den iCloud-Abgleich, und zwar ausdruecklich in derselben Ablage —
    /// nur so sieht das Werkzeug denselben Ort wie die App.
    static func ablage(_ bereich: String) -> UserDefaults? {
        Bundle.main.bundleIdentifier == bereich ? .standard : UserDefaults(suiteName: bereich)
    }

    /// Liest die Einstellungen der App.
    public static func gelesen(bereich: String = kennung) -> Einstellungen {
        let d = ablage(bereich)
        let uhren = ((try? JSONDecoder().decode([Uhr].self,
                        from: d?.data(forKey: "uhren") ?? Data())) ?? [])
            .mitSauberenAdressen()
        let ziele = (try? JSONDecoder().decode(Set<UUID>.self,
                        from: d?.data(forKey: "zielIDs") ?? Data())) ?? []
        let benutzer = d?.string(forKey: "benutzer") ?? Vorgabe.benutzer
        return Einstellungen(
            brokerHost: d?.string(forKey: "brokerHost") ?? Vorgabe.brokerHost,
            brokerPort: UInt16(d?.string(forKey: "brokerPort") ?? Vorgabe.brokerPort) ?? 0,
            benutzer: benutzer.isEmpty ? nil : benutzer,
            kennwortQuelle: { Schluesselbund.lesen("broker", dienst: bereich) },
            uhren: uhren,
            zielIDs: ziele)
    }

    /// Die Uhren, an die gesendet wird: die zuletzt gewaehlten, und wenn keine
    /// gewaehlt ist, alle. Eine Auswahl, die auf geloeschte Uhren zeigt, faellt
    /// dabei still weg — sonst zaehlte sie als „keine Auswahl" und traefe alle.
    public var ziele: [Uhr] {
        let gewaehlt = uhren.filter { zielIDs.contains($0.id) }
        return gewaehlt.isEmpty ? uhren : gewaehlt
    }

    /// Sucht eine Uhr ueber Name oder Adresse, ohne Ruecksicht auf Gross- und
    /// Kleinschreibung.
    public func uhr(benannt name: String) -> Uhr? {
        uhren.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
            ?? uhren.first { $0.host.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Reicht, um zu wissen, ob ueberhaupt gesendet werden kann — und kommt
    /// ohne das Kennwort aus.
    public var brokerEingerichtet: Bool { !brokerHost.isEmpty && brokerPort > 0 }

    /// Ob fuer diese Uhren ueberhaupt ein Broker noetig ist.
    ///
    /// Nur MQTT-Uhren brauchen einen; wer ausschliesslich ueber HTTP sendet,
    /// soll nicht an einer Brokerabfrage haengenbleiben, die nichts mit seiner
    /// Einrichtung zu tun hat. Eine Stelle fuer alle drei Absender — App
    /// (`AppZustand.eingerichtet`), Werkzeug und Kurzbefehle —, damit die
    /// Bedingung nicht dreimal etwas anderes heisst.
    public static func brokerNoetig(fuer uhren: [Uhr]) -> Bool {
        uhren.contains { $0.wirksameBetriebsart == .mqtt }
    }

    public func zugang(clientID: String) -> MQTTZugang? {
        guard brokerEingerichtet else { return nil }
        return MQTTZugang(host: brokerHost, port: brokerPort,
                          benutzer: benutzer, kennwort: kennwort)
            .mit(clientID: clientID)
    }
}

extension MQTTZugang {
    /// Eigene Kennung je Sendung: Ein Broker trennt die bestehende Sitzung,
    /// sobald dieselbe Kennung erneut verbindet.
    public func mit(clientID: String) -> MQTTZugang {
        var kopie = self
        kopie.clientID = clientID
        return kopie
    }
}
