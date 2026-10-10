import Foundation

/// Die gemeinten Uhren für die Kurzbefehle — eine Stelle für alle, damit die
/// Prüfungen (eingerichtet, abgefragt, Broker vorhanden) nicht je Kurzbefehl
/// etwas anderes heißen. Der Kern kennt weder AppIntents noch Rückfragen: Er
/// wirft `Fehler`, und die Oberfläche macht daraus eine Meldung.
public enum Kurzbefehlsziele {
    /// Ein Mangel der Einrichtung. Er ist nie ein fehlender Parameterwert und
    /// darf deshalb keine Rückfrage nach einem Wert auslösen: Die Ursache liegt
    /// in den App-Einstellungen, und ein neuer Wert im Kurzbefehl behebt sie nicht.
    public enum Fehler: Error, LocalizedError, Equatable {
        case keineUhrEingerichtet
        case uhrUnbekannt
        case keinBroker
        case nichtAbgefragt([String])
        case ohneAdresse([String])

        public var errorDescription: String? {
            switch self {
            case .keineUhrEingerichtet:
                return lok("Noch keine Uhr eingerichtet. Das geht in der App unter „Einstellungen“.")
            case .uhrUnbekannt:
                return lok("Diese Uhr gibt es in der App nicht mehr. Im Kurzbefehl eine andere wählen.")
            case .keinBroker:
                return lok("Kein Broker eingerichtet. In der App unter „Einstellungen“ Adresse und Port eintragen und „Verbindung prüfen“ drücken.")
            case .nichtAbgefragt(let namen):
                return lokf("Noch nicht abgefragt: %@. In der App unter „Einstellungen“ auf „Abfragen“ tippen.",
                            namen.joined(separator: ", "))
            case .ohneAdresse(let namen):
                return lokf("Ohne Adresse: %@. In der App unter „Einstellungen“ eine eintragen.",
                            namen.joined(separator: ", "))
            }
        }
    }

    /// - Parameters:
    ///   - uhr: die gewählte Uhr; `nil` heißt die in der App gewählten Ziele.
    ///   - nurBeschickbare: Uhren, die noch nicht abgefragt sind, fallen weg
    ///     statt zu scheitern — solange wenigstens eine bleibt.
    public static func bestimmen(_ e: Einstellungen, uhr: UUID?,
                                 nurBeschickbare: Bool = false) throws -> [Uhr] {
        guard !e.uhren.isEmpty else { throw Fehler.keineUhrEingerichtet }
        var gewaehlt: [Uhr]
        if let uhr {
            guard let gefunden = e.uhr(id: uhr) else { throw Fehler.uhrUnbekannt }
            gewaehlt = [gefunden]
        } else {
            gewaehlt = e.ziele
        }
        if nurBeschickbare {
            let bereit = gewaehlt.filter(\.beschickbar)
            guard !bereit.isEmpty else { throw Fehler.nichtAbgefragt(gewaehlt.map(\.name)) }
            gewaehlt = bereit
        }
        // Erst jetzt, wo die Ziele feststehen: Ein Broker ist nur nötig, wenn
        // wenigstens eine dieser Uhren über ihn geht.
        if Einstellungen.brokerNoetig(fuer: gewaehlt), !e.brokerEingerichtet {
            throw Fehler.keinBroker
        }
        let ohnePraefix = gewaehlt.filter { $0.wirksameBetriebsart == .mqtt && !$0.beschickbar }
        guard ohnePraefix.isEmpty else { throw Fehler.nichtAbgefragt(ohnePraefix.map(\.name)) }
        let ohneAdresse = gewaehlt.filter { $0.wirksameBetriebsart == .http && !$0.beschickbar }
        guard ohneAdresse.isEmpty else { throw Fehler.ohneAdresse(ohneAdresse.map(\.name)) }
        return gewaehlt
    }
}
