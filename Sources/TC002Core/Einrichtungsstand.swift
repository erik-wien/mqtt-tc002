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

        // **Zusammengefuehrt wird ueber `Uhr.abgleichmerkmale`, nicht ueber
        // `id` allein.** Dort steht, warum: Die Kennung entsteht je Geraet,
        // dieselbe Uhr hat also zwei — wer darueber zusammenfuehrt, haengt sie
        // aneinander statt sie zu vereinen (nachgewiesen am 14.09.2026 an drei
        // Eintraegen derselben Uhr). Die Kennung wegzuwerfen waere der
        // Gegenfehler: Wer eine Adresse aendert, hat weiterhin dieselbe Uhr.
        //
        // Darum zaehlt jede Uebereinstimmung, und zwar **ueber Ecken**: Trifft
        // sich A mit B ueber die Adresse und B mit C ueber die MAC, gehoeren
        // alle drei zusammen. Das ist eine Vereinigungssuche, kein Woerterbuch.
        //
        // Diese Fassung heilt auch rueckwirkend: Mehrere Eintraege derselben
        // Uhr fallen zu einem zusammen, sobald der Abgleich wieder laeuft.
        let alle = oertlich.uhren + fern.uhren
        var wurzel = Array(0..<alle.count)
        func suchen(_ i: Int) -> Int {
            var k = i
            while wurzel[k] != k { wurzel[k] = wurzel[wurzel[k]]; k = wurzel[k] }
            return k
        }
        func vereinen(_ a: Int, _ b: Int) {
            let wa = suchen(a), wb = suchen(b)
            if wa != wb { wurzel[max(wa, wb)] = min(wa, wb) }
        }
        var zuerstGesehen: [String: Int] = [:]
        for (i, uhr) in alle.enumerated() {
            for merkmal in uhr.abgleichmerkmale {
                if let frueher = zuerstGesehen[merkmal] { vereinen(frueher, i) }
                else { zuerstGesehen[merkmal] = i }
            }
        }

        var reihenfolge: [Int] = []
        var gruppen: [Int: [Int]] = [:]
        for i in alle.indices {
            let w = suchen(i)
            if gruppen[w] == nil { reihenfolge.append(w) }
            gruppen[w, default: []].append(i)
        }

        // Welche Kennung die zusammengefallene Uhr behaelt, muss auf **beiden**
        // Geraeten gleich ausgehen — sonst schriebe jedes seine eigene in die
        // Wolke und sie wechselten einander ab. Die kleinere gewinnt: eine
        // Regel, die ohne Absprache ueberall dasselbe ergibt.
        let fernAb = oertlich.uhren.count
        var neueKennung: [UUID: UUID] = [:]
        var uhren: [Uhr] = []
        for w in reihenfolge {
            let mitglieder = gruppen[w] ?? []
            // Die Wolke gewinnt bei den Feldern — wie bisher.
            let gewaehlt = mitglieder.first(where: { $0 >= fernAb }) ?? mitglieder[0]
            var uhr = alle[gewaehlt]
            let kanonisch = mitglieder.map { alle[$0].id }
                .min { $0.uuidString < $1.uuidString } ?? uhr.id
            uhr.id = kanonisch
            for i in mitglieder { neueKennung[alle[i].id] = kanonisch }
            uhren.append(uhr)
        }
        ergebnis.uhren = uhren

        let vorhanden = Set(uhren.map(\.id))
        // Durch die Abbildung, sonst zeigte eine Auswahl aus der Wolke auf eine
        // Kennung, die es nach dem Zusammenfallen nicht mehr gibt — sie fiele
        // heraus, und stillschweigend gaelte „alle".
        var auswahl: [UUID] = []
        for ziel in fern.zielIDs {
            let kanonisch = neueKennung[ziel] ?? ziel
            if vorhanden.contains(kanonisch), !auswahl.contains(kanonisch) { auswahl.append(kanonisch) }
        }
        ergebnis.zielIDs = auswahl.isEmpty ? uhren.map(\.id) : auswahl

        if !fern.brokerHost.isEmpty { ergebnis.brokerHost = fern.brokerHost }
        if !fern.brokerPort.isEmpty { ergebnis.brokerPort = fern.brokerPort }
        if !fern.benutzer.isEmpty { ergebnis.benutzer = fern.benutzer }

        // Die Schluessel sind Kennungen als Zeichenkette und muessen durch
        // dieselbe Abbildung — sonst haengt die Buchfuehrung an einer Uhr, die
        // es nicht mehr gibt, und die fuenf Bloecke wuessten nichts mehr von
        // ihren Anzeigen.
        func kanonisch(_ schluessel: String) -> String {
            guard let alt = UUID(uuidString: schluessel), let neu = neueKennung[alt] else {
                return schluessel
            }
            return neu.uuidString
        }
        var anzeigen: [String: [String]] = [:]
        for (uhr, namen) in oertlich.bekannteAnzeigen.sorted(by: { $0.key < $1.key })
            + fern.bekannteAnzeigen.sorted(by: { $0.key < $1.key }) {
            let schluessel = kanonisch(uhr)
            var liste = anzeigen[schluessel] ?? []
            for name in namen where !liste.contains(name) { liste.append(name) }
            anzeigen[schluessel] = liste
        }
        ergebnis.bekannteAnzeigen = anzeigen

        return ergebnis
    }
}
