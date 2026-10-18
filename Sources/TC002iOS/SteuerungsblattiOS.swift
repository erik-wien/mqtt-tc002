import SwiftUI
import TC002Ansichten
import TC002Core
import TC002Modell

/// Die Fernbedienung der angesehenen Uhr als Blatt, aus dem Titelmenü der
/// Sendeansicht. Dieselbe Ansicht wie der Bereich „Uhr“ am Schreibtisch; hier
/// eine Spalte statt zwei.
struct SteuerungsblattiOS: View {
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
            .navigationTitle("Steuerung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { schliessen() }
            } }
        }
        .presentationDragIndicator(.visible)
    }
}

/// Die Uhrseite der angesehenen Uhr als Blatt: Name, Adresse, Betriebsart und
/// die Gruppen der gespeicherten Einstellungen — dieselbe Seite, die die
/// Einstellungen für jede Uhr zeigen.
///
/// Mit `start` geht das Blatt gleich auf einer Gruppe auf (`Einstellungsziel`).
struct UhreinstellungeniOS: View {
    @Bindable var zustand: AppZustand
    var start: Uhrgruppenziel?
    @Environment(\.dismiss) private var schliessen
    @State private var pfad = NavigationPath()

    var body: some View {
        NavigationStack(path: $pfad) {
            VStack(spacing: 0) {
                FehlerleisteiOS(zustand: zustand)
                if let id = start?.uhr ?? zustand.aktiveID {
                    Uhrseite(zustand: zustand, id: id, kanon: .telefon)
                }
            }
            .onAppear { if let start, pfad.isEmpty { pfad.append(start) } }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { schliessen() }
            } }
        }
        .presentationDragIndicator(.visible)
    }
}
