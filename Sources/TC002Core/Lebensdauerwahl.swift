import Foundation

/// Die Einheit, in der die Oberfläche die Lebensdauer einer Anzeige zählt.
public enum Lebensdauereinheit: String, CaseIterable, Sendable {
    case minuten, stunden

    public var sekunden: Int { self == .minuten ? 60 : 3600 }
}

/// Die Lebensdauer so, wie die Oberfläche sie wählt: „Behalten“, eine Zahl mit
/// Einheit und was danach geschieht. Der Kern kennt nur Sekunden
/// (`Lebensdauer`); die Zerlegung steht hier, damit Mac und iPhone dieselbe
/// Umrechnung benutzen.
///
/// „Behalten“ ist `Lebensdauer.sekunden == 0`. Zahl, Einheit und Ablauf bleiben
/// dabei erhalten, damit sie beim Ausschalten von „Behalten“ wieder dastehen.
public struct Lebensdauerwahl: Equatable, Sendable {
    public static let hoechstzahl = 999

    public var behalten: Bool
    public var zahl: Int
    public var einheit: Lebensdauereinheit
    public var ablauf: Lebensablauf

    /// Die Vorgabe einer neuen Anzeige: nicht behalten, 30 Minuten, entfernen.
    public init(behalten: Bool = false, zahl: Int = 30,
                einheit: Lebensdauereinheit = .minuten, ablauf: Lebensablauf = .entfernen) {
        self.behalten = behalten
        self.zahl = zahl
        self.einheit = einheit
        self.ablauf = ablauf
    }

    /// Die Wahl hinter einer Lebensdauer; `nil` ist die Vorgabe
    /// (`Meldungsoptionen.lebensdauer`). Volle Stunden erscheinen als Stunden,
    /// alles andere in Minuten (aufgerundet, mindestens eine).
    public init(_ lebensdauer: Lebensdauer?) {
        let l = lebensdauer ?? .vorgabe
        self.init(ablauf: l.ablauf)
        guard l.sekunden > 0 else {
            behalten = true
            return
        }
        if l.sekunden % 3600 == 0, l.sekunden / 3600 <= Self.hoechstzahl {
            einheit = .stunden
            zahl = l.sekunden / 3600
        } else {
            einheit = .minuten
            zahl = min(Self.hoechstzahl, max(1, (l.sekunden + 59) / 60))
        }
    }

    /// Was an die Uhr geht. Die Zahl wird in 1…999 gehalten.
    public var lebensdauer: Lebensdauer {
        guard !behalten else { return Lebensdauer(sekunden: 0, ablauf: ablauf) }
        return Lebensdauer(sekunden: min(Self.hoechstzahl, max(1, zahl)) * einheit.sekunden,
                           ablauf: ablauf)
    }
}

/// Die Regler einer Nachricht (Oberflächenwort für Benachrichtigung). Vorgaben
/// der App: Aufwecken und Ersetzen an, „bis ich sie zurückziehe“ (`Nachrichtdauerwahl`).
/// Eine gehaltene Nachricht hält die Warteschlange an: Jede spätere wartet hinter ihr.
public struct Nachrichtwahl: Equatable, Sendable {
    public static let hoechstdurchlaeufe = 9

    public var steht: Nachrichtdauerwahl
    public var aufwecken: Bool
    public var ersetzen: Bool
    public var klang: Klangwahl

    public init(steht: Nachrichtdauerwahl = Nachrichtdauerwahl(), aufwecken: Bool = true, ersetzen: Bool = true,
                klang: Klangwahl = Klangwahl()) {
        self.steht = steht
        self.klang = klang
        self.aufwecken = aufwecken
        self.ersetzen = ersetzen
    }

    /// `durationMs / 1000` für den Rahmen der Nachricht; die Anzeigedauer
    /// (`Meldungsoptionen.dauer`) gilt für Nachrichten nicht.
    public var dauerSekunden: Int? { steht.dauer.dauerSekunden }

    /// „Ersetzen“ ist das Gegenteil von „Einreihen“ (`stack`).
    public var optionen: Benachrichtigungsoptionen { optionen(nachrichtentext: "") }

    /// Mit dem Klang; „Vorlesen“ ohne eigenen Sprechtext liest `nachrichtentext`.
    public func optionen(nachrichtentext: String) -> Benachrichtigungsoptionen {
        Benachrichtigungsoptionen(halten: steht.dauer.halten, einreihen: !ersetzen, aufwecken: aufwecken,
                                  wiederholungen: steht.dauer.wiederholungen,
                                  klang: klang.klaenge(nachrichtentext: nachrichtentext))
    }
}
