import SwiftUI

/// Die Fassung, die ein Eingabefeld sichtbar macht — derselbe Punkt wie bei
/// den Schaltflaechen, nur eine Stufe allgemeiner
/// (`docs/superpowers/vorlagen/apple-inspektor.md`, „Zeilen").
///
/// **Der Mangel war Auffindbarkeit, nicht Schoenheit.** Ohne Fassung zeigt
/// eine Zeile nur ihre Beschriftung; wo zu tippen ist, sieht man erst, wenn
/// man hineingeklickt hat. Bei „LaMetric-Nummer" stand die Beschriftung sogar
/// allein in der Zeile und las sich wie eine Ueberschrift. Im Vorbild
/// (Numbers, „Zeilen 18" / „Spalten 13") traegt jeder Wert sein graues,
/// abgerundetes Kaestchen rechts in der Zeile.
///
/// **Die Trennung verlaeuft nicht zwischen Mac und iPad**, sondern zwischen
/// **Inspektor** und **Blatt**: Beide Desktop-Oberflaechen zeigen denselben
/// Mangel, also gilt hier derselbe Aufruf fuer beide — kein `#if os(macOS)`
/// an jeder Stelle. Was auf dem iPhone in einer `Form` oder einem Blatt
/// steht, folgt dagegen dem dortigen Kanon (Beschriftung links, rechts
/// angeschlagener Wert ohne Kasten, wie in den Systemeinstellungen) und
/// bleibt unberuehrt.
public extension View {
    /// Grauer, abgerundeter Kasten um ein `TextField` oder `SecureField`.
    ///
    /// `.roundedBorder` und nicht eine selbstgezeichnete Fassung: Sie bringt
    /// Fokusring, Hoehe und Innenabstand des Systems mit, und die verschieben
    /// sich mit der eingestellten Textgroesse — eine nachgebaute Fassung
    /// taete das nicht.
    func eingabefeld() -> some View {
        textFieldStyle(.roundedBorder)
    }
}
