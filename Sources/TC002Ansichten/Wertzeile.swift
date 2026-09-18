import SwiftUI

/// Die Zeilen des Inspektors, wie Pages und Numbers sie zeigen
/// (`docs/superpowers/vorlagen/apple-inspektor.md`, „Zeilen"): Beschriftung
/// links, Wert rechts — und der Wert in einer von drei Formen, die Apple
/// sauber auseinanderhaelt und die man leicht in einen Topf wirft:
///
/// - Menuewahl (ein Wert aus einer Liste): der Wert in einem grauen,
///   abgerundeten Kaestchen, der Doppelpfeil darin. → `wertmenue()`.
/// - Weiterfuehrung (oeffnet eine Unterseite): blosser grauer Text,
///   dahinter ein einfacher Winkel `›`. Bei uns kommt das heute nicht vor —
///   aber es ist die Form, mit der die Menuewahl am leichtesten verwechselt
///   wird.
/// - Zahl mit Schrittwahl: der Wert im Kaestchen, `−│+` als ein Element
///   daneben. → `Schrittwahl`.
///
/// Ein blanker Text mit Doppelpfeil ist keines von dreien.
///
/// Die Menuewahl steht hier nicht: Ein blanker `Picker("Schriftart",
/// selection:)` in einem gruppierten `Form` zeichnet genau diese Zeile von
/// selbst — solange er nicht in `LabeledContent` mit `.labelsHidden()`
/// gewickelt wird, denn das nimmt ihm seine Standarddarstellung und laesst
/// ihn auf blanken Text zurueckfallen.
///
/// Was hier steht, steht hier, weil das System es nicht liefert.

/// Eine Zahl mit Schrittwahl, wie sie der Inspektor von Pages und Numbers
/// zeigt: Der Wert steht in einem eigenen grauen Kaestchen, daneben `−│+`
/// als ein zusammenhaengendes Element mit Trennstrich — nicht zwei
/// einzelne Knoepfe.
///
/// Warum ueberhaupt gebaut: Ein blanker `Stepper("Rand", value: $rand,
/// in: 0...3)` zeichnet Beschriftung und `−│+` von selbst, aber keinen
/// Wert — man saehe nicht, worauf der Rand steht. `Stepper(String(rand), …)`
/// loest das nicht: Es setzt die Zahl in die Beschriftungsstelle, wo sie
/// links statt rechts und ohne Fassung steht. Das Kaestchen ist der einzige
/// Teil, den es selbst zu bauen gibt.
///
/// Die Beschriftung wird durchgereicht und vom `Stepper` sofort wieder
/// versteckt: Sichtbar steht sie links in der Zeile (`LabeledContent`), fuer
/// die Sprachausgabe braucht das Bedienelement sie trotzdem. Weil sie als
/// `LocalizedStringKey` hereinkommt, traegt sie den deutschen Wortlaut als
/// Schluessel mit — nachgeschlagen wird also dasselbe Wort wie nebenan.
public struct Schrittwahl: View {
    private let beschriftung: LocalizedStringKey
    @Binding private var wert: Int
    private let bereich: ClosedRange<Int>

    public init(_ beschriftung: LocalizedStringKey, wert: Binding<Int>, bereich: ClosedRange<Int>) {
        self.beschriftung = beschriftung
        self._wert = wert
        self.bereich = bereich
    }

    public var body: some View {
        HStack(spacing: 6) {
            // `verbatim`: eine Zahl wird nicht uebersetzt, und ein
            // eingesetzter Wert waere ein Schluessel, den niemand nachschlaegt.
            Text(verbatim: String(wert))
                .monospacedDigit()
                .frame(minWidth: 14)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            Stepper(beschriftung, value: $wert, in: bereich)
                .labelsHidden()
        }
    }
}
