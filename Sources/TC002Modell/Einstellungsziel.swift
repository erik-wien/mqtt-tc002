import Foundation
import TC002Core

/// Eine Stelle in den Einstellungen, zu der ein „Ändern …“ in der Sendeansicht
/// führt. Das Ziel ist hier fachlich benannt und nicht als Seite eines
/// bestimmten Bereichs: Welche Seite es heute ist, entscheidet allein die
/// Oberfläche (`Einstellungsziel.uhrgruppenziel` in `TC002Ansichten`).
public enum Einstellungsziel: Equatable, Sendable {
    /// Die Anzeigedauer der Uhr (`appDurationMs`).
    case anzeigedauer(uhr: UUID)
}

extension AppZustand {
    /// Die Anzeigedauer, die für die Zieluhren gilt, als Text; `nil`, solange
    /// keine von ihnen den Wert genannt hat.
    public var anzeigedauerDerZiele: String? {
        Anzeigedauerstandard.text(millisekunden: vorschauuhren().map {
            uhreneinstellungen[$0.id]?.ganzzahl(.appDurationMs)
        })
    }

    /// „Ändern …“ neben der Anzeigedauer der Uhr. Mit mehreren Zieluhren die
    /// angesehene, weil die Einstellungen eine Uhr zugleich zeigen.
    public func anzeigedauerAendern() {
        guard let uhr = referenzUhr else { return }
        einstellungsziel = .anzeigedauer(uhr: uhr.id)
    }
}
