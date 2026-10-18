import SwiftUI
import TC002Ansichten
import TC002Modell

/// Der Bereich „Klänge“ am Telefon: dieselbe Sammlung wie am Schreibtisch
/// (`Klangsammlungsansicht`), als Blatt mit „Fertig“. Aufgerufen aus dem
/// Titelmenü der Sendeansicht und aus dem Klangabschnitt einer Nachricht.
struct KlaengeblattiOS: View {
    @Bindable var zustand: AppZustand
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            Klangsammlungsansicht(zustand: zustand, kanon: .telefon)
                .navigationTitle("Klänge")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                } }
        }
        .task { zustand.alleAbfragen() }
        .presentationDragIndicator(.visible)
    }
}
