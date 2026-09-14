import SwiftUI
import TC002Core
import TC002Modell

/// Wählt, **welche Uhr die App zeigt** — Vorschau, Geräterahmen, die fünf
/// Blöcke und der Zeit-Reiter beziehen sich auf sie.
///
/// **Das ist nicht das Sendeziel**, und genau diese Verwechslung hat die Wahl
/// hierhergebracht. Bis zum 14.09.2026 traf man sie nur unter „Einstellungen“,
/// an einem Punkt in der Uhrenzeile, der obendrein „Diese Uhr ist das Ziel beim
/// Senden“ behauptete. Wer dann in der Vorschau eine fremde Gerätefront sah,
/// suchte die Erklärung dort, wo etwas anderes stand.
///
/// Jetzt steht sie neben `ZielauswahlView` über der Vorschau: **ansehen**
/// links, **senden an** rechts. Nebeneinander erklärt sich der Unterschied
/// ohne einen Satz darüber — und das Auge ist ohnehin schon dort, weil die
/// Vorschau darunter liegt.
///
/// Erscheint wie `ZielauswahlView` erst ab zwei eingerichteten Uhren: Bei
/// einer ist die Wahl bedeutungslos, und ein Wähler mit einem Eintrag wäre
/// Fläche ohne Aussage.
struct AngeseheneUhrView: View {
    @Bindable var zustand: AppZustand

    /// Was der Knopf gerade zeigt. **Gebaut wie die Beschriftung von
    /// `ZielauswahlView`** („an: Küche“) — nebeneinander lesen sich die beiden
    /// dann als das Paar, das sie sind: *sieht* links, *an* rechts.
    ///
    /// Ein blosses Auge waere kuerzer, aber am iPad namenlos: Dort gibt es
    /// kein Mauszeigerschweben, ein Einblendtext bliebe unsichtbar. Ein
    /// ausgeschriebener Knopf braucht keinen.
    private var beschriftung: String {
        let name = zustand.aktiveUhr?.name ?? ""
        return lokf("sieht: %@", name)
    }

    var body: some View {
        if zustand.uhren.count > 1 {
            Menu(beschriftung) {
                Picker(selection: $zustand.aktiveID) {
                    ForEach(zustand.uhren) { uhr in
                        Text(uhr.name).tag(Optional(uhr.id))
                    }
                } label: { EmptyView() }
                .pickerStyle(.inline)
            }
            .menuStyle(.button)
            .knopfBefehl()
            .accessibilityLabel(Text("Angesehene Uhr"))
        }
    }
}
