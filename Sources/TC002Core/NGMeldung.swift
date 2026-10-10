import Foundation

/// Eine eingetroffene MQTT-Nachricht, schon zerlegt.
///
/// Das Zerlegen (JSON, UTF-8-Umwandlung einer Nutzlast bis 56 KiB) ist reine
/// Rechnung und braucht den Zustand der App nicht; es läuft deshalb auf der
/// Warteschlange des Abonnenten. Auf den Hauptakteur geht nur dieses fertige
/// Ergebnis, das die Oberfläche übernimmt.
public enum NGMeldung: Equatable, Sendable {
    /// `<P>/availability`.
    case erreichbarkeit(online: Bool)
    /// Ein Zustands- oder Ereignisthema der Uhr.
    case ereignis(Uhrenereignis)
    /// `<Thema>/result`: die Antwort auf ein Kommando, benannt wie in der Meldung.
    case antwort(bezeichnung: String, NGErgebnis)
    /// Eine mitgelesene Anzeige. `platz` ist `nil` für alles außerhalb der
    /// fünf festen Plätze, `text` die Nutzlast als UTF-8 (`nil`, wenn sie keines
    /// ist); `leer` heißt genau null Bytes, also gelöscht.
    case anzeige(name: String, platz: Int?, leer: Bool, text: String?, bytes: Int)
    /// Alles andere.
    case unbeachtet

    public static func auswerten(thema: String, nutzlast: Data, praefix: String) -> NGMeldung {
        if thema == NGThema.erreichbarkeit(praefix: praefix) {
            let text = String(data: nutzlast, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return .erreichbarkeit(online: text == "online")
        }
        if let ereignis = Uhrenereignis.lesen(thema: thema, nutzlast: nutzlast, praefix: praefix) {
            return .ereignis(ereignis)
        }
        if let name = NGThema.ergebnisBezeichnung(thema: thema, praefix: praefix) {
            return .antwort(bezeichnung: name, NGNutzlast.ergebnis(nutzlast))
        }
        let vorsilbe = NGThema.anzeige(praefix: praefix, name: "")
        guard thema.hasPrefix(vorsilbe) else { return .unbeachtet }
        let rest = String(thema.dropFirst(vorsilbe.count))
        return .anzeige(name: rest, platz: Meldungsplatz.platz(fuerName: rest),
                        leer: nutzlast.isEmpty,
                        text: nutzlast.isEmpty ? nil : String(data: nutzlast, encoding: .utf8),
                        bytes: nutzlast.count)
    }
}
