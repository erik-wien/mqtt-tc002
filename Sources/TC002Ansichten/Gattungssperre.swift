import SwiftUI
import TC002Core

/// Einen Regler sperren, den die Geräteart gar nicht kennt — und sagen warum.
///
/// Zwei Achsen, zwei Stellen: Ob ein Regler zum gewählten Weg passt,
/// entscheidet die Ansicht selbst und hat es schon immer über `.disabled`
/// getan. Ob die Geräteart ihn überhaupt hergibt, entscheidet
/// `Geraetetyp.wirkt` im Kern. Beides greift nebeneinander: `.disabled` ist
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
    func gattungssperre(_ regler: Regler, _ art: Geraetetyp,
                        sonst gewohnt: String? = nil) -> some View {
        let grund = art.begruendung(regler)
        if let hinweis = grund ?? gewohnt {
            self.disabled(grund != nil).help(hinweis)
        } else {
            // Kein Grund und kein gewohnter Text: unverändert durchreichen.
            self
        }
    }
}
