import Foundation

/// Der Ablauf eines Reglers, der eine Einstellung an die Uhr schickt: ziehen,
/// loslassen, senden, Bestätigung zeigen. Gesendet wird genau einmal je
/// Bewegung, beim Loslassen; Tastatur und VoiceOver melden kein Loslassen und
/// schließen ihre Bewegung über `ruhe()` ab.
public struct Reglerablauf: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case ruhig, gezogen, sendend, bestaetigt
    }

    /// Wie lange das Häkchen steht, bevor es ausblendet.
    public static let haekchendauer: Double = 1.5
    /// Ruhe nach der letzten Verstellung ohne Loslassen (Pfeiltasten,
    /// VoiceOver), bevor gesendet wird.
    public static let ruhefrist: Double = 0.5

    public private(set) var phase: Phase = .ruhig
    /// Der gezogene Wert; `nil`, solange der Wert der Uhr gilt.
    public private(set) var wert: Double?
    /// Ob der Zeiger oder Finger gerade auf dem Regler liegt.
    public private(set) var beruehrt = false

    public init() {}

    /// Der Regler meldet Beginn (`true`) oder Ende (`false`) des Ziehens.
    public mutating func bearbeitet(_ aktiv: Bool) {
        beruehrt = aktiv
    }

    /// Der Regler hat einen neuen Wert. Ein Wert während des Sendens ersetzt
    /// den gesendeten nicht: die Bewegung beginnt von vorn.
    public mutating func aendert(_ neu: Double) {
        wert = neu
        phase = .gezogen
    }

    /// Das Ziehen ist zu Ende: der Wert, der zu senden ist, oder `nil`, wenn
    /// nichts offen ist.
    public mutating func loslassen() -> Int? {
        beruehrt = false
        guard phase == .gezogen, let w = wert else { return nil }
        phase = .sendend
        return Int(w.rounded())
    }

    /// Nichts mehr geändert, seit `ruhefrist` verging, ohne dass jemand
    /// losgelassen hätte: Tastatur oder VoiceOver. Während des Ziehens sendet
    /// nur das Loslassen.
    public mutating func ruhe() -> Int? {
        guard !beruehrt else { return nil }
        return loslassen()
    }

    /// Die Uhr hat die Sendung angenommen (`true`) oder nicht. Nur für die
    /// Sendung, die noch offen ist: war inzwischen wieder gezogen worden,
    /// bleibt es beim Ziehen.
    public mutating func antwort(erfolg: Bool) {
        guard phase == .sendend else { return }
        if erfolg { phase = .bestaetigt } else { phase = .ruhig; wert = nil }
    }

    /// Das Häkchen ist ausgeblendet.
    public mutating func haekchenFertig() {
        if phase == .bestaetigt { phase = .ruhig }
    }

    /// Die Uhr meldet einen Stand: Er gilt wieder. Ein stehendes Häkchen
    /// und ein offenes Senden bleiben; ein laufendes Ziehen behält seinen Wert.
    public mutating func uhrMeldet() {
        if phase != .gezogen { wert = nil }
    }

    /// Eine andere Uhr: alles verwerfen.
    public mutating func zuruecksetzen() {
        self = Reglerablauf()
    }
}
