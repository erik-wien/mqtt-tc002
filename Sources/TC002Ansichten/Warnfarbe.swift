import SwiftUI

/// Die Farben für „es ist etwas nicht ganz gelungen“.
///
/// Systemgelb und Systemorange erreichen auf hellem Grund nur etwa 1,3:1
/// bzw. 2,2:1 — für Kleintext (WCAG AA verlangt 4,5:1) und für Symbole
/// (3:1) zu wenig. Es gibt in SwiftUI keine dynamische Farbe ohne `UIColor`/
/// `NSColor`, die hier nicht vorkommen dürfen; deshalb zwei feste Töne und
/// die Wahl nach Erscheinungsbild.
public enum Warnfarbe {
    /// Rot, Grün, Blau je 0…1 — als Zahlen, damit ein Test das
    /// Kontrastverhältnis nachrechnen kann.
    static let symbolRGB = [0.78, 0.42, 0.0]
    static let erfolgRGB = [0.12, 0.55, 0.25]
    static let textHellRGB = [0.58, 0.33, 0.0]

    /// Für Symbole und Flächen unter weißem Zeichen: ≥ 3:1 auf Weiß und auf
    /// Schwarz.
    public static let symbol = Color(red: symbolRGB[0], green: symbolRGB[1], blue: symbolRGB[2])
    /// Für gefüllte Kreise unter weißem Zeichen (Haken „angekommen“).
    public static let erfolg = Color(red: erfolgRGB[0], green: erfolgRGB[1], blue: erfolgRGB[2])
    /// Für Text auf hellem Grund: ≥ 4,5:1 auf Weiß und auf Gruppengrau.
    public static let textHell = Color(red: textHellRGB[0], green: textHellRGB[1], blue: textHellRGB[2])
    /// Für Text auf dunklem Grund: das Systemorange (≈ 9:1 auf Schwarz).
    public static let textDunkel = Color.orange
}

private struct Warntext: ViewModifier {
    @Environment(\.colorScheme) private var schema

    func body(content: Content) -> some View {
        content.foregroundStyle(schema == .dark ? Warnfarbe.textDunkel : Warnfarbe.textHell)
    }
}

extension View {
    /// Warn- und Hinweistext in einer Farbe, die in beiden Erscheinungsbildern
    /// lesbar bleibt (WCAG AA).
    public func warntext() -> some View {
        modifier(Warntext())
    }
}

extension View {
    /// Trefferfläche von mindestens 44 × 44 pt am Finger (HIG), ohne das
    /// Zeichen zu vergrößern. Am Mac bleibt die Größe des Zeichens: Mit dem
    /// Zeiger genügt sie, und die Zeilen des Inspektors sind eng.
    public func fingerflaeche() -> some View {
        #if os(iOS)
        self.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        #else
        self
        #endif
    }
}
