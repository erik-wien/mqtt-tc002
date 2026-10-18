import Foundation

/// Was die Kurzbefehle aus ihren Eingaben machen — die Rechnung, nicht die
/// Oberfläche. Die Intents (`TC002Kurzbefehle`) reichen nur Werte durch; hier
/// stehen Grenzen, Vorgaben und Verbote, damit sie sich mit `swift test`
/// prüfen lassen.
public enum Kurzbefehlswerte {
    /// Dauer einer Anzeige in Sekunden. Die Obergrenze ist die der Uhr
    /// (`NGNutzlast`); der Parameter im Kurzbefehl hat dieselbe Spanne, eine
    /// Variable aus einer Automation kann sie trotzdem überschreiten.
    public static let dauerbereich = 1...86_400

    /// `nil` heißt: keine eigene Dauer. Null und Negatives sind keine Angabe,
    /// alles darüber wird auf die Obergrenze gebracht.
    public static func dauer(_ sekunden: Int?) -> Int? {
        guard let sekunden, sekunden > 0 else { return nil }
        return min(sekunden, dauerbereich.upperBound)
    }

    /// Lebensdauer einer Anzeige in Minuten (24 Stunden).
    public static let lebensdauerbereich = 1...1_440

    /// Die Lebensdauer, die ein Kurzbefehl verlangt. `nil` heißt: nichts
    /// angegeben, es gilt die Vorgabe der App (`Lebensdauer.vorgabe`).
    ///
    /// „Behalten“ geht vor: Eine Anzeige ohne Ablauf hat keinen Ablauf. Gibt
    /// es nur den Ablauf (entfernen oder markieren), bleibt die Zeit die
    /// Vorgabe von 30 Minuten.
    public static func lebensdauer(minuten: Int?, behalten: Bool, ablauf: Lebensablauf?) -> Lebensdauer? {
        if behalten { return .aus }
        guard minuten != nil || ablauf != nil else { return nil }
        let sekunden = minuten.map { min(max($0, lebensdauerbereich.lowerBound), lebensdauerbereich.upperBound) * 60 }
            ?? Lebensdauer.vorgabe.sekunden
        return Lebensdauer(sekunden: sekunden, ablauf: ablauf ?? .entfernen)
    }

    /// Wie oft laufender Text einer Nachricht durchzieht.
    public static let durchlaufbereich = 1...Nachrichtwahl.hoechstdurchlaeufe

    public enum Fehler: Error, LocalizedError, Equatable {
        case klangUndVorlesen
        case iconGeloescht(String)

        public var errorDescription: String? {
            switch self {
            case .klangUndVorlesen:
                return lok("Entweder ein Klang oder Vorlesen, nicht beides.")
            case .iconGeloescht(let name):
                return lokf("Das gewählte Icon „%@“ gibt es nicht mehr. Bitte im Kurzbefehl ein anderes wählen.", name)
            }
        }
    }

    /// Das Moodlight, das ein Kurzbefehl verlangt: Farbe **oder** Weißton in
    /// Kelvin (`SteuerungsFehler.farbeUndKelvin`), dazu die Helligkeit in
    /// Prozent wie am Regler der Fernbedienung. Ohne jede Angabe leuchtet es
    /// weiß: "Moodlight an" soll etwas einschalten, nicht nach einem Wert
    /// fragen. Nur die Helligkeit lässt die Farbe, wie die Uhr sie hat.
    public static func moodlight(farbe: String?, kelvin: Int?, prozent: Int?) throws -> Moodlight {
        let licht = Moodlight(farbe: (farbe == nil && kelvin == nil && prozent == nil) ? "#FFFFFF" : farbe,
                              kelvin: kelvin,
                              helligkeit: prozent.map { Steuerwerte.helligkeitRoh(prozent: $0) })
        try licht.pruefen()
        return licht
    }

    /// Die Klangwahl einer Nachricht aus den drei Angaben des Kurzbefehls:
    /// Name einer Melodie oder MP3-Datei auf der Uhr, Vorlesen, Wiederholen.
    /// Beides zugleich geht nicht (`Klangwahl.Art` ist eines von beiden).
    public static func klangwahl(name: String?, vorlesen: Bool, wiederholen: Bool) throws -> Klangwahl {
        let klangname = name?.trimmingCharacters(in: .whitespaces) ?? ""
        if vorlesen && !klangname.isEmpty { throw Fehler.klangUndVorlesen }
        if vorlesen { return Klangwahl(art: .vorlesen, wiederholen: wiederholen) }
        if klangname.isEmpty { return Klangwahl(wiederholen: wiederholen) }
        return Klangwahl(art: .uhr, name: klangname, wiederholen: wiederholen)
    }

