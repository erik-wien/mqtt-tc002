import SwiftUI
import TC002Core

/// Einen Regler sperren, den der gewählte Weg nicht kennt — und sagen warum.
/// Auf dem Pixelweg ist keiner gesperrt, bei „als Text" die, die NG nicht kennt.
///
/// Zwei Achsen, zwei Stellen: Ob ein Regler zum gewählten Weg passt,
/// entscheidet die Ansicht selbst und hat es schon immer über `.disabled`
/// getan. Ob die Firmware ihn überhaupt hergibt, entscheidet
/// `AwtrixNG.wirkt` im Kern. Beides greift nebeneinander: `.disabled` ist
/// kumulativ, ein zweites `true` weiter außen sperrt zusätzlich, und die
/// Ansicht behält ihre eigene Bedingung unverändert.
///
/// Der Einblendtext ist der Preis dafür, dass hier gesperrt und nicht
/// versteckt wird — die Bauart des Inspektors, im Quelltext von `SendenView`
/// begründet: Ein Abschnitt, der je nach Zustand erscheint und verschwindet,
/// lässt die Seitenleiste springen.
///
/// Was dieser Weg nicht löst: Am iPad und am iPhone gibt es kein
/// Mauszeigerschweben, der Grund bleibt dort also unsichtbar — ein gesperrter
/// Regler ohne erkennbaren Anlass. Das betrifft auch `fettWirkt` und
/// `kleinbuchstabenMoeglich`, hier nur mehr Zeilen. Eine sichtbare Fassung
/// davon ist eine eigene Entscheidung über die Oberfläche und steht im
/// Rückstandsdokument.
extension View {
    @ViewBuilder
    func reglersperre(_ regler: Regler, weg: SendeWeg, sonst gewohnt: String? = nil) -> some View {
        let grund = AwtrixNG.begruendung(regler, weg: weg)
        if let hinweis = grund ?? gewohnt {
            self.disabled(grund != nil).help(hinweis)
                // `.help` zeigt am iPad nichts; die Sprachausgabe bekommt den
                // Grund als Hinweis. Sichtbar für sehende Anwender am Finger
                // ist er damit nicht — das bleibt die offene Entscheidung
                // oben.
                .accessibilityHint(Text(hinweis))
        } else {
            // Kein Grund und kein gewohnter Text: unverändert durchreichen.
            self
        }
    }
}
