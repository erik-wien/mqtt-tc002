import Foundation

/// Auf wie vielen Punkten gerastert wird — Breite und Höhe der Anzeige,
/// als ein Wert.
///
/// Fest mit `Pixelfeld.breiteStandard`/`hoeheStandard`, also mit den 52 × 16
/// der Werksfirmware, zu rechnen ist für eine AWTRIX NG falsch: Ihre Anzeige
/// hat acht Zeilen, ein Sechzehn-Zeilen-Bild in einem auf 32 × 8 gezeichneten
/// Rahmen liesse rechts knapp ein Fünftel des Displayfeldes leer
/// (`docs/superpowers/specs/2026-09-15-vorschau-feldgroesse-design.md`
/// rechnet es vor).
///
/// Ein Wert und nicht zwei Zahlen. Wer `breite:` und `hoehe:` einzeln
/// durchreicht, vergisst eine davon an einer Stelle und rastert dann 52 breit
/// in ein Feld, das 32 ist — ein Fehler, der genau wie der jetzige aussähe und
/// schwerer zu finden wäre.
///
/// Die Zahlen selbst stehen nicht hier, sondern in `Uhr.anzeigemass`: Dort
/// gehören sie hin, weil dort die Gattung und die vom Gerät gemeldete
/// Panelbreite bekannt sind. `fuer(_:)` ist nur der Weg von dort hierher.
public struct Anzeigemass: Equatable, Sendable {
    public let breite: Int
    public let hoehe: Int

    public init(breite: Int, hoehe: Int) {
        self.breite = breite
        self.hoehe = hoehe
    }

    /// Die Werksfirmware — zugleich die Vorgabe überall dort, wo das Maß als
    /// Parameter durchgereicht wird. Damit bleibt jeder bestehende Aufruf
    /// wörtlich gleich, und die vorhandene Testreihe ist der Beweis, dass sich
    /// am Weg der TC002 nichts gerührt hat.
    public static let tc002 = Anzeigemass(breite: Pixelfeld.breiteStandard,
                                          hoehe: Pixelfeld.hoeheStandard)

    public static func fuer(_ uhr: Uhr) -> Anzeigemass {
        let mass = uhr.anzeigemass
        return Anzeigemass(breite: mass.breite, hoehe: mass.hoehe)
    }

    /// Wo ein quadratisches Icon senkrecht sitzt: mittig. Auf sechzehn Zeilen
    /// liegt ein 8×8 damit auf Zeile 4, ein 16×16 auf Zeile 0; auf acht Zeilen
    /// füllt das 8×8 die volle Höhe.
    public func iconY(kante: Int) -> Int { (hoehe - kante) / 2 }
}
