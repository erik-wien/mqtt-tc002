import Foundation

/// Die Einrichtung dieser Installation als ein Stueck — genau das, was ueber
/// iCloud abgeglichen wird.
///
/// **Zwei Mechanismen, nicht einer.** Dateien gehoeren in einen Behaelter
/// (`Ablageort`), Einstellungen liegen in `UserDefaults` und gehen nur ueber
/// `NSUbiquitousKeyValueStore`. Das ist keine Umstaendlichkeit, sondern Apples
/// Aufteilung: Ein Behaelter kennt keine Schluessel, und die
/// Schluessel-Wert-Ablage kennt keine Dateien.
///
/// **Ein Schluessel, nicht sieben.** Die Ablage erlaubt 1024 Schluessel und 1 MB
/// im ganzen. Sieben einzelne Schluessel kaemen einzeln an, und zwischendurch
/// stuende eine Einrichtung da, deren Uhrenliste schon neu und deren Auswahl
/// noch alt ist. Ein Schluessel kommt als Ganzes oder gar nicht —
/// `zusammenfuehren` bekommt damit immer zwei vollstaendige Staende zu sehen.
///
/// **Was hier nicht drinsteht, und warum:**
/// - Das **Brokerkennwort** — es liegt im Schluesselbund. Es mitzunehmen hiesse
///   iCloud-Schluesselbund, also einen dritten Mechanismus mit eigener
///   Berechtigung, eigenem Dialog und eigenem Versagensfall. Der Preis dafuer,
///   es wegzulassen, ist ein Kennwort, das man je Geraet einmal eintraegt.
/// - Die Regler unter „Senden" (`senden.text`, `senden.farbe` …). Das ist kein
///   eingerichteter Zustand, sondern das, was man gerade tippt. Zwei Geraete,
///   die einander den halb geschriebenen Satz aus dem Feld ziehen, waeren
///   keine Verbesserung.
public struct Einrichtungsstand: Codable, Equatable, Sendable {
    public var uhren: [Uhr]
    /// Als Feld statt als `Set`, damit die abgelegte Form eine feste
    /// Reihenfolge hat — ein `Set` schriebe bei gleichem Inhalt mal so und mal
    /// so, und jedes Schreiben saehe nach einer Aenderung aus.
    public var zielIDs: [UUID]
    public var brokerHost: String
    public var brokerPort: String
    public var benutzer: String
    /// Kennungen als Zeichenkette — wie in `UserDefaults` auch, wo ein
    /// Woerterbuch keine UUID-Schluessel kennt.
    public var bekannteAnzeigen: [String: [String]]

    public init(uhren: [Uhr] = [], zielIDs: [UUID] = [], brokerHost: String = "",
                brokerPort: String = "", benutzer: String = "",
                bekannteAnzeigen: [String: [String]] = [:]) {
        self.uhren = uhren
        self.zielIDs = zielIDs
        self.brokerHost = brokerHost
        self.brokerPort = brokerPort
        self.benutzer = benutzer
        self.bekannteAnzeigen = bekannteAnzeigen
    }
}

// MARK: - Passt das hinein?

extension Einrichtungsstand {
    /// Was `NSUbiquitousKeyValueStore` traegt: 1 MB im ganzen, und ebenso viel
    /// je Schluessel. Bei **einem** Schluessel ist beides dieselbe Grenze.
    public static let hoechstmass = 1_024 * 1_024

    /// **Mit sortierten Schluesseln**, und das ist kein Schoenheitswunsch:
    /// `bekannteAnzeigen` ist ein Woerterbuch und schriebe sonst bei gleichem
    /// Inhalt mal so und mal so. Der Vergleich „hat sich etwas geaendert"
    /// (`AppZustand.zuletztGeschrieben`) verglich dann Bytes, die sich
    /// unterscheiden duerfen, ohne dass sich etwas geaendert hat — und jedes
    /// Lesen aus der Wolke loeste ein Schreiben aus.
    public var alsDaten: Data? {
        let kodierer = JSONEncoder()
        kodierer.outputFormatting = [.sortedKeys]
        return try? kodierer.encode(self)
    }

