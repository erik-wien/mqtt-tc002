import Foundation
import TC002Core

/// Was aus einer Sendung geworden ist — an wie viele Uhren sie ging und an
/// wie viele sie gehen sollte.
///
/// Ein `Bool` reichte nicht mehr. Der Auftraggeber: *„Wenn User versucht eine
/// 16er Grafik an eine gemischte Gruppe von TC001 und TC002 zu schicken,
/// bekommt er statt dem grünen Haken einen gelben Haken plus Fehlermeldung in
/// der Nähe, dass die Grafik nur an TC002 geschickt werden konnte."* Dafür
/// muss die Ansicht „teilweise“ von „ganz“ unterscheiden können, und „ja/nein“
/// kennt diesen Fall nicht.
///
/// `ziele` ist die Zahl der Uhren, an die überhaupt gesendet wurde —
/// `AppZustand.ziele()` filtert vorher aus, was gar nicht beschickbar ist
/// (einer MQTT-Uhr fehlt das Präfix, einer HTTP-Uhr die Adresse); das steht
/// im Protokoll, nicht in dieser Zahl.
public struct Sendebilanz: Equatable, Sendable {
    /// Die Namen der Uhren, die es genommen haben.
    public let erreicht: [String]
    /// Wie viele es hätten nehmen sollen.
    public let ziele: Int

    public init(erreicht: [String], ziele: Int) {
        self.erreicht = erreicht
        self.ziele = ziele
    }

    /// Alle haben genommen.
    public var ganz: Bool { !erreicht.isEmpty && erreicht.count == ziele }

    /// Manche haben genommen, andere nicht — der Fall, für den es diesen Typ
    /// gibt.
    public var teilweise: Bool { !erreicht.isEmpty && erreicht.count < ziele }

    /// Nichts ist angekommen. Dann sagt die Fehlerleiste, woran es lag.
    public var nichts: Bool { erreicht.isEmpty }
}
