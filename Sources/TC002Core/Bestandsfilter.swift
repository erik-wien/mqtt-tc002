import Foundation

/// Was von einem Bestand zu sehen ist — Suche, Größe, Bewegung. Drei Fragen an
/// dieselbe Liste, an einer Stelle beantwortet statt in jeder Oberfläche neu.
///
/// `Iconfilter` stellt dieselben drei Fragen an `Icon` und kennt deshalb nur
/// die beiden Icongrößen. Dieser hier fragt über `Editoreintrag` und damit über
/// alle drei: Die Übersicht am Schreibtisch und das Icons-Blatt am Telefon
/// zeigen beide 8 × 8, 16 × 16 und 52 × 16.
///
/// Die Bewegung steht nicht im Eintrag, sondern in der Datei; sie wird deshalb
/// als Funktion gereicht, wie bei `Iconfilter`. Die Oberfläche liest sie einmal
/// beim Laden des Bestands und schlägt danach nur noch nach.
public struct Bestandsfilter: Equatable, Sendable {
    /// Name oder Nummer, Groß- und Kleinschreibung egal. Leer heißt: alles.
    public var suche: String
    /// `nil` heißt: alle drei Größen.
    public var groesse: Leinwandgroesse?
    /// Nur Einträge mit mehr als einem Einzelbild.
    public var nurBewegte: Bool

    public init(suche: String = "", groesse: Leinwandgroesse? = nil, nurBewegte: Bool = false) {
        self.suche = suche
        self.groesse = groesse
        self.nurBewegte = nurBewegte
    }

    /// Ob überhaupt etwas eingeschränkt ist. Nur dann steht ein Zurücksetzen da:
    /// Ein Knopf, der nichts zu tun hat, ist eine Frage ohne Anlass.
    public var schraenktEin: Bool {
        !suche.trimmingCharacters(in: .whitespaces).isEmpty || groesse != nil || nurBewegte
    }

    public mutating func zuruecksetzen() {
        self = Bestandsfilter()
    }
}

public extension Array where Element == Editoreintrag {
    /// Der Bestand, wie der Filter ihn übrig lässt. Die Reihenfolge bleibt —
    /// sie kommt aus `Editorbestand.alle()` und ist Teil des Versprechens.
    func gefiltert(_ filter: Bestandsfilter,
                   bewegt: (Editoreintrag) -> Bool) -> [Editoreintrag] {
        var ergebnis = gefiltert(nach: filter.suche)
        if let groesse = filter.groesse { ergebnis = ergebnis.filter { $0.groesse == groesse } }
        if filter.nurBewegte { ergebnis = ergebnis.filter(bewegt) }
        return ergebnis
    }
}
