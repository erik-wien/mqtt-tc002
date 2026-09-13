import Foundation

/// Welche Art Geraet hinter einer `Uhr` steckt.
///
/// Alte Einstellungen bleiben lesbar, weil sie den Schluessel gar nicht erst
/// enthalten — `Uhr.typ` ist `Optional`, und `nil` heisst `.tc002`.
///
/// **Der umgekehrte Weg traegt nicht.** Eine Datei, in der `awtrixNG` steht,
/// wirft in einer Fassung vor dieser beim Decode, und weil beide Leser mit
/// `try?` lesen, waere die Folge eine leere Uhrenliste statt einer Meldung.
/// Wer also je eine dritte Art eintraegt, aendert damit nichts an heutigen
/// Installationen, wohl aber an der Rueckwaertsrichtung; das ist der Preis
/// eines `RawRepresentable`-Enums in einem Dateiformat und hier bewusst
/// bezahlt, weil eine unbekannte Geraeteart nicht sinnvoll zu raten waere.
public enum Geraetetyp: String, Codable, Sendable {
    /// Die Ulanzi-Werksfirmware (TC002). Der Bestand.
    case tc002
    /// AWTRIX NG auf einer TC001/TC002 — eigene Themen, eigene Nutzlast,
    /// eigene Geraetezeichnung.
    case awtrixNG
}

/// Auf welchem Weg eine Uhr beschickt wird. Je Uhr eine Wahl, kein
/// Programmschalter: In einem Haus kann die eine Uhr unmittelbar erreichbar
/// sein und die naechste nur ueber den Broker.
///
/// **Es ist ein Tausch, kein Gewinn** — beide Wege koennen etwas, das der
/// andere nicht kann (die Messungen stehen in `docs/tc002-protokoll.md`, §3
/// und §5):
///
/// - `.http` antwortet. Anlegen, Loeschen und Umschalten quittiert die Uhr mit
///   `{"code":200}`, ein unbekannter Anzeigenname mit `404` — eine gescheiterte
///   Sendung ist damit als solche zu erkennen. Ein Broker wird nicht gebraucht,
///   ein Praefix auch nicht.
/// - `.mqtt` schweigt. MQTT 3.1.1 hat keinen Rueckkanal fuer eine abgelehnte
///   Veroeffentlichung; dafuer liest die App am Broker **mit**, was *andere*
///   an dieselbe Uhr schicken, und kann daraus die fuenf Bloecke fuellen.
///
/// Ein Mitlesen ueber HTTP gibt es nicht, und zwar nicht aus Bequemlichkeit:
/// Am 13.09.2026 wurde 45 Sekunden lang auf `<praefix>/custom/#`,
/// `<praefix>/customList` und `<praefix>/status` gehorcht, mit einer
/// HTTP-Loeschung mittendrin — es kam eine einzige Nachricht, `status online`.
/// **Die Uhr reicht HTTP-Vorgaenge nicht ueber MQTT weiter.** Ein zusaetzlich
/// eingetragener Broker taugt deshalb nicht als Ohr fuer den HTTP-Betrieb.
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
    public var host: String
    public var praefix: String = ""
    public var mac: String = ""
    /// **Optional, und das ist der ganze Grund, warum es heute schon da ist.**
    ///
    /// Ein nachtraeglich hinzugefuegtes **Pflichtfeld** macht bestehende
    /// Einstellungen unlesbar: Swift setzt beim synthetisierten Decode keine
    /// Vorgabewerte fuer fehlende Schluessel ein — auch ein Feld *mit*
    /// Vorgabewert wirft `keyNotFound`. Gelesen wird die Liste an beiden
    /// Stellen mit `try?` (`Einstellungen.gelesen`, `AppZustand.init`), es
    /// gaebe also keinen Fehler und keine Meldung, sondern eine **leere
    /// Uhrenliste** — in der App und im Werkzeug, beim ersten Start nach dem
    /// Update. Nur ein `Optional` bekommt `decodeIfPresent`.
    /// `EinstellungenTests` misst beide Richtungen nach.
    ///
    /// `nil` heisst „TC002", nicht „unbekannt": Jede bestehende Einrichtung
    /// ist eine. Beim Schreiben faellt das Feld wieder weg, solange es `nil`
    /// ist — eine aeltere Fassung liest die Datei damit weiterhin.
    ///
    /// Heute fragt nichts danach, und die Oberflaeche zeigt es nicht.
    public var typ: Geraetetyp?

    /// Der Weg, auf dem diese Uhr beschickt wird — **optional aus demselben
    /// Grund wie `typ`**: Ein nachtraegliches Pflichtfeld wirft beim Decode
    /// `keyNotFound`, und weil beide Leser (`Einstellungen.gelesen`,
    /// `AppZustand.init`) mit `try?` lesen, waere die Folge keine Meldung,
    /// sondern eine leere Uhrenliste in App **und** Werkzeug.
    ///
    /// **`nil` heisst `.mqtt`, nicht `.http` — und das ist eine Entscheidung
    /// ueber Bestand, keine ueber Vorgaben.** Die Vorgabe ist sehr wohl HTTP:
    /// `AppZustand.uhrHinzufuegen` traegt `.http` ausdruecklich ein, jede von
    /// nun an angelegte Uhr hat den Schluessel also in der Datei. `nil` kommt
    /// damit **nur** in Dateien vor, die eine Fassung vor dieser geschrieben
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
                praefix: String = "", mac: String = "", typ: Geraetetyp? = nil,
                betriebsart: Betriebsart? = nil) {
        self.id = id
        self.name = name
        self.host = host
        self.praefix = praefix
        self.mac = mac
        self.typ = typ
        self.betriebsart = betriebsart
    }
}

/// Was die App abgelegt hat, nur zum Lesen.
///
/// Die App selbst fuehrt ihre Einstellungen in `AppZustand` und schreibt sie
/// dort; dieser Typ ist der Weg von aussen hinein — fuer das
/// Kommandozeilenwerkzeug, das dieselbe Einrichtung benutzen soll, statt eine
/// zweite zu verlangen. Deshalb hier ausdruecklich **kein** Schreiben: zwei
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
    /// **Adresse und Benutzer sind leer, und das ist die Vorgabe.** Ein
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
    /// den iCloud-Abgleich, und zwar ausdruecklich in **derselben** Ablage —
    /// nur so sieht das Werkzeug denselben Ort wie die App.
    static func ablage(_ bereich: String) -> UserDefaults? {
        Bundle.main.bundleIdentifier == bereich ? .standard : UserDefaults(suiteName: bereich)
    }

    /// Liest die Einstellungen der App.
    public static func gelesen(bereich: String = kennung) -> Einstellungen {
        let d = ablage(bereich)
        let uhren = (try? JSONDecoder().decode([Uhr].self,
                        from: d?.data(forKey: "uhren") ?? Data())) ?? []
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
