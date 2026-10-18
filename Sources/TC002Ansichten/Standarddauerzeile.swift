import SwiftUI
import TC002Core
import TC002Modell

/// „Standard der Uhr: 7 s · Ändern …“ — der Wert, der gilt, wenn eine Anzeige
/// keine eigene Dauer nennt, und der Weg dorthin, wo man ihn ändert
/// (`AppZustand.anzeigedauerAendern`). Neben jedem Satz, der auf „die
/// Anzeigedauer der Uhr“ verweist.
///
/// Ohne bekannten Wert steht keine Zahl da: Die Einstellungen der Uhr werden
/// erst abgefragt, wenn sie jemand braucht, und eine geratene Zahl wäre falsch.
public struct Standarddauerzeile: View {
    @Bindable var zustand: AppZustand

    public init(zustand: AppZustand) {
        self.zustand = zustand
    }

    public var body: some View {
        LabeledContent {
            Button("Ändern …") { zustand.anzeigedauerAendern() }
                .buttonStyle(.automatic)
        } label: {
            Text(verbatim: titel)
        }
        .task(id: zustand.vorschauuhren().map(\.id)) {
            for uhr in zustand.vorschauuhren() where zustand.uhreneinstellungen[uhr.id] == nil {
                await zustand.zustandAbfragen(uhr.id)
            }
        }
    }

    private var titel: String {
        zustand.anzeigedauerDerZiele.map { lokf("Standard der Uhr: %@", $0) } ?? lok("Standard der Uhr")
    }
}
