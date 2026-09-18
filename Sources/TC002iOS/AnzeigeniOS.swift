import SwiftUI
import TC002Core
import TC002Modell

/// Das Protokoll — die technische Mitschrift. Was auf der Uhr liegt, zeigen
/// die fünf Blöcke unter „Senden"; eine zweite Liste daneben war dieselbe
/// Auskunft an einer Stelle, an der sie niemand suchte.
struct AnzeigeniOS: View {
    @Bindable var zustand: AppZustand
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FehlerleisteiOS(zustand: zustand)
                List { protokollAbschnitt }
            }
            .navigationTitle("Protokoll")
            // Format- und Icon-Blatt haben "Fertig" bzw. "Abbrechen" in der
            // Titelleiste, dieses hatte nur den Greifer — uneinheitlich, und
            // ohne ausdruecklichen Weg hinaus.
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { schliessen() }
            } }
        }
        .presentationDragIndicator(.visible)
    }

    private var protokollAbschnitt: some View {
        Section {
            ForEach(Array(zustand.protokoll.enumerated()), id: \.offset) { _, zeile in
                Text(zeile).font(.system(.caption, design: .monospaced))
            }
        } header: {
            HStack {
                Text("Protokoll")
                Spacer()
                // Am Mac ist „Leeren" ein rot getoenter Befehlsknopf; hier
                // steht es im Kopf eines Listenabschnitts, und dort ist auf
                // dem Telefon blosse Schrift der Kanon (wie „Bearbeiten").
                // Rot getoent ist es trotzdem — es wirft weg.
                Button(role: .destructive) {
                    zustand.protokoll.removeAll()
                } label: {
                    Text("Leeren")
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.automatic)
                .tint(.red)
                .font(.caption)
            }
        }
    }
}
