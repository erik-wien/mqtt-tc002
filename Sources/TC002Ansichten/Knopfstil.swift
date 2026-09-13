import SwiftUI

/// Die drei Abstufungen, in denen Schaltflaechen dieser App auftreten — und
/// die Schrittwahl, die aus derselben Vorlage stammt
/// (`docs/superpowers/vorlagen/apple-inspektor.md`).
///
/// **Warum ueberhaupt ein eigener Ort.** Die Vorgabe (`.automatic`) sieht auf
/// den beiden Geraeten verschieden aus: Am Mac zeichnet sie in einer `Form`
/// einen gerahmten Knopf, unter iOS und iPadOS blosse Schrift in der
/// Akzentfarbe. Ein Befehl sah dort damit aus wie ein Verweis — „Radieren" wie
/// ein Link. Drei Aufrufe an einer Stelle statt hundert verstreuter
/// `.buttonStyle`-Zeilen halten das zusammen.
///
/// **Die Falle, die auf einem Geraet richtig und auf dem anderen falsch
/// aussieht.** `.bordered` faerbt die Beschriftung am Mac dunkel, unter iPadOS
/// dagegen in der Akzentfarbe — also blau, und damit wieder wie ein Verweis.
/// Die Vorlage (Pages-Inspektor) will dunkle Schrift auf grauem Grund. Abhilfe
/// ist `.tint(.primary)`, aber **nur ausserhalb von macOS**: Dort faerbt ein
/// Tint auch die Flaeche, und aus dem gewohnten Systemknopf wuerde ein dunkler
/// Kasten. Deshalb `knopfschrift()` und nicht ein Tint fuer beide.
public extension View {
    /// Ein gewoehnlicher Befehl: grauer abgerundeter Kasten, dunkle Schrift.
    func knopfBefehl() -> some View {
        buttonStyle(.bordered).knopfschrift()
    }

    /// Die **eine** Haupthandlung einer Ansicht — gefuellt in der Akzentfarbe.
    /// Mehr als eine je Ansicht hebt sich gegenseitig auf; welche es ist,
    /// steht bei der jeweiligen Ansicht.
    ///
    /// Kein `knopfschrift()`: Auf der gefuellten Flaeche steht die Schrift
    /// ohnehin weiss, und ein Tint wuerde hier die Flaeche selbst umfaerben.
    func knopfHaupthandlung() -> some View {
        buttonStyle(.borderedProminent)
    }

    /// Zerstoerend — dieselbe Fassung wie ein gewoehnlicher Befehl, rot
    /// getoent. Die Stellen tragen zusaetzlich `role: .destructive`: Der Tint
    /// macht es sichtbar, die Rolle sagt es der Sprachausgabe.
    func knopfZerstoerend() -> some View {
        buttonStyle(.bordered).tint(.red)
    }
}

private extension View {
    /// Siehe oben — der Unterschied zwischen Mac und iPadOS in einer Zeile.
    @ViewBuilder
    func knopfschrift() -> some View {
        #if os(macOS)
        self
        #else
        tint(.primary)
        #endif
    }
}
