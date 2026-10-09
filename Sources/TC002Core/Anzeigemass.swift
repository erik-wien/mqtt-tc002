import Foundation

/// Auf wie vielen Punkten gerastert wird — Breite und Höhe der Anzeige,
/// als ein Wert.
///
/// Ein Wert und nicht zwei Zahlen. Wer `breite:` und `hoehe:` einzeln
/// durchreicht, vergisst eine davon an einer Stelle und rastert dann 52 breit
/// in ein Feld, das anders groß ist — ein Fehler, der schwer zu finden wäre.
///
/// Die Zahlen selbst stehen nicht hier, sondern in `Uhr.anzeigemass`: Dort
/// gehören sie hin, weil dort die von der Uhr gemeldete Größe bekannt ist.
/// `fuer(_:)` ist nur der Weg von dort hierher.
public struct Anzeigemass: Equatable, Sendable {
    public let breite: Int
    public let hoehe: Int

    public init(breite: Int, hoehe: Int) {
        self.breite = breite
        self.hoehe = hoehe
    }

    /// Die Vorgabe überall dort, wo das Maß als Parameter durchgereicht wird:
    /// das feste Raster der TC002, 52 × 16.
    public static let vorgabe = Anzeigemass(breite: Pixelfeld.breiteStandard,
                                            hoehe: Pixelfeld.hoeheStandard)

    public static func fuer(_ uhr: Uhr) -> Anzeigemass {
        let mass = uhr.anzeigemass
        return Anzeigemass(breite: mass.breite, hoehe: mass.hoehe)
    }

    /// Wo ein quadratisches Icon senkrecht sitzt: mittig. Auf sechzehn Zeilen
    /// liegt ein 8×8 damit auf Zeile 4, ein 16×16 auf Zeile 0.
    public func iconY(kante: Int) -> Int { (hoehe - kante) / 2 }
}