    /// Ob dieser Stand in die Ablage passt. Er tut es mit weitem Abstand: Eine
    /// Uhr wiegt rund 200 Bytes, ein gemerkter Anzeigenname ein paar Dutzend.
    /// Erst mehrere tausend Uhren oder zehntausende Anzeigennamen kaemen an die
    /// Grenze — und wer die hat, hat ein anderes Problem.
    public var passtInDieWolke: Bool {
        guard let daten = alsDaten else { return false }
        return daten.count <= Self.hoechstmass
    }
}

// MARK: - Widerspruch zweier Geraete

extension Einrichtungsstand {
    /// Fuehrt den eigenen Stand mit dem zusammen, der aus der Wolke kam.
    ///
    /// **Warum nicht einfach „letzter gewinnt".** Die ganze Einrichtung liegt
    /// unter einem Schluessel; „letzter gewinnt" hiesse: Wer am Mac eine Uhr
    /// hinzufuegt, waehrend am Telefon eine Betriebsart umgestellt wird,
    /// verliert eine der beiden Aenderungen vollstaendig — und zwar wortlos.
    /// Zusammengefuehrt wird deshalb **je Uhr**, nicht je Einrichtung.
    ///
    /// Die Regeln, jede mit ihrem Grund:
    ///
    /// - **Uhren**: vereinigt ueber die Kennung. Was beide kennen, nimmt die
    ///   Fassung aus der Wolke — sie ist die spaetere, denn sie ist eben
    ///   angekommen. Was nur eine Seite kennt, bleibt; eine neu eingetragene
    ///   Uhr verschwindet nicht, weil das andere Geraet sie noch nicht kennt.
    ///   Der eigene Bestand behaelt seine Reihenfolge, Fremdes kommt hinten an.
    /// - **Auswahl**: die aus der Wolke, beschraenkt auf Uhren, die es noch
    ///   gibt. Bleibt nichts uebrig, gelten alle — dieselbe Lesart, die
    ///   `AppZustand.init` und `Einstellungen.ziele` schon haben.
    /// - **Broker**: ein gefuellter Wert aus der Wolke gewinnt, ein leerer
    ///   loescht nichts. Sonst raeumte ein Geraet, auf dem nie ein Broker
    ///   eingetragen wurde, dem anderen seinen weg.
    /// - **Bekannte Anzeigen**: vereinigt. Das ist die Buchfuehrung darueber,
    ///   was auf einer Uhr stehen koennte; faellt ein Name weg, bleibt die
    ///   Anzeige auf der Uhr stehen, ohne dass es noch einen Weg gaebe, sie zu
    ///   loeschen.
    ///
    /// **Was bleibt: Aendern beide Geraete dieselbe Uhr, gewinnt die Wolke.**
    /// Das ist nicht wegzurechnen — eine Konfliktkopie einer Uhr waere eine
    /// zweite Uhr mit derselben Adresse, und die waere schlimmer als der
    /// verlorene Griff.
    public static func zusammengefuehrt(oertlich: Einrichtungsstand,
                                        fern: Einrichtungsstand) -> Einrichtungsstand {
        var ergebnis = oertlich

        let ausDerWolke = Dictionary(fern.uhren.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var uhren = oertlich.uhren.map { ausDerWolke[$0.id] ?? $0 }
        let eigene = Set(oertlich.uhren.map(\.id))
        uhren += fern.uhren.filter { !eigene.contains($0.id) }
        ergebnis.uhren = uhren

        let vorhanden = Set(uhren.map(\.id))
        let auswahl = fern.zielIDs.filter { vorhanden.contains($0) }
        ergebnis.zielIDs = auswahl.isEmpty ? uhren.map(\.id) : auswahl

        if !fern.brokerHost.isEmpty { ergebnis.brokerHost = fern.brokerHost }
        if !fern.brokerPort.isEmpty { ergebnis.brokerPort = fern.brokerPort }
        if !fern.benutzer.isEmpty { ergebnis.benutzer = fern.benutzer }

        var anzeigen = oertlich.bekannteAnzeigen
        for (uhr, namen) in fern.bekannteAnzeigen {
            var liste = anzeigen[uhr] ?? []
            for name in namen where !liste.contains(name) { liste.append(name) }
            anzeigen[uhr] = liste
        }
        ergebnis.bekannteAnzeigen = anzeigen

        return ergebnis
    }
}
