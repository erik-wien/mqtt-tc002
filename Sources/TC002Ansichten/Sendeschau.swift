import SwiftUI
import TC002Core

/// Wie eine Sendung ausgegangen ist, so weit es das Sendezeichen angeht.
///
/// Drei Zustaende, nicht zwei. Der Auftraggeber: *„Wenn User versucht eine
/// 16er Grafik an eine gemischte Gruppe von TC001 und TC002 zu schicken,
/// bekommt er statt dem grünen Haken einen gelben Haken plus Fehlermeldung in
/// der Nähe, dass die Grafik nur an TC002 geschickt werden konnte."* Ein
/// gruener Haken fuer eine Sendung, die nur die Haelfte erreicht hat, waere
/// eine Zusage, die nicht stimmt.
///
/// Woran nichts haengt: der Fall, dass gar nichts ankam. Dann bleibt der
/// Pfeil stehen, und die Fehlerleiste sagt, woran es lag — ein Haken waere
/// dort in jeder Farbe falsch.
public enum Sendeschau: Equatable, Sendable {
    /// Noch nichts geschickt, oder nichts angekommen: der Pfeil.
    case offen
    /// Alle Zieluhren haben genommen.
    case ganz
    /// Manche haben genommen, andere nicht.
    case teilweise

    var farbe: AnyShapeStyle {
        switch self {
        case .offen: return AnyShapeStyle(.tint)
        case .ganz: return AnyShapeStyle(.green)
        // Gelb und nicht rot: Es ist etwas angekommen, nur nicht ueberall.
        case .teilweise: return AnyShapeStyle(.yellow)
        }
    }

    /// Was die Sprachausgabe sagt und der Einblendtext zeigt — `nil`, solange
    /// nichts geschickt wurde.
    var wort: String? {
        switch self {
        case .offen: return nil
        case .ganz: return lok("Hinausgeschickt")
        case .teilweise: return lok("Nur an manche Uhren hinausgeschickt")
        }
    }
}
