import Foundation

/// Wartet auf die Antwort der Uhr auf `<Thema>/result` (§3.4), während ein
/// Kommando hinausgeht.
///
/// Als Protokoll, damit Tests ohne Broker auskommen. Die App braucht das nicht:
/// Sie bleibt ohnehin am Broker und liest die Antworten mit
/// (`AppZustand.horchenAbgleichen`). Das Werkzeug und die Kurzbefehle laufen
/// nur kurz und müssen deshalb selbst zuhören.
public protocol ErgebnisLauschend: Sendable {
    /// Hört auf `<thema>/result`, führt `tat` aus und wartet danach höchstens
    /// `frist` Sekunden. `nil` heißt: keine Antwort — das Thema hat dann keine
    /// Route getroffen (§3.3), oder die Uhr war nicht zu erreichen.
    ///
    /// Gehört wird **vor** dem Senden: Die Uhr antwortet innerhalb von
    /// Millisekunden und hebt die Antwort nicht auf.
    func erwarten(thema: String, zugang: MQTTZugang, frist: TimeInterval,
                  waehrend tat: () throws -> Void) throws -> Data?
}

/// Der wirkliche Lauscher: eine eigene Verbindung zum Broker mit eigener
/// Kennung, weil ein Broker die Sitzung trennt, sobald dieselbe Kennung erneut
/// verbindet — und gesendet wird auf der Kennung des Absenders.
public struct MQTTErgebnislauscher: ErgebnisLauschend {
    /// So lange darf das Abonnement brauchen. Wird es nicht bestätigt, geht die
    /// Sendung trotzdem hinaus; das Ausbleiben der Antwort beweist dann nichts
    /// mehr, und der Absender meldet es als Warnung.
    private let abonnierfrist: TimeInterval

    public init(abonnierfrist: TimeInterval = 5) { self.abonnierfrist = abonnierfrist }

    public func erwarten(thema: String, zugang: MQTTZugang, frist: TimeInterval,
                         waehrend tat: () throws -> Void) throws -> Data? {
        try MQTTThemenlauscher(abonnierfrist: abonnierfrist, kennungszusatz: "-antwort")
            .erwarten(thema: NGThema.ergebnis(zu: thema), zugang: zugang, frist: frist, waehrend: tat)
    }
}
