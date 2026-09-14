import SwiftUI
import TC002Ansichten

/// Das Über-Blatt. Der Inhalt selbst ist geteilt (`UeberView` in
/// `TC002Ansichten`); hier kommt nur der Rahmen dazu, den ein Blatt am
/// Telefon braucht: Titelleiste und ein ausdrücklicher Weg hinaus, wie bei
/// „Format“ und „Verlauf“ auch.
struct UeberiOS: View {
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            UeberView()
                .navigationTitle("Über Pixel Clock Messenger")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                } }
        }
        .presentationDragIndicator(.visible)
    }
}
