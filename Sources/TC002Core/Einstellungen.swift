import Foundation

/// Welche Art Geraet hinter einer `Uhr` steckt.
///
/// Heute gibt es nur eine Art, und nichts fragt danach — der Typ steht hier,
/// damit `Uhr.typ` einen hat. Eine zweite Art kommt mit ihrem eigenen
/// Durchgang und traegt dann ihren eigenen Fall ein; alte Einstellungen bleiben
/// dabei lesbar, weil sie den Schluessel gar nicht erst enthalten.
public enum Geraetetyp: String, Codable, Sendable {
    case tc002
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

    public init(id: UUID = UUID(), name: String, host: String,
                praefix: String = "", mac: String = "", typ: Geraetetyp? = nil) {
        self.id = id
        self.name = name
        self.host = host
        self.praefix = praefix
        self.mac = mac
        self.typ = typ
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
    private static func ablage(_ bereich: String) -> UserDefaults? {
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
