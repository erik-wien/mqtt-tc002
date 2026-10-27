import SwiftUI
import TC002Ansichten
import TC002Core
import TC002Modell

/// Die Favoriten am Telefon: ein Tippen sendet, langes Drücken öffnet
/// Bearbeiten, Duplizieren, Umbenennen und Löschen. Bearbeiten und Duplizieren
/// führen in den Senden-Schirm zurück, das Blatt schließt sich.
struct FavoritenblattiOS: View {
    @Bindable var zustand: AppZustand
    @Environment(\.dismiss) private var schliessen
    @State private var umbenennen: Favorit?
    @State private var loeschen: Favorit?

    var body: some View {
        NavigationStack {
            List {
                let bestaende = Iconbestaende.mitMitgeliefertem()
                ForEach(zustand.favoriten) { f in
                    Favoritenzeile(zustand: zustand, favorit: f, bestaende: bestaende,
                                   oeffneSenden: { schliessen() })
                        .swipeActions {
                            Button("Löschen …", role: .destructive) { loeschen = f }
                        }
                }
            }
            .navigationTitle("Favoriten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { schliessen() }
            } }
            .favoritendialoge(zustand: zustand, umbenennen: $umbenennen, loeschen: $loeschen)
        }
        .presentationDragIndicator(.visible)
    }
}
