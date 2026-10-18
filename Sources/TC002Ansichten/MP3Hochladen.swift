import SwiftUI
import TC002Core
import TC002Modell

/// Eine MP3-Datei der Uhr in der Liste: Name und Größe, Löschen über das
/// Kontextmenü, am Zeiger zusätzlich über ein Zeichen, das erst unter dem Zeiger
/// erscheint, am Finger über Wischen.
struct MP3Zeile: View {
    let name: String
    let groesse: Int?
    var symbol = "waveform"
    let loeschen: () -> Void
    @State private var darueber = false

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                if let groesse {
                    Text(verbatim: ByteCountFormatter.string(fromByteCount: Int64(groesse), countStyle: .file))
                        .foregroundStyle(.secondary)
                }
                if darueber {
                    Button(role: .destructive, action: loeschen) { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(lok("Löschen"))
                }
            }
        } label: {
            Label { Text(verbatim: name) } icon: { Image(systemName: symbol) }
        }
        .onHover { darueber = $0 }
        .contextMenu {
            Button(lok("Löschen …"), role: .destructive, action: loeschen)
        }
        .swipeActions {
            Button(lok("Löschen …"), role: .destructive, action: loeschen)
        }
    }
}