    /// Die Bestände, aus denen ein Kurzbefehl Icons liest: 8×8 samt den
    /// mitgelieferten und die eigenen 16×16.
    public static func iconbestaende() -> [Iconsammlung] {
        [Iconsammlung(schreibordner: Iconordner.eigene, leseordner: [Iconordner.mitgeliefert]),
         Iconsammlung(schreibordner: Iconordner.eigene16, kante: 16)]
    }

    /// Alle Icons beider Bestände nach Name sortiert (bei gleichem Namen nach
    /// Kennung): die Vorschläge der Icon-Auswahl.
    public static func iconvorschlaege(bestaende: [Iconsammlung]? = nil) -> [Icon] {
        (bestaende ?? iconbestaende()).flatMap { $0.alle() }.sorted {
            let ordnung = $0.name.localizedStandardCompare($1.name)
            return ordnung == .orderedSame ? $0.kennung < $1.kennung : ordnung == .orderedAscending
        }
    }

    /// Die Treffer der Suchzeile in der Icon-Auswahl: Name oder Nummer
    /// (Schlüssel), ohne Rücksicht auf Groß- und Kleinschreibung. Eine leere
    /// Suche liefert alle.
    public static func icons(passend suche: String, in icons: [Icon]) -> [Icon] {
        icons.gefiltert(nach: suche)
    }

    /// Das Icon zu einer Auswahl (`Icon.kennung`), frisch aus dem Bestand
    /// gelesen. Ist es seit der Wahl gelöscht worden, ein klarer Fehler statt
    /// eines Senden ohne Icon.
    public static func icon(kennung: String, bestaende: [Icon]? = nil) throws -> Icon {
        let icons = bestaende ?? iconvorschlaege()
        guard let treffer = icons.first(where: { $0.kennung == kennung }) else {
            throw Fehler.iconGeloescht(kennung.split(separator: "/", maxSplits: 1).last.map(String.init) ?? kennung)
        }
        return treffer
    }
}

public extension Iconbestaende {
    /// Die Sätze für den Ergebnisdialog eines Kurzbefehls: bei welchen Uhren
    /// das gewählte Icon durch eine kleinere Fassung ersetzt wird (16×16 auf
    /// acht Zeilen). Leer, wenn alle Uhren das gewählte bekommen.
    static func hinweise(gewaehlt: Icon, fuer uhren: [Uhr],
                         bestaende: (() -> [Iconsammlung])? = nil) -> [String] {
        uhren.compactMap { uhr in
            hinweis(gewaehlt: gewaehlt,
                    tatsaechlich: passend(gewaehlt, fuer: Anzeigemass.fuer(uhr), in: bestaende),
                    uhr: uhr.name)
        }
    }
}

/// Die Helligkeit, wie ein Kurzbefehl sie verlangt: ein Wert in Prozent (wie
/// der Regler der Fernbedienung), die Automatik des Lichtsensors, oder beides.
public struct Helligkeitswunsch: Equatable, Sendable {
    public var prozent: Int?
    public var automatisch: Bool?

    public init(prozent: Int? = nil, automatisch: Bool? = nil) {
        self.prozent = prozent
        self.automatisch = automatisch
    }

    public enum Fehler: Error, LocalizedError, Equatable {
        case nichtsAngegeben
        /// Der Sensor übergeht einen festen Wert, solange die Automatik an ist.
        case automatikUndWert

        public var errorDescription: String? {
            switch self {
            case .nichtsAngegeben:
                return lok("Weder ein Wert noch die Automatik ist angegeben.")
            case .automatikUndWert:
                return lok("Automatik und fester Wert schließen sich aus: Der Lichtsensor übergeht den Wert.")
            }
        }
    }

    public func pruefen() throws {
        if prozent == nil && automatisch == nil { throw Fehler.nichtsAngegeben }
        if prozent != nil && automatisch == true { throw Fehler.automatikUndWert }
    }

    /// Schickt es an die Uhr. Erst die Automatik, dann der Wert: Ein fester
    /// Wert gilt erst, wenn die Automatik aus ist. Eine Uhr ohne Lichtsensor
    /// weist die Automatik ab (`SteuerungsFehler.wirkungslos`), statt sie still
    /// zu überspringen.
    public func anwenden(auf anzeigen: Anzeigen, faehigkeiten: Geraetefaehigkeiten?) throws {
        try pruefen()
        if let automatisch { try anzeigen.helligkeitAutomatik(automatisch, faehigkeiten: faehigkeiten) }
        if let prozent {
            try anzeigen.helligkeit(Steuerwerte.helligkeitRoh(prozent: prozent), faehigkeiten: faehigkeiten)
        }
    }
}
