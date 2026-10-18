import SwiftUI
import TC002Ansichten
import TC002Core
import TC002Modell

/// Der Bereich „Uhr“ als Blatt, aus dem Titelmenü der Sendeansicht. Dieselbe
/// Ansicht wie am Schreibtisch (`Fernbedienung`); hier eine Spalte statt zwei, die
/// Wahl der Uhr im Titelmenü.
struct UhrblattiOS: View {
    @Bindable var zustand: AppZustand
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Eine Abweisung der Uhr muss man sehen, während das Blatt
                // offen ist; die Leiste der Sendeansicht liegt darunter.
                FehlerleisteiOS(zustand: zustand)
                Fernbedienung(zustand: zustand, kanon: .telefon)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { schliessen() }
            } }
        }
        .presentationDragIndicator(.visible)
    }
}
