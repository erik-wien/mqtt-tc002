import SwiftUI
import TC002Ansichten

/// Das Über-Blatt. Der Inhalt selbst ist geteilt (`UeberView` in
/// `TC002Ansichten`); hier kommt nur der Rahmen dazu, den ein Blatt am
/// Telefon braucht: Titelleiste und ein ausdrücklicher Weg hinaus, wie bei
/// „Format“ und „Verlauf“ auch.
struct UeberiOS: View {
    @Environment(\.dismiss) private var schliessen
    /// Als Seite im Stapel der Einstellungen: ohne eigenen Stapel, und der
    /// Rückweg ist der des Stapels.
    var eingebettet = false

    var body: some View {
        if eingebettet {
            inhalt
        } else {
            NavigationStack {
                inhalt
                    .toolbar { ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { schliessen() }
                    } }
            }
            .presentationDragIndicator(.visible)
        }
    }

    private var inhalt: some View {
        UeberView()
            .navigationTitle("Über Pixel Clock Messenger")
            .navigationBarTitleDisplayMode(.inline)
    }
}
